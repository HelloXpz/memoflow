import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_html_sanitizer.dart';

void main() {
  test(
    'sanitizeMemoHtml removes blocked tags comments and dangerous links',
    () {
      const html =
          '<!-- note -->'
          '<script>alert(1)</script>'
          '<style>body{display:none;}</style>'
          '<p>safe</p>'
          '<a href="javascript:alert(1)">bad</a>';

      final sanitized = sanitizeMemoHtml(html);

      expect(sanitized, contains('<p>safe</p>'));
      expect(sanitized, isNot(contains('<!--')));
      expect(sanitized, isNot(contains('<script')));
      expect(sanitized, isNot(contains('<style')));
      expect(sanitized, isNot(contains('javascript:')));
      expect(sanitized, isNot(contains('<a href="javascript:alert(1)">')));
    },
  );

  test(
    'sanitizeMemoHtml preserves safe urls checkbox inputs and allowed attrs',
    () {
      const html =
          '<a href="/docs" title="Doc">docs</a>'
          '<a href="mailto:test@example.com">mail</a>'
          '<img src="https://example.com/a.png" width="16" onclick="bad">'
          '<input type="checkbox" checked disabled onclick="bad">';

      final sanitized = sanitizeMemoHtml(html);

      expect(sanitized, contains('<a href="/docs" title="Doc">docs</a>'));
      expect(sanitized, contains('<a href="mailto:test@example.com">mail</a>'));
      expect(
        sanitized,
        contains('<img src="https://example.com/a.png" width="16">'),
      );
      expect(
        sanitized,
        contains('<input type="checkbox" checked="" disabled="">'),
      );
      expect(sanitized, isNot(contains('onclick=')));
    },
  );
}
