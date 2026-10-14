import 'dart:ui';
import 'package:flutter/material.dart';

/// Premium Frosted Liquid Glass Container with specular highlight borders,
/// ambient backdrop blur, and Apple-grade curvature.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? borderGradient;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderGradient,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.shadows,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBg = backgroundColor ??
        (isDark
            ? const Color(0xFF0D121F).withValues(alpha: 0.65)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.75));

    final defaultGradient = borderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.8),
            isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.05),
          ],
        );

    final defaultShadows = shadows ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: effectiveRadius,
      ),
      child: child,
    );

    // If blur > 0, apply backdrop blur
    if (blur > 0) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: defaultShadows,
      ),
      child: CustomPaint(
        foregroundPainter: _GradientBorderPainter(
          strokeWidth: borderWidth,
          radius: effectiveRadius,
          gradient: defaultGradient,
          solidColor: borderColor,
        ),
        child: content,
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final BorderRadius radius;
  final Gradient gradient;
  final Color? solidColor;

  _GradientBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.gradient,
    this.solidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;

    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (solidColor != null) {
      paint.color = solidColor!;
    } else {
      paint.shader = gradient.createShader(rect);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.gradient != gradient ||
        oldDelegate.solidColor != solidColor;
  }
}
