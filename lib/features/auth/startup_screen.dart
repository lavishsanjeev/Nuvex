import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/services/native_media_service.dart';
import 'controllers/auth_controller.dart';

/// Minimal, branded startup screen for Nuvex.
///
/// Ensures authenticated users never see onboarding/Getting Started,
/// and prevents double navigation or UI flicker on cold launch.
class StartupScreen extends StatefulWidget {
  final AuthController? controller;

  const StartupScreen({super.key, this.controller});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = widget.controller ?? AuthController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    // Purge any unwanted legacy files in public folders on startup
    NativeMediaService.cleanupUnwantedGalleryFiles();
    await _authController.initialize();
    if (!mounted) return;

    if (_authController.isAuthenticated) {
      Navigator.of(context)
          .pushReplacementNamed(NuvexRoutes.home, arguments: _authController);
    } else {
      Navigator.of(context).pushReplacementNamed(
        NuvexRoutes.gettingStarted,
        arguments: _authController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuvexColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branded Nuvex Logo
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: NuvexTypography.primaryFamily,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
                children: [
                  TextSpan(
                    text: 'Nu',
                    style: TextStyle(color: NuvexColors.darkNavy),
                  ),
                  TextSpan(
                    text: 'vex',
                    style: TextStyle(color: NuvexColors.primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your files, your space.',
              style: TextStyle(
                fontFamily: NuvexTypography.primaryFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: NuvexColors.secondaryText,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: NuvexColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
