import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'controllers/auth_controller.dart';

/// Screen displayed when the Telegram account has been genuinely authorized and verified via MTProto.
///
/// Complies with Task 4 navigation flow:
/// Telegram Authorized → automatically open Nuvex Home.
class AuthenticatedScreen extends StatefulWidget {
  final AuthController controller;

  const AuthenticatedScreen({super.key, required this.controller});

  @override
  State<AuthenticatedScreen> createState() => _AuthenticatedScreenState();
}

class _AuthenticatedScreenState extends State<AuthenticatedScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(NuvexRoutes.home, arguments: widget.controller);
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final String displayName = user?.displayName ?? 'Telegram User';
    final String? username = user?.username;
    final String phone =
        user?.phone ?? widget.controller.currentPhoneNumber ?? '';
    final int? userId = user?.id;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: NuvexColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: NuvexColors.iceBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Nuvex Header
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nuvex',
                    style: TextStyle(
                      fontFamily: NuvexTypography.primaryFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: NuvexColors.primaryBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // Main Authenticated Card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: RepaintBoundary(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: NuvexColors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Success Checkmark Badge
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F9F0),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF34C759),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 40,
                              color: Color(0xFF34C759),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Heading
                          const Text(
                            'Telegram Authorized',
                            style: TextStyle(
                              fontFamily: NuvexTypography.primaryFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: NuvexColors.darkNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          const Text(
                            'Your Telegram account has been authenticated via MTProto and stored securely.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: NuvexTypography.primaryFamily,
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // User Profile Summary Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5E9F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Avatar circle with initial
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: NuvexColors.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontFamily:
                                            NuvexTypography.primaryFamily,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Name
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontFamily: NuvexTypography.primaryFamily,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: NuvexColors.darkNavy,
                                  ),
                                ),
                                if (username != null &&
                                    username.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '@$username',
                                    style: const TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 14,
                                      color: NuvexColors.primaryBlue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],

                                const Divider(
                                  height: 24,
                                  color: Color(0xFFE5E9F0),
                                ),

                                // Metadata rows
                                if (phone.isNotEmpty)
                                  _buildMetadataRow(
                                    Icons.phone_rounded,
                                    'Phone',
                                    phone,
                                  ),
                                if (userId != null && userId != 0) ...[
                                  const SizedBox(height: 10),
                                  _buildMetadataRow(
                                    Icons.badge_rounded,
                                    'User ID',
                                    userId.toString(),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                _buildMetadataRow(
                                  Icons.dns_rounded,
                                  'Telegram DC',
                                  'DC ${widget.controller.connectedDcId ?? 2}',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Security Confirmation Badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: NuvexColors.primaryBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Session saved securely via Android KeyStore (EncryptedSharedPreferences).',
                                    style: TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 12,
                                      height: 1.3,
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: NuvexTypography.primaryFamily,
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontFamily: NuvexTypography.primaryFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: NuvexColors.darkNavy,
          ),
        ),
      ],
    );
  }
}
