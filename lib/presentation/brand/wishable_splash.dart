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
                // Big brand wordmark, wrapped in FittedBox + horizontal padding
                // so it scales down to fit narrow viewports instead of
                // overflowing.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: WishableWordmark(markSize: 144),
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Enhanced the typography for the tagline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Turn Wishes Into Achievements',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                const SizedBox(height: 48), // Added a bit more breathing room

                // 3. Made the loading bar wider and thicker to feel like a true loading screen
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // Rounder edges
                    child: LinearProgressIndicator(
                      minHeight: 6, // Thicker bar
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
