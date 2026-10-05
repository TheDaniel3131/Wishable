/// [AuthGate] — wraps the app and withholds content while locked (auth spec,
/// Option A — R2.1, R6).
///
/// Installed in `main.dart` around the router so it is orthogonal to the route
/// graph: no routes change to protect content. It watches [authControllerProvider]:
///
///   - [AuthUnconfigured] / [AuthUnlocked] -> render the app ([child]).
///   - [AuthLocked] / [AuthCoolingDown]    -> render the [LockScreen] and NEVER
///     build the Wish UI (R2.1).
///
/// It also owns the auto-lock behavior (R6): a [WidgetsBindingObserver] watches
/// app lifecycle; when the app is paused/inactive beyond the configured
/// `lockTimeout`, it re-locks on resume. Cold start is already locked because
/// the controller initializes to [AuthLocked] when a passcode is enrolled
/// (R6.2).
///
/// Presentation-layer only: depends on the application layer and domain auth
/// types; never imports Drift or a plugin.
library wishable.presentation.auth.auth_gate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth.dart';
import '../../domain/auth/auth.dart';
import 'lock_screen.dart';

/// Gates [child] behind the app lock and drives auto-lock on backgrounding.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({required this.child, super.key});

  /// The app to show when unlocked or unconfigured.
  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
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

  /// Re-locks if the app was backgrounded longer than the configured timeout
  /// (R6.1). A zero timeout locks immediately on any backgrounding.
  Future<void> _maybeLockOnResume() async {
    final DateTime? since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;

    final AuthController ctrl = ref.read(authControllerProvider.notifier);
    final AuthCredentials? creds = await ctrl.currentCredentials();
    if (creds == null) return; // Unconfigured: nothing to lock.

    final Duration away = DateTime.now().toUtc().difference(since);
    if (away >= creds.lockTimeout) {
      await ctrl.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    final bool locked = state is AuthLocked || state is AuthCoolingDown;
    if (locked) {
      return const LockScreen();
    }
    return widget.child;
  }
}
