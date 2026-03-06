import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_read.dart';

final appSessionStorageErrorProvider =
    StateProvider<StorageLoadError?>((ref) => null);

final appPreferencesStorageErrorProvider =
    StateProvider<StorageLoadError?>((ref) => null);

final localLibraryStorageErrorProvider =
    StateProvider<StorageLoadError?>((ref) => null);

final storageLoadErrorProvider = Provider<StorageLoadError?>((ref) {
  return ref.watch(appSessionStorageErrorProvider) ??
      ref.watch(appPreferencesStorageErrorProvider) ??
      ref.watch(localLibraryStorageErrorProvider);
});

final storageLoadHasErrorProvider = Provider<bool>((ref) {
  return ref.watch(storageLoadErrorProvider) != null;
});
