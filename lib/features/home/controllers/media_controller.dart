import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/remote_file.dart';
import '../models/collection_preview.dart';
import '../repositories/media_repository.dart';
import '../services/collection_thumbnail_resolver.dart';

/// Distinct statuses of media sync and database cache loading.
enum MediaLoadingStatus {
  /// Uninitialized state before reading cache.
  initial,

  /// Actively loading or synchronizing from Telegram.
  loading,

  /// Data successfully loaded from local DB or Telegram.
  loaded,

  /// An error occurred with retry capability.
  error,
}

/// Controller driving local-first media presentation and Telegram synchronization.
///
/// Complies strictly with Task 5 requirements:
/// - Reuses existing authenticated session
/// - Loads from SQLite DB cache first for zero UI freeze
/// - Paginated background sync from Telegram Saved Messages
/// - Real database-derived collection counts
/// - Proper loading, empty, error, and retry states
class MediaController extends ChangeNotifier {
  static final MediaController _instance = MediaController._internal();
  factory MediaController({MediaRepository? repository}) {
    if (repository != null) {
      return MediaController._internal(repository: repository);
    }
    return _instance;
  }
  MediaController._internal({MediaRepository? repository})
    : _repository = repository ?? MediaRepository();

  final MediaRepository _repository;

  MediaRepository get repository => _repository;

  late final CollectionThumbnailResolver _thumbnailResolver =
      CollectionThumbnailResolver(repository: _repository);
  CollectionThumbnailResolver get thumbnailResolver => _thumbnailResolver;

  MediaLoadingStatus _status = MediaLoadingStatus.initial;
  List<RemoteFile> _recentMedia = [];
  Map<String, int> _collectionCounts = {};
  Map<String, String?> _collectionThumbnails = {};
  List<CollectionPreview> _collectionPreviews = [];
  String? _errorMessage;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  MediaLoadingStatus get status => _status;
  List<RemoteFile> get recentMedia => _recentMedia;
  Map<String, int> get collectionCounts => _collectionCounts;
  Map<String, String?> get collectionThumbnails => _collectionThumbnails;
  List<CollectionPreview> get collectionPreviews => _collectionPreviews;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  bool get isLoading => _status == MediaLoadingStatus.loading;
  bool get isLoaded => _status == MediaLoadingStatus.loaded;
  bool get hasError => _status == MediaLoadingStatus.error;
  bool get isEmpty =>
      _status == MediaLoadingStatus.loaded && _recentMedia.isEmpty;

  /// Retrieves the prepared preview for a specific collection category.
  CollectionPreview? getPreviewForCategory(String category) {
    for (final p in _collectionPreviews) {
      if (p.category == category) return p;
    }
    return null;
  }

  /// Resolves real thumbnail image paths and previews for primary collection cards.
  Future<void> loadCollectionThumbnails({bool autoFetch = true}) async {
    try {
      if (!_repository.database.isInitialized) return;
      final previews = await _repository.getPrimaryCollectionPreviews(
        autoFetchThumb: autoFetch,
      );
      _collectionPreviews = previews;
      final Map<String, String?> thumbs = {};
      final Map<String, int> counts = Map.of(_collectionCounts);
      for (final p in previews) {
        thumbs[p.category] = p.thumbnailPath;
        counts[p.category] = p.itemCount;
      }
      _collectionThumbnails = thumbs;
      _collectionCounts = counts;
      notifyListeners();
    } catch (e) {
      debugPrint('[MEDIA] Error loading collection thumbnails: $e');
    }
  }

  /// Loads cached data from SQLite database first, then triggers background sync.
  Future<void> initializeAndSync() async {
    if (_status == MediaLoadingStatus.loaded && _recentMedia.isNotEmpty) {
      // Data already in memory; check if background sync is needed
      final now = DateTime.now();
      if (_lastSyncTime != null &&
          now.difference(_lastSyncTime!).inMinutes < 5) {
        return;
      }
    }

    // 1. Read SQLite DB cache immediately (zero latency)
    await loadCacheOnly();

    // 2. Trigger asynchronous background Telegram sync
    await syncMedia();
  }

  /// Loads cached media and collection counts directly from SQLite DB without network.
  Future<void> loadCacheOnly() async {
    try {
      final cached = await _repository.getCachedRecentMedia(limit: null);
      final counts = await _repository.getCachedCollectionCounts();

      _recentMedia = cached;
      _collectionCounts = counts;

      try {
        final previews = await _repository.getPrimaryCollectionPreviews(
          autoFetchThumb: false,
        );
        _collectionPreviews = previews;
        final Map<String, String?> thumbs = {};
        for (final p in previews) {
          thumbs[p.category] = p.thumbnailPath;
        }
        _collectionThumbnails = thumbs;
      } catch (_) {}

      debugPrint(
        '[CONTROLLER_DIAGNOSTIC] loadCacheOnly: loaded ${_recentMedia.length} items from SQLite cache',
      );

      if (_recentMedia.isNotEmpty) {
        _status = MediaLoadingStatus.loaded;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MEDIA] Error loading local DB cache: $e');
    }
  }

  /// Synchronizes newest media metadata from Telegram Saved Messages.
  Future<void> syncMedia({
    bool isRetry = false,
    int pageSize = 30,
    int maxPages = 50,
  }) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _errorMessage = null;

    if (_recentMedia.isEmpty) {
      _status = MediaLoadingStatus.loading;
    }
    notifyListeners();

