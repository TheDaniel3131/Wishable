/// [LockScreen] — the app-lock entry UI (auth spec, Option A — R2, R3, R4).
///
/// Shown by [AuthGate] whenever the app is [AuthLocked] or [AuthCoolingDown].
/// It collects the passcode, offers a biometric button when available and
/// enabled, surfaces non-revealing errors (R2.3), and shows a live countdown
/// while a lockout cooldown is active (R4.2).
///
/// Presentation-layer only: it depends on the application layer
/// ([authControllerProvider]) and the pure domain auth types; it never imports
/// Drift or a plugin.
library wishable.presentation.auth.lock_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth.dart';
import '../../domain/auth/auth.dart';

/// Full-screen passcode + biometric unlock UI.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final TextEditingController _passcode = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _biometricAvailable = false;
  PasscodeKind _kind = PasscodeKind.password;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _passcode.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final AuthController ctrl = ref.read(authControllerProvider.notifier);
    final AuthCredentials? creds = await ctrl.currentCredentials();
    if (!mounted || creds == null) return;
    setState(() => _kind = creds.kind);
    if (creds.biometricEnabled) {
      // Offer biometric immediately on open for a fast path.
      final AuthOutcome outcome = await ctrl.unlockBiometric();
      if (!mounted) return;
      if (outcome is! AuthSuccess) {
        setState(() => _biometricAvailable = true);
      }
    }
  }

  Future<void> _submitPasscode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final AuthOutcome outcome =
        await ref.read(authControllerProvider.notifier).unlock(_passcode.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _passcode.clear();
      switch (outcome) {
        case AuthSuccess():
          _error = null;
        case AuthInvalid(:final String message):
          _error = message;
        case AuthRejected(:final String message):
          _error = message;
        case AuthLockedOut():
          _error = null; // The cooldown banner conveys this.
          _startTicker();
      }
    });
  }

  Future<void> _submitBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final AuthOutcome outcome =
        await ref.read(authControllerProvider.notifier).unlockBiometric();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (outcome is! AuthSuccess) {
        _error = 'Biometric unlock was not successful. Enter your passcode.';
      }
    });
  }

  /// Rebuilds once a second while cooling down so the countdown updates.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthState authState = ref.watch(authControllerProvider);
    final bool isPin = _kind == PasscodeKind.pin;

    final bool coolingDown = authState is AuthCoolingDown;
    final Duration remaining = authState is AuthCoolingDown
        ? authState.remaining(DateTime.now().toUtc())
        : Duration.zero;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(Icons.lock_outline,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Wishable is locked',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Enter your ${isPin ? 'PIN' : 'passcode'} to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passcode,
                  autofocus: true,
                  obscureText: true,
                  enabled: !coolingDown && !_busy,
                  keyboardType:
                      isPin ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: isPin ? 'PIN' : 'Passcode',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submitPasscode(),
                ),
                const SizedBox(height: 16),
                if (coolingDown)
                  _CooldownBanner(remaining: remaining)
                else
                  FilledButton(
                    onPressed: _busy ? null : _submitPasscode,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
                  ),
                if (_biometricAvailable && !coolingDown) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _submitBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A banner shown during a lockout cooldown with the remaining wait (R4.2).
class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int seconds = remaining.inSeconds;
    final String label = seconds >= 60
        ? '${(seconds / 60).ceil()} min'
        : '$seconds s';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Too many attempts. Try again in $label.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
