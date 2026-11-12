class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final DateTime expiresAt;

  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) => AuthSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    userId: userId,
    email: email,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'email': email,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    userId: json['userId'] as String? ?? '',
    email: json['email'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now(),
  );
}
