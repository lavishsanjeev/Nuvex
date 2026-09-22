import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Minimal, high-polish bottom navigation bar for Nuvex.
///
/// Strictly displays EXACTLY TWO destinations:
/// 1. Photos
/// 2. Collections
///
/// No Create button, no Search/Magic button, and no extra tabs.
class NuvexBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NuvexBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NuvexColors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E9F0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: currentIndex == 0
                      ? Icons.photo_library_rounded
                      : Icons.photo_library_outlined,
                  label: 'Photos',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: currentIndex == 1
                      ? Icons.grid_view_rounded
                      : Icons.grid_view_outlined,
                  label: 'Collections',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = NuvexColors.primaryBlue;
    final inactiveColor = NuvexColors.mutedText;

    return InkWell(
      onTap: onTap,
      splashColor: activeColor.withAlpha(20),
      highlightColor: Colors.transparent,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(NuvexSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
