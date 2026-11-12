import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/auth/auth_api.dart';
import '../data/auth/auth_session.dart';
import '../data/auth/token_store.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    if (AppConfig.authDisabled) return _devSession();
    final store = ref.watch(tokenStoreProvider);
    final saved = await store.read();
    if (saved == null) return null;
    if (!saved.needsRefresh) return saved;
    try {
      final refreshed = await ref
          .read(authApiProvider)
          .refresh(saved.refreshToken);
      await store.write(refreshed);
      return refreshed;
    } on AuthException {
      await store.clear();
      return null;
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final session = await ref
          .read(authApiProvider)
          .signIn(email: email, password: password);
      await ref.read(tokenStoreProvider).write(session);
      state = AsyncData(session);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'No se pudo iniciar sesión: $error';
    }
  }

  Future<void> signOut() async {
    final current = state.value;
    if (current != null && !AppConfig.authDisabled) {
      await ref.read(authApiProvider).signOut(current.accessToken);
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (AppConfig.authDisabled) return null;
    final current = state.value;
    if (current == null) return null;
    if (!forceRefresh && !current.needsRefresh) return current.accessToken;
    try {
      final refreshed = await ref
          .read(authApiProvider)
          .refresh(current.refreshToken);
      await ref.read(tokenStoreProvider).write(refreshed);
      state = AsyncData(refreshed);
      return refreshed.accessToken;
    } on AuthException {
      await ref.read(tokenStoreProvider).clear();
      state = const AsyncData(null);
      return null;
    }
  }

  AuthSession _devSession() => AuthSession(
    accessToken: '',
    refreshToken: '',
    userId: 'dev-user',
    email: 'desarrollo@local',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
  );
}
