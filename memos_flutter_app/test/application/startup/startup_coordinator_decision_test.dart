import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/startup/startup_coordinator.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';

void main() {
  group('StartupCoordinator decision helpers', () {
    test('selects share before widget and launch action', () {
      final action = StartupCoordinator.debugSelectStartupActionName(
        hasPendingShare: true,
        hasPendingWidget: true,
        launchAction: LaunchAction.quickInput,
      );
      final reason = StartupCoordinator.debugSelectStartupReason(
        hasPendingShare: true,
        hasPendingWidget: true,
        launchAction: LaunchAction.quickInput,
      );

      expect(action, 'share');
      expect(reason, 'pending_share');
    });

    test('selects widget when no pending share exists', () {
      final action = StartupCoordinator.debugSelectStartupActionName(
        hasPendingShare: false,
        hasPendingWidget: true,
        launchAction: LaunchAction.dailyReview,
      );
      final reason = StartupCoordinator.debugSelectStartupReason(
        hasPendingShare: false,
        hasPendingWidget: true,
        launchAction: LaunchAction.dailyReview,
      );

      expect(action, 'widget');
      expect(reason, 'pending_widget');
    });

    test('selects prefs launch action when no pending startup sources exist', () {
      final action = StartupCoordinator.debugSelectStartupActionName(
        hasPendingShare: false,
        hasPendingWidget: false,
        launchAction: LaunchAction.quickInput,
      );
      final reason = StartupCoordinator.debugSelectStartupReason(
        hasPendingShare: false,
        hasPendingWidget: false,
        launchAction: LaunchAction.quickInput,
      );

      expect(action, 'launchAction');
      expect(reason, 'prefs_launch_action');
    });

    test('evaluates share block reasons in priority order', () {
      expect(
        StartupCoordinator.debugEvaluateShareBlockReason(
          prefsLoaded: false,
          hasAccount: true,
          hasNavigator: true,
          hasContext: true,
        ),
        'prefs_not_loaded',
      );
      expect(
        StartupCoordinator.debugEvaluateShareBlockReason(
          prefsLoaded: true,
          hasAccount: false,
          hasNavigator: true,
          hasContext: true,
        ),
        'no_account',
      );
      expect(
        StartupCoordinator.debugEvaluateShareBlockReason(
          prefsLoaded: true,
          hasAccount: true,
          hasNavigator: false,
          hasContext: true,
        ),
        'no_navigator',
      );
      expect(
        StartupCoordinator.debugEvaluateShareBlockReason(
          prefsLoaded: true,
          hasAccount: true,
          hasNavigator: true,
          hasContext: false,
        ),
        'no_context',
      );
    });

    test('evaluates widget block reasons', () {
      expect(
        StartupCoordinator.debugEvaluateWidgetBlockReason(
          hasWorkspace: false,
          hasNavigator: true,
          hasContext: true,
        ),
        'no_workspace',
      );
      expect(
        StartupCoordinator.debugEvaluateWidgetBlockReason(
          hasWorkspace: true,
          hasNavigator: false,
          hasContext: true,
        ),
        'no_navigator',
      );
      expect(
        StartupCoordinator.debugEvaluateWidgetBlockReason(
          hasWorkspace: true,
          hasNavigator: true,
          hasContext: false,
        ),
        'no_context',
      );
    });

    test('retries only navigator and context readiness reasons', () {
      expect(StartupCoordinator.debugShouldRetryForReason('no_navigator'), isTrue);
      expect(StartupCoordinator.debugShouldRetryForReason('no_context'), isTrue);
      expect(StartupCoordinator.debugShouldRetryForReason('prefs_not_loaded'), isFalse);
      expect(StartupCoordinator.debugShouldRetryForReason('no_account'), isFalse);
      expect(StartupCoordinator.debugShouldRetryForReason('no_workspace'), isFalse);
    });
  });
}
