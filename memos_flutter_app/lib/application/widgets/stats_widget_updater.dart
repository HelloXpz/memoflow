import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../features/settings/widgets_service.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';

class StatsWidgetUpdater {
  StatsWidgetUpdater({
    required AppBootstrapAdapter bootstrapAdapter,
    required bool Function() isMounted,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _isMounted = isMounted;

  final AppBootstrapAdapter _bootstrapAdapter;
  final bool Function() _isMounted;
  bool _statsWidgetUpdating = false;
  String? _statsWidgetAccountKey;

  void scheduleUpdate(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      unawaited(updateIfNeeded(ref));
    });
  }

  Future<void> updateIfNeeded(WidgetRef ref, {bool force = false}) async {
    if (_statsWidgetUpdating) return;
    final session = _bootstrapAdapter.readSession(ref);
    final account = session?.currentAccount;
    if (account == null) return;
    if (!force && _statsWidgetAccountKey == account.key) return;

    _statsWidgetUpdating = true;
    try {
      final api = _bootstrapAdapter.readMemosApi(ref);
      final stats = await api.getUserStatsSummary(userName: account.user.name);
      final days = _buildHeatmapDays(stats.memoDisplayTimes, dayCount: 14);
      final language = _bootstrapAdapter.readPreferences(ref).language;
      await HomeWidgetService.updateStatsWidget(
        total: stats.totalMemoCount,
        days: days,
        title: trByLanguageKey(
          language: language,
          key: 'legacy.msg_activity_heatmap',
        ),
        totalLabel: trByLanguageKey(
          language: language,
          key: 'legacy.msg_total',
        ),
        rangeLabel: trByLanguageKey(
          language: language,
          key: 'legacy.msg_last_14_days',
        ),
      );
      _statsWidgetAccountKey = account.key;
    } catch (_) {
      // Ignore widget updates if the backend isn't reachable.
    } finally {
      _statsWidgetUpdating = false;
    }
  }

  List<int> _buildHeatmapDays(
    List<DateTime> timestamps, {
    required int dayCount,
  }) {
    final counts = List<int>.filled(dayCount, 0);
    if (dayCount <= 0) return counts;

    final now = DateTime.now();
    final endDay = DateTime(now.year, now.month, now.day);
    final startDay = endDay.subtract(Duration(days: dayCount - 1));

    for (final ts in timestamps) {
      final local = ts.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final index = day.difference(startDay).inDays;
      if (index < 0 || index >= dayCount) continue;
      counts[index] = counts[index] + 1;
    }
    return counts;
  }
}