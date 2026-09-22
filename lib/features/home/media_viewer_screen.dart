import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';
import '../../core/database/remote_file.dart';
import '../../core/services/native_media_service.dart';
import '../../core/services/video_prefetch_manager.dart';
import '../../core/services/video_streaming_proxy.dart';
import 'controllers/media_controller.dart';

/// Full-screen immersive media viewer and player for original-quality Telegram media.
///
/// Implements Task 6 & Task 6 Fix requirements:
/// - Horizontal swipe left/right navigation across the current media list via PageView
/// - Pure black edge-to-edge immersive background (Google Photos style)
/// - Minimal floating top bar with Back button only
/// - Photo uses maximum available screen area with BoxFit.contain (no initial crop)
/// - InteractiveViewer with pinch-to-zoom (1.0x to 5.0x) and pan
/// - Critical Zoom/Pan conflict resolution:
///   * At normal/fit zoom (1.0x): panEnabled is false, PageView physics is BouncingScrollPhysics;
///     horizontal swipe changes media without gesture contention.
///   * When zoomed in (>1.05x): panEnabled is true, PageView physics is NeverScrollableScrollPhysics;
///     all gestures pan/zoom the image and NEVER change the page.
///   * Double-tap back to fit scale immediately re-enables page swiping.
/// - Preloads adjacent item thumbnails for smooth transitions (without preloading heavy originals).
/// - Safe boundaries at first/last items.
/// - Clean lifecycle management: pauses video when swiped away, disposes controllers.
/// - Bottom action bar with real Android Share, Save to Device, and Media Details.
class MediaViewerScreen extends StatefulWidget {
  final List<RemoteFile> files;
  final int initialIndex;
  final MediaController controller;

  /// Backwards-compatible getter returning the active/initial file for single-file tests and callers.
  RemoteFile get file => files.isNotEmpty
      ? files[initialIndex.clamp(0, files.length - 1)]
      : RemoteFile(
          id: 0,
          telegramChatId: 0,
          telegramMessageId: 0,
          telegramFileId: 0,
          name: '',
          mimeType: 'image/jpeg',
          sizeBytes: 0,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
          category: 'photos',
        );

  MediaViewerScreen({
    super.key,
    List<RemoteFile>? files,
    RemoteFile? file,
    int initialIndex = 0,
    required this.controller,
  }) : files = files ?? (file != null ? [file] : const []),
       initialIndex = file != null && (files == null || files.isEmpty)
           ? 0
           : initialIndex;

