import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_repository.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';

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
    'analysis history preserves whether public memos were included',
    () async {
      final dbName = uniqueDbName('ai_analysis_history_scope');
      final db = AppDatabase(dbName: dbName);
      final repository = AiAnalysisRepository(db);

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final taskId = await repository.createAnalysisTask(
        taskUid: 'task-private-only',
        analysisType: AiAnalysisType.emotionMap,
        status: AiTaskStatus.completed,
        rangeStart: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch ~/ 1000,
        rangeEndExclusive:
            DateTime.utc(2026, 3, 8).millisecondsSinceEpoch ~/ 1000,
        includePublic: false,
        includePrivate: true,
        includeProtected: false,
        promptTemplate: 'Reflect on the week with care.',
        generationProfileKey: 'gen-default',
        embeddingProfileKey: 'embed-default',
        retrievalProfile: const <String, dynamic>{'include_public': false},
      );

      await repository.saveAnalysisResult(
        taskId: taskId,
        result: const AiStructuredAnalysisResult(
          schemaVersion: 1,
          analysisType: AiAnalysisType.emotionMap,
          summary: 'A private-only reflection.',
          sections: <AiAnalysisSectionData>[
            AiAnalysisSectionData(
              sectionKey: 'main',
              title: '',
              body: 'This week felt quieter and more internal.',
              evidenceKeys: <String>[],
            ),
          ],
          evidences: <AiAnalysisEvidenceData>[],
          followUpSuggestions: <String>[],
          rawResponseText: '{}',
        ),
      );

      final history = await repository.listAnalysisReportHistory(
        analysisType: AiAnalysisType.emotionMap,
      );

      expect(history, hasLength(1));
      expect(history.single.includePublic, isFalse);
      expect(history.single.includePrivate, isTrue);
      expect(history.single.includeProtected, isFalse);
    },
  );

  test('analysis history returns all rows when limit is null', () async {
    final dbName = uniqueDbName('ai_analysis_history_all_rows');
    final db = AppDatabase(dbName: dbName);
    final repository = AiAnalysisRepository(db);

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    for (var index = 0; index < 3; index++) {
      final taskId = await repository.createAnalysisTask(
        taskUid: 'task-all-$index',
        analysisType: AiAnalysisType.emotionMap,
        status: AiTaskStatus.completed,
        rangeStart:
            DateTime.utc(2026, 3, 1 + index).millisecondsSinceEpoch ~/ 1000,
        rangeEndExclusive:
            DateTime.utc(2026, 3, 2 + index).millisecondsSinceEpoch ~/ 1000,
        includePublic: true,
        includePrivate: true,
        includeProtected: false,
        promptTemplate: 'Prompt $index',
        generationProfileKey: 'gen-default',
        embeddingProfileKey: 'embed-default',
        retrievalProfile: const <String, dynamic>{'include_public': true},
      );
      await repository.saveAnalysisResult(
        taskId: taskId,
        result: AiStructuredAnalysisResult(
          schemaVersion: 1,
          analysisType: AiAnalysisType.emotionMap,
          summary: 'Summary $index',
          sections: const <AiAnalysisSectionData>[],
          evidences: const <AiAnalysisEvidenceData>[],
          followUpSuggestions: const <String>[],
          rawResponseText: '{}',
        ),
      );
    }

    final unlimited = await repository.listAnalysisReportHistory(
      analysisType: AiAnalysisType.emotionMap,
      limit: null,
    );
    final limited = await repository.listAnalysisReportHistory(
      analysisType: AiAnalysisType.emotionMap,
      limit: 2,
    );

    expect(unlimited, hasLength(3));
    expect(limited, hasLength(2));
    expect(
      unlimited.map((entry) => entry.summary),
      containsAll(<String>['Summary 0', 'Summary 1', 'Summary 2']),
    );
  });
}
