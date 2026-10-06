/// App-lock widgets (auth spec, Option A — redesigned).
///
/// The lock no longer gates the WHOLE app. Instead:
///
///   - [AutoLockObserver] sits invisibly at the app root. It only watches app
///     lifecycle and flips the lock STATE back to locked when the app has been
///     backgrounded longer than the configured auto-lock timeout. It renders
///     its [child] unchanged — it never withholds the UI, so switching tabs
///     never re-prompts for the passcode.
///   - [LockGuard] wraps a single SENSITIVE screen (e.g. Account & sync). It
///     requires the app to be unlocked before showing its [child]; while the
///     app is locked it shows the [LockScreen]. Non-sensitive screens are not
///     wrapped and are always visible.
///
/// This keeps the passcode protecting what matters (the sensitive screen) while
/// leaving everyday browsing (the lifecycle tabs) unobstructed.
///
/// Presentation-layer only: depends on the application layer and domain auth
/// types; never imports Drift or a plugin.
library wishable.presentation.auth.auth_gate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth.dart';
import '../../domain/auth/auth.dart';
import 'lock_screen.dart';

/// Root-level, invisible observer that re-locks the app after it has been
/// backgrounded beyond the configured auto-lock timeout. It NEVER gates the UI
/// — it only updates the lock state so the next time a [LockGuard] screen is
/// opened it will require unlocking.
class AutoLockObserver extends ConsumerStatefulWidget {
  const AutoLockObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoLockObserver> createState() => _AutoLockObserverState();
}

class _AutoLockObserverState extends ConsumerState<AutoLockObserver>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now().toUtc();
      case AppLifecycleState.resumed:
        _maybeLockOnResume();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Re-locks if the app was backgrounded for at least the configured timeout.
  /// A `Never` timeout (represented as a negative sentinel) never auto-locks.
  Future<void> _maybeLockOnResume() async {
    final DateTime? since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;

    final AuthController ctrl = ref.read(authControllerProvider.notifier);
    final AuthCredentials? creds = await ctrl.currentCredentials();
    if (creds == null) return; // Unconfigured: nothing to lock.

    // A negative lockTimeout means "Never auto-lock".
    if (creds.lockTimeout.isNegative) return;

    final Duration away = DateTime.now().toUtc().difference(since);
    if (away >= creds.lockTimeout) {
      await ctrl.lock();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Guards a single sensitive screen: shows [child] only while the app is
/// unlocked (or no passcode is enrolled); otherwise shows the [LockScreen].
///
/// Wrap only sensitive destinations (e.g. Account & sync) with this. Opening a
/// guarded screen while locked prompts for the passcode; everyday tabs are not
/// wrapped and never prompt.
class LockGuard extends ConsumerWidget {
  const LockGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState state = ref.watch(authControllerProvider);
    final bool locked = state is AuthLocked || state is AuthCoolingDown;
    return locked ? const LockScreen() : child;
  }
}
