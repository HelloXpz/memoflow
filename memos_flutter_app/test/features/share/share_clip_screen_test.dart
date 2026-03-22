import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_capture_engine.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_clip_screen.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  late SharePayload payload;

  setUp(() {
    payload = const SharePayload(
      type: SharePayloadType.text,
      text: 'Interesting Article https://example.com/articles/1',
      title: 'Interesting Article',
    );
  });

  testWidgets('shows loading then returns compose request on save', (
    WidgetTester tester,
  ) async {
    final engine = _CompleterShareCaptureEngine(
      ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        articleTitle: 'Interesting Article',
        siteName: 'Example',
        excerpt: 'Summary',
        contentHtml: '<p>Hello world</p>',
        readabilitySucceeded: true,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    final routeFuture = navigatorKey.currentState!.push<ShareComposeRequest>(
      MaterialPageRoute<ShareComposeRequest>(
        builder: (_) => ShareClipScreen(payload: payload, engine: engine),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Loading page'), findsWidgets);

    engine.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocale.en.build().strings.legacy.msg_save_memo));
    await tester.pumpAndSettle();

    final result = await routeFuture;
    expect(result, isNotNull);
    expect(result!.text, contains('# Interesting Article'));
    expect(result.text, contains('<p>Hello world</p>'));
  });

  testWidgets('returns link-only compose request when capture fails', (
    WidgetTester tester,
  ) async {
    final engine = _FakeShareCaptureEngine(
      result: ShareCaptureResult.failure(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        failure: ShareCaptureFailure.parserEmpty,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    final routeFuture = navigatorKey.currentState!.push<ShareComposeRequest>(
      MaterialPageRoute<ShareComposeRequest>(
        builder: (_) => ShareClipScreen(payload: payload, engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Link Only'));
    await tester.pumpAndSettle();

    final result = await routeFuture;
    expect(result, isNotNull);
    expect(
      result!.text,
      '[Interesting Article](https://example.com/articles/1)',
    );
  });

  testWidgets('retry triggers capture again after a failure', (
    WidgetTester tester,
  ) async {
    final engine = _SequencedFakeShareCaptureEngine([
      ShareCaptureResult.failure(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        failure: ShareCaptureFailure.parserEmpty,
      ),
      ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        articleTitle: 'Interesting Article',
        siteName: 'Example',
        contentHtml: '<p>Hello again</p>',
      ),
    ]);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));
    unawaited(navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShareClipScreen(payload: payload, engine: engine),
      ),
    ));
    await tester.pumpAndSettle();

    expect(engine.callCount, 1);
    await tester.tap(find.text(AppLocale.en.build().strings.legacy.msg_retry));
    await tester.pumpAndSettle();

    expect(engine.callCount, 2);
    expect(find.text(AppLocale.en.build().strings.legacy.msg_save_memo), findsOneWidget);
  });
}

Widget _buildTestApp({required GlobalKey<NavigatorState> navigatorKey}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      navigatorKey: navigatorKey,
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

class _FakeShareCaptureEngine implements ShareCaptureEngine {
  _FakeShareCaptureEngine({required this.result});

  final ShareCaptureResult result;

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    onStageChanged?.call(ShareCaptureStage.loadingPage);
    await Future<void>.delayed(Duration.zero);
    onStageChanged?.call(ShareCaptureStage.buildingPreview);
    return result;
  }
}

class _CompleterShareCaptureEngine implements ShareCaptureEngine {
  _CompleterShareCaptureEngine(this.result);

  final ShareCaptureResult result;
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    onStageChanged?.call(ShareCaptureStage.loadingPage);
    await _completer.future;
    onStageChanged?.call(ShareCaptureStage.buildingPreview);
    return result;
  }
}

class _SequencedFakeShareCaptureEngine implements ShareCaptureEngine {
  _SequencedFakeShareCaptureEngine(this._results);

  final List<ShareCaptureResult> _results;
  int callCount = 0;

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    callCount += 1;
    onStageChanged?.call(ShareCaptureStage.loadingPage);
    await Future<void>.delayed(Duration.zero);
    onStageChanged?.call(ShareCaptureStage.buildingPreview);
    final index = (callCount - 1).clamp(0, _results.length - 1);
    return _results[index];
  }
}
