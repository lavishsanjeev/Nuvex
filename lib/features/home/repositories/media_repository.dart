import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/nuvex_database.dart';
import '../../../core/database/remote_file.dart';
import '../../../core/utils/image_dimensions.dart';
import '../../../telegram/telegram_media_service.dart';
import '../../../telegram/telegram_models.dart';

/// Repository coordinating local SQLite database cache and Telegram MTProto media sync.
///
/// Implements local-first pattern:
/// 1. Immediately loads cached records from SQLite DB for fast zero-latency UI rendering.
/// 2. Asynchronously synchronizes newest Telegram metadata in background.
/// 3. Updates SQLite DB and notifies presentation layers.
class MediaRepository {
  final NuvexDatabase _database;
  final TelegramMediaService _mediaService;
  final Map<int, Future<RemoteFile>> _inFlightDownloads = {};

  MediaRepository({NuvexDatabase? database, TelegramMediaService? mediaService})
    : _database = database ?? NuvexDatabase(),
      _mediaService = mediaService ?? TelegramMediaService();

  NuvexDatabase get database => _database;
  TelegramMediaService get mediaService => _mediaService;

  /// Loads cached recent media (photos and videos) from SQLite database.
  /// Loads cached recent media (photos and videos) from SQLite database.
  Future<List<RemoteFile>> getCachedRecentMedia({
    int? limit,
    int offset = 0,
  }) async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }
    return _database.getRecentMedia(limit: limit, offset: offset);
  }

  /// Loads real collection counts derived directly from SQLite database.
  Future<Map<String, int>> getCachedCollectionCounts() async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }
    return _database.getCollectionCounts();
  }

  /// Loads files for a given collection category from SQLite database.
  Future<List<RemoteFile>> getCachedFilesByCategory(
    String category, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }
    return _database.getFilesByCategory(category, limit: limit, offset: offset);
  }

  /// Retrieves real storage statistics aggregated directly from SQLite metadata.
  Future<NuvexStorageStats> getStorageStats() async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }
    return _database.getStorageStats();
  }

  /// Synchronizes metadata from Telegram Saved Messages into local database across multiple pages.
  ///
  /// Conforms strictly to requirements:
  /// - Paginates until no more messages or boundary reached
  /// - Uses correct Telegram oldest message ID offset for subsequent pages
  /// - Deduplicates by Telegram message ID
  /// - Preserves newest-to-oldest ordering
  /// - Does not repeatedly fetch the same page
  /// - Upserts into SQLite without creating duplicate rows
  /// - Distinguishes total Telegram messages, media items extracted, database count, gallery query count
  Future<List<RemoteFile>> syncSavedMessages({
    int? limit,
    int pageSize = 30,
    int? maxTotalMessages,
    int maxPages = 50,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final effectivePageSize = limit ?? pageSize;
    if (!_database.isInitialized) {
      await _database.initialize();
    }

    String? thumbsDir;
    try {
      final dir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 500),
      );
      thumbsDir = '${dir.path}/nuvex_thumbs';
      _ensureNoMedia(thumbsDir);
    } catch (_) {
      thumbsDir = '${Directory.systemTemp.path}/nuvex_thumbs';
    }

    int currentOffsetId = 0;
    int pageIndex = 0;
    int totalTelegramMessagesFetched = 0;
    final Map<int, RemoteFile> allExtractedMedia = {};
    final Set<int> seenOffsets = {};

    debugPrint(
      '[SYNC_PAGINATION] Starting Telegram Saved Messages sync: pageSize=$effectivePageSize, maxPages=$maxPages',
    );

    while (pageIndex < maxPages) {
      if (seenOffsets.contains(currentOffsetId)) {
        debugPrint(
          '[SYNC_PAGINATION] Offset $currentOffsetId already visited, terminating to prevent loop',
        );
        break;
      }
      seenOffsets.add(currentOffsetId);
      pageIndex++;

      debugPrint(
        '[SYNC_DIAGNOSTIC] [Stage 1 & 2] Telegram request limit: $effectivePageSize | offsetId: $currentOffsetId',
      );

      final pageMedia = await _mediaService.fetchSavedMessagesPage(
        offsetId: currentOffsetId,
        limit: effectivePageSize,
        thumbsDir: thumbsDir,
        timeout: timeout,
      );

      final totalRawInPage = _mediaService.lastTotalMessagesInPage > 0
          ? _mediaService.lastTotalMessagesInPage
          : pageMedia.length;
      totalTelegramMessagesFetched += totalRawInPage;

      for (final file in pageMedia) {
        allExtractedMedia[file.telegramMessageId] = file;
      }

      if (pageMedia.isNotEmpty) {
        await _database.upsertFiles(pageMedia);
      }

      final oldestMsgId = _mediaService.lastOldestMessageId ??
          (pageMedia.isNotEmpty
              ? pageMedia
                  .map((f) => f.telegramMessageId)
                  .reduce((a, b) => a < b ? a : b)
              : null);

      final bool hasMore = (totalRawInPage >= effectivePageSize ||
              pageMedia.length >= effectivePageSize) &&
          oldestMsgId != null &&
          oldestMsgId != currentOffsetId;

      debugPrint(
        '[SYNC_PAGINATION] Page $pageIndex completed: '
        'rawMessages=$totalRawInPage, '
        'extractedMediaThisPage=${pageMedia.length}, '
        'cumulativeMedia=${allExtractedMedia.length}, '
        'oldestMessageId=$oldestMsgId, '
        'hasMore=$hasMore',
      );

      if (!hasMore ||
          oldestMsgId == currentOffsetId ||
          pageMedia.isEmpty) {
        debugPrint(
          '[SYNC_PAGINATION] Reached end of Telegram history on page $pageIndex',
        );
        break;
      }

      if (maxTotalMessages != null &&
          totalTelegramMessagesFetched >= maxTotalMessages) {
        debugPrint(
          '[SYNC_PAGINATION] Reached maxTotalMessages boundary ($maxTotalMessages)',
        );
        break;
      }

      currentOffsetId = oldestMsgId;
    }

    // Retrieve full recent media from local database
    final galleryMedia = await _database.getRecentMedia();

    debugPrint(
      '[SYNC_SUMMARY] Total Telegram messages: $totalTelegramMessagesFetched | '
      'Recognized media extracted: ${allExtractedMedia.length} | '
      'Gallery query loaded: ${galleryMedia.length} items',
    );

    return galleryMedia;
  }

  final Map<int, Future<RemoteFile>> _inFlightThumbDownloads = {};
  Future<void> _thumbLock = Future.value();

  /// Ensures a thumbnail is downloaded and cached locally on disk.
  ///
  /// - Verifies if [file.thumbnailPath] or [file.localPath] actually exists on disk.
  /// - If missing, downloads small thumbnail on demand from Telegram MTProto.
  /// - Deduplicates simultaneous requests for the same file ID.
  /// - Updates local SQLite database record with [thumbnailPath].
  Future<RemoteFile> ensureThumbnailAvailable(RemoteFile file) async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }

    // 1. If full media is already downloaded, it serves as the full-res thumbnail
    if (file.localPath != null && file.localPath!.isNotEmpty) {
      final existing = File(file.localPath!);
      if (existing.existsSync() && existing.lengthSync() > 0) {
        return file;
      }
    }

    // 2. If existing thumbnail path is valid on disk and is a genuine HQ thumbnail, reuse immediately
    if (file.thumbnailPath != null && file.thumbnailPath!.isNotEmpty) {
      final existing = File(file.thumbnailPath!);
      if (isValidHqThumbnail(existing)) {
        return file;
      }
    }

    // 3. Deduplicate in-flight download requests
    final msgId = file.telegramMessageId;
    if (_inFlightThumbDownloads.containsKey(msgId)) {
      return _inFlightThumbDownloads[msgId]!;
    }

    final future = _executeThumbDownload(file);
    _inFlightThumbDownloads[msgId] = future;

    try {
      return await future;
    } finally {
      _inFlightThumbDownloads.remove(msgId);
    }
  }

  Future<RemoteFile> _executeThumbDownload(RemoteFile file) async {
    String basePath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      basePath = dir.path;
    } catch (_) {
      basePath = Directory.systemTemp.path;
    }

    _ensureNoMedia('$basePath/nuvex_thumbs');
    final targetPath =
        '$basePath/nuvex_thumbs/${file.telegramMessageId}_hq.jpg';
    final targetFile = File(targetPath);

    if (isValidHqThumbnail(targetFile)) {
      final updated = file.copyWith(thumbnailPath: targetPath);
      await _database.upsertFiles([updated]);
      return updated;
    }

    // Sequentialize network downloads to prevent MTProto TCP socket contention
    final prevLock = _thumbLock;
    final completer = Completer<void>();
    _thumbLock = completer.future;

    try {
      await prevLock;
      // Re-check if written while waiting
      if (isValidHqThumbnail(targetFile)) {
        final updated = file.copyWith(thumbnailPath: targetPath);
        await _database.upsertFiles([updated]);
        return updated;
      }

      // Download thumbnail from Telegram MTProto
      await _mediaService.downloadThumbnailFile(
        file: file,
        destinationPath: targetPath,
      );

      final updated = file.copyWith(thumbnailPath: targetPath);
      await _database.upsertFiles([updated]);
      return updated;
    } finally {
      completer.complete();
    }
  }

  /// Ensures a media file is downloaded and cached locally on disk.
  ///
  /// - Verifies if [file.localPath] actually exists on disk.
  /// - If missing, downloads full payload on demand from Telegram MTProto.
  /// - Deduplicates simultaneous requests for the same file ID.
  /// - Updates local SQLite database record with [localPath].
  Future<RemoteFile> ensureFileDownloaded(
    RemoteFile file, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_database.isInitialized) {
      await _database.initialize();
    }

    // 1. If existing path is still valid on disk, reuse immediately
    if (file.localPath != null && file.localPath!.isNotEmpty) {
      final existing = File(file.localPath!);
      if (existing.existsSync() && existing.lengthSync() > 0) {
        return file;
      }
    }

    // 2. Reuse in-flight download if user tapped repeatedly
    final msgId = file.telegramMessageId;
    if (_inFlightDownloads.containsKey(msgId)) {
      return _inFlightDownloads[msgId]!;
    }

    final future = _executeDownload(file, onProgress: onProgress);
    _inFlightDownloads[msgId] = future;

    try {
      return await future;
    } finally {
      _inFlightDownloads.remove(msgId);
    }
  }

  Future<RemoteFile> _executeDownload(
    RemoteFile file, {
    void Function(double progress)? onProgress,
  }) async {
    String basePath;
    try {
      final dir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 500),
      );
      basePath = dir.path;
    } catch (_) {
      basePath = Directory.systemTemp.path;
    }

    _ensureNoMedia('$basePath/nuvex_media');
    final safeName = file.name.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final targetPath =
        '$basePath/nuvex_media/${file.telegramMessageId}_$safeName';
    final targetFile = File(targetPath);

    if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
      final updated = file.copyWith(localPath: targetPath);
      await _database.upsertFiles([updated]);
      return updated;
    }

    // Download from Telegram MTProto
    await _mediaService.downloadMediaFile(
      file: file,
      destinationPath: targetPath,
      onProgress: onProgress,
    );

    final updated = file.copyWith(localPath: targetPath);
    await _database.upsertFiles([updated]);
    return updated;
  }

  /// Ensures a directory exists and contains a .nomedia file as an extra safeguard
  /// to guarantee Android MediaStore never indexes app-private cache files.
  void _ensureNoMedia(String directoryPath) {
    try {
      final dir = Directory(directoryPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final noMedia = File('$directoryPath/.nomedia');
      if (!noMedia.existsSync()) {
        noMedia.createSync();
      }
    } catch (_) {}
  }

  /// Deletes media from Telegram, cleans up local app-private cache files,
  /// and removes the record from the SQLite database.
  Future<void> deleteMedia(RemoteFile file) async {
    // 1. Delete from Telegram Cloud using existing authenticated MTProto connection
    await _mediaService.deleteMessage(messageId: file.telegramMessageId);

    // 2. Clear local cached thumbnail and original (safeguarded: only within app-private cache)
    deleteLocalCachedFiles(file);

    // 3. Delete from local SQLite database
    if (!_database.isInitialized) {
      await _database.initialize();
    }
    await _database.deleteFile(file.telegramMessageId);
  }

  /// Safely deletes local cached files strictly within Nuvex app-private cache directories.
  /// Strictly complies with the requirement: "Never delete arbitrary device files."
  void deleteLocalCachedFiles(RemoteFile file) {
    if (file.thumbnailPath != null && file.thumbnailPath!.isNotEmpty) {
      try {
        final thumbFile = File(file.thumbnailPath!);
        if (thumbFile.path.contains('nuvex_thumbs') && thumbFile.existsSync()) {
          thumbFile.deleteSync();
        }
      } catch (e) {
        debugPrint('[DELETE] Error removing cached thumbnail: $e');
      }
    }

    if (file.localPath != null && file.localPath!.isNotEmpty) {
      try {
        final localFile = File(file.localPath!);
        if (localFile.path.contains('nuvex_media') && localFile.existsSync()) {
          localFile.deleteSync();
        }
      } catch (e) {
        debugPrint('[DELETE] Error removing cached media: $e');
      }
    }
  }

  /// Uploads a local file to Telegram Saved Messages in original quality without modifications.
  ///
  /// Optionally persists the resulting [RemoteFile] record to the local SQLite database.
  Future<TelegramUploadResult> uploadFile({
    required File file,
    String? mimeType,
    void Function(double progress)? onProgress,
    TelegramUploadCancelToken? cancelToken,
    int? randomId,
    bool saveToDatabase = true,
  }) async {
    final result = await _mediaService.uploadDocumentFile(
      file: file,
      mimeType: mimeType,
      onProgress: onProgress,
      cancelToken: cancelToken,
      randomId: randomId,
    );

    if (saveToDatabase) {
      if (!_database.isInitialized) {
        await _database.initialize();
      }
      final remoteFile = result.toRemoteFile(localPath: file.path);
      await _database.upsertFiles([remoteFile]);
      debugPrint(
        '[REPO] Persisted uploaded file #${result.messageId} to SQLite database',
      );
    }

    return result;
  }
}
