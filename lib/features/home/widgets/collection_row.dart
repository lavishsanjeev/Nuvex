import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Secondary list row item for the Nuvex Collections screen.
///
/// Categories:
/// - Screenshots
/// - Videos
/// - Recently added
/// - Creations
/// - Archive
/// - Locked
///
/// Complies with Task 4 requirements:
/// - Clean visual system
/// - UI shell only
/// - Strictly NO fake file counts
class CollectionRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? count;
  final VoidCallback? onTap;

  const CollectionRow({
    super.key,
    required this.title,
    required this.icon,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Soft rounded icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, size: 20, color: NuvexColors.darkNavy),
              ),
            ),
            const SizedBox(width: 14),
            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: NuvexColors.darkNavy,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (count != null && count! > 0) ...[
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: NuvexColors.secondaryText,
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Trailing Chevron
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
