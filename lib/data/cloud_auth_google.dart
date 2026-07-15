import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_auth.dart';

/// Google implementation of [CloudAuth] over `google_sign_in` v7
/// (Credential Manager on Android): the system account-picker sheet + one
/// consent screen — no password ever enters the app, which only ever holds
/// short-lived access tokens scoped to `drive.file` (files the app itself
/// created).
///
/// Android-only surface by decision (iOS gets its own solution later): the
/// plugin compiles into both platforms, but nothing invokes this class on
/// iOS and no iOS OAuth client is configured.
class GoogleDriveAuth implements CloudAuth {
  /// Non-sensitive "recommended" scope: access limited to files this app
  /// created — no OAuth verification review needed.
  static const kDriveFileScope = 'https://www.googleapis.com/auth/drive.file';

  /// The "Web application" OAuth client of the ReefTracker Google Cloud
  /// project. Credential Manager requires a server client id on Android even
  /// without a backend; it is a public identifier (not a secret — the
  /// matching Android clients are what bind sign-in to this app's package +
  /// signing certificates).
  static const kServerClientId =
      '23592052378-d6m1n8srpannlvirs1lhl4ln8r5dmni8'
      '.apps.googleusercontent.com';

  /// `GoogleSignIn.instance.initialize()` must complete once before any other
  /// call; memoized so every entry point can just await it.
  Future<void>? _initialized;
  Future<void> _ensureInitialized() => _initialized ??= GoogleSignIn.instance
      .initialize(serverClientId: kServerClientId);

  @override
  Future<CloudAccount?> connect() async {
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const [kDriveFileScope],
      );
      // Identity (authenticate) and the scope grant are separate steps in
      // v7; chaining them here makes the two dialogs feel like one connect
      // flow. `scopeHint` above lets platforms that can combine them do so.
      await account.authorizationClient.authorizeScopes(const [
        kDriveFileScope,
      ]);
    } on GoogleSignInException catch (e) {
      // Backing out of the account picker or the consent screen is a normal
      // "never mind", not an error.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
    return CloudAccount(email: account.email);
  }

  @override
  Future<String?> accessToken() async {
    await _ensureInitialized();
    // Nullable future: platforms without a lightweight (silent) path return
    // null instead of a future.
    final account =
        await (GoogleSignIn.instance.attemptLightweightAuthentication() ??
            Future<GoogleSignInAccount?>.value());
    if (account == null) return null;
    final authorization = await account.authorizationClient
        .authorizationForScopes(const [kDriveFileScope]);
    return authorization?.accessToken;
  }

  @override
  Future<void> disconnect() async {
    await _ensureInitialized();
    // Full disconnect (not just signOut): revokes the app's grant, matching
    // what "Disconnect" promises in Settings.
    await GoogleSignIn.instance.disconnect();
  }
}
