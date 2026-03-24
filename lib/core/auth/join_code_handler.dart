import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Capture le code d'invitation depuis l'URL avant que GoRouter ne la consomme.
///
/// Supporte deux formats :
/// - `/join?code=847392` (query parameter)
/// - `/join?join_code=847392` (query parameter)
///
/// Le code est sauvegardé en mémoire (priorité, pas de latence async)
/// ET dans SharedPreferences (fallback si l'app recharge).
class JoinCodeHandler {
  static String? _pendingJoinCode;

  /// Le code en mémoire (lecture synchrone, pas de latence).
  static String? get pendingJoinCode => _pendingJoinCode;

  /// Appelé AVANT Supabase.initialize() pour capturer le code d'invitation.
  static Future<void> captureFromUrl() async {
    try {
      final uri = Uri.base;
      String? code;

      // Chercher dans les query parameters
      code ??= uri.queryParameters['code'];
      code ??= uri.queryParameters['join_code'];

      // Chercher dans le path: /join/847392
      if (code == null && uri.path.startsWith('/join/')) {
        final segment = uri.path.replaceFirst('/join/', '');
        if (RegExp(r'^\d{6}$').hasMatch(segment)) {
          code = segment;
        }
      }

      if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) {
        _pendingJoinCode = code;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_join_code', code);
        debugPrint('[JoinCodeHandler] Code capturé: $code');
      }
    } catch (e) {
      debugPrint('[JoinCodeHandler] Erreur capture: $e');
    }
  }

  /// Consomme le code (une seule utilisation).
  static Future<String?> consume() async {
    // Priorité mémoire (pas de latence async)
    if (_pendingJoinCode != null) {
      final code = _pendingJoinCode;
      _pendingJoinCode = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_join_code');
      return code;
    }

    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pending_join_code');
    if (code != null) {
      await prefs.remove('pending_join_code');
    }
    return code;
  }

  /// Vérifie s'il y a un code en attente (sans le consommer).
  static Future<bool> hasPendingCode() async {
    if (_pendingJoinCode != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pending_join_code') != null;
  }
}
