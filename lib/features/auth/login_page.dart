import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'controllers/auth_controller.dart';
import 'widgets/credential_field.dart';
import 'widgets/credentials_help_dialog.dart';
import 'widgets/login_button.dart';

/// Nuvex API Credentials / Login screen with real MTProto Telegram connection.
///
/// Features:
/// - Light ice-blue background with top centered Nuvex brand
/// - Large rounded white card with two-line heading
/// - App ID input with numeric keyboard and digits filter
/// - App Hash input with visibility toggle
/// - Nuvex blue pill login button connecting to real Telegram MTProto gateway
/// - Help link for Telegram developer portal guidance
/// - Performance-optimized with AnnotatedRegion and RepaintBoundary
class LoginPage extends StatefulWidget {
  final AuthController? controller;

  const LoginPage({super.key, this.controller});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthController _authController;
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _appHashController = TextEditingController();
  final FocusNode _appIdFocus = FocusNode();
  final FocusNode _appHashFocus = FocusNode();

  String? _appIdError;
  String? _appHashError;

  @override
  void initState() {
    super.initState();
    _authController = widget.controller ?? AuthController();
    _authController.addListener(_handleAuthStateChange);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    await _authController.initialize();
    if (mounted) {
      if (_authController.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed(
          NuvexRoutes.authenticated,
          arguments: _authController,
        );
        return;
      }
      if (_authController.savedAppId != null && _appIdController.text.isEmpty) {
        _appIdController.text = _authController.savedAppId.toString();
      }
      if (_authController.savedAppHash != null &&
          _appHashController.text.isEmpty) {
        _appHashController.text = _authController.savedAppHash!;
      }
    }
  }

  void _handleAuthStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthStateChange);
    _appIdController.dispose();
    _appHashController.dispose();
    _appIdFocus.dispose();
    _appHashFocus.dispose();
    super.dispose();
  }

  /// Validates credentials and initiates real Telegram MTProto connection.
  Future<void> _handleLogin() async {
    if (_authController.isConnecting) return;
    FocusScope.of(context).unfocus();

    final String appIdText = _appIdController.text.trim();
    final String appHashText = _appHashController.text.trim();

    String? appIdError;
    String? appHashError;

    // Validate App ID
    int? parsedId;
    if (appIdText.isEmpty) {
      appIdError = 'Please enter your App ID';
    } else {
      parsedId = int.tryParse(appIdText);
      if (parsedId == null || parsedId <= 0) {
        appIdError = 'App ID must be a valid positive number';
      }
    }

    // Validate App Hash
    if (appHashText.isEmpty) {
      appHashError = 'Please enter your App Hash';
    } else if (appHashText.length < 16) {
      appHashError = 'App Hash format is invalid (too short)';
    }

    setState(() {
      _appIdError = appIdError;
      _appHashError = appHashError;
    });

    if (appIdError == null && appHashError == null && parsedId != null) {
      final success = await _authController.connectWithCredentials(
        apiId: parsedId,
        apiHash: appHashText,
      );

      if (!mounted) return;

      if (success) {
        if (_authController.isAuthenticated) {
          Navigator.of(context).pushReplacementNamed(
            NuvexRoutes.authenticated,
            arguments: _authController,
          );
        } else if (_authController.status == AuthStatus.connectedWaitingPhone) {
          Navigator.of(context)
              .pushNamed(NuvexRoutes.phone, arguments: _authController);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: NuvexColors.loginBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),

                            // Top Brand Wordmark: Nuvex
                            const Text(
                              'Nuvex',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: NuvexColors.brandBlue,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Login Card
                            RepaintBoundary(child: _buildLoginCard()),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the central elevated rounded white card matching the reference.
  Widget _buildLoginCard() {
    final isConnecting = _authController.isConnecting;
    final isConnected = _authController.isConnected;
    final errorMsg = _authController.errorMessage;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(26, 36, 26, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered Heading:
          // Welcome to
          // Nuvex login now!
          const Text(
            'Welcome to\nNuvex login now!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 30),

          // App ID Field
          CredentialField(
            label: 'App ID',
            controller: _appIdController,
            focusNode: _appIdFocus,
            hintText: '38684487',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _appIdError,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _appHashFocus.requestFocus(),
            onChanged: (_) {
              if (_appIdError != null) {
                setState(() => _appIdError = null);
              }
              _authController.clearError();
            },
          ),
          const SizedBox(height: 18),

          // App Hash Field
          CredentialField(
            label: 'App Hash',
            controller: _appHashController,
            focusNode: _appHashFocus,
            hintText: 'a125b160139e18353dc4c2424d1414fb6',
            keyboardType: TextInputType.text,
            isPassword: true,
            errorText: _appHashError,
            textInputAction: TextInputAction.done,
            onSubmitted: _handleLogin,
            onChanged: (_) {
              if (_appHashError != null) {
                setState(() => _appHashError = null);
              }
              _authController.clearError();
            },
          ),
          const SizedBox(height: 26),

          // Login Button
          LoginButton(
            onPressed: isConnecting ? null : _handleLogin,
            isLoading: isConnecting,
          ),
          const SizedBox(height: 22),

          // Help Link: [?] How do I get my API credentials?
          _buildHelpLink(),

          // Connection Error Message (if failed)
          if (errorMsg != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: NuvexColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Real Telegram MTProto Connection Status (if connected)
          if (isConnected) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: NuvexColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connected to Telegram DC ${_authController.connectedDcId} (MTProto encrypted).\nCredentials saved. Ready for Phone Authentication in Task 3B.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the tappable help text with question icon below the login button.
  Widget _buildHelpLink() {
    return InkWell(
      onTap: () => CredentialsHelpDialog.show(context),
      borderRadius: BorderRadius.circular(12),
      splashColor: NuvexColors.brandBlue.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.help_outline_rounded,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'How do I get my API credentials?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
