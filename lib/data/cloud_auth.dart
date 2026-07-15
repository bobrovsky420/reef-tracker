/// Auth seam for cloud backup sync (U24).
///
/// Kept separate from [CloudBackupStore]: the store needs only "a valid
/// access token, please", while connect/disconnect are user-facing account
/// operations driven from Settings. The `google_sign_in` implementation lives
/// in `cloud_auth_google.dart` — plugin method calls throw under
/// `flutter test` (the flutter_local_notifications lesson), so the sync
/// engine and every test talk to this interface only.
library;

/// A connected cloud account, as much identity as the provider shares.
class CloudAccount {
  const CloudAccount({required this.email});

  /// Shown in Settings so the user knows *which* account holds the backups.
  final String email;
}

abstract interface class CloudAuth {
  /// Interactive connect: account picker + consent screen. Returns null when
  /// the user cancels either step (not an error). Throws on real failures
  /// (e.g. misconfigured OAuth client, Play services unavailable).
  Future<CloudAccount?> connect();

  /// Silent token acquisition. Returns a currently valid OAuth access token,
  /// or null when the grant is gone (revoked, expired, signed out) and the
  /// user must [connect] again — never pops UI.
  Future<String?> accessToken();

  /// Signs out and revokes the app's grant.
  Future<void> disconnect();
}
