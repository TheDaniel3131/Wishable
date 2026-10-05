/// The Wishable brand logo, drawn in Flutter (no asset/plugin dependency).
///
/// A gradient rounded-square badge with a four-point "wish spark" mark,
/// matching `assets/brand/wishable_logo.svg`. Used by the splash/loading screen
/// and anywhere the brand mark is shown. Being a [CustomPainter] it stays crisp
/// at any size and needs no SVG renderer.
library wishable.presentation.brand.wishable_logo;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Draws the Wishable mark at [size] logical pixels square.
class WishableLogo extends StatelessWidget {
  const WishableLogo({this.size = 96, super.key});

  /// Side length of the (square) logo in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _WishableLogoPainter()),
    );
  }
}

/// The brand wordmark: the mark beside the "Wishable" text. Used on the splash.
class WishableWordmark extends StatelessWidget {
  const WishableWordmark({this.markSize = 64, super.key});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WishableLogo(size: markSize),
        SizedBox(width: markSize * 0.28),
        ShaderMask(
          shaderCallback: (Rect bounds) => const LinearGradient(
            colors: <Color>[
              AppTheme.brandGradientStart,
              AppTheme.brandGradientEnd,
            ],
          ).createShader(bounds),
          child: Text(
            'Wishable',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _WishableLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final double scale = s / 512.0;

    // Rounded-square badge with the brand gradient.
    final RRect badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(48 * scale, 48 * scale, 416 * scale, 416 * scale),
      Radius.circular(112 * scale),
    );
    final Paint badgePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppTheme.brandGradientStart,
          AppTheme.brandGradientEnd,
        ],
      ).createShader(badge.outerRect);
    canvas.drawRRect(badge, badgePaint);

    // Four-point wish spark.
    final Path spark = Path()
      ..moveTo(256 * scale, 140 * scale)
      ..cubicTo(268 * scale, 196 * scale, 300 * scale, 228 * scale,
          356 * scale, 240 * scale)
      ..cubicTo(300 * scale, 252 * scale, 268 * scale, 284 * scale,
          256 * scale, 340 * scale)
      ..cubicTo(244 * scale, 284 * scale, 212 * scale, 252 * scale,
          156 * scale, 240 * scale)
      ..cubicTo(212 * scale, 228 * scale, 244 * scale, 196 * scale,
          256 * scale, 140 * scale)
      ..close();
    final Paint sparkPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, AppTheme.brandAccent],
      ).createShader(spark.getBounds());
    canvas.drawPath(spark, sparkPaint);

    // Trailing sparkles.
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(344 * scale, 168 * scale), 16 * scale, dot);
    canvas.drawCircle(
      Offset(176 * scale, 332 * scale),
      10 * scale,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _WishableLogoPainter oldDelegate) => false;
}
