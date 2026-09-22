import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

/// Custom painter for the diagonal two-node link icon visible in the reference.
class _NodeLinkPainter extends CustomPainter {
  final Color color;

  const _NodeLinkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // Node 1: lower-left circle
    final Offset node1 = Offset(w * 0.32, h * 0.68);
    // Node 2: upper-right circle
    final Offset node2 = Offset(w * 0.68, h * 0.32);
    final double radius = w * 0.16;

    // Draw connecting line between circle edges
    const double cosA = 0.70710678;
    const double sinA = 0.70710678;

    canvas.drawLine(
      Offset(node1.dx + radius * cosA, node1.dy - radius * sinA),
      Offset(node2.dx - radius * cosA, node2.dy + radius * sinA),
      paint,
    );

    // Draw circular nodes
    canvas.drawCircle(node1, radius, paint);
    canvas.drawCircle(node2, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _NodeLinkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A node-link icon widget replicating the reference design.
class NodeLinkIcon extends StatelessWidget {
  final Color color;
  final double size;

  const NodeLinkIcon({
    super.key,
    this.color = const Color(0xFF9CA3AF),
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NodeLinkPainter(color: color)),
    );
  }
}

/// Modern rounded input field for Nuvex API credentials.
class CredentialField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  const CredentialField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<CredentialField> createState() => _CredentialFieldState();
}

class _CredentialFieldState extends State<CredentialField> {
  late bool _obscureText;
  late final FocusNode _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    // Default to plain visible so hint/initial value looks like reference,
    // but toggleable if user wants secure hiding.
    _obscureText = false;
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final hasFocus = _effectiveFocusNode.hasFocus;
    if (mounted && _isFocused != hasFocus) {
      setState(() {
        _isFocused = hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(CredentialField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode).removeListener(
        _handleFocusChange,
      );
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field Label
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),

        // Rounded Field Box
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            color: NuvexColors.inputBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasError
                  ? NuvexColors.error
                  : _isFocused
                  ? NuvexColors.brandBlue.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              // Prefix link icon
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: NodeLinkIcon(
                  color: hasError
                      ? NuvexColors.error
                      : _isFocused
                      ? NuvexColors.brandBlue
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),

              // Real editable text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _effectiveFocusNode,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  obscureText: widget.isPassword && _obscureText,
                  textInputAction: widget.textInputAction,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  onChanged: widget.onChanged,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: NuvexColors.primaryText,
                    letterSpacing: -0.1,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              // Optional password visibility toggle for App Hash
              if (widget.isPassword)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: const Color(0xFF9CA3AF),
                    ),
                    tooltip: _obscureText ? 'Show hash' : 'Hide hash',
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),

        // Inline Error Text
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                color: NuvexColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
