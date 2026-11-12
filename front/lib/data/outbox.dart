import '../core/storage/local_store.dart';

class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    this.query,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, String>? query;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  PendingMutation copyWith({int? attempts, String? lastError}) =>
      PendingMutation(
        id: id,
        method: method,
        path: path,
        body: body,
        query: query,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'path': path,
    'body': body,
    'query': query,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  factory PendingMutation.fromJson(Map<String, dynamic> json) =>
      PendingMutation(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        body: json['body'] is Map<String, dynamic>
            ? json['body'] as Map<String, dynamic>
            : null,
        query: (json['query'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}

class OutboxRepository {
  OutboxRepository(this._store);

  static const _key = 'items';
  final LocalStore _store;

  Future<List<PendingMutation>> read() async {
    final data = await _store.read();
    if (data == null) return [];
    final raw = data[_key];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PendingMutation.fromJson)
        .toList();
  }

  Future<void> add(PendingMutation mutation) async {
    final items = await read();
    items.add(mutation);
    await _write(items);
  }

  Future<void> remove(String id) async {
    final items = await read()
      ..removeWhere((item) => item.id == id);
    await _write(items);
  }

  Future<void> replace(PendingMutation mutation) async {
    final items = await read();
    final index = items.indexWhere((item) => item.id == mutation.id);
    if (index >= 0) items[index] = mutation;
    await _write(items);
  }

  Future<void> clear() => _store.clear();

  Future<void> _write(List<PendingMutation> items) =>
      _store.write({_key: items.map((item) => item.toJson()).toList()});
}
