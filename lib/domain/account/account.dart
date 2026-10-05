/// The [Account] domain value object (auth spec, Option B — R10.2).
///
/// Identifies the signed-in remote user. Carries only non-secret identity
/// fields — never tokens or passwords (those live in secure storage). Pure
/// Dart: no Flutter, no backend SDK.
library wishable.domain.account.account;

/// A signed-in remote account.
final class Account {
  const Account({
    required this.id,
    required this.email,
    this.displayName,
    this.verified = false,
  });

  /// Stable backend user id.
  final String id;

  /// Account email (the login identity for the email/password method).
  final String email;

  /// Optional display name.
  final String? displayName;

  /// Whether the backend considers the account's email verified.
  final bool verified;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.verified == verified;

  @override
  int get hashCode => Object.hash(id, email, displayName, verified);

  @override
  String toString() => 'Account(id: $id, email: $email)';
}
