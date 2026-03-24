import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'authentification — wrapper propre autour de Supabase Auth.
///
/// Réécriture complète (2026-03-23) — voir auth-rewrite-spec.
class AuthService {
  AuthService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Crée un nouveau compte email + mot de passe.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Connexion email + mot de passe.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Déconnexion — supprime la session locale.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Envoie un email de réinitialisation de mot de passe.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Renvoie l'email de confirmation.
  ///
  /// Utilise resend() — JAMAIS signUp() avec mot de passe vide.
  Future<void> resendConfirmationEmail(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  /// L'utilisateur actuellement connecté, ou null.
  User? get currentUser => _client.auth.currentUser;

  /// L'ID de l'utilisateur connecté, ou null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// True si une session active existe.
  bool get isAuthenticated => _client.auth.currentSession != null;

  /// Stream des changements d'état d'authentification.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
