import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'controllers/auth_controller.dart';
import 'widgets/login_button.dart';

/// Phone number entry screen for Telegram authentication.
class PhoneScreen extends StatefulWidget {
  final AuthController controller;

  const PhoneScreen({super.key, required this.controller});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  String? _validationError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAuthState);
    if (widget.controller.currentPhoneNumber != null) {
      _phoneController.text = widget.controller.currentPhoneNumber!;
    }
  }

  void _handleAuthState() {
    if (mounted) {
      setState(() {});
      if (widget.controller.status == AuthStatus.waitingCode) {
        Navigator.of(context)
            .pushNamed(NuvexRoutes.code, arguments: widget.controller);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAuthState);
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (widget.controller.isSendingCode) return;
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _validationError = 'Please enter your phone number';
      });
      return;
    }

    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length < 7) {
      setState(() {
        _validationError = 'Phone number is too short. Include country code.';
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    final formatted = phone.startsWith('+') ? phone : '+$phone';
    await widget.controller.sendCode(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.controller.isSendingCode;
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
              // Header with Back Button and Brand
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
                    const SizedBox(width: 48), // Balance back button
                  ],
                ),
              ),

              // Main scrollable card
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
                          // Top Icon Badge
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF3FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                size: 32,
                                color: NuvexColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Heading
                          const Center(
                            child: Text(
                              'Phone Number',
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
                              'Enter your phone number to sign in with your Telegram account.',
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

                          // Phone Label
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontFamily: NuvexTypography.primaryFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: NuvexColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Phone Input
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
                                  Icons.phone_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocus,
                                    keyboardType: TextInputType.phone,
                                    enabled: !isLoading,
                                    style: const TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: NuvexColors.darkNavy,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '+1 234 567 8900',
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
                              ],
                            ),
                          ),

                          // Validation or Server Error Message
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

                          // Send Code Button
                          LoginButton(
                            label: 'Send Code',
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _handleSendCode,
                          ),

                          const SizedBox(height: 20),

                          // Note
                          const Center(
                            child: Text(
                              'Telegram will send an authorization code to your other devices or via SMS.',
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
