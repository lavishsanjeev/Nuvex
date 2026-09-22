import 'package:flutter/material.dart';

/// Custom painter for Nuvex onboarding atmosphere.
/// Renders the layered watercolor mist, soft mountain silhouettes,
/// sun disc, flying birds, delicate concentric arcs, and water ripples.
class OnboardingBackgroundPainter extends CustomPainter {
  const OnboardingBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawUpperAtmosphere(canvas, size);
    _drawTopRightScript(canvas, size);
    _drawLandscape(canvas, size);
  }

  void _drawUpperAtmosphere(Canvas canvas, Size size) {
    // Large faint concentric circular arcs in upper region
    final arcPaint1 = Paint()
      ..color = const Color(0x2893C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final arcPaint2 = Paint()
      ..color = const Color(0x2093C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Arc on the left
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.22),
      size.width * 0.52,
      arcPaint1,
    );

    // Arc on the right
    canvas.drawCircle(
      Offset(size.width * 0.98, size.height * 0.35),
      size.width * 0.44,
      arcPaint2,
    );
  }

  static final TextPainter _cachedScriptPainter = TextPainter(
    text: const TextSpan(
      children: [
        TextSpan(
          text: 'Private\n',
          style: TextStyle(
            color: Color(0xD28FB3D5),
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            height: 1.15,
          ),
        ),
        TextSpan(
          text: 'Secure\n',
          style: TextStyle(
            color: Color(0xD28FB3D5),
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            height: 1.15,
          ),
        ),
        TextSpan(
          text: 'Yours',
          style: TextStyle(
            color: Color(0xE68FB3D5),
            fontSize: 17,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            height: 1.15,
          ),
        ),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _drawTopRightScript(Canvas canvas, Size size) {
    final scriptX = size.width - _cachedScriptPainter.width - 28;
    final scriptY = size.height * 0.09;

    canvas.save();
    canvas.translate(scriptX, scriptY);
    // Slight counter-clockwise tilt for handwritten feel
    canvas.rotate(-0.08);
    _cachedScriptPainter.paint(canvas, Offset.zero);

    // Dynamic hand-drawn underline accent below "Yours"
    final strokePaint = Paint()
      ..color = const Color(0xFF9FC1E2).withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    final underline = Path()
      ..moveTo(0, _cachedScriptPainter.height + 6)
      ..quadraticBezierTo(
        _cachedScriptPainter.width * 0.5,
        _cachedScriptPainter.height + 9,
        _cachedScriptPainter.width * 0.95,
        _cachedScriptPainter.height + 4,
      );
    canvas.drawPath(underline, strokePaint);
    canvas.restore();
  }

  void _drawLandscape(Canvas canvas, Size size) {
    // 1. Soft glowing sun/moon disc
    final sunCenter = Offset(size.width * 0.77, size.height * 0.585);
    final sunRadius = size.width * 0.125;
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF60A5FA).withAlpha(45),
          const Color(0xFF93C5FD).withAlpha(20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // 2. Wide sweeping mist wave across the middle
    final mistPath = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.57,
        size.width * 0.65,
        size.height * 0.50,
        size.width,
        size.height * 0.49,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final mistPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFBFDBFE).withAlpha(45),
              const Color(0xFFDBEAFE).withAlpha(25),
              const Color(0xFFEFF6FF).withAlpha(10),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.49,
              size.width,
              size.height * 0.51,
            ),
          );
    canvas.drawPath(mistPath, mistPaint);

    // Faint highlighted edge on top of mist wave
    final mistEdge = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.57,
        size.width * 0.65,
        size.height * 0.50,
        size.width,
        size.height * 0.49,
      );
    final mistEdgePaint = Paint()
      ..color = const Color(0xFF93C5FD).withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(mistEdge, mistEdgePaint);

    // 3. Soaring birds
    _drawBird(canvas, Offset(size.width * 0.54, size.height * 0.635), 7.0);
    _drawBird(canvas, Offset(size.width * 0.60, size.height * 0.655), 5.5);
    _drawBird(canvas, Offset(size.width * 0.65, size.height * 0.628), 6.5);

    // 4. Distant mountains (soft blue-gray wash)
    final distantMountain = Path()
      ..moveTo(size.width * 0.42, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.67,
        size.width * 0.82,
        size.height * 0.71,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.69,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..close();

    final distantMountainPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF93C5FD).withAlpha(120),
              const Color(0xFFBFDBFE).withAlpha(60),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.66,
              size.width,
              size.height * 0.34,
            ),
          );
    canvas.drawPath(distantMountain, distantMountainPaint);

    // 5. Foreground rolling hills in lower right
    final foregroundHill = Path()
      ..moveTo(size.width * 0.38, size.height * 0.75)
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.71,
        size.width * 0.62,
        size.height * 0.69,
        size.width * 0.72,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.715,
        size.width * 0.90,
        size.height * 0.68,
        size.width,
        size.height * 0.63,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.38, size.height)
      ..close();

    final foregroundHillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF7BAEE4).withAlpha(150),
              const Color(0xFF9BC4EE).withAlpha(100),
              const Color(0xFFC7E0FA).withAlpha(40),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.63,
              size.width,
              size.height * 0.37,
            ),
          );
    canvas.drawPath(foregroundHill, foregroundHillPaint);

    // 6. Water ripples on lake surface
    final ripplePaint = Paint()
      ..color = const Color(0xFF93C5FD).withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.9;

    _drawRipple(
      canvas,
      ripplePaint,
      Offset(size.width * 0.68, size.height * 0.74),
      28,
    );
    _drawRipple(
      canvas,
      ripplePaint,
      Offset(size.width * 0.78, size.height * 0.75),
      36,
    );
    _drawRipple(
      canvas,
      ripplePaint,
      Offset(size.width * 0.72, size.height * 0.765),
      44,
    );
    _drawRipple(
      canvas,
      ripplePaint,
      Offset(size.width * 0.84, size.height * 0.78),
      24,
    );

    // 7. Foreground white/mist wave swooping from mid-left down to lower right
    final frontWave = Path()
      ..moveTo(0, size.height * 0.64)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.66,
        size.width * 0.38,
        size.height * 0.71,
        size.width * 0.50,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.84,
        size.width * 0.66,
        size.height * 0.90,
        size.width * 0.72,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();

    final frontWavePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFFFF),
              const Color(0xFFFFFFFF).withAlpha(245),
              const Color(0xFFF0F6FF).withAlpha(220),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.64,
              size.width,
              size.height * 0.36,
            ),
          );
    canvas.drawPath(frontWave, frontWavePaint);

    // Subtle edge highlight on front wave
    final frontEdge = Path()
      ..moveTo(0, size.height * 0.64)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.66,
        size.width * 0.38,
        size.height * 0.71,
        size.width * 0.50,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.84,
        size.width * 0.66,
        size.height * 0.90,
        size.width * 0.72,
        size.height,
      );
    final frontEdgePaint = Paint()
      ..color = const Color(0xFF93C5FD).withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(frontEdge, frontEdgePaint);
  }

  void _drawBird(Canvas canvas, Offset position, double wingSpan) {
    final birdPaint = Paint()
      ..color = const Color(0xFF5B87B2).withAlpha(220)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;

    final halfSpan = wingSpan * 0.5;
    final dip = wingSpan * 0.28;

    final path = Path()
      ..moveTo(position.dx - halfSpan, position.dy - dip * 0.6)
      ..quadraticBezierTo(
        position.dx - halfSpan * 0.4,
        position.dy - dip,
        position.dx,
        position.dy,
      )
      ..quadraticBezierTo(
        position.dx + halfSpan * 0.4,
        position.dy - dip,
        position.dx + halfSpan,
        position.dy - dip * 0.6,
      );

    canvas.drawPath(path, birdPaint);
  }

  void _drawRipple(Canvas canvas, Paint paint, Offset center, double width) {
    final path = Path()
      ..moveTo(center.dx - width * 0.5, center.dy)
      ..lineTo(center.dx + width * 0.5, center.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
