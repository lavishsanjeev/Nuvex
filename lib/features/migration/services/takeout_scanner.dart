import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../telegram/telegram_models.dart';
import '../models/migration_queue_item.dart';

/// Metadata extracted from a scanned Google Takeout file.
class ScannedTakeoutItem {
  final String path;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final String mimeType;
  final String category;

  const ScannedTakeoutItem({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.mimeType,
    required this.category,
  });

  /// Converts this scanned item to a queued database item.
  MigrationQueueItem toQueueItem({int? telegramRandomId}) {
    return MigrationQueueItem.create(
      localPath: path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      sha256: sha256,
      mimeType: mimeType,
      category: category,
      telegramRandomId: telegramRandomId,
    );
  }
}

/// Scanner for Google Takeout / Google Photos directory exports.
///
/// Features:
/// - Recursively traverses directories without modifying or moving source files
/// - Filters out Google metadata JSON files and OS artifacts
/// - Computes SHA-256 via streaming without loading complete files into memory
/// - Classifies MIME types and categories across all standard media and document formats
class TakeoutScanner {
  const TakeoutScanner();

  /// Scans [directory] recursively and yields a list of valid media/document items.
  Future<List<ScannedTakeoutItem>> scanDirectory(
    Directory directory, {
    void Function(int count, String currentPath)? onProgress,
    TelegramUploadCancelToken? cancelToken,
  }) async {
    if (!directory.existsSync()) {
      throw FileSystemException(
        'Takeout directory does not exist',
        directory.path,
      );
    }

    final List<ScannedTakeoutItem> items = [];
    int scannedCount = 0;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      cancelToken?.throwIfCancelled();

      if (entity is! File) continue;

      final file = entity;
      final fileName = p.basename(file.path);

      if (shouldIgnoreFile(fileName)) {
        continue;
      }

      int sizeBytes = 0;
      try {
        sizeBytes = file.lengthSync();
      } catch (e) {
        debugPrint('[SCANNER] Unable to read size for ${file.path}: $e');
        continue;
      }

      // Ignore 0-byte corrupted or placeholder files
      if (sizeBytes == 0) {
        continue;
      }

      // Stream SHA-256 computation to keep memory footprint bounded
      final hash = await computeFileSha256(file, cancelToken: cancelToken);
      if (hash == null) continue;

      final mimeType = detectMimeType(fileName);
      final category = detectCategory(mimeType, fileName);

      final item = ScannedTakeoutItem(
        path: p.normalize(file.path),
        fileName: fileName,
        sizeBytes: sizeBytes,
        sha256: hash,
        mimeType: mimeType,
        category: category,
      );

      items.add(item);
      scannedCount++;
      onProgress?.call(scannedCount, file.path);
    }

    debugPrint(
      '[SCANNER] Completed scan of ${directory.path}: discovered ${items.length} media items',
    );
    return items;
  }

  /// Streams SHA-256 computation for a file without loading entire file into memory.
  Future<String?> computeFileSha256(
    File file, {
    TelegramUploadCancelToken? cancelToken,
  }) async {
    try {
      cancelToken?.throwIfCancelled();
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      if (e is TelegramUploadCancelledException) rethrow;
      debugPrint('[SCANNER] Failed to compute SHA-256 for ${file.path}: $e');
      return null;
    }
  }

  /// Evaluates whether a file should be ignored.
  ///
  /// Ignores:
  /// - Google metadata JSON files (e.g. `.json`, `.supplemental-metadata.json`, `.info.json`)
  /// - System files (e.g. `.DS_Store`, `Thumbs.db`, `desktop.ini`, `._*`)
  bool shouldIgnoreFile(String fileName) {
    final lower = fileName.toLowerCase();

    // 1. System files and hidden artifacts
    if (lower == '.ds_store' ||
        lower == 'thumbs.db' ||
        lower == 'desktop.ini' ||
        lower.startsWith('._') ||
        lower.endsWith('.tmp') ||
        lower.endsWith('.crdownload')) {
      return true;
    }

    // 2. Google Takeout metadata JSON files
    // Matches: photo.jpg.json, supplemental-metadata.json, metadata.json, etc.
    if (lower.endsWith('.json')) {
      return true;
    }

    return false;
  }

  /// Detects MIME type from file extension.
  String detectMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.dng':
        return 'image/x-adobe-dng';
      case '.raw':
        return 'image/x-panasonic-raw';
      case '.cr2':
        return 'image/x-canon-cr2';
      case '.nef':
        return 'image/x-nikon-nef';
      case '.arw':
        return 'image/x-sony-arw';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.3gp':
        return 'video/3gpp';
      case '.m4v':
        return 'video/x-m4v';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.flac':
        return 'audio/flac';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
      case '.oga':
        return 'audio/ogg';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      case '.tar':
      case '.gz':
        return 'application/gzip';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Detects Nuvex media category from MIME type and filename.
  String detectCategory(String mimeType, String fileName) {
    final lower = fileName.toLowerCase();
    if (mimeType.startsWith('video/')) {
      return 'videos';
    } else if (lower.contains('screenshot') ||
        lower.startsWith('screen_') ||
        lower.startsWith('scr_') ||
        lower.startsWith('screenshot_')) {
      return 'screenshots';
    } else if (mimeType == 'application/x-tgsticker' ||
        mimeType == 'image/webp' ||
        lower.endsWith('.tgs')) {
      return 'stickers';
    } else if (mimeType.startsWith('image/')) {
      return 'photos';
    } else {
      return 'documents';
    }
  }
}
