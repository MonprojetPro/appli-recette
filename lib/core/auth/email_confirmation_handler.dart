import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère le retour depuis un lien de confirmation email.
///
/// Quand l'utilisateur clique sur le lien de confirmation, Supabase
/// redirige vers l'app avec un `#access_token=...` dans l'URL.
/// Cela crée une session temporaire qui n'est pas fiable sur Flutter web
/// (WASM/IndexedDB). On détecte ce cas AVANT Supabase.initialize(),
/// puis on sign out APRÈS pour forcer un login propre.
class EmailConfirmationHandler {
  static const _kEmailConfirmed = 'email_just_confirmed';

  /// Détecte si l'URL contient un fragment de confirmation email.
  ///
  /// **Doit être appelé AVANT [Supabase.initialize()]** car l'init
  /// consomme le fragment URL.
  static bool _hasConfirmationFragment = false;

  static Future<void> detectBeforeInit() async {
    if (!kIsWeb) return;

    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty && fragment.contains('access_token')) {
      _hasConfirmationFragment = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEmailConfirmed, true);
    }
  }

  /// Sign out la session temporaire créée par le fragment.
  ///
  /// **Doit être appelé APRÈS [Supabase.initialize()]**.
  static Future<void> signOutIfNeeded() async {
    if (!_hasConfirmationFragment) return;
    _hasConfirmationFragment = false;
    await Supabase.instance.client.auth.signOut();
  }

  /// Vérifie et consomme le flag "email confirmé".
  ///
  /// Retourne `true` une seule fois après une confirmation email.
  static Future<bool> consumeConfirmationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final confirmed = prefs.getBool(_kEmailConfirmed) ?? false;
    if (confirmed) {
      await prefs.remove(_kEmailConfirmed);
    }
    return confirmed;
  }
}
