import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/tag_colors.dart';
import '../../core/tags.dart';
import '../../data/db/app_database.dart';
import '../../data/models/tag.dart';
import '../../data/models/tag_snapshot.dart';
import '../system/database_provider.dart';

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(db: ref.watch(databaseProvider));
});

class TagRepository {
  TagRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  static const Object _unsetParent = Object();

  Future<List<TagEntity>> listTags() async {
    final sqlite = await _db.db;
    final rows = await sqlite.query('tags', orderBy: 'path ASC');
    return rows.map(TagEntity.fromDb).toList(growable: false);
  }

  Future<TagEntity?> getTagByPath(String path) async {
    final normalized = normalizeTagPath(path);
    if (normalized.isEmpty) return null;
    final sqlite = await _db.db;
    final rows = await sqlite.query(
      'tags',
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TagEntity.fromDb(rows.first);
  }

  Future<TagEntity> createTag({
    required String name,
    int? parentId,
    bool pinned = false,
    String? colorHex,
  }) async {
    final normalizedName = _normalizeTagName(name);
    final normalizedColor = normalizeTagColorHex(colorHex);
    final sqlite = await _db.db;
    late TagEntity created;
    await sqlite.transaction((txn) async {
      if (parentId != null) {
        final parent = await _loadTag(txn, parentId);
        if (parent == null) {
          throw StateError('Parent tag not found');
        }
      }
      await _ensureUniqueName(
        txn,
        name: normalizedName,
        parentId: parentId,
        excludeId: null,
      );
      final parentPath = parentId == null
          ? null
          : (await _loadTag(txn, parentId))?.path;
      if (parentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final path = parentPath == null || parentPath.isEmpty
          ? normalizedName
          : '$parentPath/$normalizedName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final id = await txn.insert('tags', {
        'name': normalizedName,
        'parent_id': parentId,
        'path': path,
        'pinned': pinned ? 1 : 0,
        'color_hex': normalizedColor,
        'create_time': now,
        'update_time': now,
      });
      created = TagEntity(
        id: id,
        name: normalizedName,
        path: path,
        parentId: parentId,
        pinned: pinned,
        colorHex: normalizedColor,
        createTimeSec: now,
        updateTimeSec: now,
      );
    });
    _db.notifyDataChanged();
    return created;
  }

