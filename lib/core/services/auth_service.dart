import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Thrown by [AuthService]'s Google sign-in flow. [message] is always safe
/// to show a user. [debugDetails] additionally contains non-sensitive
/// configuration diagnostics (package name, Firebase project id, error
/// code) -- appended to [toString] only in debug builds, so it shows up
/// directly wherever the UI displays this exception's text (no adb/logcat
/// needed), while release builds only ever show the clean [message].
class AuthServiceException implements Exception {
  AuthServiceException(this.message, {this.cause, this.debugDetails});
  final String message;
  final Object? cause;
  final String? debugDetails;
  @override
  String toString() {
    if (kDebugMode && debugDetails != null) {
      return "$message\n\n[Diagnostics -- debug builds only]\n$debugDetails";
    }
    return message;
  }
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// IMPORTANT: this must be the Firebase project's WEB OAuth client ID
  /// (Google Cloud Console > APIs & Services > Credentials > "Web client
  /// (auto created by Google Service)"), NOT the Android client ID.
  /// Without a serverClientId, Android Google Sign-In on some devices/OS
  /// versions fails with ApiException: 10 even when the Android OAuth
  /// client itself is registered correctly, because the plugin cannot
  /// resolve an ID token audience. If this project's Firebase config ever
  /// changes (new Firebase project, project deleted/recreated), this value
  /// MUST be updated from Google Cloud Console -- it must never be a
  /// placeholder or guessed value.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '391561027779-fq8t9eo47aubj7to6c84es8vbbdald8n.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmail(String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(displayName);
    return cred;
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled the picker
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      final details = await _buildGoogleSignInDiagnostics(e);
      throw AuthServiceException(_friendlyGoogleSignInMessage(e), cause: e, debugDetails: details);
    } catch (e) {
      debugPrint('[AuthService] Google: ' + e.toString());
      rethrow;
    }
  }

  /// Extracts the numeric Android GoogleSignIn status code (e.g. 10 =
  /// DEVELOPER_ERROR, 7 = NETWORK_ERROR, 12501 = SIGN_IN_CANCELLED) from
  /// the raw platform exception message, if present.
  int? _extractApiExceptionCode(PlatformException e) {
    final match = RegExp(r'ApiException:\s*(\d+)').firstMatch(e.message ?? '');
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Maps known Google Sign-In failure codes to a message that is safe and
  /// useful to show a user -- never the raw "PlatformException(...)" text.
  String _friendlyGoogleSignInMessage(PlatformException e) {
    switch (_extractApiExceptionCode(e)) {
      case 10:
        return 'Google Sign-In configuration error. Please check Google/Firebase configuration.';
      case 7:
        return 'No internet connection. Please check your network and try again.';
      case 12501:
        return 'Sign-in was cancelled.';
      default:
        return 'Google Sign-In failed. Please try again, or use email sign-in instead.';
    }
  }

  /// Builds a non-sensitive diagnostics string (package name, Firebase
  /// project id, error code) to help debug Google Sign-In failures without
  /// needing adb/logcat access. Never includes access tokens, ID tokens,
  /// or any other credential material. Only meant to be shown in debug
  /// builds (see [AuthServiceException.toString]).
  Future<String> _buildGoogleSignInDiagnostics(PlatformException e) async {
    try {
      final apiCode = _extractApiExceptionCode(e);
      final packageInfo = await PackageInfo.fromPlatform();
      final projectId = Firebase.apps.isNotEmpty ? Firebase.app().options.projectId : 'no Firebase app initialized';
      return "package: ${packageInfo.packageName}\n"
          "firebase project: $projectId\n"
          "platform error code: ${e.code}\n"
          'ApiException status: ${apiCode?.toString() ?? "n/a (not an ApiException)"}';
    } catch (diagError) {
      return "(diagnostics unavailable: $diagError)";
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()..addScope('email')..addScope('fullName');
      return await _auth.signInWithProvider(provider);
    } catch (e) { debugPrint('[AuthService] Apple: ' + e.toString()); rethrow; }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  /// Deletes the signed-in user's Firebase Auth account. Callers should
  /// delete the user's Firestore data first (see SyncService.deleteAllCloudData)
  /// since this only removes the auth record itself. Firebase may require
  /// a recent sign-in for this sensitive operation -- if it throws, the
  /// caller's error handling surfaces that to the user.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    try { await _googleSignIn.signOut(); } catch (_) {}
    notifyListeners();
  }
}
