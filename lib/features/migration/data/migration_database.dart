import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/nuvex_database.dart';
import '../models/migration_queue_item.dart';

/// Dedicated SQLite storage layer for the Telegram migration queue.
///
/// Strictly isolates temporary queue states from primary gallery/media tables (`remote_files`).
/// Enforces:
/// - Stable [telegramRandomId] persistence across retries and crashes
/// - Database-level SHA-256 content deduplication
/// - Safe crash recovery without regenerating IDs
class MigrationDatabase {
  final NuvexDatabase _nuvexDatabase;

  MigrationDatabase({NuvexDatabase? nuvexDatabase})
    : _nuvexDatabase = nuvexDatabase ?? NuvexDatabase();

  Database get _db => _nuvexDatabase.db;

  /// Initializes the dedicated migration queue tables and indices.
  Future<void> initialize({Database? overrideDb}) async {
    if (!_nuvexDatabase.isInitialized || overrideDb != null) {
      await _nuvexDatabase.initialize(overrideDb: overrideDb);
    }
    await _createQueueTables(_db);
  }

  static Future<void> _createQueueTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS migration_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        localPath TEXT NOT NULL UNIQUE,
        fileName TEXT NOT NULL,
        sizeBytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        telegramRandomId INTEGER NOT NULL,
        telegramMessageId INTEGER,
        telegramFileId INTEGER,
        errorMessage TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mq_sha256 
      ON migration_queue(sha256)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mq_status 
      ON migration_queue(status)
    ''');
  }

  /// Enqueues a single item with database-level SHA-256 deduplication and path safety.
  ///
  /// - If [localPath] already exists: preserves existing state unless it failed and can be retried.
  /// - If content with the same [sha256] was already uploaded: automatically marks this item as SKIPPED.
  Future<MigrationQueueItem> enqueueItem(MigrationQueueItem item) async {
    final normalizedPath = p.normalize(item.localPath);
    final normalizedItem = item.copyWith(localPath: normalizedPath);
    final existingPath = await getItemByPath(normalizedPath);
    if (existingPath != null) {
      // Do not overwrite confirmed uploaded items
      if (existingPath.status == MigrationItemStatus.uploaded) {
        return existingPath;
      }
      return existingPath;
    }

    // Check if an identical file (by SHA-256) is already uploaded
    final uploadedDuplicate = await findUploadedItemBySha(
      normalizedItem.sha256,
    );
    final MigrationQueueItem itemToInsert;
    if (uploadedDuplicate != null) {
      itemToInsert = normalizedItem.copyWith(
        status: MigrationItemStatus.skipped,
        telegramMessageId: uploadedDuplicate.telegramMessageId,
        telegramFileId: uploadedDuplicate.telegramFileId,
        errorMessage: 'Duplicate of ${uploadedDuplicate.localPath}',
      );
    } else {
      // Check if an identical file is already queued pending/uploading
      final existingPending = await findFirstItemBySha(normalizedItem.sha256);
      if (existingPending != null &&
          existingPending.localPath != normalizedItem.localPath) {
        itemToInsert = normalizedItem.copyWith(
          status: MigrationItemStatus.skipped,
          errorMessage: 'Duplicate of queued ${existingPending.localPath}',
        );
      } else {
        itemToInsert = normalizedItem;
      }
    }

    final id = await _db.insert(
      'migration_queue',
      itemToInsert.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return itemToInsert.copyWith(id: id > 0 ? id : null);
  }

  /// Batch enqueues multiple scanned items.
  Future<List<MigrationQueueItem>> enqueueItems(
    List<MigrationQueueItem> items,
  ) async {
    final List<MigrationQueueItem> results = [];
    for (final item in items) {
      results.add(await enqueueItem(item));
    }
    return results;
  }

  /// Finds the first uploaded item matching [sha256].
  Future<MigrationQueueItem?> findUploadedItemBySha(String sha256) async {
    final rows = await _db.query(
      'migration_queue',
      where: 'sha256 = ? AND status = ?',
      whereArgs: [sha256, MigrationItemStatus.uploaded.toDbString()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MigrationQueueItem.fromMap(rows.first);
  }

  /// Finds any item matching [sha256].
  Future<MigrationQueueItem?> findFirstItemBySha(String sha256) async {
    final rows = await _db.query(
      'migration_queue',
      where: 'sha256 = ?',
      whereArgs: [sha256],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MigrationQueueItem.fromMap(rows.first);
  }

  /// Gets an item by its local path.
  Future<MigrationQueueItem?> getItemByPath(String path) async {
    final normalized = p.normalize(path);
    final rows = await _db.query(
      'migration_queue',
      where: 'localPath = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MigrationQueueItem.fromMap(rows.first);
  }

  /// Gets an item by primary key [id].
  Future<MigrationQueueItem?> getItemById(int id) async {
    final rows = await _db.query(
      'migration_queue',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MigrationQueueItem.fromMap(rows.first);
  }

  /// Fetches the next available pending item to upload.
  Future<MigrationQueueItem?> getNextPendingItem() async {
    final rows = await _db.query(
      'migration_queue',
      where: 'status = ?',
      whereArgs: [MigrationItemStatus.pending.toDbString()],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MigrationQueueItem.fromMap(rows.first);
  }

  /// Updates an existing queue item.
  Future<void> updateItem(MigrationQueueItem item) async {
    if (item.id == null) return;
    await _db.update(
      'migration_queue',
      item.toMap()..['updatedAt'] = DateTime.now().millisecondsSinceEpoch,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Marks an item as in-progress [uploading].
  Future<void> markUploading(int id) async {
    await _db.update(
      'migration_queue',
      {
        'status': MigrationItemStatus.uploading.toDbString(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an item as successfully [uploaded] with Telegram identifiers.
  Future<void> markUploaded(
    int id, {
    required int messageId,
    required int fileId,
  }) async {
    await _db.update(
      'migration_queue',
      {
        'status': MigrationItemStatus.uploaded.toDbString(),
        'telegramMessageId': messageId,
        'telegramFileId': fileId,
        'errorMessage': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an item as [failed] with error details and retry count.
  Future<void> markFailed(
    int id, {
    required String errorMessage,
    required int retryCount,
    bool retryable = false,
  }) async {
    await _db.update(
      'migration_queue',
      {
        'status': retryable
            ? MigrationItemStatus.pending.toDbString()
            : MigrationItemStatus.failed.toDbString(),
        'retryCount': retryCount,
        'errorMessage': errorMessage,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an item as [skipped] (e.g. duplicate).
  Future<void> markSkipped(
    int id, {
    String? reason,
    int? messageId,
    int? fileId,
  }) async {
    final values = <String, Object?>{
      'status': MigrationItemStatus.skipped.toDbString(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (messageId != null) values['telegramMessageId'] = messageId;
    if (fileId != null) values['telegramFileId'] = fileId;
    if (reason != null) values['errorMessage'] = reason;

    await _db.update(
      'migration_queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Recovers from unexpected app crash or interruption.
  ///
  /// Resets any items stuck in [uploading] status back to [pending] while
  /// PRESERVING their original persistent [telegramRandomId] to ensure MTProto idempotence.
  Future<int> resetStaleUploadingToPending() async {
    final updatedCount = await _db.update(
      'migration_queue',
      {
        'status': MigrationItemStatus.pending.toDbString(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'status = ?',
      whereArgs: [MigrationItemStatus.uploading.toDbString()],
    );
    if (updatedCount > 0) {
      debugPrint(
        '[MIGRATION_DB] Reset $updatedCount interrupted uploading item(s) to pending (preserved random IDs)',
      );
    }
    return updatedCount;
  }

  /// Retrieves summary metrics for the migration queue.
  Future<Map<String, int>> getQueueSummary() async {
    final rows = await _db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM migration_queue 
      GROUP BY status
    ''');

    final summary = <String, int>{
      'total': 0,
      'pending': 0,
      'uploading': 0,
      'uploaded': 0,
      'failed': 0,
      'skipped': 0,
    };

    int total = 0;
    for (final row in rows) {
      final status = (row['status'] as String).toLowerCase();
      final count = (row['count'] as int?) ?? 0;
      summary[status] = count;
      total += count;
    }
    summary['total'] = total;
    return summary;
  }

  /// Retrieves all items in the queue (useful for testing and monitoring).
  Future<List<MigrationQueueItem>> getAllItems() async {
    final rows = await _db.query('migration_queue', orderBy: 'id ASC');
    return rows.map((r) => MigrationQueueItem.fromMap(r)).toList();
  }

  /// Clears the migration queue table (for testing).
  Future<void> clearQueue() async {
    await _db.delete('migration_queue');
  }
}
