import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync_feedback.dart';
import '../../core/top_toast.dart';
import '../../data/logs/log_manager.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';

class SyncFeedbackPresenter {
  SyncFeedbackPresenter({
    required AppBootstrapAdapter bootstrapAdapter,
    required WidgetRef ref,
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<State<StatefulWidget>> mainHomePageKey,
    required bool Function() isMounted,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _ref = ref,
       _navigatorKey = navigatorKey,
       _mainHomePageKey = mainHomePageKey,
       _isMounted = isMounted;

  final AppBootstrapAdapter _bootstrapAdapter;
  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  final GlobalKey<State<StatefulWidget>> _mainHomePageKey;
  final bool Function() _isMounted;

  void showAutoSyncFeedbackToast({required bool succeeded}) {
    final language = _bootstrapAdapter.readPreferences(_ref).language;
    final message = buildAutoSyncFeedbackMessage(
      language: language,
      succeeded: succeeded,
    );
    var delivered = false;
    var retryScheduled = false;

    void emit({required String phase, bool allowRetry = false}) {
      if (delivered) return;
      final homeContext = _mainHomePageKey.currentContext;
      final navigatorContext = _navigatorKey.currentContext;
      final overlayContext =
          homeContext ??
          navigatorContext ??
          _navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null) {
        LogManager.instance.info(
          'AutoSync: feedback_toast_skipped_no_context',
          context: <String, Object?>{
            'phase': phase,
            'succeeded': succeeded,
            'message': message,
          },
        );
        return;
      }
      final channel = showSyncFeedback(
        overlayContext: overlayContext,
        messengerContext: navigatorContext ?? homeContext,
        language: language,
        succeeded: succeeded,
        message: message,
      );
      final event = switch (channel) {
        SyncFeedbackChannel.snackbar => 'AutoSync: feedback_snackbar_shown',
        SyncFeedbackChannel.toast => 'AutoSync: feedback_toast_shown',
        SyncFeedbackChannel.skipped =>
          'AutoSync: feedback_toast_skipped_no_overlay',
      };
      LogManager.instance.info(
        event,
        context: <String, Object?>{
          'phase': phase,
          'succeeded': succeeded,
          'message': message,
          'hasHomeContext': homeContext != null,
          'hasNavigatorContext': navigatorContext != null,
        },
      );
      if (channel != SyncFeedbackChannel.skipped) {
        delivered = true;
      }
      if (allowRetry &&
          channel == SyncFeedbackChannel.skipped &&
          !retryScheduled) {
        retryScheduled = true;
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (!_isMounted()) return;
          emit(phase: 'delayed_retry', allowRetry: false);
        });
      }
    }

    emit(phase: 'immediate', allowRetry: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      emit(phase: 'next_frame', allowRetry: true);
    });
  }

  void showAutoSyncProgressToast() {
    final language = _bootstrapAdapter.readPreferences(_ref).language;
    final message = buildAutoSyncProgressMessage(language: language);
    final homeContext = _mainHomePageKey.currentContext;
    final navigatorContext = _navigatorKey.currentContext;
    final overlayContext =
        homeContext ??
        navigatorContext ??
        _navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) {
      LogManager.instance.info(
        'AutoSync: progress_toast_skipped_no_context',
        context: <String, Object?>{
          'message': message,
          'hasHomeContext': homeContext != null,
          'hasNavigatorContext': navigatorContext != null,
        },
      );
      return;
    }

    var shown = showTopToast(
      overlayContext,
      message,
      duration: const Duration(seconds: 2),
      topOffset: 96,
    );
    if (!shown &&
        navigatorContext != null &&
        !identical(overlayContext, navigatorContext)) {
      shown = showTopToast(
        navigatorContext,
        message,
        duration: const Duration(seconds: 2),
        topOffset: 96,
      );
    }

    LogManager.instance.info(
      shown
          ? 'AutoSync: progress_toast_shown'
          : 'AutoSync: progress_toast_skipped_no_overlay',
      context: <String, Object?>{
        'message': message,
        'hasHomeContext': homeContext != null,
        'hasNavigatorContext': navigatorContext != null,
      },
    );
  }
}
