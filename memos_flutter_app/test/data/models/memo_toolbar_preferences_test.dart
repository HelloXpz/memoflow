import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/memo_toolbar_preferences.dart';

void main() {
  test('falls back to defaults when json is missing', () {
    final parsed = MemoToolbarPreferences.fromJson(null);

    expect(parsed, MemoToolbarPreferences.defaults);
  });

  test('normalizes duplicate unknown and missing builtin actions', () {
    final parsed = MemoToolbarPreferences.fromJson({
      'topRow': ['bold', 'bold', 'unknown'],
      'bottomRow': ['tag', 'unknown'],
      'hiddenActions': ['tag', 'unknown'],
    });

    expect(parsed.topRow.first, MemoToolbarActionId.bold);
    expect(parsed.bottomRow.first, MemoToolbarActionId.tag);
    expect(parsed.hiddenActions, {MemoToolbarActionId.tag});

    final allActions = <MemoToolbarActionId>{
      ...parsed.topRow,
      ...parsed.bottomRow,
    };
    expect(allActions, MemoToolbarActionId.values.toSet());
    expect(
      parsed.topRow.length + parsed.bottomRow.length,
      MemoToolbarActionId.values.length,
    );
  });

  test('round-trips json and keeps restored builtin actions in prior row', () {
    final moved = MemoToolbarPreferences.defaults.moveAction(
      action: MemoToolbarActionId.link,
      targetRow: MemoToolbarRow.top,
      targetIndex: 1,
    );
    final hidden = moved.setHidden(MemoToolbarActionId.link, true);
    final restored = MemoToolbarPreferences.fromJson(
      hidden.toJson(),
    ).setHidden(MemoToolbarActionId.link, false);

    expect(restored.rowOf(MemoToolbarActionId.link), MemoToolbarRow.top);
    expect(restored.topRow[1], MemoToolbarActionId.link);
    expect(restored.hiddenActions.contains(MemoToolbarActionId.link), isFalse);
  });

  test('maps visible insertion slots while preserving hidden positions', () {
    final prefs = MemoToolbarPreferences.defaults.setHidden(
      MemoToolbarActionId.list,
      true,
    );

    expect(
      prefs.insertionIndexForVisibleSlot(
        row: MemoToolbarRow.top,
        visibleIndex: 1,
      ),
      2,
    );
    expect(prefs.hiddenActionsInOrder(), [MemoToolbarActionId.list]);
  });

  test('round-trips custom buttons and keeps hidden custom order', () {
    final customButton = MemoToolbarCustomButton(
      id: 'heading-1',
      label: 'H1',
      iconKey: 'hammer',
      insertContent: '# ',
    );

    final prefs = MemoToolbarPreferences.defaults
        .addCustomButton(customButton)
        .moveItem(
          item: customButton.itemId,
          targetRow: MemoToolbarRow.top,
          targetIndex: 1,
        );

    final parsed = MemoToolbarPreferences.fromJson(prefs.toJson());

    expect(parsed.customButtons, [customButton]);
    expect(parsed.rowOfItem(customButton.itemId), MemoToolbarRow.top);
    expect(parsed.hiddenItemIdsInOrder(), contains(customButton.itemId));
  });

  test('drops custom keys whose button payload is missing', () {
    final parsed = MemoToolbarPreferences.fromJson({
      'topRow': ['custom:missing'],
      'bottomRow': ['bold'],
      'hiddenActions': ['custom:missing'],
      'customButtons': const [],
    });

    expect(parsed.customButtons, isEmpty);
    expect(parsed.topRowItems.any((item) => item.isCustom), isFalse);
    expect(parsed.hiddenItemIds.any((item) => item.isCustom), isFalse);
  });
}
