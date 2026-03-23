import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/markdown_editing.dart';

TextEditingValue _value(String text, {required TextSelection selection}) {
  return TextEditingValue(text: text, selection: selection);
}

void main() {
  group('wrapMarkdownSelection', () {
    test(
      'unwraps when the selected content is already wrapped by matching markers',
      () {
        final value = wrapMarkdownSelection(
          _value(
            '**hello**',
            selection: const TextSelection(baseOffset: 2, extentOffset: 7),
          ),
          prefix: '**',
          suffix: '**',
        );

        expect(value.text, 'hello');
        expect(
          value.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5),
        );
      },
    );

    test('unwraps when the full wrapped range is selected', () {
      final value = wrapMarkdownSelection(
        _value(
          '~~hello~~',
          selection: const TextSelection(baseOffset: 0, extentOffset: 9),
        ),
        prefix: '~~',
        suffix: '~~',
      );

      expect(value.text, 'hello');
      expect(
        value.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    });

    test('unwraps when the cursor is inside matching wrapped content', () {
      final value = wrapMarkdownSelection(
        _value(
          '<u>hello</u>',
          selection: const TextSelection.collapsed(offset: 5),
        ),
        prefix: '<u>',
        suffix: '</u>',
      );

      expect(value.text, 'hello');
      expect(value.selection, const TextSelection.collapsed(offset: 2));
    });

    test(
      'unwraps an empty wrapper when the cursor is between inserted markers',
      () {
        final value = wrapMarkdownSelection(
          _value('====', selection: const TextSelection.collapsed(offset: 2)),
          prefix: '==',
          suffix: '==',
        );

        expect(value.text, '');
        expect(value.selection, const TextSelection.collapsed(offset: 0));
      },
    );

    test('does not confuse bold markers as italic wrappers', () {
      final value = wrapMarkdownSelection(
        _value(
          '**hello**',
          selection: const TextSelection(baseOffset: 2, extentOffset: 7),
        ),
        prefix: '*',
        suffix: '*',
      );

      expect(value.text, '***hello***');
      expect(
        value.selection,
        const TextSelection(baseOffset: 2, extentOffset: 9),
      );
    });

    test(
      'unwraps an empty bold wrapper when the cursor is between inserted markers',
      () {
        final value = wrapMarkdownSelection(
          _value('****', selection: const TextSelection.collapsed(offset: 2)),
          prefix: '**',
          suffix: '**',
        );

        expect(value.text, '');
        expect(value.selection, const TextSelection.collapsed(offset: 0));
      },
    );
  });

  group('selectedLogicalParagraphs', () {
    test('finds the logical paragraph for a collapsed cursor', () {
      const text = 'first line\nsecond line\n\nthird';

      final paragraphs = selectedLogicalParagraphs(
        text,
        const TextSelection.collapsed(offset: 8),
      );

      expect(paragraphs, hasLength(1));
      expect(
        text.substring(paragraphs.single.start, paragraphs.single.end),
        'first line\nsecond line',
      );
    });

    test('collects every paragraph intersecting an expanded selection', () {
      const text = 'first\n\nsecond\n\nthird';

      final paragraphs = selectedLogicalParagraphs(
        text,
        const TextSelection(baseOffset: 1, extentOffset: 13),
      );

      expect(
        paragraphs
            .map((paragraph) => text.substring(paragraph.start, paragraph.end))
            .toList(),
        <String>['first', 'second'],
      );
    });
  });

  group('toggleBlockStyle', () {
    test(
      'inserts heading prefix at a blank new line instead of restyling the previous paragraph',
      () {
        const text = '==abc==\n';

        final value = toggleBlockStyle(
          _value(text, selection: TextSelection.collapsed(offset: text.length)),
          MarkdownBlockStyle.heading1,
        );

        expect(value.text, '==abc==\n# ');
        expect(value.selection, const TextSelection.collapsed(offset: 10));
      },
    );

    test(
      'toggles unordered lists from a cursor in the middle of a paragraph',
      () {
        const text = 'first line\nsecond line\n\nthird';

        final listed = toggleBlockStyle(
          _value(text, selection: const TextSelection.collapsed(offset: 7)),
          MarkdownBlockStyle.unorderedList,
        );
        expect(listed.text, '- first line\nsecond line\n\nthird');

        final plain = toggleBlockStyle(
          listed,
          MarkdownBlockStyle.unorderedList,
        );
        expect(plain.text, text);
      },
    );

    test('replaces headings instead of stacking them', () {
      final converted = toggleBlockStyle(
        _value('# Title', selection: const TextSelection.collapsed(offset: 3)),
        MarkdownBlockStyle.heading2,
      );
      expect(converted.text, '## Title');

      final plain = toggleBlockStyle(converted, MarkdownBlockStyle.heading2);
      expect(plain.text, 'Title');
    });

    test('quotes and unquotes every line in a logical paragraph', () {
      const text = 'line 1\nline 2\n\nnext';

      final quoted = toggleBlockStyle(
        _value(text, selection: const TextSelection.collapsed(offset: 2)),
        MarkdownBlockStyle.quote,
      );
      expect(quoted.text, '> line 1\n> line 2\n\nnext');

      final plain = toggleBlockStyle(quoted, MarkdownBlockStyle.quote);
      expect(plain.text, text);
    });

    test(
      'still uses logical paragraph toggling when there is text before the cursor',
      () {
        const text = 'abc';

        final value = toggleBlockStyle(
          _value(text, selection: const TextSelection.collapsed(offset: 2)),
          MarkdownBlockStyle.heading2,
        );

        expect(value.text, '## abc');
      },
    );
  });

  test(
    'insertBlockSnippet preserves block boundaries around inserted content',
    () {
      final inserted = insertBlockSnippet(
        _value(
          'before\nafter',
          selection: const TextSelection.collapsed(offset: 6),
        ),
        '---',
        caretOffset: 3,
      );

      expect(inserted.text, 'before\n\n---\n\nafter');
      expect(inserted.selection, const TextSelection.collapsed(offset: 11));
    },
  );

  group('cutParagraphs', () {
    test(
      'cuts a middle paragraph and leaves one blank line between neighbors',
      () {
        const text = 'first\n\nsecond line\nsecond 2\n\nthird';

        final result = cutParagraphs(
          _value(text, selection: const TextSelection.collapsed(offset: 10)),
        );

        expect(result, isNotNull);
        expect(result!.copiedText, 'second line\nsecond 2');
        expect(result.value.text, 'first\n\nthird');
        expect(
          result.value.selection,
          const TextSelection.collapsed(offset: 5),
        );
      },
    );

    test('cuts multiple selected paragraphs and preserves copied spacing', () {
      const text = 'first\n\nsecond\n\nthird';

      final result = cutParagraphs(
        _value(
          text,
          selection: const TextSelection(baseOffset: 1, extentOffset: 13),
        ),
      );

      expect(result, isNotNull);
      expect(result!.copiedText, 'first\n\nsecond');
      expect(result.value.text, 'third');
      expect(result.value.selection, const TextSelection.collapsed(offset: 0));
    });
  });
}
