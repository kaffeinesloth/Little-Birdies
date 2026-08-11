import 'models.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
  });

  final CurrentUser user;
  final String accessToken;
}

class SupabaseAuthPlaceholder {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  bool get isMockMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  Future<AuthSession> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw AuthException('Email and password are required.');
    }
    if (email.toLowerCase().contains('disabled')) {
      throw AuthException('This account is disabled.');
    }
    if (!isMockMode) {
      // Placeholder boundary for replacing with supabase_flutter once mobile
      // credentials and package policy are finalized.
    }
    return AuthSession(
      accessToken:
          isMockMode ? 'mock-mobile-token' : 'supabase-placeholder-token',
      user: CurrentUser(
        id: role == UserRole.agent ? 'agent-demo' : 'owner-demo',
        email: email,
        fullName: role == UserRole.agent ? 'Support Agent' : 'Shop Owner',
        role: role,
      ),
    );
  }

  Future<void> signOut() async {}
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
