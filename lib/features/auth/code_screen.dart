import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'controllers/auth_controller.dart';
import 'widgets/login_button.dart';

/// Verification code screen for Telegram authorization.
class CodeScreen extends StatefulWidget {
  final AuthController controller;

  const CodeScreen({super.key, required this.controller});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  String? _validationError;
  int _secondsRemaining = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAuthState);
    _secondsRemaining = widget.controller.codeTimeoutSeconds ?? 60;
    if (_secondsRemaining <= 0) _secondsRemaining = 60;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _handleAuthState() {
    if (mounted) {
      setState(() {});
      if (widget.controller.status == AuthStatus.waitingPassword) {
        Navigator.of(context)
            .pushNamed(NuvexRoutes.password, arguments: widget.controller);
      } else if (widget.controller.status == AuthStatus.authenticated) {
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
    _countdownTimer?.cancel();
    widget.controller.removeListener(_handleAuthState);
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode() async {
    if (widget.controller.isVerifyingCode) return;
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _validationError = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    await widget.controller.verifyCode(code);
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0) return;
    await widget.controller.resendCode();
    setState(() {
      _secondsRemaining = 60;
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.controller.isVerifyingCode;
    final String? serverError = widget.controller.errorMessage;
    final String phoneDisplay = widget.controller.currentPhoneNumber ?? '';

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
                                Icons.mark_email_read_rounded,
                                size: 32,
                                color: NuvexColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Heading
                          const Center(
                            child: Text(
                              'Verification Code',
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

                          Center(
                            child: Text(
                              phoneDisplay.isNotEmpty
                                  ? 'We sent a verification code to your Telegram app for $phoneDisplay'
                                  : 'We sent a verification code to your Telegram app.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: NuvexTypography.primaryFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Code Label
                          const Text(
                            'Authorization Code',
                            style: TextStyle(
                              fontFamily: NuvexTypography.primaryFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: NuvexColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Code Input Field
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
                                  Icons.lock_clock_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _codeController,
                                    focusNode: _codeFocus,
                                    keyboardType: TextInputType.number,
                                    enabled: !isLoading,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    style: const TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: NuvexColors.darkNavy,
                                      letterSpacing: 8,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '•••••',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 4,
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
                            label: 'Verify Code',
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _handleVerifyCode,
                          ),

                          const SizedBox(height: 20),

                          // Resend Code countdown
                          Center(
                            child: _secondsRemaining > 0
                                ? Text(
                                    'Resend code in ${_secondsRemaining}s',
                                    style: const TextStyle(
                                      fontFamily: NuvexTypography.primaryFamily,
                                      fontSize: 13,
                                      color: Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _handleResend,
                                    child: const Text(
                                      'Resend Code',
                                      style: TextStyle(
                                        fontFamily:
                                            NuvexTypography.primaryFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: NuvexColors.primaryBlue,
                                      ),
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
