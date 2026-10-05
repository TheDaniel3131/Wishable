/// The branded loading/splash screen shown while the app initializes.
///
/// Displays the Wishable wordmark on the brand background with a gentle
/// fade-and-scale entrance and a subtle progress indicator. Shown by the root
/// gate until startup work (database open, auth-state restore) settles, then
/// crossfades into the app.
library wishable.presentation.brand.wishable_splash;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'wishable_logo.dart';

/// A full-screen branded splash with an animated logo.
class WishableSplash extends StatefulWidget {
  const WishableSplash({super.key});

  @override
  State<WishableSplash> createState() => _WishableSplashState();
}

class _WishableSplashState extends State<WishableSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.86, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F17) : const Color(0xFFF7F7FB),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const WishableWordmark(markSize: 96),
                const SizedBox(height: 28),
                Text(
                  'Turn Wishes Into Achievements',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor:
                          AppTheme.brandGradientStart.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.brandGradientEnd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
