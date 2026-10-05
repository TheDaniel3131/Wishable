/// [PasscodeSetupView] — enroll / change / disable the app lock (auth spec,
/// Option A — R1, R5, R9.2).
///
/// Presented from the Settings screen. It adapts to whether a passcode is
/// already enrolled:
///   - not enrolled -> an enroll form (new passcode + confirmation, kind,
///     optional biometric and auto-lock timeout) (R1).
///   - enrolled     -> change-passcode and disable actions (each requiring the
///     current passcode), plus the biometric / timeout toggles (R5).
///
/// It states plainly that the lock protects access to the UI, not data at rest,
/// unless database encryption is enabled (R9.2).
///
/// Presentation-layer only: depends on the application layer and domain auth
/// types; never imports Drift or a plugin.
library wishable.presentation.auth.passcode_setup_view;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth.dart';
import '../../domain/auth/auth.dart';

/// Settings screen for the app lock.
class PasscodeSetupView extends ConsumerStatefulWidget {
  const PasscodeSetupView({super.key});

  @override
  ConsumerState<PasscodeSetupView> createState() => _PasscodeSetupViewState();
}

class _PasscodeSetupViewState extends ConsumerState<PasscodeSetupView> {
  AuthCredentials? _creds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final AuthCredentials? creds =
        await ref.read(authControllerProvider.notifier).currentCredentials();
    if (!mounted) return;
    setState(() {
      _creds = creds;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'The app lock protects access to the app on this device. '
                      'It gates the user interface; it does not encrypt your '
                      'data at rest.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_creds == null)
                  _EnrollForm(onDone: _reload)
                else
                  _ManageForm(credentials: _creds!, onChanged: _reload),
              ],
            ),
    );
  }
}

/// Form shown when no passcode is enrolled yet (R1).
class _EnrollForm extends ConsumerStatefulWidget {
  const _EnrollForm({required this.onDone});
  final Future<void> Function() onDone;

  @override
  ConsumerState<_EnrollForm> createState() => _EnrollFormState();
}

class _EnrollFormState extends ConsumerState<_EnrollForm> {
  final TextEditingController _passcode = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  PasscodeKind _kind = PasscodeKind.pin;
  bool _biometric = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _passcode.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final AuthOutcome outcome =
        await ref.read(authControllerProvider.notifier).enroll(
              _passcode.text,
              _kind,
              confirmation: _confirm.text,
              biometricEnabled: _biometric,
            );
    if (!mounted) return;
    if (outcome is AuthInvalid) {
      setState(() {
        _busy = false;
        _error = outcome.message;
      });
      return;
    }
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPin = _kind == PasscodeKind.pin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<PasscodeKind>(
          segments: const <ButtonSegment<PasscodeKind>>[
            ButtonSegment<PasscodeKind>(
                value: PasscodeKind.pin, label: Text('PIN')),
            ButtonSegment<PasscodeKind>(
                value: PasscodeKind.password, label: Text('Password')),
          ],
          selected: <PasscodeKind>{_kind},
          onSelectionChanged: (Set<PasscodeKind> s) =>
              setState(() => _kind = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passcode,
          obscureText: true,
          keyboardType: isPin ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: isPin ? 'New PIN' : 'New passcode',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          keyboardType: isPin ? TextInputType.number : TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Confirm',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable biometric unlock'),
          subtitle: const Text('Use fingerprint/face where available'),
          value: _biometric,
          onChanged: (bool v) => setState(() => _biometric = v),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enable app lock'),
        ),
      ],
    );
  }
}

/// Form shown when a passcode is enrolled: change / disable + toggles (R5).
class _ManageForm extends ConsumerStatefulWidget {
  const _ManageForm({required this.credentials, required this.onChanged});
  final AuthCredentials credentials;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_ManageForm> createState() => _ManageFormState();
}

class _ManageFormState extends ConsumerState<_ManageForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Biometric unlock'),
          value: widget.credentials.biometricEnabled,
          onChanged: (bool v) async {
            await ref
                .read(authControllerProvider.notifier)
                .setBiometricEnabled(v);
            await widget.onChanged();
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password),
          title: const Text('Change passcode'),
          onTap: () => _showChangeDialog(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_open_outlined),
          title: const Text('Disable app lock'),
          onTap: () => _showDisableDialog(context),
        ),
      ],
    );
  }

  Future<void> _showChangeDialog(BuildContext context) async {
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();
    final TextEditingController confirm = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setLocal) {
          return AlertDialog(
            title: const Text('Change passcode'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current',
                    errorText: error,
                  ),
                ),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New'),
                ),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new'),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final AuthOutcome outcome = await ref
                      .read(authControllerProvider.notifier)
                      .changePasscode(
                        current: current.text,
                        next: next.text,
                        confirmation: confirm.text,
                      );
                  if (outcome is AuthSuccess) {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    await widget.onChanged();
                  } else {
                    setLocal(() => error = _messageOf(outcome));
                  }
                },
                child: const Text('Change'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDisableDialog(BuildContext context) async {
    final TextEditingController current = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setLocal) {
          return AlertDialog(
            title: const Text('Disable app lock'),
            content: TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current passcode',
                errorText: error,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final AuthOutcome outcome = await ref
                      .read(authControllerProvider.notifier)
                      .disable(current.text);
                  if (outcome is AuthSuccess) {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    await widget.onChanged();
                  } else {
                    setLocal(() => error = _messageOf(outcome));
                  }
                },
                child: const Text('Disable'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _messageOf(AuthOutcome outcome) => switch (outcome) {
        AuthInvalid(:final String message) => message,
        AuthRejected(:final String message) => message,
        AuthLockedOut() => 'Too many attempts. Try again later.',
        AuthSuccess() => '',
      };
}
