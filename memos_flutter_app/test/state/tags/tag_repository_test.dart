import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/tag_snapshot.dart';
import 'package:memos_flutter_app/state/tags/tag_repository.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'applySnapshot preserves metadata for memo tags missing from a stale snapshot',
    () async {
      final dbName = uniqueDbName('tag_repository_apply_snapshot');
      final db = AppDatabase(dbName: dbName);
      final repository = TagRepository(db: db);
      final now = DateTime.now().toUtc();

      await repository.createTag(
        name: 'projects',
        pinned: true,
        colorHex: '#AABBCC',
      );
      await db.upsertMemo(
        uid: 'memo-1',
        content: 'hello world',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        tags: const ['projects'],
        attachments: const [],
        location: null,
        relationCount: 0,
        syncState: 0,
        lastError: null,
      );

      await repository.applySnapshot(const TagSnapshot(tags: [], aliases: []));

      final restored = await repository.getTagByPath('projects');
      expect(restored, isNotNull);
      expect(restored!.pinned, isTrue);
      expect(restored.colorHex, '#AABBCC');

      final memo = await db.getMemoByUid('memo-1');
      expect(memo?['tags'], 'projects');

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );
}
