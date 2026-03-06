import 'app_database.dart';

class DatabaseRegistry {
  DatabaseRegistry._();

  static final Set<AppDatabase> _databases = <AppDatabase>{};

  static void register(AppDatabase db) {
    _databases.add(db);
  }

  static void unregister(AppDatabase db) {
    _databases.remove(db);
  }

  static Future<void> closeAll() async {
    final snapshot = _databases.toList(growable: false);
    for (final db in snapshot) {
      try {
        await db.close();
      } catch (_) {}
    }
    _databases.clear();
  }
}
