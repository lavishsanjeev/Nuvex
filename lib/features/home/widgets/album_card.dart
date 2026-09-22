import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Reusable horizontal album carousel card for the Nuvex Photos screen.
///
/// Complies with Task 4 requirements:
/// - Clean visual styling matching Nuvex light aesthetic
/// - Distinct album badge with soft gradient
/// - Dark navy album title
/// - Strictly NO fake photo counts or fake image thumbnails
class AlbumCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;

  const AlbumCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: NuvexColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            // UI shell only for Task 4
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Soft gradient icon badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                  child: Center(child: Icon(icon, size: 26, color: iconColor)),
                ),
                // Album title
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NuvexTypography.primaryFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NuvexColors.darkNavy,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