  /// Creates a transparent page route allowing the underlying gallery to show
  /// through smoothly during the vertical swipe-to-dismiss gesture.
  static Route<void> route({
    required List<RemoteFile> files,
    int initialIndex = 0,
    required MediaController controller,
  }) {
    return PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) =>
          MediaViewerScreen(
            files: files,
            initialIndex: initialIndex,
            controller: controller,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  late List<RemoteFile> _files;
  bool _isCurrentItemZoomed = false;
  bool _showControls = true;
  bool _isSharing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  // Swipe-down to dismiss gesture state
  double _dragOffsetY = 0.0;
  bool _isDismissing = false;
  late final AnimationController _resetAnimationController;
  Animation<double>? _resetAnimation;

  RemoteFile get _currentFile => _files.isNotEmpty
      ? _files[_currentIndex.clamp(0, _files.length - 1)]
      : widget.file;

  int get currentIndex => _currentIndex;
  RemoteFile get currentFile => _currentFile;

  @override
  void initState() {
    super.initState();
    _files = List<RemoteFile>.from(widget.files);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _files.isEmpty ? 0 : _files.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
    _preloadAdjacent(_currentIndex);

    _resetAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (_resetAnimation != null) {
            setState(() {
              _dragOffsetY = _resetAnimation!.value;
            });
          }
        });
  }

  /// Preloads thumbnails for adjacent items only (Correction 4: never heavy originals).
  void _preloadAdjacent(int index) {
    if (_files.isEmpty) return;
    if (index > 0) {
      widget.controller.loadThumbnail(_files[index - 1]);
    }
    if (index < _files.length - 1) {
      widget.controller.loadThumbnail(_files[index + 1]);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resetAnimationController.dispose();
    super.dispose();
  }

  // ── Swipe-Down to Dismiss Handlers ──
  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isCurrentItemZoomed || _isDismissing) return;
    if (_resetAnimationController.isAnimating) {
      _resetAnimationController.stop();
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isCurrentItemZoomed || _isDismissing) return;
    // Disallow dragging upward when already at resting position
    if (_dragOffsetY == 0.0 && details.delta.dy < 0) {
      return;
    }
    setState(() {
      _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isCurrentItemZoomed || _isDismissing || _dragOffsetY <= 0.0) return;

    final velocity = details.primaryVelocity ?? 0.0;
    final isFastDownwardFlick = velocity > 600;
    final isPastThreshold = _dragOffsetY > 140;

    if (isFastDownwardFlick || isPastThreshold) {
      _dismissViewer();
    } else {
      _resetDragPosition();
    }
  }

  void _handleVerticalDragCancel() {
    if (_isCurrentItemZoomed || _isDismissing || _dragOffsetY <= 0.0) return;
    _resetDragPosition();
  }

  void _resetDragPosition() {
    _resetAnimation = Tween<double>(begin: _dragOffsetY, end: 0.0).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _resetAnimationController.forward(from: 0.0);
  }

  void _dismissViewer() {
    setState(() => _isDismissing = true);
    Navigator.of(context).pop();
  }

  // ── Delete Handler ──
  Future<void> _confirmDelete() async {
    if (_isDeleting || _files.isEmpty) return;
    final file = _currentFile;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Delete Media?',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this media? This will permanently remove it from Telegram and your device.',
          style: TextStyle(
            fontFamily: NuvexTypography.primaryFamily,
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _handleDelete(file);
    }
  }

  Future<void> _handleDelete(RemoteFile file) async {
    if (_isDeleting || _files.isEmpty) return;
    setState(() => _isDeleting = true);

    try {
      await widget.controller.deleteMedia(file);

      if (!mounted) return;

      final targetIndex = _files.indexWhere(
        (f) => f.telegramMessageId == file.telegramMessageId,
      );

      setState(() {
        if (targetIndex != -1) {
          _files.removeAt(targetIndex);
        }
        _isDeleting = false;
        _isCurrentItemZoomed = false;

        if (_files.isEmpty) {
          Navigator.of(context).pop();
          return;
        }

        if (_currentIndex >= _files.length) {
          _currentIndex = _files.length - 1;
        }
      });

      if (_files.isNotEmpty) {
        _pageController.jumpToPage(_currentIndex);
        _preloadAdjacent(_currentIndex);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media deleted from Telegram'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: NuvexColors.errorRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleDelete(file),
          ),
        ),
      );
    }
  }

  Future<bool> _isOriginalLocallyAvailable(RemoteFile file) async {
    final path = file.localPath;
    if (path == null || path.isEmpty) return false;
    if (path == file.thumbnailPath || path.contains('nuvex_thumbs')) {
      return false;
    }
    final ioFile = File(path);
    if (!await ioFile.exists()) return false;
    if (await ioFile.length() <= 0) return false;
    return true;
  }

  // ── Share Handler ──
  Future<void> _handleShare() async {
    if (_isSharing || _files.isEmpty) return;
    setState(() => _isSharing = true);

    try {
      final file = _currentFile;
      final isReady = await _isOriginalLocallyAvailable(file);
      if (!isReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Downloading original photo from Telegram for sharing...',
            ),
            duration: Duration(seconds: 2),
          ),
        );

        final downloaded = await widget.controller.downloadFile(file);
        if (mounted) {
          setState(() {
            _files[_currentIndex] = downloaded;
          });
        }
      }

      final activeFile = _currentFile;
      if (activeFile.localPath == null ||
          !File(activeFile.localPath!).existsSync()) {
        throw Exception('Local file is not available for sharing');
      }

      final resolvedMime = NativeMediaService.resolveMimeType(
        fileName: activeFile.name,
        currentMime: activeFile.mimeType,
        isPhoto: activeFile.isPhoto,
        isVideo: activeFile.isVideo,
      );

      await NativeMediaService.shareFile(
        filePath: activeFile.localPath!,
        mimeType: resolvedMime,
        title: activeFile.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sharing failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: NuvexColors.errorRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleShare,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  // ── Save to Device Handler ──
  Future<void> _handleSaveToDevice() async {
    if (_isSaving || _files.isEmpty) return;
    final file = _currentFile;

    final isReady = await _isOriginalLocallyAvailable(file);
    if (!isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching file from Telegram to save...'),
          duration: Duration(seconds: 2),
        ),
      );
      final downloaded = await widget.controller.downloadFile(file);
      if (mounted) {
        setState(() {
          _files[_currentIndex] = downloaded;
        });
      }
    }

    final activeFile = _currentFile;
    if (activeFile.localPath == null ||
        !File(activeFile.localPath!).existsSync()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedPath = await NativeMediaService.saveToDevice(
        filePath: activeFile.localPath!,
        fileName: activeFile.name,
        mimeType: activeFile.mimeType,
        category: activeFile.category,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saved to $savedPath',
                  style: const TextStyle(
                    fontFamily: NuvexTypography.primaryFamily,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: NuvexColors.errorRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleSaveToDevice,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Media Details Sheet ──
  void _showDetailsSheet() {
    final file = _currentFile;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isCachedLocally =
            file.localPath != null &&
            file.localPath != file.thumbnailPath &&
            !file.localPath!.contains('nuvex_thumbs') &&
            File(file.localPath!).existsSync() &&
            File(file.localPath!).lengthSync() > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF18181B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: NuvexColors.primaryBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Media Details',
                      style: TextStyle(
                        fontFamily: NuvexTypography.primaryFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                _buildDetailRow(
                  icon: Icons.title_rounded,
                  label: 'File Name',
                  value: file.name,
                ),
                _buildDetailRow(
                  icon: Icons.category_outlined,
                  label: 'Media Type',
                  value: file.mimeType,
                ),
                _buildDetailRow(
                  icon: Icons.data_usage_rounded,
                  label: 'File Size',
                  value:
                      '${file.formattedSize} (${_formatNumber(file.sizeBytes)} bytes)',
                ),
                _buildDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date & Time',
                  value: _formatFullDateTime(file.createdAt),
                ),
                if (file.width != null && file.height != null)
                  _buildDetailRow(
                    icon: Icons.aspect_ratio_rounded,
                    label: 'Resolution',
                    value: '${file.width} × ${file.height} px',
                  ),
                if (file.durationMs != null && file.durationMs! > 0)
                  _buildDetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(
                      Duration(milliseconds: file.durationMs!),
                    ),
                  ),
                _buildDetailRow(
                  icon: isCachedLocally
                      ? Icons.check_circle_outline
                      : Icons.cloud_outlined,
                  label: 'Storage Status',
                  value: isCachedLocally
                      ? 'Cached locally on device'
                      : 'Stored in Telegram Cloud',
                  valueColor: isCachedLocally
                      ? Colors.greenAccent
                      : NuvexColors.primaryBlue,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white60),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFullDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  String _formatNumber(int number) {
    final s = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final double bgOpacity = (1.0 - (_dragOffsetY / 320)).clamp(0.0, 1.0);
    final double dragScale = (1.0 - (_dragOffsetY / 1600)).clamp(0.82, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Edge-to-Edge Media PageView with swipe-down to dismiss gesture
          Positioned.fill(
            child: _files.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onVerticalDragStart: _isCurrentItemZoomed
                        ? null
                        : _handleVerticalDragStart,
                    onVerticalDragUpdate: _isCurrentItemZoomed
                        ? null
                        : _handleVerticalDragUpdate,
                    onVerticalDragEnd: _isCurrentItemZoomed
                        ? null
                        : _handleVerticalDragEnd,
                    onVerticalDragCancel: _isCurrentItemZoomed
                        ? null
                        : _handleVerticalDragCancel,
                    behavior: HitTestBehavior.translucent,
                    child: Transform.translate(
                      offset: Offset(0, _dragOffsetY),
                      child: Transform.scale(
                        scale: dragScale,
                        alignment: Alignment.center,
                        child: PageView.builder(
                          controller: _pageController,
                          physics: _isCurrentItemZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                          itemCount: _files.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                              _isCurrentItemZoomed = false;
                            });
                            _preloadAdjacent(index);
                          },
                          itemBuilder: (context, index) {
                            return _MediaPageItem(
                              key: ValueKey(_files[index].telegramMessageId),
                              file: _files[index],
                              controller: widget.controller,
                              isActive: index == _currentIndex,
                              onZoomChanged: (zoomed) {
                                if (index == _currentIndex &&
                                    _isCurrentItemZoomed != zoomed) {
                                  setState(() {
                                    _isCurrentItemZoomed = zoomed;
                                  });
                                }
                              },
                              onToggleControls: () {
                                if (!_isCurrentItemZoomed) {
                                  setState(() {
                                    _showControls = !_showControls;
                                  });
                                }
                              },
                              onFileUpdated: (updated) {
                                if (mounted) {
                                  setState(() {
                                    _files[index] = updated;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),

          // 2. Minimal Floating Top Overlay (Back button only)
          _buildTopOverlay(bgOpacity),

          // 3. Immersive Bottom Action Bar (Share, Save, Delete, Details)
          _buildBottomActionBar(bgOpacity),
        ],
      ),
    );
  }

  Widget _buildTopOverlay(double bgOpacity) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: (_showControls && !_isCurrentItemZoomed) ? bgOpacity : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showControls || _isCurrentItemZoomed || _dragOffsetY > 10,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(double bgOpacity) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: (_showControls && !_isCurrentItemZoomed) ? bgOpacity : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showControls || _isCurrentItemZoomed || _dragOffsetY > 10,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: _isSharing ? null : Icons.share_outlined,
                      isLoading: _isSharing,
                      label: 'Share',
                      onTap: _isSharing ? null : _handleShare,
                    ),
                    _buildActionButton(
                      icon: _isSaving ? null : Icons.file_download_outlined,
                      isLoading: _isSaving,
                      label: 'Save',
                      onTap: _isSaving ? null : _handleSaveToDevice,
                    ),
                    _buildActionButton(
                      icon: _isDeleting ? null : Icons.delete_outline_rounded,
                      iconColor: Colors.redAccent,
                      isLoading: _isDeleting,
                      label: 'Delete',
                      onTap: _isDeleting ? null : _confirmDelete,
                    ),
                    _buildActionButton(
                      icon: Icons.info_outline,
                      label: 'Details',
                      onTap: _showDetailsSheet,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    Color? iconColor,
    bool isLoading = false,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor ?? Colors.white,
                          ),
                        )
                      : Icon(icon, color: iconColor ?? Colors.white, size: 22),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: iconColor ?? Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone presentation widget for each media item in the PageView.
///
/// Encapsulates per-item zoom state, download lifecycle, and video player controls.
class _MediaPageItem extends StatefulWidget {
  final RemoteFile file;
  final MediaController controller;
  final bool isActive;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onToggleControls;
  final ValueChanged<RemoteFile> onFileUpdated;

  const _MediaPageItem({
    super.key,
    required this.file,
    required this.controller,
    required this.isActive,
    required this.onZoomChanged,
    required this.onToggleControls,
    required this.onFileUpdated,
  });

  @override
  State<_MediaPageItem> createState() => _MediaPageItemState();
}

class _MediaPageItemState extends State<_MediaPageItem>
    with SingleTickerProviderStateMixin {
  late RemoteFile _currentFile;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  // Zoom State
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  // Video State
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isStreaming = false;
  String? _activeStreamUrl;

  bool get _isVideo =>
      _currentFile.category == 'videos' ||
      _currentFile.mimeType.toLowerCase().startsWith('video/');

  bool get _isPhoto =>
      _currentFile.category == 'photos' ||
      _currentFile.mimeType.toLowerCase().startsWith('image/');

  bool get _isLocallyAvailable {
    final path = _currentFile.localPath;
    if (path == null || path.isEmpty) return false;
    if (path == _currentFile.thumbnailPath || path.contains('nuvex_thumbs')) {
      return false;
    }
    final ioFile = File(path);
    return ioFile.existsSync() && ioFile.lengthSync() > 0;
  }

  /// Strictly conforms to Rule 5:
  /// Verifies if localPath is a genuine complete original file matching exact byte size.
  bool get _isVerifiedCompleteOriginal {
    final path = _currentFile.localPath;
    if (path == null || path.isEmpty) return false;
    if (path == _currentFile.thumbnailPath) return false;
    if (path.contains('nuvex_thumbs') || path.contains('nuvex_stream_cache')) {
      return false;
    }
    final ioFile = File(path);
    if (!ioFile.existsSync()) return false;
    final len = ioFile.lengthSync();
    if (len <= 0) return false;
    if (_currentFile.sizeBytes > 0 && len != _currentFile.sizeBytes) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;

    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformationChange);

    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
          }
        });

    if (widget.isActive) {
      _checkAndPrepareFile();
    }
  }

  @override
  void didUpdateWidget(_MediaPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file != oldWidget.file) {
      _currentFile = widget.file;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _checkAndPrepareFile();
        if (_videoPlayerController != null && _isVideoInitialized) {
          _videoPlayerController?.play();
        }
      } else {
        // Pause active video when swiped away
        if (_videoPlayerController != null) {
          _videoPlayerController?.pause();
        }
        // Reset zoom when swiped away
        if (_isZoomed) {
          _transformationController.value = Matrix4.identity();
          _isZoomed = false;
          widget.onZoomChanged(false);
        }
      }
    }
  }

  void _handleTransformationChange() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (isZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
      widget.onZoomChanged(isZoomed);
    }
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (currentScale > 1.05) {
      // Zoom out to 1.0 (identity / fit scale)
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.5x centered on tap location
      const double targetScale = 2.5;
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;

      final double x = -position.dx * (targetScale - 1);
      final double y = -position.dy * (targetScale - 1);

      endMatrix = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
    }

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _zoomAnimationController.forward(from: 0).then((_) {
      final newScale = _transformationController.value.getMaxScaleOnAxis();
      final isZoomed = newScale > 1.05;
      if (_isZoomed != isZoomed) {
        setState(() {
          _isZoomed = isZoomed;
        });
        widget.onZoomChanged(isZoomed);
      }
    });
  }

  void _checkAndPrepareFile() {
    if (_isVideo) {
      if (_isVerifiedCompleteOriginal) {
        _initVideoPlayerFromFile(_currentFile.localPath!);
      } else {
        _startStreamingVideo();
      }
    } else {
      if (_isLocallyAvailable) {
        // Photo or document available
      } else {
        _startDownload();
      }
    }
  }

  /// Instantly streams video via localhost HTTP range proxy without full download.
  Future<void> _startStreamingVideo() async {
    if (_isStreaming || _isVideoInitialized) return;

    setState(() {
      _isStreaming = true;
      _downloadError = null;
    });

    final startupStopwatch = Stopwatch()..start();

    try {
      final proxy = VideoStreamingProxy.instance;
      await proxy.ensureStarted();
      final streamUrl = proxy.registerFile(_currentFile);
      _activeStreamUrl = streamUrl;

      // Proactively start aggressive read-ahead prefetch for this video session
      VideoPrefetchManager.instance.start(
        file: _currentFile,
        mediaService: proxy.mediaService,
      );

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController = controller;

      controller.addListener(_videoPlayerListener);

      await controller.initialize().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Video streaming initialization timed out');
        },
      );

      if (!mounted) return;

      startupStopwatch.stop();
      debugPrint(
        '[PERF_STARTUP] Tap to controller init: ${startupStopwatch.elapsedMilliseconds}ms | size=${controller.value.size}, duration=${controller.value.duration} for #${_currentFile.telegramMessageId}',
      );

      setState(() {
        _isVideoInitialized = true;
        _isStreaming = false;
      });

      if (widget.isActive) {
        controller.play();
      }
    } catch (e, stack) {
      debugPrint(
        '[STREAM_ERROR] Video streaming failed: $e\n$stack. Falling back to full download...',
      );
      if (!mounted) return;
      _fallbackToFullDownload();
    }
  }

  void _fallbackToFullDownload() {
    _cleanUpStream();
    setState(() {
      _isStreaming = false;
      _isVideoInitialized = false;
    });
    _startDownload();
  }

  void _cleanUpStream() {
    VideoPrefetchManager.instance.stop();
    if (_activeStreamUrl != null) {
      VideoStreamingProxy.instance.unregisterFile(
        _currentFile.telegramMessageId,
      );
      _activeStreamUrl = null;
    }
    if (_videoPlayerController != null) {
      _videoPlayerController?.removeListener(_videoPlayerListener);
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    }
  }

  bool _lastBufferingState = false;
  bool _firstFrameLogged = false;

  void _videoPlayerListener() {
    if (!mounted) return;
    final controller = _videoPlayerController;
    if (controller == null) return;

    if (controller.value.hasError) {
      debugPrint(
        '[STREAM_ERROR] Playback error: ${controller.value.errorDescription}. Falling back to full download...',
      );
      _fallbackToFullDownload();
      return;
    }

    // Instrument first rendered frame
    if (!_firstFrameLogged && controller.value.position > Duration.zero) {
      _firstFrameLogged = true;
      debugPrint(
        '[PERF_STARTUP] Tap to first rendered frame reached at position: ${controller.value.position} for #${_currentFile.telegramMessageId}',
      );
    }

    // Instrument buffering state transitions
    if (controller.value.isBuffering != _lastBufferingState) {
      _lastBufferingState = controller.value.isBuffering;
      debugPrint(
        '[PERF_EVENT] Player buffering: ${_lastBufferingState ? "START" : "STOP"} (position: ${controller.value.position})',
      );
    }

    // Connect prefetch manager to actual player state (secondary tracking and tuning)
    VideoPrefetchManager.instance.updatePlayerState(
      position: controller.value.position,
      duration: controller.value.duration,
      buffered: controller.value.buffered,
      isPlaying: controller.value.isPlaying,
      isBuffering: controller.value.isBuffering,
    );

    // DO NOT call setState() here! High-frequency position ticks are handled by ValueListenableBuilder.
  }

  Future<void> _initVideoPlayerFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    try {
      final controller = VideoPlayerController.file(file);
      _videoPlayerController = controller;
      await controller.initialize();
      if (!mounted) return;

      controller.addListener(_videoPlayerListener);

      setState(() {
        _isVideoInitialized = true;
        _isStreaming = false;
      });
      if (widget.isActive) {
        controller.play();
      }
    } catch (e) {
      debugPrint('[VIDEO] Error initializing video player from file: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _downloadError = 'Unable to play video: $e';
        });
      }
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      final downloaded = await widget.controller.downloadFile(
        _currentFile,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _currentFile = downloaded;
        _isDownloading = false;
      });
      widget.onFileUpdated(downloaded);

      if (_isVideo && downloaded.localPath != null) {
        _initVideoPlayerFromFile(downloaded.localPath!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _cleanUpStream();
    _transformationController.removeListener(_handleTransformationChange);
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Actively downloading original state (fallback or photo download)
    if (_isDownloading) {
      final percent = (_downloadProgress * 100).toInt();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 3.5,
                color: NuvexColors.primaryBlue,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _downloadProgress > 0
                  ? 'Downloading original ($percent%)...'
                  : 'Connecting to Telegram...',
              style: const TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentFile.formattedSize,
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Error state with retry button
    if (_downloadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Playback Failed',
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _downloadError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Download Full Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NuvexColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Video Player (Streaming via localhost proxy or verified local file)
    if (_isVideo) {
      if (!_isVideoInitialized || _videoPlayerController == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: NuvexColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isStreaming
                    ? 'Streaming instant video from Telegram...'
                    : 'Loading video...',
                style: const TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _currentFile.formattedSize,
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      }

      final controller = _videoPlayerController!;

      return GestureDetector(
        onTap: () {
          widget.onToggleControls();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
            // Play/Pause / Buffering tap overlay scoped to ValueListenableBuilder
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, val, _) {
                if (val.isBuffering) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: NuvexColors.primaryBlue,
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () {
                    if (val.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      val.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            // Video Bottom Progress Bar & Time scoped to ValueListenableBuilder
            Positioned(
              bottom: 72,
              left: 16,
              right: 16,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, val, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(val.position),
                          style: const TextStyle(
                            fontFamily: NuvexTypography.primaryFamily,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: NuvexColors.primaryBlue,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatDuration(val.duration),
                          style: TextStyle(
                            fontFamily: NuvexTypography.primaryFamily,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // 4. Photo Viewer
    final localPath = _currentFile.localPath;
    if (localPath != null && File(localPath).existsSync()) {
      if (_isPhoto) {
        return GestureDetector(
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: _handleDoubleTap,
          onTap: () {
            if (!_isZoomed) {
              widget.onToggleControls();
            }
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              panEnabled: _isZoomed,
              scaleEnabled: true,
              child: Center(
                child: Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Document preview
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 44,
                color: NuvexColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _currentFile.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentFile.formattedSize} • ${_currentFile.mimeType}',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Saved in local cache',
                    style: TextStyle(
                      fontFamily: NuvexTypography.primaryFamily,
                      fontSize: 13,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default loader while checking local storage
    return const Center(
      child: CircularProgressIndicator(color: NuvexColors.primaryBlue),
    );
  }
}
