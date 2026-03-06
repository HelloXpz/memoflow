import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../data/db/database_registry.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/system/logging_provider.dart';
import 'desktop_quick_input_controller.dart';
import 'desktop_tray_controller.dart';

class DesktopExitCoordinator with WindowListener {
  static const Duration _closeSubWindowsStepTimeout = Duration(seconds: 2);
  static const Duration _listSubWindowsTimeout = Duration(milliseconds: 400);
  static const Duration _subWindowExitSignalTimeout = Duration(
    milliseconds: 350,
  );
  static const Duration _subWindowCloseTimeout = Duration(milliseconds: 800);

  DesktopExitCoordinator._({
    required WidgetRef ref,
    required DesktopQuickInputController quickInputController,
  }) : _ref = ref,
       _quickInputController = quickInputController;

  static DesktopExitCoordinator? _instance;

  final WidgetRef _ref;
  final DesktopQuickInputController _quickInputController;
  bool _listenerAttached = false;
  bool _exiting = false;
  Completer<void>? _exitCompleter;

  static DesktopExitCoordinator? get instance => _instance;
  static bool get isReady => _instance != null;

  static DesktopExitCoordinator init({
    required WidgetRef ref,
    required DesktopQuickInputController quickInputController,
  }) {
    _instance = DesktopExitCoordinator._(
      ref: ref,
      quickInputController: quickInputController,
    );
    return _instance!;
  }

  static Future<void> requestClose({String? source}) async {
    final instance = _instance;
    if (instance == null) return;
    await instance._requestClose(source: source);
  }

  static Future<void> requestExit({String? reason, bool force = false}) async {
    final instance = _instance;
    if (instance == null) return;
    await instance._requestExit(reason: reason, force: force);
  }

  static Future<void> activateMainWindow() async {
    final instance = _instance;
    if (instance == null) return;
    await instance._activateMainWindow();
  }

  Future<void> attachWindowListener() async {
    if (_listenerAttached || kIsWeb || !Platform.isWindows) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _listenerAttached = true;
  }

  Future<void> dispose() async {
    if (_listenerAttached) {
      windowManager.removeListener(this);
      _listenerAttached = false;
    }
  }

  @override
  void onWindowClose() {
    if (_exiting) return;
    unawaited(_requestClose(source: 'window_close'));
  }

  Future<void> _requestClose({String? source}) async {
    if (kIsWeb || !Platform.isWindows) {
      await windowManager.close();
      return;
    }
    if (_exiting) return;
    final closeToTray = _ref.read(
      appPreferencesProvider.select((p) => p.windowsCloseToTray),
    );
    if (closeToTray && DesktopTrayController.instance.supported) {
      try {
        await DesktopTrayController.instance.hideToTray();
        return;
      } catch (error, stackTrace) {
        _ref
            .read(logManagerProvider)
            .warn(
              'Hide to tray failed. Falling back to exit.',
              error: error,
              stackTrace: stackTrace,
            );
      }
    }
    await _requestExit(reason: source ?? 'close', force: false);
  }

  Future<void> _requestExit({String? reason, bool force = false}) async {
    if (_exiting) {
      await _exitCompleter?.future;
      return;
    }
    _exiting = true;
    final completer = Completer<void>();
    _exitCompleter = completer;
    unawaited(_forceExitAfterTimeout());
    unawaited(_performExit(reason: reason, force: force).whenComplete(() {
      if (!completer.isCompleted) completer.complete();
    }));
    await completer.future;
  }

  Future<void> _performExit({String? reason, bool force = false}) async {
    if (!kIsWeb && Platform.isWindows) {
      _ref.read(logManagerProvider).info(
        'Desktop exit requested',
        context: {'reason': reason ?? 'unknown', 'force': force},
      );
    }
    await _runExitStep(
      'close_sub_windows',
      _closeSubWindows,
      timeout: _closeSubWindowsStepTimeout,
    );
    await _runExitStep(
      'unregister_hotkey',
      () => _quickInputController.unregisterHotKey(),
    );
    await _runExitStep(
      'dispose_tray',
      () => DesktopTrayController.instance.dispose(),
    );
    await _runExitStep('close_databases', DatabaseRegistry.closeAll);
    await _runExitStep(
      'disable_prevent_close',
      () => windowManager.setPreventClose(false),
    );
    await _runExitStep('close_main_window', () => windowManager.close());
  }

  Future<void> _closeSubWindows() async {
    List<int> ids = const <int>[];
    try {
      ids = await DesktopMultiWindow.getAllSubWindowIds().timeout(
        _listSubWindowsTimeout,
        onTimeout: () => const <int>[],
      );
    } catch (_) {}
    final closeTasks = <Future<void>>[];
    for (final id in ids) {
      if (id <= 0) continue;
      closeTasks.add(_closeSubWindow(id));
    }
    if (closeTasks.isEmpty) return;
    await Future.wait(closeTasks);
  }

  Future<void> _closeSubWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        id,
        desktopSubWindowExitMethod,
        null,
      ).timeout(_subWindowExitSignalTimeout);
    } catch (_) {}

    try {
      await WindowController.fromWindowId(id)
          .close()
          .timeout(_subWindowCloseTimeout);
    } catch (_) {}
  }

  Future<void> _activateMainWindow() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      } else {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (_) {}
    try {
      await DesktopTrayController.instance.showFromTray();
    } catch (_) {}
  }

  Future<void> _forceExitAfterTimeout() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_exiting) return;
    exit(0);
  }

  Future<void> _runExitStep(
    String name,
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    try {
      await action().timeout(timeout);
    } catch (error, stackTrace) {
      try {
        _ref.read(logManagerProvider).warn(
              'Exit step failed: $name',
              error: error,
              stackTrace: stackTrace,
            );
      } catch (_) {}
    }
  }
}
