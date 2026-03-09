import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/access_boundary/access_boundary.dart';
import 'package:memos_flutter_app/access_boundary/access_decision.dart';
import 'package:memos_flutter_app/access_boundary/app_capability.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/features/settings/settings_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/module_boundary/settings_entry_contribution.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  Widget buildTestApp({PrivateExtensionBundle? bundle}) {
    LocaleSettings.setLocale(AppLocale.en);
    return ProviderScope(
      overrides: [
        appSessionProvider.overrideWith((ref) => _TestSessionController()),
        appPreferencesProvider.overrideWith(
          (ref) => _TestAppPreferencesController(ref),
        ),
        currentLocalLibraryProvider.overrideWith((ref) => null),
        if (bundle != null)
          privateExtensionBundleProvider.overrideWithValue(bundle),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const SettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('keeps donation entry and removes crown UI by default', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final donationFinder = find.byIcon(Icons.bolt_outlined);
    await tester.scrollUntilVisible(
      donationFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(donationFinder, findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.text('Private Entry'), findsNothing);
  });

  testWidgets(
    'renders bundle supplied settings entries without capability checks',
    (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          bundle: _FakePrivateExtensionBundle(onTap: () => tapped = true),
        ),
      );
      await tester.pumpAndSettle();

      final donationFinder = find.byIcon(Icons.bolt_outlined);
      await tester.scrollUntilVisible(
        donationFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Private Entry'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(donationFinder, findsOneWidget);
      expect(find.text('Private Entry'), findsOneWidget);
      expect(find.text('Bundle supplied entry'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

      await tester.tap(find.text('Private Entry'));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );
}

class _FakePrivateExtensionBundle implements PrivateExtensionBundle {
  _FakePrivateExtensionBundle({required this.onTap});

  final VoidCallback onTap;

  @override
  AccessBoundary get diagnosticsAccessBoundary =>
      const _DisabledAccessBoundary();

  @override
  Future<void> onAppReady(WidgetRef ref) async {}

  @override
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      SettingsEntryContribution(
        id: 'private-entry',
        order: 10,
        icon: Icons.extension,
        titleBuilder: (_) => 'Private Entry',
        subtitleBuilder: (_) => 'Bundle supplied entry',
        onTap: onTap,
      ),
    ];
  }
}

class _DisabledAccessBoundary implements AccessBoundary {
  const _DisabledAccessBoundary();

  @override
  AccessDecision decisionFor(AppCapability capability) {
    return const AccessDecision.disabled('test');
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
      );

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository()
    : super(const FlutterSecureStorage(), accountKey: null);

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<AppPreferences> read() async {
    return AppPreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<void> write(AppPreferences prefs) async {}

  @override
  Future<void> clear() async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref)
    : super(
        ref,
        _TestAppPreferencesRepository(),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );
}
