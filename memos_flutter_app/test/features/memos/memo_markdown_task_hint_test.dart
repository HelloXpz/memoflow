import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';

void main() {
  test('stripTaskListToggleHint keeps title and removes hint suffix', () {
    const content = '任务列表（可点击切换）\n- [ ] 未完成任务\n- [x] 已完成任务';

    expect(stripTaskListToggleHint(content), '任务列表\n- [ ] 未完成任务\n- [x] 已完成任务');
  });

  test('stripTaskListToggleHint keeps unrelated lines unchanged', () {
    const content = '任务列表\n- [ ] 未完成任务';

    expect(stripTaskListToggleHint(content), content);
  });

  testWidgets('MemoMarkdown renders task list title without hint suffix', (
    WidgetTester tester,
  ) async {
    const content = '任务列表（可点击切换）\n- [ ] 未完成任务\n- [x] 已完成任务';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, isNot(contains('任务列表（可点击切换）')));
    expect(rendered, contains('任务列表'));
    expect(rendered, contains('未完成任务'));
    expect(rendered, contains('已完成任务'));
  });
}

String _collectRenderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final value = richText.text.toPlainText();
    if (value.isNotEmpty) {
      buffer.writeln(value);
    }
  }
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    final value = span?.toPlainText() ?? text.data;
    if (value != null && value.isNotEmpty) {
      buffer.writeln(value);
    }
  }
  return buffer.toString();
}
