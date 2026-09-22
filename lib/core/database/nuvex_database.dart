import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'remote_file.dart';

/// Central SQLite local database for Nuvex.
///
/// Implements local-first storage architecture conforming to architecture.md:
/// - Real metadata persistence for Telegram media and files
/// - Efficient indexing on timestamps and categories
/// - Real collection counts without fake data
class NuvexDatabase {
  static final NuvexDatabase _instance = NuvexDatabase._internal();
  factory NuvexDatabase() => _instance;
  NuvexDatabase._internal();

  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError(
        'NuvexDatabase has not been initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  bool get isInitialized => _db != null;

  /// Initializes the local SQLite database.
  ///
  /// Can accept [overrideDb] for deterministic unit and widget testing.
  Future<void> initialize({Database? overrideDb}) async {
    if (_db != null && overrideDb == null) return;

    if (overrideDb != null) {
      _db = overrideDb;
      await _createTables(_db!);
      return;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'nuvex_storage.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      );
      debugPrint('[DB] SQLite database initialized at $path');
    } catch (e) {
      debugPrint('[DB] Error opening SQLite database: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_files (
        id INTEGER PRIMARY KEY,
        telegramChatId INTEGER NOT NULL,
        telegramMessageId INTEGER NOT NULL UNIQUE,
        telegramFileId INTEGER NOT NULL,
        name TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        sizeBytes INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        modifiedAt INTEGER NOT NULL,
        thumbnailPath TEXT,
        localPath TEXT,
        remoteAvailable INTEGER NOT NULL DEFAULT 1,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isLocked INTEGER NOT NULL DEFAULT 0,
        latitude REAL,
        longitude REAL,
        durationMs INTEGER,
        width INTEGER,
        height INTEGER,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_remote_files_created 
      ON remote_files(createdAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_remote_files_category 
      ON remote_files(category)
    ''');
  }

  /// Inserts or updates remote file metadata.
  Future<void> upsertFiles(List<RemoteFile> files) async {
    if (files.isEmpty) return;
    final database = db;

    final batch = database.batch();
    for (final file in files) {
      batch.rawInsert(
        '''
        INSERT INTO remote_files (
          id, telegramChatId, telegramMessageId, telegramFileId, name, mimeType,
          sizeBytes, createdAt, modifiedAt, thumbnailPath, localPath, remoteAvailable,
          isFavorite, isArchived, isLocked, latitude, longitude, durationMs, width, height, category
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(telegramMessageId) DO UPDATE SET
          name = excluded.name,
          mimeType = excluded.mimeType,
          sizeBytes = excluded.sizeBytes,
          createdAt = excluded.createdAt,
          modifiedAt = excluded.modifiedAt,
          thumbnailPath = COALESCE(excluded.thumbnailPath, remote_files.thumbnailPath),
          localPath = CASE 
            WHEN excluded.localPath IS NOT NULL AND excluded.localPath != '' THEN excluded.localPath 
            ELSE remote_files.localPath 
          END,
          remoteAvailable = excluded.remoteAvailable,
          isFavorite = CASE 
            WHEN excluded.isFavorite = 1 THEN 1 
            ELSE remote_files.isFavorite 
          END,
          isArchived = CASE 
            WHEN excluded.isArchived = 1 THEN 1 
            ELSE remote_files.isArchived 
          END,
          isLocked = CASE 
            WHEN excluded.isLocked = 1 THEN 1 
            ELSE remote_files.isLocked 
          END,
          latitude = COALESCE(excluded.latitude, remote_files.latitude),
          longitude = COALESCE(excluded.longitude, remote_files.longitude),
          durationMs = COALESCE(excluded.durationMs, remote_files.durationMs),
          width = COALESCE(excluded.width, remote_files.width),
          height = COALESCE(excluded.height, remote_files.height),
          category = excluded.category
        ''',
        [
          file.id,
          file.telegramChatId,
          file.telegramMessageId,
          file.telegramFileId,
          file.name,
          file.mimeType,
          file.sizeBytes,
          file.createdAt.millisecondsSinceEpoch,
          file.modifiedAt.millisecondsSinceEpoch,
          file.thumbnailPath,
          file.localPath,
          file.remoteAvailable ? 1 : 0,
          file.isFavorite ? 1 : 0,
          file.isArchived ? 1 : 0,
          file.isLocked ? 1 : 0,
          file.latitude,
          file.longitude,
          file.durationMs,
          file.width,
          file.height,
          file.category,
        ],
      );
    }
    await batch.commit(noResult: true);
    debugPrint(
      '[DB_DIAGNOSTIC] [Stage 5] Upserted ${files.length} files to SQLite database',
    );
  }

  /// Retrieves recent media (photos and videos) ordered by creation date descending.
  Future<List<RemoteFile>> getRecentMedia({
    int? limit,
    int offset = 0,
  }) async {
    final database = db;
    final rows = await database.query(
      'remote_files',
      where: 'category IN (?, ?, ?)',
      whereArgs: ['photos', 'videos', 'screenshots'],
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );

    debugPrint(
      '[DB_DIAGNOSTIC] [Stage 6] getRecentMedia returned ${rows.length} rows (limit: $limit, offset: $offset)',
    );

    return rows.map((r) => RemoteFile.fromMap(r)).toList();
  }

  /// Retrieves files classified into a specific category.
  Future<List<RemoteFile>> getFilesByCategory(
    String category, {
    int limit = 50,
    int offset = 0,
  }) async {
    final database = db;
    if (category == 'largest_files') {
      final rows = await database.query(
        'remote_files',
        orderBy: 'sizeBytes DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    if (category == 'recently_added') {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final rows = await database.query(
        'remote_files',
        where: 'createdAt >= ?',
        whereArgs: [cutoff],
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    if (category == 'archive') {
      final rows = await database.query(
        'remote_files',
        where: 'isArchived = 1',
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    if (category == 'locked') {
      final rows = await database.query(
        'remote_files',
        where: 'isLocked = 1',
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    if (category == 'favorites') {
      final rows = await database.query(
        'remote_files',
        where: 'isFavorite = 1',
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    if (category == 'places') {
      final rows = await database.query(
        'remote_files',
        where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => RemoteFile.fromMap(r)).toList();
    }

    final rows = await database.query(
      'remote_files',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => RemoteFile.fromMap(r)).toList();
  }

  /// Computes real collection counts derived directly from database metadata.
  Future<Map<String, int>> getCollectionCounts() async {
    final database = db;
    final Map<String, int> counts = {
      'documents': 0,
      'places': 0,
      'stickers': 0,
      'moments': 0,
      'screenshots': 0,
      'videos': 0,
      'recently_added': 0,
      'creations': 0,
      'archive': 0,
      'locked': 0,
    };

    final rows = await database.rawQuery('''
      SELECT category, COUNT(*) as count 
      FROM remote_files 
      GROUP BY category
    ''');

    for (final r in rows) {
      final cat = r['category'] as String?;
      final count = (r['count'] as num?)?.toInt() ?? 0;
      if (cat != null && counts.containsKey(cat)) {
        counts[cat] = count;
      }
    }

    // Places count
    final placesRes = await database.rawQuery(
      'SELECT COUNT(*) as count FROM remote_files WHERE latitude IS NOT NULL AND longitude IS NOT NULL',
    );
    counts['places'] = (placesRes.firstOrNull?['count'] as num?)?.toInt() ?? 0;

    // Recently added count (past 7 days)
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final recentRes = await database.rawQuery(
      'SELECT COUNT(*) as count FROM remote_files WHERE createdAt >= ?',
      [cutoff],
    );
    counts['recently_added'] =
        (recentRes.firstOrNull?['count'] as num?)?.toInt() ?? 0;

    // Archive count
    final archiveRes = await database.rawQuery(
      'SELECT COUNT(*) as count FROM remote_files WHERE isArchived = 1',
    );
    counts['archive'] =
        (archiveRes.firstOrNull?['count'] as num?)?.toInt() ?? 0;

    // Locked count
    final lockedRes = await database.rawQuery(
      'SELECT COUNT(*) as count FROM remote_files WHERE isLocked = 1',
    );
    counts['locked'] = (lockedRes.firstOrNull?['count'] as num?)?.toInt() ?? 0;

    // Favorites count
    final favRes = await database.rawQuery(
      'SELECT COUNT(*) as count FROM remote_files WHERE isFavorite = 1',
    );
    counts['favorites'] = (favRes.firstOrNull?['count'] as num?)?.toInt() ?? 0;

    return counts;
  }

  /// Returns the maximum Telegram message ID saved locally for incremental sync.
  Future<int?> getLatestMessageId() async {
    final database = db;
    final rows = await database.rawQuery(
      'SELECT MAX(telegramMessageId) as maxId FROM remote_files',
    );
    final maxId = rows.firstOrNull?['maxId'] as int?;
    return maxId;
  }

  /// Deletes a file record by Telegram message ID.
  Future<void> deleteFile(int telegramMessageId) async {
    final database = db;
    await database.delete(
      'remote_files',
      where: 'telegramMessageId = ?',
      whereArgs: [telegramMessageId],
    );
  }

  /// Computes real storage statistics derived directly from SQLite metadata.
  Future<NuvexStorageStats> getStorageStats() async {
    final database = db;
    final rows = await database.rawQuery('''
      SELECT category, COUNT(*) as file_count, SUM(sizeBytes) as total_bytes
      FROM remote_files
      GROUP BY category
    ''');

    int photosCount = 0;
    int photosBytes = 0;
    int videosCount = 0;
    int videosBytes = 0;
    int docsCount = 0;
    int docsBytes = 0;
    int otherCount = 0;
    int otherBytes = 0;

    for (final r in rows) {
      final cat = (r['category'] as String?)?.toLowerCase() ?? 'other';
      final count = (r['file_count'] as num?)?.toInt() ?? 0;
      final bytes = (r['total_bytes'] as num?)?.toInt() ?? 0;

      if (cat == 'photos') {
        photosCount += count;
        photosBytes += bytes;
      } else if (cat == 'videos') {
        videosCount += count;
        videosBytes += bytes;
      } else if (cat == 'documents') {
        docsCount += count;
        docsBytes += bytes;
      } else {
        otherCount += count;
        otherBytes += bytes;
      }
    }

    final totalCount = photosCount + videosCount + docsCount + otherCount;
    final totalBytes = photosBytes + videosBytes + docsBytes + otherBytes;

    return NuvexStorageStats(
      photos: CategoryStorageStat(count: photosCount, totalBytes: photosBytes),
      videos: CategoryStorageStat(count: videosCount, totalBytes: videosBytes),
      documents: CategoryStorageStat(count: docsCount, totalBytes: docsBytes),
      other: CategoryStorageStat(count: otherCount, totalBytes: otherBytes),
      totalCount: totalCount,
      totalBytes: totalBytes,
    );
  }

  /// Closes database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// Statistics for a single storage category.
class CategoryStorageStat {
  final int count;
  final int totalBytes;

  const CategoryStorageStat({required this.count, required this.totalBytes});
}

/// Aggregated storage statistics derived from real SQLite metadata.
class NuvexStorageStats {
  final CategoryStorageStat photos;
  final CategoryStorageStat videos;
  final CategoryStorageStat documents;
  final CategoryStorageStat other;
  final int totalCount;
  final int totalBytes;

  const NuvexStorageStats({
    required this.photos,
    required this.videos,
    required this.documents,
    required this.other,
    required this.totalCount,
    required this.totalBytes,
  });

  static const NuvexStorageStats empty = NuvexStorageStats(
    photos: CategoryStorageStat(count: 0, totalBytes: 0),
    videos: CategoryStorageStat(count: 0, totalBytes: 0),
    documents: CategoryStorageStat(count: 0, totalBytes: 0),
    other: CategoryStorageStat(count: 0, totalBytes: 0),
    totalCount: 0,
    totalBytes: 0,
  );
}
