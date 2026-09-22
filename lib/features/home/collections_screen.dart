import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../account/account_screen.dart';
import '../auth/controllers/auth_controller.dart';
import '../../telegram/telegram_media_service.dart';
import 'collection_detail_screen.dart';
import 'controllers/media_controller.dart';
import 'repositories/media_repository.dart';
import 'widgets/collection_card.dart';
import 'widgets/collection_row.dart';

/// The Nuvex Collections screen connected to real Telegram data from SQLite.
///
/// Complies strictly with Task 5 requirements:
/// - Real counts derived from SQLite database
/// - Real categories (Documents, Places, Stickers, Moments, etc.)
/// - Tapping an empty category navigates to clean empty state
/// - Responsive grid layout with zero RenderFlex overflow
class CollectionsScreen extends StatefulWidget {
  final AuthController? controller;
  final MediaController? mediaController;

  const CollectionsScreen({super.key, this.controller, this.mediaController});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  late final MediaController _mediaController;

  @override
  void initState() {
    super.initState();
    _mediaController =
        widget.mediaController ??
        MediaController(
          repository: widget.controller?.telegramService != null
              ? MediaRepository(
                  mediaService: TelegramMediaService(
                    authService: widget.controller!.telegramService,
                  ),
                )
              : null,
        );
    _mediaController.addListener(_onCountsChanged);
  }

  void _onCountsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _mediaController.removeListener(_onCountsChanged);
    super.dispose();
  }

  void _openCategory(String title, String categoryKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(
          title: title,
          categoryKey: categoryKey,
          repository: _mediaController.repository,
          mediaController: _mediaController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller?.currentUser;
    final String displayName = user?.displayName ?? 'User';
    final String initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';
    final counts = _mediaController.collectionCounts;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header: Title + Profile Control ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Collections',
                  style: TextStyle(
                    fontFamily: NuvexTypography.primaryFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: NuvexColors.darkNavy,
                    letterSpacing: -0.8,
                  ),
                ),
                // Profile Avatar Control (Navigates to AccountScreen)
                Tooltip(
                  message: 'Account & Storage',
                  child: InkWell(
                    key: const ValueKey('profile_avatar_button_collections'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountScreen(
                            authController: widget.controller,
                            mediaController: _mediaController,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: NuvexColors.primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDBEAFE),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x102563EB),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: NuvexTypography.primaryFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Primary Cards: 2x2 Grid with Real DB Counts ──
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.22,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                CollectionCard(
                  title: 'Documents',
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF2563EB),
                  badgeBackground: const Color(0xFFEFF6FF),
                  count: counts['documents'],
                  onTap: () => _openCategory('Documents', 'documents'),
                ),
                CollectionCard(
                  title: 'Places',
                  icon: Icons.place_outlined,
                  iconColor: const Color(0xFF059669),
                  badgeBackground: const Color(0xFFECFDF5),
                  count: counts['places'],
                  onTap: () => _openCategory('Places', 'places'),
                ),
                CollectionCard(
                  title: 'Stickers',
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  badgeBackground: const Color(0xFFF5F3FF),
                  count: counts['stickers'],
                  onTap: () => _openCategory('Stickers', 'stickers'),
                ),
                CollectionCard(
                  title: 'Moments',
                  icon: Icons.auto_awesome_outlined,
                  iconColor: const Color(0xFFE11D48),
                  badgeBackground: const Color(0xFFFFF1F2),
                  count: counts['moments'],
                  onTap: () => _openCategory('Moments', 'moments'),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Secondary Rows Grouped Container with Real DB Counts ──
            Container(
              decoration: BoxDecoration(
                color: NuvexColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    CollectionRow(
                      title: 'Screenshots',
                      icon: Icons.phone_android_rounded,
                      count: counts['screenshots'],
                      onTap: () => _openCategory('Screenshots', 'screenshots'),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    CollectionRow(
                      title: 'Videos',
                      icon: Icons.videocam_outlined,
                      count: counts['videos'],
                      onTap: () => _openCategory('Videos', 'videos'),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    CollectionRow(
                      title: 'Recently added',
                      icon: Icons.schedule_rounded,
                      count: counts['recently_added'],
                      onTap: () =>
                          _openCategory('Recently added', 'recently_added'),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    CollectionRow(
                      title: 'Creations',
                      icon: Icons.brush_outlined,
                      count: counts['creations'],
                      onTap: () => _openCategory('Creations', 'creations'),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    CollectionRow(
                      title: 'Archive',
                      icon: Icons.archive_outlined,
                      count: counts['archive'],
                      onTap: () => _openCategory('Archive', 'archive'),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    CollectionRow(
                      title: 'Locked',
                      icon: Icons.lock_outline_rounded,
                      count: counts['locked'],
                      onTap: () => _openCategory('Locked', 'locked'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
