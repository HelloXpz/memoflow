import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/api/memo_api_version.dart';
import '../database_provider.dart';
import '../local_library_provider.dart';
import '../logging_provider.dart';
import '../session_provider.dart';
import '../sync_coordinator_provider.dart';

part 'submit_logs_controller.dart';

final submitLogsControllerProvider = Provider<SubmitLogsController>((ref) {
  return SubmitLogsController(ref);
});