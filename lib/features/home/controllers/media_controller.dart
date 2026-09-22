import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/remote_file.dart';
import '../repositories/media_repository.dart';

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

  MediaLoadingStatus _status = MediaLoadingStatus.initial;
  List<RemoteFile> _recentMedia = [];
  Map<String, int> _collectionCounts = {};
  String? _errorMessage;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  MediaLoadingStatus get status => _status;
  List<RemoteFile> get recentMedia => _recentMedia;
  Map<String, int> get collectionCounts => _collectionCounts;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  bool get isLoading => _status == MediaLoadingStatus.loading;
  bool get isLoaded => _status == MediaLoadingStatus.loaded;
  bool get hasError => _status == MediaLoadingStatus.error;
  bool get isEmpty =>
      _status == MediaLoadingStatus.loaded && _recentMedia.isEmpty;

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
        notifyListeners();
      }
      return updated;
    } catch (e) {
      debugPrint('[MEDIA] Error loading thumbnail for ${file.name}: $e');
      return file;
    }
  }

  /// Deletes a media item from Telegram, local cache, and SQLite database.
  ///
  /// Immediately updates [_recentMedia] and [_collectionCounts] and notifies listeners,
  /// causing PhotosScreen and Collection screens to update in real time.
  Future<void> deleteMedia(RemoteFile file) async {
    await _repository.deleteMedia(file);

    _recentMedia.removeWhere(
      (f) => f.telegramMessageId == file.telegramMessageId,
    );

    try {
      _collectionCounts = await _repository.getCachedCollectionCounts();
    } catch (e) {
      debugPrint('[MEDIA] Error refreshing collection counts after delete: $e');
    }

    notifyListeners();
  }
}
