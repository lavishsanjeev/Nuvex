import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'controllers/auth_controller.dart';
import 'widgets/login_button.dart';

/// 2-Step Verification password screen for Telegram accounts with 2FA enabled.
class Password2FAScreen extends StatefulWidget {
  final AuthController controller;

  const Password2FAScreen({super.key, required this.controller});

  @override
  State<Password2FAScreen> createState() => _Password2FAScreenState();
}

class _Password2FAScreenState extends State<Password2FAScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscureText = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAuthState);
  }

  void _handleAuthState() {
    if (mounted) {
      setState(() {});
      if (widget.controller.status == AuthStatus.authenticated) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          NuvexRoutes.authenticated,
          (route) => false,
          arguments: widget.controller,
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAuthState);
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyPassword() async {
    if (widget.controller.isVerifyingPassword) return;
    FocusScope.of(context).unfocus();
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _validationError = 'Please enter your 2-step verification password';
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    await widget.controller.verifyPassword(password);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.controller.isVerifyingPassword;
    final String? serverError = widget.controller.errorMessage;

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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: NuvexColors.darkNavy,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    const Text(
                      'Nuvex',
                      style: TextStyle(
                        fontFamily: NuvexTypography.primaryFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: NuvexColors.primaryBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Main Card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Badge
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF3FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 32,
                                color: NuvexColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Heading
                          const Center(
                            child: Text(
                              'Two-Step Verification',
                              style: TextStyle(
                                fontFamily: NuvexTypography.primaryFamily,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: NuvexColors.darkNavy,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          const Center(
                            child: Text(
                              'Your Telegram account is protected with a 2-step verification password.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: NuvexTypography.primaryFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Password Label
                          const Text(
                            'Telegram Password',
                            style: TextStyle(
                              fontFamily: NuvexTypography.primaryFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: NuvexColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Password Input Field
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F5F8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    (_validationError != null ||
                                        serverError != null)
                                    ? NuvexColors.errorRed
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    obscureText: _obscureText,
                                    enabled: !isLoading,
                                    style: const TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: NuvexColors.darkNavy,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your 2FA password',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (_) {
                                      if (_validationError != null ||
                                          serverError != null) {
                                        setState(() {
                                          _validationError = null;
                                          widget.controller.clearError();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                  tooltip: _obscureText
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ],
                            ),
                          ),

                          // Error Message
                          if (_validationError != null ||
                              serverError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: NuvexColors.errorRed,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _validationError ?? serverError ?? '',
                                      style: const TextStyle(
                                        fontFamily:
                                            NuvexTypography.primaryFamily,
                                        fontSize: 13,
                                        color: NuvexColors.errorRed,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Verify Button
                          LoginButton(
                            label: 'Verify Password',
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _handleVerifyPassword,
                          ),

                          const SizedBox(height: 20),

                          const Center(
                            child: Text(
                              'Your password is encrypted and never stored on your device or Nuvex servers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: NuvexTypography.primaryFamily,
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF9CA3AF),
                              ),
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
}
