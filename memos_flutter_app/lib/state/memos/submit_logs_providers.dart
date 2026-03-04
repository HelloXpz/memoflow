import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/api/memo_api_version.dart';
import '../system/database_provider.dart';
import '../system/local_library_provider.dart';
import '../system/logging_provider.dart';
import '../system/session_provider.dart';
import '../sync/sync_coordinator_provider.dart';
part 'submit_logs_controller.dart';

final submitLogsControllerProvider = Provider<SubmitLogsController>((ref) {
  return SubmitLogsController(ref);
});