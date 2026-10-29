import '../core/storage/local_store.dart';
import '../domain/models.dart';

class AppRepository {
  AppRepository(this._store);

  final LocalStore _store;

  Future<AppState?> load() async {
    final data = await _store.read();
    if (data == null) return null;
    try {
      final snapshot = AppSnapshot.fromJson(data);
      if (snapshot.assets.isEmpty) return null;
      return AppState.fromSnapshot(snapshot);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AppState state) async {
    await _store.write(state.toSnapshot().toJson());
  }

  Future<void> clear() => _store.clear();
}
