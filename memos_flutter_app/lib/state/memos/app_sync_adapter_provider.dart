import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/models/app_preferences.dart';
import '../local_library_provider.dart';
import '../preferences_provider.dart';
import '../session_provider.dart';
import '../sync_coordinator_provider.dart';

final appSyncAdapterProvider = Provider<AppSyncAdapter>((ref) {
  return AppSyncAdapter(ref);
});

class AppSyncAdapter {
  AppSyncAdapter(this._ref);

  final Ref _ref;

  AppPreferences readPreferences() => _ref.read(appPreferencesProvider);

  AppSessionState? readSession() =>
      _ref.read(appSessionProvider).valueOrNull;

  bool hasLocalLibrary() =>
      _ref.read(currentLocalLibraryProvider) != null;

  Future<void> refreshCurrentUser() =>
      _ref.read(appSessionProvider.notifier).refreshCurrentUser();

  Future<void> requestSync(SyncRequest request) =>
      _ref.read(syncCoordinatorProvider.notifier).requestSync(request);
}
