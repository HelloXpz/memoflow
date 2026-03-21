import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';

void main() {
  group('buildShareTextDraft', () {
    test('uses explicit title from payload when available', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/article',
        title: 'Example Article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[Example Article](https://example.com/article)');
      expect(draft.selectionOffset, draft.text.length);
    });

    test('derives title from shared browser text', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'Example Article\nhttps://example.com/article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[Example Article](https://example.com/article)');
      expect(draft.selectionOffset, draft.text.length);
    });

    test('keeps empty link label when only url is shared', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[](https://example.com/article)');
      expect(draft.selectionOffset, 1);
    });

    test('keeps plain text when there is no url', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'just some text',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, 'just some text');
      expect(draft.selectionOffset, draft.text.length);
    });
  });

  test('SharePayload.fromArgs normalizes title', () {
    final payload = SharePayload.fromArgs(<String, Object?>{
      'type': 'text',
      'text': 'https://example.com/article',
      'title': '  Example   Article  ',
    });

    expect(payload, isNotNull);
    expect(payload!.title, 'Example Article');
  });
}
