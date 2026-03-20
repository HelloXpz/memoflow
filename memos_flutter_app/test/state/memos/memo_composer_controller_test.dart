import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/state/memos/memo_composer_controller.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_state.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoComposerController', () {
    test('supports undo and redo for text edits', () {
      final controller = MemoComposerController(initialText: 'hello');
      addTearDown(controller.dispose);

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      controller.insertText(' world');

      expect(controller.text, 'hello world');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      controller.undo();

      expect(controller.text, 'hello');
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      controller.redo();

      expect(controller.text, 'hello world');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
    });

    test('applies smart enter for task items', () {
      final controller = MemoComposerController(initialText: '- [ ] item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '- [ ] item\n- [ ] ');
    });

    test('wraps selections with formatting markers', () {
      final controller = MemoComposerController(initialText: 'hello');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleBold();
      expect(controller.text, '**hello**');

      controller.replaceText('hello');
      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleUnderline();
      expect(controller.text, '<u>hello</u>');

      controller.replaceText('hello');
      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleHighlight();
      expect(controller.text, '==hello==');
    });

    test('applies template content and list/code block commands', () {
      final controller = MemoComposerController(initialText: 'seed');
      addTearDown(controller.dispose);

      controller.applyTemplateContent('templated body');
      expect(controller.text, 'templated body');

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.insertUnorderedListMarker();
      expect(controller.text, 'templated body- ');

      controller.insertOrderedListMarker();
      expect(controller.text, 'templated body- 1. ');

      controller.insertTaskCheckbox();
      expect(controller.text, 'templated body- 1. - [ ] ');

      controller.insertCodeBlock();
      expect(controller.text, 'templated body- 1. - [ ] ```\n\n```');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 29),
      );
    });

    test('navigates and applies tag autocomplete suggestions', () {
      final controller = MemoComposerController(initialText: 'See #wo');
      addTearDown(controller.dispose);
      final tags = <TagStat>[
        const TagStat(tag: 'work', path: 'work', count: 3),
        const TagStat(tag: 'world', path: 'world', count: 2),
        const TagStat(tag: 'personal', path: 'personal', count: 1),
      ];

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.syncTagAutocompleteState(tagStats: tags, hasFocus: true);

      expect(
        controller
            .currentTagSuggestions(tags, hasFocus: true)
            .map((tag) => tag.path)
            .toList(),
        <String>['work', 'world'],
      );
      expect(controller.tagAutocompleteIndex, 0);

      final moved = controller.handleTagAutocompleteKeyEvent(
        KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
        ),
        tagStats: tags,
        hasFocus: true,
      );
      expect(moved, KeyEventResult.handled);
      expect(controller.tagAutocompleteIndex, 1);

      final applied = controller.handleTagAutocompleteKeyEvent(
        KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
        ),
        tagStats: tags,
        hasFocus: true,
      );
      expect(applied, KeyEventResult.handled);
      expect(controller.text, 'See #world ');
      expect(controller.tagAutocompleteToken, isNull);
    });

    test('manages pending attachments', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const first = MemoComposerPendingAttachment(
        uid: 'a1',
        filePath: '/tmp/1.png',
        filename: '1.png',
        mimeType: 'image/png',
        size: 10,
      );

      controller.addPendingAttachments(const [first]);
      expect(controller.pendingAttachments, hasLength(1));

      controller.replacePendingAttachment(
        'a1',
        first.copyWith(filename: 'updated.png', size: 12),
      );
      expect(controller.pendingAttachments.single.filename, 'updated.png');
      expect(controller.pendingAttachments.single.size, 12);

      expect(controller.removePendingAttachment('a1'), isTrue);
      expect(controller.pendingAttachments, isEmpty);
    });

    test('deduplicates pending attachments by uid', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const first = MemoComposerPendingAttachment(
        uid: 'same',
        filePath: '/tmp/1.png',
        filename: '1.png',
        mimeType: 'image/png',
        size: 10,
      );
      const duplicateUid = MemoComposerPendingAttachment(
        uid: 'same',
        filePath: '/tmp/2.png',
        filename: '2.png',
        mimeType: 'image/png',
        size: 20,
      );

      controller.addPendingAttachments(const [first, duplicateUid]);

      expect(controller.pendingAttachments, hasLength(1));
      expect(controller.pendingAttachments.single.filePath, '/tmp/1.png');
    });

    test('manages linked memos without duplicates', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const memo = MemoComposerLinkedMemo(name: 'memos/1', label: 'First');

      expect(controller.addLinkedMemo(memo), isTrue);
      expect(controller.addLinkedMemo(memo), isFalse);
      expect(controller.linkedMemoNames, <String>{'memos/1'});

      expect(controller.removeLinkedMemo('memos/1'), isTrue);
      expect(controller.linkedMemos, isEmpty);

      controller.addLinkedMemo(memo);
      controller.clearLinkedMemos();
      expect(controller.linkedMemos, isEmpty);
    });
  });
}
