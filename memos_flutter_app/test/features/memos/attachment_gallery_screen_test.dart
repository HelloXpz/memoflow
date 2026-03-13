import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/attachment_gallery_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

Widget _buildTestApp(Widget child, {AppLocale locale = AppLocale.zhHans}) {
  LocaleSettings.setLocale(locale);
  return TranslationProvider(
    child: MaterialApp(
      locale: locale.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  testWidgets('desktop gallery supports keyboard and click navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
            AttachmentImageSource(
              id: 'second',
              title: 'Second',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);

    final pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(pageRect.left + 40, pageRect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('escape closes pushed gallery route', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AttachmentGalleryScreen(
                          images: [
                            AttachmentImageSource(
                              id: 'only',
                              title: 'Only',
                              mimeType: 'image/png',
                            ),
                          ],
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('1/1'), findsNothing);
  });

  testWidgets('double tap resets image zoom to default scale', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    final viewerBefore = tester.widget<InteractiveViewer>(viewerFinder);
    viewerBefore.transformationController!.value = Matrix4.diagonal3Values(
      2,
      2,
      1,
    );
    await tester.pump();

    final pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(pageRect.center);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(pageRect.center);
    await tester.pumpAndSettle();

    final viewerAfter = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewerAfter.transformationController!.value.getMaxScaleOnAxis(), 1);
  });
}
