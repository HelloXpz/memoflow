import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access_boundary/access_boundary.dart';
import '../module_boundary/settings_entry_contribution.dart';

abstract interface class PrivateExtensionBundle {
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  );

  Future<void> onAppReady(WidgetRef ref);

  AccessBoundary get diagnosticsAccessBoundary;
}
