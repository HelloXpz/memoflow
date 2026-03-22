import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_capture_formatter.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';

void main() {
  group('buildShareCaptureMemoText', () {
    test('prefers article title and absolutizes links and images', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
        title: 'Shared Title',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        pageTitle: 'Page Title',
        articleTitle: 'Article Title',
        siteName: 'Example',
        excerpt: 'Short summary',
        contentHtml: '<div><h2>Body</h2><a href="/about">About</a><img src="/cover.png"></div>',
        readabilitySucceeded: true,
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, startsWith('# Article Title'));
      expect(text, contains('[Example](https://example.com/posts/42)'));
      expect(text, contains('> Short summary'));
      expect(text, contains('href="https://example.com/about"'));
      expect(text, contains('src="https://example.com/cover.png"'));
      expect(text.toLowerCase(), isNot(contains('<html')));
      expect(text.toLowerCase(), isNot(contains('<body')));
    });

    test('omits excerpt block when excerpt is absent', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        siteName: 'Example',
        contentHtml: '<p>Hello</p>',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, isNot(contains('> ')));
    });

    test('falls back to text paragraphs when html content is absent', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        textContent: 'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, contains('<p>First paragraph.</p>'));
      expect(text, contains('<p>Second paragraph.</p>'));
      expect(text, contains('<p>Third paragraph.</p>'));
    });
  });
}
