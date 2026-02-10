import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Supabase authentication operations
class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static Session? get currentSession => _supabase.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Update user password
  static Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Update user email
  static Future<UserResponse> updateEmail(String newEmail) async {
    return await _supabase.auth.updateUser(
      UserAttributes(email: newEmail),
    );
  }

  // Get user profile from database
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isLoggedIn) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .single();

    return response;
  }

  // Update user profile in database
  static Future<void> updateUserProfile({
    String? fullName,
    String? role,
  }) async {
    if (!isLoggedIn) throw Exception('Not logged in');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (role != null) updates['role'] = role;

    await _supabase.from('profiles').update(updates).eq('id', currentUser!.id);
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // Sign in with Google - native popup on mobile, OAuth redirect on web
  static Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: use OAuth redirect flow
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _webRedirectUrl,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      return null; // Web redirects, no immediate response
    }

    // Mobile: use native Google Sign-In popup
    const webClientId =
        '853024357754-ksqvcpgdd2get38464jm6n7ms2n7hjqf.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: webClientId);

    final googleUser = await googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    return response;
  }

  /// Returns the current web origin URL for OAuth redirect
  static String get _webRedirectUrl {
    final uri = Uri.base;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  // Check if email is verified
  static bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  // Resend email verification
  static Future<void> resendVerificationEmail() async {
    if (!isLoggedIn) throw Exception('Not logged in');
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: currentUser!.email,
    );
  }
}
