import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'authentification email/mot de passe via Supabase Auth.
///
/// Remplace l'authentification anonyme. La persistance de session
/// est gérée automatiquement par supabase_flutter (localStorage web,
/// SharedPreferences mobile).
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Connecte un utilisateur existant avec email + mot de passe.
  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Crée un nouveau compte utilisateur.
  ///
  /// [AuthResponse.session] est null si la confirmation email est requise.
  /// [emailRedirectTo] redirige vers /login après confirmation email
  /// pour éviter un flash sur la home avec un token temporaire.
  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: '${_webBaseUrl}/login',
    );
  }

  /// URL de base web, injectée via dart-define ou défaut menuzen.
  static const _webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://menuzen.vercel.app',
  );

  /// Envoie un email de réinitialisation du mot de passe.
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Déconnecte l'utilisateur courant.
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// Utilisateur actuellement connecté (null = non authentifié).
  User? get currentUser => _client.auth.currentUser;

  /// UUID de l'utilisateur courant (null = non authentifié).
  String? get currentUserId => _client.auth.currentUser?.id;
}
