import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/database/remote_file.dart';
import 'controllers/media_controller.dart';
import 'media_viewer_screen.dart';
import 'repositories/media_repository.dart';
import 'widgets/media_tile.dart';

/// Screen displayed when tapping any collection category.
///
/// Implements Task 6 requirements:
/// - Real database-derived content filtered by category
/// - Identical Nuvex 4-column gallery grid layout
/// - Square 1:1 tiles with duration/play badge on videos
/// - Reuses MediaController, MediaRepository, MediaTile, and MediaViewerScreen
/// - Clean "Nothing here yet" state if no items exist
/// - Smooth back navigation to the Collections tab
class CollectionDetailScreen extends StatefulWidget {
  final String title;
  final String categoryKey;
  final MediaRepository? repository;
  final MediaController? mediaController;

  const CollectionDetailScreen({
    super.key,
    required this.title,
    required this.categoryKey,
    this.repository,
    this.mediaController,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late final MediaRepository _repository;
  late final MediaController _mediaController;
  List<RemoteFile> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        widget.mediaController?.repository ??
        MediaRepository();
    _mediaController =
        widget.mediaController ?? MediaController(repository: _repository);
    _mediaController.addListener(_handleControllerUpdate);
    _loadCategoryFiles();
  }

  void _handleControllerUpdate() {
    if (!mounted) return;
    _loadCategoryFiles();
  }

  @override
  void dispose() {
    _mediaController.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  Future<void> _loadCategoryFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _repository.getCachedFilesByCategory(
        widget.categoryKey,
      );
      if (mounted) {
        setState(() {
          _items = files;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuvexColors.iceBackground,
      appBar: AppBar(
        backgroundColor: NuvexColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: NuvexColors.darkNavy,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NuvexColors.darkNavy,
                letterSpacing: -0.4,
              ),
            ),
            if (!_isLoading && _items.isNotEmpty)
              Text(
                '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 12,
                  color: NuvexColors.secondaryText,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: NuvexColors.primaryBlue,
                  ),
                ),
              )
            : _items.isEmpty
            ? _buildEmptyState()
            : _buildGrid(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 36,
                color: NuvexColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: NuvexColors.darkNavy,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No ${widget.title.toLowerCase()} found in your Telegram storage.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 14,
                color: NuvexColors.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    // On phone (<600dp): EXACTLY 4 square tiles per row matching Photos gallery
    final int crossAxisCount = screenWidth < 600
        ? 4
        : (screenWidth / 100).floor().clamp(4, 12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 2.5,
          mainAxisSpacing: 2.5,
          childAspectRatio: 1.0,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final file = _items[index];
          final isTrash =
              widget.categoryKey == 'recently_deleted' ||
              widget.categoryKey == 'trash' ||
              file.isTrashed;
          return MediaTile(
            file: file,
            controller: widget.mediaController,
            badgeText: isTrash ? '${file.daysRemainingInTrash}d' : null,
            onTap: () {
              Navigator.of(context).push(
                MediaViewerScreen.route(
                  files: _items,
                  initialIndex: index,
                  controller: _mediaController,
                  isTrashMode: isTrash,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