  Future<TagEntity> updateTag({
    required int id,
    String? name,
    Object? parentId = _unsetParent,
    bool? pinned,
    String? colorHex,
  }) async {
    final sqlite = await _db.db;
    late TagEntity updated;
    await sqlite.transaction((txn) async {
      final current = await _loadTag(txn, id);
      if (current == null) {
        throw StateError('Tag not found');
      }
      final nextName = name == null ? current.name : _normalizeTagName(name);
      final nextParentId = parentId == _unsetParent
          ? current.parentId
          : parentId as int?;
      final nextPinned = pinned ?? current.pinned;
      final nextColor = colorHex == null
          ? current.colorHex
          : normalizeTagColorHex(colorHex);

      await _assertNoCycle(txn, id, nextParentId);
      await _ensureUniqueName(
        txn,
        name: nextName,
        parentId: nextParentId,
        excludeId: id,
      );

      final parentPath = nextParentId == null
          ? null
          : (await _loadTag(txn, nextParentId))?.path;
      if (nextParentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final newPath = parentPath == null || parentPath.isEmpty
          ? nextName
          : '$parentPath/$nextName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      if (newPath == current.path) {
        await txn.update(
          'tags',
          {
            'name': nextName,
            'parent_id': nextParentId,
            'pinned': nextPinned ? 1 : 0,
            'color_hex': nextColor,
            'update_time': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        final descendants = await txn.query(
          'tags',
          columns: const ['id', 'path', 'parent_id'],
          where: 'path = ? OR path LIKE ?',
          whereArgs: [current.path, '${current.path}/%'],
        );
        final subtreeIds = <int>{};
        final newPaths = <int, String>{};
        for (final row in descendants) {
          final tagId = _readInt(row['id']) ?? 0;
          final oldPath = row['path'] as String? ?? '';
          if (tagId <= 0 || oldPath.isEmpty) continue;
          subtreeIds.add(tagId);
          final suffix = oldPath == current.path
              ? ''
              : oldPath.substring(current.path.length);
          final updatedPath = '$newPath$suffix';
          newPaths[tagId] = updatedPath;
        }

        for (final entry in newPaths.entries) {
          final rows = await txn.query(
            'tags',
            columns: const ['id'],
            where: 'path = ?',
            whereArgs: [entry.value],
            limit: 1,
          );
          final existingId = rows.isNotEmpty
              ? (_readInt(rows.first['id']) ?? 0)
              : 0;
          if (existingId > 0 && !subtreeIds.contains(existingId)) {
            throw StateError('Tag path already exists');
          }
        }

        for (final row in descendants) {
          final tagId = _readInt(row['id']) ?? 0;
          final oldPath = row['path'] as String? ?? '';
          if (tagId <= 0 || oldPath.isEmpty) continue;
          await txn.insert('tag_aliases', {
            'tag_id': tagId,
            'alias': oldPath,
            'created_time': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        final newPathForTag = newPaths[id] ?? newPath;
        await txn.update(
          'tags',
          {
            'name': nextName,
            'parent_id': nextParentId,
            'path': newPathForTag,
            'pinned': nextPinned ? 1 : 0,
            'color_hex': nextColor,
            'update_time': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        for (final entry in newPaths.entries) {
          final tagId = entry.key;
          if (tagId == id) continue;
          await txn.update(
            'tags',
            {'path': entry.value, 'update_time': now},
            where: 'id = ?',
            whereArgs: [tagId],
          );
        }

        final memoUids = await _db.listMemoUidsByTagIds(
          txn,
          subtreeIds.toList(growable: false),
        );
        for (final memoUid in memoUids) {
          final paths = await _db.listTagPathsForMemo(txn, memoUid);
          await _db.updateMemoTagsText(txn, memoUid, paths);
        }
      }

      updated = (await _loadTag(txn, id)) ?? current;
    });
    _db.notifyDataChanged();
    return updated;
  }

  Future<void> deleteTag(int id) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final current = await _loadTag(txn, id);
      if (current == null) return;
      final parentId = current.parentId;
      final parentPath = parentId == null
          ? ''
          : (await _loadTag(txn, parentId))?.path ?? '';

      final descendants = await txn.query(
        'tags',
        columns: const ['id', 'path', 'parent_id'],
        where: 'path LIKE ?',
        whereArgs: ['${current.path}/%'],
      );

      final affectedIds = <int>{id};
      final newPaths = <int, String>{};
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final oldPath = row['path'] as String? ?? '';
        if (tagId <= 0 || oldPath.isEmpty) continue;
        affectedIds.add(tagId);
        final suffix = oldPath.substring(current.path.length + 1);
        final updatedPath = parentPath.isEmpty ? suffix : '$parentPath/$suffix';
        newPaths[tagId] = updatedPath;
      }

      for (final entry in newPaths.entries) {
        final rows = await txn.query(
          'tags',
          columns: const ['id'],
          where: 'path = ?',
          whereArgs: [entry.value],
          limit: 1,
        );
        final existingId = rows.isNotEmpty
            ? (_readInt(rows.first['id']) ?? 0)
            : 0;
        if (existingId > 0 && !affectedIds.contains(existingId)) {
          throw StateError('Tag path already exists');
        }
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final oldPath = row['path'] as String? ?? '';
        if (tagId <= 0 || oldPath.isEmpty) continue;
        await txn.insert('tag_aliases', {
          'tag_id': tagId,
          'alias': oldPath,
          'created_time': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final directChildren = <int>{};
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final parent = _readInt(row['parent_id']) ?? 0;
        if (tagId > 0 && parent == id) {
          directChildren.add(tagId);
        }
      }
      for (final entry in newPaths.entries) {
        final tagId = entry.key;
        final isDirectChild = directChildren.contains(tagId);
        await txn.update(
          'tags',
          {
            'path': entry.value,
            'update_time': now,
            if (isDirectChild) 'parent_id': parentId,
          },
          where: 'id = ?',
          whereArgs: [tagId],
        );
      }

      final memoUids = await _db.listMemoUidsByTagIds(
        txn,
        affectedIds.toList(growable: false),
      );

      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);

      for (final memoUid in memoUids) {
        final paths = await _db.listTagPathsForMemo(txn, memoUid);
        await _db.updateMemoTagsText(txn, memoUid, paths);
      }
    });
    _db.notifyDataChanged();
  }

  Future<TagSnapshot> readSnapshot() async {
    final sqlite = await _db.db;
    final tagRows = await sqlite.query('tags', orderBy: 'id ASC');
    final aliasRows = await sqlite.query('tag_aliases', orderBy: 'id ASC');
    final tags = tagRows.map(TagEntity.fromDb).toList(growable: false);
    final aliases = aliasRows
        .map(TagAliasRecord.fromDb)
        .toList(growable: false);
    return TagSnapshot(tags: tags, aliases: aliases);
  }

  Future<void> applySnapshot(TagSnapshot snapshot) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final existingTagRows = await txn.query('tags', orderBy: 'id ASC');
      final existingAliasRows = await txn.query(
        'tag_aliases',
        orderBy: 'id ASC',
      );
      final existingTags = existingTagRows
          .map(TagEntity.fromDb)
          .toList(growable: false);
      final existingAliases = existingAliasRows
          .map(TagAliasRecord.fromDb)
          .toList(growable: false);
      final existingTagsByPath = <String, TagEntity>{
        for (final tag in existingTags)
          if (tag.path.trim().isNotEmpty) tag.path: tag,
      };
      final existingTagsById = <int, TagEntity>{
        for (final tag in existingTags)
          if (tag.id > 0) tag.id: tag,
      };
      final existingAliasesByPath = <String, List<TagAliasRecord>>{};
      for (final alias in existingAliases) {
        final tag = existingTagsById[alias.tagId];
        if (tag == null || tag.path.trim().isEmpty) continue;
        existingAliasesByPath
            .putIfAbsent(tag.path, () => <TagAliasRecord>[])
            .add(alias);
      }

      await txn.delete('memo_tags');
      await txn.delete('tag_aliases');
      await txn.delete('tags');

      for (final tag in snapshot.tags) {
        await txn.insert('tags', {
          'id': tag.id,
          'name': tag.name,
          'parent_id': tag.parentId,
          'path': tag.path,
          'pinned': tag.pinned ? 1 : 0,
          'color_hex': tag.colorHex,
          'create_time': tag.createTimeSec,
          'update_time': tag.updateTimeSec,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final alias in snapshot.aliases) {
        await txn.insert('tag_aliases', {
          'tag_id': alias.tagId,
          'alias': alias.alias,
          'created_time': alias.createdTimeSec,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final memos = await txn.query('memos', columns: const ['uid', 'tags']);
      for (final row in memos) {
        final uid = row['uid'];
        if (uid is! String || uid.trim().isEmpty) continue;
        final tagsText = (row['tags'] as String?) ?? '';
        final tags = tagsText
            .split(' ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(growable: false);
        final resolved = <String, int>{};
        for (final tag in tags) {
          var entry = await _findResolvedTag(txn, tag);
          entry ??= await _restoreTagFromExisting(
            txn,
            tag,
            existingTagsByPath: existingTagsByPath,
            existingTagsById: existingTagsById,
            existingAliasesByPath: existingAliasesByPath,
          );
          if (entry == null) {
            final created = await _db.resolveTagPath(txn, tag);
            if (created != null) {
              entry = _ResolvedTagRef(id: created.id, path: created.path);
            }
          }
          if (entry == null) continue;
          final resolvedEntry = entry;
          resolved.putIfAbsent(resolvedEntry.path, () => resolvedEntry.id);
        }
        await _db.updateMemoTagsMapping(
          txn,
          uid,
          resolved.values.toList(growable: false),
        );
        await _db.updateMemoTagsText(
          txn,
          uid,
          resolved.keys.toList(growable: false),
        );
      }
    });
    _db.notifyDataChanged();
  }

  Future<_ResolvedTagRef?> _findResolvedTag(
    DatabaseExecutor txn,
    String rawTag,
  ) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final directRows = await txn.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (directRows.isNotEmpty) {
      final row = directRows.first;
      final id = _readInt(row['id']) ?? 0;
      final path = row['path'] as String? ?? normalized;
      if (id > 0 && path.trim().isNotEmpty) {
        return _ResolvedTagRef(id: id, path: path);
      }
    }

    final aliasRows = await txn.query(
      'tag_aliases',
      columns: const ['tag_id'],
      where: 'alias = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (aliasRows.isEmpty) return null;
    final tagId = _readInt(aliasRows.first['tag_id']) ?? 0;
    if (tagId <= 0) return null;
    final tagRows = await txn.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'id = ?',
      whereArgs: [tagId],
      limit: 1,
    );
    if (tagRows.isEmpty) return null;
    final row = tagRows.first;
    final path = row['path'] as String? ?? normalized;
    if (path.trim().isEmpty) return null;
    return _ResolvedTagRef(id: tagId, path: path);
  }

  Future<_ResolvedTagRef?> _restoreTagFromExisting(
    DatabaseExecutor txn,
    String rawTag, {
    required Map<String, TagEntity> existingTagsByPath,
    required Map<int, TagEntity> existingTagsById,
    required Map<String, List<TagAliasRecord>> existingAliasesByPath,
  }) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final existing = existingTagsByPath[normalized];
    if (existing == null) return null;

    final resolved = await _findResolvedTag(txn, normalized);
    if (resolved != null) return resolved;

    _ResolvedTagRef? restoredParent;
    final parentFromId = existing.parentId == null
        ? null
        : existingTagsById[existing.parentId!];
    if (parentFromId != null) {
      restoredParent = await _restoreTagFromExisting(
        txn,
        parentFromId.path,
        existingTagsByPath: existingTagsByPath,
        existingTagsById: existingTagsById,
        existingAliasesByPath: existingAliasesByPath,
      );
    } else {
      final slashIndex = existing.path.lastIndexOf('/');
      if (slashIndex > 0) {
        restoredParent = await _restoreTagFromExisting(
          txn,
          existing.path.substring(0, slashIndex),
          existingTagsByPath: existingTagsByPath,
          existingTagsById: existingTagsById,
          existingAliasesByPath: existingAliasesByPath,
        );
      }
    }

    await txn.insert('tags', {
      'name': existing.name,
      'parent_id': restoredParent?.id,
      'path': existing.path,
      'pinned': existing.pinned ? 1 : 0,
      'color_hex': existing.colorHex,
      'create_time': existing.createTimeSec,
      'update_time': existing.updateTimeSec,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final restored = await _findResolvedTag(txn, existing.path);
    if (restored == null) return null;

    final aliases =
        existingAliasesByPath[existing.path] ?? const <TagAliasRecord>[];
    for (final alias in aliases) {
      final normalizedAlias = normalizeTagPath(alias.alias);
      if (normalizedAlias.isEmpty || normalizedAlias == restored.path) continue;
      await txn.insert('tag_aliases', {
        'tag_id': restored.id,
        'alias': normalizedAlias,
        'created_time': alias.createdTimeSec,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return restored;
  }

  Future<TagEntity?> _loadTag(DatabaseExecutor txn, int id) async {
    if (id <= 0) return null;
    final rows = await txn.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TagEntity.fromDb(rows.first);
  }

  String _normalizeTagName(String raw) {
    final normalized = normalizeTagPath(raw);
    if (normalized.isEmpty) {
      throw StateError('Tag name is empty');
    }
    if (normalized.contains('/')) {
      throw StateError('Tag name cannot contain "/"');
    }
    return normalized;
  }

  Future<void> _ensureUniqueName(
    DatabaseExecutor txn, {
    required String name,
    required int? parentId,
    required int? excludeId,
  }) async {
    final rows = await txn.query(
      'tags',
      columns: const ['id'],
      where: parentId == null
          ? 'name = ? AND parent_id IS NULL'
          : 'name = ? AND parent_id = ?',
      whereArgs: parentId == null ? [name] : [name, parentId],
      limit: 1,
    );
    final existingId = rows.isNotEmpty ? (_readInt(rows.first['id']) ?? 0) : 0;
    if (existingId > 0 && existingId != excludeId) {
      throw StateError('Tag name already exists');
    }
  }

  Future<void> _assertNoCycle(
    DatabaseExecutor txn,
    int id,
    int? parentId,
  ) async {
    if (parentId == null) return;
    if (parentId == id) {
      throw StateError('Tag cannot be its own parent');
    }
    int? current = parentId;
    final visited = <int>{};
    while (current != null && visited.add(current)) {
      if (current == id) {
        throw StateError('Tag hierarchy cycle detected');
      }
      final rows = await txn.query(
        'tags',
        columns: const ['parent_id'],
        where: 'id = ?',
        whereArgs: [current],
        limit: 1,
      );
      if (rows.isEmpty) break;
      current = _readInt(rows.first['parent_id']);
    }
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class _ResolvedTagRef {
  const _ResolvedTagRef({required this.id, required this.path});

  final int id;
  final String path;
}
