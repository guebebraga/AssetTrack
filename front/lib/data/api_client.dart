import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/utils/ids.dart';
import '../domain/enums.dart';
import '../domain/models.dart';

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiNetworkException extends ApiException {
  const ApiNetworkException([
    super.message =
        'Sin conexión con el servidor. Se usarán los datos locales.',
  ]);
}

class ApiMutationResult {
  const ApiMutationResult({
    required this.success,
    required this.message,
    required this.state,
  });

  final bool success;
  final String message;
  final AppSnapshot state;
}

class Me {
  const Me({
    required this.userId,
    required this.role,
    required this.organizationId,
    this.fullName,
  });

  final String userId;
  final UserRole role;
  final String organizationId;
  final String? fullName;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    userId: json['userId'] as String? ?? '',
    role: _roleFrom(json['role']),
    organizationId: json['organizationId'] as String? ?? '',
    fullName: json['fullName'] as String?,
  );

  static UserRole _roleFrom(dynamic raw) {
    for (final role in UserRole.values) {
      if (role.name == raw) return role;
    }
    return UserRole.viewer;
  }
}

class RfidReadResult {
  const RfidReadResult({
    required this.success,
    required this.message,
    required this.recognised,
    required this.duplicate,
    required this.ambiguous,
    this.assetId,
  });

  final bool success;
  final String message;
  final bool recognised;
  final bool duplicate;
  final bool ambiguous;
  final String? assetId;

  factory RfidReadResult.fromJson(Map<String, dynamic> json) => RfidReadResult(
    success: json['success'] as bool? ?? false,
    message: json['message'] as String? ?? '',
    recognised: json['recognised'] as bool? ?? false,
    duplicate: json['duplicate'] as bool? ?? false,
    ambiguous: json['ambiguous'] as bool? ?? false,
    assetId: json['assetId'] as String?,
  );
}

class RfidReadsResponse {
  const RfidReadsResponse({required this.results, required this.state});

  final List<RfidReadResult> results;
  final AppSnapshot state;
}

class ApiClient {
  ApiClient({required this.tokenProvider, http.Client? client})
    : client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client client;

  Future<Me> me() async {
    final response = await _send('GET', '/api/v1/me');
    return Me.fromJson(_object(response));
  }

  Future<AppSnapshot> getState() async {
    final response = await _send('GET', '/api/v1/state');
    return AppSnapshot.fromJson(_object(response));
  }

  Future<ApiMutationResult> mutate({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    final response = await _send(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey ?? newId('IDEM'),
    );
    final json = _object(response);
    final result = json['result'];
    final state = json['state'];
    if (result is! Map<String, dynamic> || state is! Map<String, dynamic>) {
      throw const ApiException(
        'El servidor devolvió una respuesta incompleta.',
      );
    }
    return ApiMutationResult(
      success: result['success'] as bool? ?? false,
      message: result['message'] as String? ?? '',
      state: AppSnapshot.fromJson(state),
    );
  }

  Future<RfidReadsResponse> sendRfidReads(
    List<Map<String, dynamic>> reads,
  ) async {
    final response = await _send(
      'POST',
      '/api/v1/rfid/reads',
      body: reads,
      idempotencyKey: newId('IDEM'),
    );
    final json = _object(response);
    final rawResults = json['results'];
    final state = json['state'];
    if (rawResults is! List || state is! Map<String, dynamic>) {
      throw const ApiException(
        'El servidor devolvió una respuesta incompleta.',
      );
    }
    return RfidReadsResponse(
      results: rawResults
          .whereType<Map<String, dynamic>>()
          .map(RfidReadResult.fromJson)
          .toList(),
      state: AppSnapshot.fromJson(state),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? idempotencyKey,
    bool allowRetry = true,
  }) async {
    final token = await tokenProvider(forceRefresh: false);
    final response = await _sendOnce(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
      token: token,
    );
    if (response.statusCode == 401 && allowRetry && !AppConfig.authDisabled) {
      final refreshed = await tokenProvider(forceRefresh: true);
      if (refreshed != null) {
        return _sendOnce(
          method,
          path,
          body: body,
          query: query,
          idempotencyKey: idempotencyKey,
          token: refreshed,
        );
      }
    }
    return response;
  }

  Future<http.Response> _sendOnce(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? idempotencyKey,
    String? token,
  }) async {
    var uri = Uri.parse('${AppConfig.normalizedApiBaseUrl}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) request.body = jsonEncode(body);

    late http.StreamedResponse streamed;
    try {
      streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiNetworkException(
        'El servidor tardó demasiado en responder. Se usarán los datos locales.',
      );
    } on SocketException {
      throw const ApiNetworkException();
    } on http.ClientException {
      throw const ApiNetworkException();
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    final message = _errorMessage(response);
    if (response.statusCode == 401) {
      throw ApiException(message, statusCode: 401);
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _object(http.Response response) {
    final decoded = _decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException('El servidor devolvió una respuesta inválida.');
  }

  dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(http.Response response) {
    final decoded = _decode(response.body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (response.statusCode == 401) {
      return 'La sesión venció. Iniciá sesión de nuevo.';
    }
    if (response.statusCode == 403) {
      return 'No tenés permisos para realizar esta acción.';
    }
    return 'El servidor devolvió un error (${response.statusCode}).';
  }
}
