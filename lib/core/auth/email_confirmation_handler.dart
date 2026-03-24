import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère la détection du fragment de confirmation email dans l'URL.
///
/// DOIT être appelé AVANT Supabase.initialize() car l'init consomme
/// le fragment URL (#access_token=...).
///
/// Flow :
/// 1. detectBeforeInit() → lit Uri.base.fragment pour détecter #access_token
/// 2. Supabase.initialize() → consomme le fragment et crée une session temporaire
/// 3. signOutIfNeeded() → sign out la session temporaire pour forcer le login
/// 4. LoginScreen lit EmailConfirmedFlag.consume() → affiche banner verte
class EmailConfirmationHandler {
  static bool _emailConfirmed = false;

  /// Appelé AVANT Supabase.initialize().
  ///
  /// Détecte si l'URL contient un fragment de confirmation email.
  static Future<void> detectBeforeInit() async {
    try {
      final fragment = Uri.base.fragment;
      if (fragment.contains('access_token') &&
          fragment.contains('type=signup')) {
        _emailConfirmed = true;
        debugPrint('[EmailConfirmationHandler] Fragment confirmation détecté');
      }
    } catch (e) {
      debugPrint('[EmailConfirmationHandler] Erreur détection: $e');
    }
  }

  /// Appelé APRÈS Supabase.initialize().
  ///
  /// Si une confirmation a été détectée, sign out la session temporaire
  /// pour forcer l'utilisateur à se connecter manuellement.
  /// Active le flag pour que LoginScreen affiche la banner "Email confirmé".
  static Future<void> signOutIfNeeded() async {
    if (!_emailConfirmed) return;

    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint('[EmailConfirmationHandler] Session temporaire signOut OK');
    } catch (e) {
      debugPrint('[EmailConfirmationHandler] Erreur signOut: $e');
    }
  }

  /// True si un email vient d'être confirmé (consommé une seule fois).
  static bool consumeConfirmationFlag() {
    if (_emailConfirmed) {
      _emailConfirmed = false;
      return true;
    }
    return false;
  }
}
