import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/logs/log_manager.dart';
import '../../data/models/app_preferences.dart';
import '../auth/login_screen.dart';
import 'home_screen.dart';
import '../onboarding/language_selection_screen.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';

class MainHomePage extends ConsumerStatefulWidget {
  const MainHomePage({super.key});

  @override
  ConsumerState<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends ConsumerState<MainHomePage> {
  String? _lastRouteDecisionKey;

  void _logRouteDecision({
    required bool prefsLoaded,
    required bool hasSelectedLanguage,
    required String sessionState,
    required String? sessionKey,
    required bool hasCurrentAccount,
    required bool hasLocalLibrary,
    required String destination,
  }) {
    if (!kDebugMode) return;
    final key =
        '$prefsLoaded|$hasSelectedLanguage|$sessionState|$sessionKey|$hasCurrentAccount|$hasLocalLibrary|$destination';
    if (_lastRouteDecisionKey == key) return;
    _lastRouteDecisionKey = key;
    LogManager.instance.info(
      'RouteGate: main_home_decision',
      context: <String, Object?>{
        'prefsLoaded': prefsLoaded,
        'hasSelectedLanguage': hasSelectedLanguage,
        'sessionState': sessionState,
        'sessionKey': sessionKey,
        'hasCurrentAccount': hasCurrentAccount,
        'hasLocalLibrary': hasLocalLibrary,
        'destination': destination,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adapter = ref.read(appBootstrapAdapterProvider);
    final prefsLoaded = adapter.watchPreferencesLoaded(ref);
    final prefs = adapter.watchPreferences(ref);
    final sessionAsync = adapter.watchSession(ref);
    final session = sessionAsync.valueOrNull;
    final localLibrary = adapter.watchCurrentLocalLibrary(ref);

    if (!prefsLoaded) {
      _logRouteDecision(
        prefsLoaded: false,
        hasSelectedLanguage: prefs.hasSelectedLanguage,
        sessionState: sessionAsync.isLoading
            ? 'loading'
            : (sessionAsync.hasError ? 'error' : 'data'),
        sessionKey: session?.currentKey,
        hasCurrentAccount: session?.currentAccount != null,
        hasLocalLibrary: localLibrary != null,
        destination: 'splash',
      );
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const SizedBox.expand(),
      );
    }
    if (!prefs.hasSelectedLanguage) {
      _logRouteDecision(
        prefsLoaded: true,
        hasSelectedLanguage: false,
        sessionState: sessionAsync.isLoading
            ? 'loading'
            : (sessionAsync.hasError ? 'error' : 'data'),
        sessionKey: session?.currentKey,
        hasCurrentAccount: session?.currentAccount != null,
        hasLocalLibrary: localLibrary != null,
        destination: 'onboarding',
      );
      return const LanguageSelectionScreen();
    }

    return sessionAsync.when(
      data: (session) {
        final hasCurrentAccount = session.currentAccount != null;
        final hasLocalLibrary = localLibrary != null;
        final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
        final showOnboarding =
            !hasWorkspace &&
            (prefs.onboardingMode == null ||
                prefs.onboardingMode == AppOnboardingMode.local);
        final needsLogin =
            !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'data',
          sessionKey: session.currentKey,
          hasCurrentAccount: hasCurrentAccount,
          hasLocalLibrary: hasLocalLibrary,
          destination: showOnboarding
              ? 'onboarding'
              : (needsLogin ? 'login' : 'home'),
        );
        if (showOnboarding) return const LanguageSelectionScreen();
        return needsLogin ? const LoginScreen() : const HomeScreen();
      },
      loading: () {
        if (session != null) {
          final hasCurrentAccount = session.currentAccount != null;
          final hasLocalLibrary = localLibrary != null;
          final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
          final showOnboarding =
              !hasWorkspace &&
              (prefs.onboardingMode == null ||
                  prefs.onboardingMode == AppOnboardingMode.local);
          final needsLogin =
              !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
          _logRouteDecision(
            prefsLoaded: true,
            hasSelectedLanguage: prefs.hasSelectedLanguage,
            sessionState: 'loading_with_cached',
            sessionKey: session.currentKey,
            hasCurrentAccount: hasCurrentAccount,
            hasLocalLibrary: hasLocalLibrary,
            destination: showOnboarding
                ? 'onboarding'
                : (needsLogin ? 'login' : 'home'),
          );
          if (showOnboarding) return const LanguageSelectionScreen();
          return needsLogin ? const LoginScreen() : const HomeScreen();
        }
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'loading_without_cached',
          sessionKey: null,
          hasCurrentAccount: false,
          hasLocalLibrary: localLibrary != null,
          destination: 'splash',
        );
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const SizedBox.expand(),
        );
      },
      error: (e, _) {
        if (session != null) {
          final hasCurrentAccount = session.currentAccount != null;
          final hasLocalLibrary = localLibrary != null;
          final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
          final showOnboarding =
              !hasWorkspace &&
              (prefs.onboardingMode == null ||
                  prefs.onboardingMode == AppOnboardingMode.local);
          final needsLogin =
              !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
          _logRouteDecision(
            prefsLoaded: true,
            hasSelectedLanguage: prefs.hasSelectedLanguage,
            sessionState: 'error_with_cached',
            sessionKey: session.currentKey,
            hasCurrentAccount: hasCurrentAccount,
            hasLocalLibrary: hasLocalLibrary,
            destination: showOnboarding
                ? 'onboarding'
                : (needsLogin ? 'login' : 'home'),
          );
          if (showOnboarding) return const LanguageSelectionScreen();
          return needsLogin ? const LoginScreen() : const HomeScreen();
        }
        final showOnboarding =
            prefs.onboardingMode == null ||
            prefs.onboardingMode == AppOnboardingMode.local;
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'error_without_cached',
          sessionKey: null,
          hasCurrentAccount: false,
          hasLocalLibrary: localLibrary != null,
          destination: showOnboarding ? 'onboarding' : 'login_error',
        );
        if (showOnboarding) return const LanguageSelectionScreen();
        return LoginScreen(initialError: e.toString());
      },
    );
  }
}