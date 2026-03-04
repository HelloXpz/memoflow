import 'package:flutter/material.dart';

import '../data/models/app_preferences.dart';
import 'app_localization.dart';

enum SyncFeedbackChannel { snackbar, toast, skipped }

String buildSyncFeedbackMessage({
  required AppLanguage language,
  required bool succeeded,
}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  if (succeeded) {
    return switch (effective) {
      AppLanguage.zhHans => '\u540c\u6b65\u5b8c\u6210',
      AppLanguage.zhHantTw => '\u540c\u6b65\u5b8c\u6210',
      AppLanguage.ja => '\u540c\u671f\u5b8c\u4e86',
      AppLanguage.de => 'Synchronisierung abgeschlossen',
      AppLanguage.en => 'Sync completed',
      AppLanguage.system => 'Sync completed',
    };
  }
  return switch (effective) {
    AppLanguage.zhHans => '\u540c\u6b65\u5931\u8d25',
    AppLanguage.zhHantTw => '\u540c\u6b65\u5931\u6557',
    AppLanguage.ja => '\u540c\u671f\u5931\u6557',
    AppLanguage.de => 'Synchronisierung fehlgeschlagen',
    AppLanguage.en => 'Sync failed',
    AppLanguage.system => 'Sync failed',
  };
}

String buildAutoSyncProgressMessage({required AppLanguage language}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  return switch (effective) {
    AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u4e2d...',
    AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u4e2d...',
    AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u4e2d...',
    AppLanguage.de => 'Automatische Synchronisierung l\u00e4uft...',
    AppLanguage.en => 'Auto sync in progress...',
    AppLanguage.system => 'Auto sync in progress...',
  };
}

String buildAutoSyncFeedbackMessage({
  required AppLanguage language,
  required bool succeeded,
}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  if (succeeded) {
    return switch (effective) {
      AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u5b8c\u6210',
      AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u5b8c\u6210',
      AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u5b8c\u4e86',
      AppLanguage.de => 'Automatische Synchronisierung abgeschlossen',
      AppLanguage.en => 'Auto sync completed',
      AppLanguage.system => 'Auto sync completed',
    };
  }
  return switch (effective) {
    AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u5931\u8d25',
    AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u5931\u6557',
    AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u5931\u6557',
    AppLanguage.de => 'Automatische Synchronisierung fehlgeschlagen',
    AppLanguage.en => 'Auto sync failed',
    AppLanguage.system => 'Auto sync failed',
  };
}

