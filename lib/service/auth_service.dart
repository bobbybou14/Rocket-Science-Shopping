import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get client => Supabase.instance.client;

  static Session? get currentSession => client.auth.currentSession;

  static User? get currentUser => client.auth.currentUser;

  static Stream<AuthState> get authStateChanges {
    return client.auth.onAuthStateChange;
  }

  static bool get isSignedIn => currentSession != null;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedDisplayName = displayName?.trim();

    return client.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {
        if (normalizedDisplayName != null && normalizedDisplayName.isNotEmpty)
          'display_name': normalizedDisplayName,
      },
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  static Future<void> sendPasswordResetEmail({required String email}) async {
    await client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
