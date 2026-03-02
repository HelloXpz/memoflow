import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';

part 'flomo_import_controller.dart';

typedef FlomoImportDatabase = AppDatabase;

final flomoImportControllerProvider = Provider<FlomoImportController>((ref) {
  return const FlomoImportController();
});