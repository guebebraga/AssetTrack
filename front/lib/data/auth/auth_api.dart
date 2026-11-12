import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'auth_session.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final response = await _post('/auth/v1/token?grant_type=password', {
      'email': email.trim(),
      'password': password,
    });
    return _sessionFrom(response);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    _ensureConfigured();
    final response = await _post('/auth/v1/token?grant_type=refresh_token', {
      'refresh_token': refreshToken,
    });
    return _sessionFrom(response);
  }

  Future<void> signOut(String accessToken) async {
    if (!AppConfig.hasSupabase) return;
    try {
      await _client.post(
        _uri('/auth/v1/logout'),
        headers: _headers(accessToken: accessToken),
      );
    } catch (_) {
      // El cierre local es suficiente si el servidor no responde.
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    late http.Response response;
    try {
      response = await _client
          .post(_uri(path), headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AuthException(
        'Supabase Auth no respondió. Revisá la conexión.',
      );
    } on SocketException {
      throw const AuthException(
        'No se pudo conectar con Supabase Auth. Revisá la conexión.',
      );
    } on http.ClientException {
      throw const AuthException(
        'No se pudo conectar con Supabase Auth. Revisá la conexión.',
      );
    }

    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_errorMessage(decoded, response.statusCode));
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AuthException(
        'Supabase Auth devolvió una respuesta inválida.',
      );
    }
    return decoded;
  }

  AuthSession _sessionFrom(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String? ?? '';
    final refreshToken = json['refresh_token'] as String? ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const AuthException('Supabase Auth no devolvió una sesión válida.');
    }
    final user = json['user'];
    final userMap = user is Map<String, dynamic> ? user : const {};
    final expiresIn = json['expires_in'];
    final expiresAt = json['expires_at'];
    final expiry = expiresAt is int
        ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
        : DateTime.now().add(
            Duration(seconds: expiresIn is int ? expiresIn : 3600),
          );
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userMap['id'] as String? ?? '',
      email: userMap['email'] as String? ?? '',
      expiresAt: expiry,
    );
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.supabaseUrl}$path');

  Map<String, String> _headers({String? accessToken}) => {
    'apikey': AppConfig.supabaseAnonKey,
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      for (final key in const [
        'msg',
        'message',
        'error_description',
        'error',
      ]) {
        final value = decoded[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    if (statusCode == 400) return 'Correo o contraseña incorrectos.';
    if (statusCode == 401) return 'La sesión venció. Iniciá sesión de nuevo.';
    return 'Supabase Auth devolvió un error ($statusCode).';
  }

  void _ensureConfigured() {
    if (!AppConfig.hasSupabase) {
      throw const AuthException(
        'Faltan SUPABASE_URL y SUPABASE_ANON_KEY en la compilación.',
      );
    }
  }
}