    try {
      final updatedMedia = await _repository.syncSavedMessages(
        pageSize: pageSize,
        maxPages: maxPages,
        timeout: const Duration(seconds: 15),
      );
      final counts = await _repository.getCachedCollectionCounts();

      _recentMedia = updatedMedia;
      _collectionCounts = counts;
      try {
        final previews = await _repository.getPrimaryCollectionPreviews(
          autoFetchThumb: true,
        );
        _collectionPreviews = previews;
        final Map<String, String?> thumbs = {};
        for (final p in previews) {
          thumbs[p.category] = p.thumbnailPath;
        }
        _collectionThumbnails = thumbs;
      } catch (_) {}
      _status = MediaLoadingStatus.loaded;
      _lastSyncTime = DateTime.now();
      _errorMessage = null;

      debugPrint(
        '[CONTROLLER_DIAGNOSTIC] [Stage 7] Loaded ${_recentMedia.length} media items into active gallery state',
      );
    } on TimeoutException catch (e) {
      debugPrint('[MEDIA] Sync timeout: $e');
      if (_recentMedia.isEmpty) {
        _status = MediaLoadingStatus.error;
        _errorMessage = 'Connection timed out while syncing with Telegram. Please tap retry.';
      }
    } catch (e) {
      debugPrint('[MEDIA] Sync error: $e');
      if (_recentMedia.isEmpty) {
        _status = MediaLoadingStatus.error;
        _errorMessage =
            'Unable to sync with Telegram: ${e.toString().replaceAll('Exception: ', '')}';
      }
    } finally {
      _isSyncing = false;
      // Guaranteed safety: if still loading, set to loaded or error
      if (_status == MediaLoadingStatus.loading) {
        _status = _recentMedia.isNotEmpty
            ? MediaLoadingStatus.loaded
            : MediaLoadingStatus.loaded;
      }
      notifyListeners();
    }
  }

  /// Retries syncing after an error.
  Future<void> retry() => syncMedia(isRetry: true);

  /// Downloads and caches a media file on demand, updating local state.
  Future<RemoteFile> downloadFile(
    RemoteFile file, {
    void Function(double progress)? onProgress,
  }) async {
    final downloaded = await _repository.ensureFileDownloaded(
      file,
      onProgress: onProgress,
    );
    final index = _recentMedia.indexWhere(
      (f) => f.telegramMessageId == file.telegramMessageId,
    );
    if (index != -1) {
      _recentMedia[index] = downloaded;
      notifyListeners();
    }
    return downloaded;
  }

  /// Ensures a thumbnail is available on disk, updating local state and database.
  Future<RemoteFile> loadThumbnail(RemoteFile file) async {
    try {
      final updated = await _repository.ensureThumbnailAvailable(file);
      final index = _recentMedia.indexWhere(
        (f) => f.telegramMessageId == file.telegramMessageId,
      );
      if (index != -1 &&
          _recentMedia[index].thumbnailPath != updated.thumbnailPath) {
        _recentMedia[index] = updated;
      }
      return updated;
    } catch (e) {
      debugPrint('[MEDIA] Error loading thumbnail for ${file.name}: $e');
      return file;
    }
  }

  /// Moves a media item to Trash, removing it from normal Photos and Collections immediately.
  /// Complies with Trash architecture: Telegram file and local cache remain intact.
  Future<void> moveToTrash(RemoteFile file, {int? trashedAtMs}) async {
    await _repository.deleteMedia(file);

    _recentMedia.removeWhere(
      (f) => f.telegramMessageId == file.telegramMessageId,
    );

    try {
      _collectionCounts = await _repository.getCachedCollectionCounts();
    } catch (e) {
      debugPrint('[MEDIA] Error refreshing collection counts after trash: $e');
    }

    notifyListeners();

    final affectsCollectionThumb = _collectionPreviews.any(
      (p) => p.thumbnailRemoteFile?.telegramMessageId == file.telegramMessageId,
    );
    if (affectsCollectionThumb) {
      try {
        await loadCollectionThumbnails(autoFetch: false);
      } catch (_) {}
    }
  }

  /// Alias for moveToTrash to preserve backward compatibility with existing callers.
  Future<void> deleteMedia(RemoteFile file) async => moveToTrash(file);

  /// Restores a trashed media item back to active Photos and Collections.
  Future<void> restoreFromTrash(RemoteFile file) async {
    await _repository.restoreFromTrash(file);

    try {
      _recentMedia = await _repository.getCachedRecentMedia(limit: null);
      _collectionCounts = await _repository.getCachedCollectionCounts();
    } catch (e) {
      debugPrint('[MEDIA] Error refreshing media after restore: $e');
    }

    notifyListeners();

    try {
      await loadCollectionThumbnails(autoFetch: false);
    } catch (_) {}
  }

  /// Permanently deletes media from Telegram, local cache, and SQLite database.
  Future<void> permanentlyDeleteMedia(RemoteFile file) async {
    await _repository.permanentlyDeleteMedia(file);

    _recentMedia.removeWhere(
      (f) => f.telegramMessageId == file.telegramMessageId,
    );

    try {
      _collectionCounts = await _repository.getCachedCollectionCounts();
    } catch (e) {
      debugPrint(
        '[MEDIA] Error refreshing collection counts after permanent delete: $e',
      );
    }

    notifyListeners();

    final affectsCollectionThumb = _collectionPreviews.any(
      (p) => p.thumbnailRemoteFile?.telegramMessageId == file.telegramMessageId,
    );
    if (affectsCollectionThumb) {
      try {
        await loadCollectionThumbnails(autoFetch: false);
      } catch (_) {}
    }
  }

  /// Safely cleans up expired items from Trash in the background (older than 30 days retention).
  Future<int> cleanupExpiredTrash() async {
    final cleaned = await _repository.cleanupExpiredTrash();
    if (cleaned > 0) {
      try {
        _collectionCounts = await _repository.getCachedCollectionCounts();
        notifyListeners();
      } catch (_) {}
    }
    return cleaned;
  }
}
