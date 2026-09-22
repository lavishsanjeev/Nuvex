import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Primary card for the Nuvex Collections screen (2x2 grid).
///
/// Categories:
/// - Documents
/// - Places
/// - Stickers
/// - Moments
///
/// Complies with Task 4 requirements:
/// - UI/navigation shell only
/// - Strictly NO fake file counts
/// - Modern rounded styling matching Nuvex design system
class CollectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color badgeBackground;
  final int? count;
  final VoidCallback? onTap;

  const CollectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.badgeBackground,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NuvexColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tinted icon container
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(icon, size: 20, color: iconColor)),
                ),
                // Title and Real Count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: NuvexTypography.primaryFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: NuvexColors.darkNavy,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(height: 1),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontFamily: NuvexTypography.primaryFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: NuvexColors.secondaryText,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
