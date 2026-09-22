import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import 'onboarding_background_painter.dart';

/// Premium Nuvex onboarding screen.
///
/// Renders the full-bleed atmospheric background, cloud icon,
/// Nuvex wordmark, tagline, decorative floating media icons,
/// micro-copy, and the primary Getting Started CTA.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
        backgroundColor: NuvexColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // ── Full-bleed painted background isolated in RepaintBoundary ──
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: OnboardingBackgroundPainter()),
                  ),
                ),

                // ── Decorative floating media icons ──
                ..._buildFloatingIcons(constraints),

                // ── Main content with animated entrance ──
                Positioned.fill(
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: RepaintBoundary(
                          child: _OnboardingContent(
                            onGettingStarted: _handleGettingStarted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleGettingStarted() {
    Navigator.of(context).pushNamed(NuvexRoutes.credentials);
  }

  /// Builds the small decorative floating icon tiles.
  List<Widget> _buildFloatingIcons(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    return [
      // Image/photo — upper left
      _FloatingIconTile(
        icon: Icons.image_outlined,
        left: w * 0.06,
        top: h * 0.14,
        angle: -0.10,
        size: 42,
      ),
      // Document — left side, mid-upper
      _FloatingIconTile(
        icon: Icons.description_outlined,
        left: w * 0.04,
        top: h * 0.29,
        angle: 0.08,
        size: 38,
      ),
      // Play/video — left side, mid
      _FloatingIconTile(
        icon: Icons.play_arrow_outlined,
        left: w * 0.03,
        top: h * 0.44,
        angle: -0.05,
        size: 36,
      ),
      // Camera — upper right area
      _FloatingIconTile(
        icon: Icons.camera_alt_outlined,
        left: w * 0.85,
        top: h * 0.34,
        angle: 0.12,
        size: 40,
      ),
    ];
  }
}

/// The main vertical content column inside SafeArea.
class _OnboardingContent extends StatelessWidget {
  final VoidCallback onGettingStarted;

  const _OnboardingContent({required this.onGettingStarted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Top breathing room
          const Spacer(flex: 3),

          // ── Cloud icon ──
          const _CloudIcon(),
          const SizedBox(height: 28),

          // ── Nuvex wordmark ──
          const _NuvexWordmark(),
          const SizedBox(height: 12),

          // ── Tagline ──
          Text(
            'Your files, your space.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: NuvexColors.secondaryText,
              letterSpacing: 0.3,
            ),
          ),

          // Middle breathing room (where landscape shows)
          const Spacer(flex: 5),

          // ── Micro-copy trio ──
          const _MicrocopyTrio(),

          const Spacer(flex: 2),

          // ── Getting Started button ──
          _GettingStartedButton(onPressed: onGettingStarted),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Subwidgets
// ═══════════════════════════════════════════════════════════════════

/// Polished cloud icon inside a soft gradient container.
class _CloudIcon extends StatelessWidget {
  const _CloudIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF93C5FD).withAlpha(50),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.cloud_outlined,
          size: 40,
          color: NuvexColors.primaryAccent,
        ),
      ),
    );
  }
}

/// Nuvex wordmark with the final "x" in accent blue.
class _NuvexWordmark extends StatelessWidget {
  const _NuvexWordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'Nuve',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: NuvexColors.primaryText,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: 'x',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: NuvexColors.primaryAccent,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny "STORE / ORGANIZE / RELIVE" stacked microcopy in lower-left.
class _MicrocopyTrio extends StatelessWidget {
  const _MicrocopyTrio();

  static const _words = ['STORE', 'ORGANIZE', 'RELIVE'];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _words.length; i++) ...[
            if (i == 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: NuvexColors.primaryAccent.withAlpha(160),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _words[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NuvexColors.primaryAccent.withAlpha(180),
                      letterSpacing: 3.0,
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  _words[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NuvexColors.primaryAccent.withAlpha(140),
                    letterSpacing: 3.0,
                  ),
                ),
              ),
            if (i < _words.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

/// Premium Getting Started button with gradient and arrow.
class _GettingStartedButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GettingStartedButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusFull),
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withAlpha(60),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: MaterialButton(
          onPressed: onPressed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NuvexSpacing.radiusFull),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    'Getting Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single decorative floating icon tile positioned absolutely.
class _FloatingIconTile extends StatelessWidget {
  final IconData icon;
  final double left;
  final double top;
  final double angle;
  final double size;

  const _FloatingIconTile({
    required this.icon,
    required this.left,
    required this.top,
    required this.angle,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withAlpha(180),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF93C5FD).withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: size * 0.45,
              color: NuvexColors.primaryAccent.withAlpha(160),
            ),
          ),
        ),
      ),
    );
  }
}
