/// [AccountView] — remote account sign-in / sign-up / sign-out (auth spec,
/// Option B — R10, R11.3). Shown from Settings.
///
/// Presentation-layer only: depends on the application layer
/// ([accountControllerProvider], [syncControllerProvider]) and the pure domain
/// account types; never imports the PocketBase SDK.
///
/// When signed out it offers an email+password form (sign in / sign up toggle)
/// and OAuth buttons. When signed in it shows the account email, a manual
/// "Sync now" action, and sign-out. The two auth methods (R: both) are both
/// available.
library wishable.presentation.account.account_view;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account/account.dart';
import '../../data/account/account_auth_service.dart' show OAuthProvider;
import '../../domain/account/accounts.dart';
import 'sync_status_indicator.dart';

/// Settings screen for the remote account.
class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _signUpMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final AccountController ctrl = ref.read(accountControllerProvider.notifier);
    final AccountSession result = _signUpMode
        ? await ctrl.signUpEmail(_email.text.trim(), _password.text)
        : await ctrl.signInEmail(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result is AccountSessionError ? result.message : null;
    });
  }

  // Retained for when OAuth sign-in is re-enabled (buttons currently hidden).
  // ignore: unused_element
  Future<void> _submitOAuth(OAuthProvider provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final AccountSession result = await ref
        .read(accountControllerProvider.notifier)
        .signInOAuth(provider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result is AccountSessionError ? result.message : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AccountSession session = ref.watch(accountControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account & sync')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (session) {
          SignedIn(:final Account account) => _signedIn(account),
          _ => _signedOut(session),
        },
      ),
    );
  }

  Widget _signedIn(Account account) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(account.email),
            subtitle: Text(account.verified ? 'Verified' : 'Not verified'),
          ),
        ),
        const SizedBox(height: 16),
        const SyncStatusIndicator(),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => ref.read(syncControllerProvider.notifier).sync(),
          icon: const Icon(Icons.sync),
          label: const Text('Sync now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(accountControllerProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 16),
        Text(
          'Signing out keeps your wishlists on this device.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _signedOut(AccountSession session) {
    return ListView(
      children: <Widget>[
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('Sign in')),
            ButtonSegment<bool>(value: true, label: Text('Sign up')),
          ],
          selected: <bool>{_signUpMode},
          onSelectionChanged: (Set<bool> s) =>
              setState(() => _signUpMode = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submitEmail,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_signUpMode ? 'Create account' : 'Sign in'),
        ),
        // OAuth sign-in (Google / Apple / GitHub) is intentionally hidden for
        // now — only email + password is enabled. The OAuth code path
        // (_submitOAuth + AccountAuthService.signInOAuth) is kept intact so the
        // buttons can be restored later by re-adding them here.
      ],
    );
  }
}
