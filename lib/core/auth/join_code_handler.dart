import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Capture le code d'invitation depuis l'URL du navigateur.
///
/// Doit être appelé AVANT le bootstrap pour capturer le code
/// depuis `Uri.base` avant que GoRouter ne modifie l'URL.
class JoinCodeHandler {
  static const _kPendingJoinCode = 'pending_join_code';

  /// Capture le code d'invitation depuis l'URL si présent.
  ///
  /// Détecte les URLs de type :
  /// - `https://menuzen.vercel.app/join?code=123456`
  /// - `https://menuzen.vercel.app/#/join?code=123456`
  static Future<void> captureFromUrl() async {
    if (!kIsWeb) return;

    final uri = Uri.base;
    String? code;

    // Path strategy: /join?code=XXX
    if (uri.path.contains('/join')) {
      code = uri.queryParameters['code'];
    }

    // Hash strategy: /#/join?code=XXX
    if (code == null && uri.fragment.contains('/join')) {
      try {
        final fragmentUri = Uri.parse(uri.fragment);
        code = fragmentUri.queryParameters['code'];
      } catch (_) {
        // Fragment mal formé, ignorer
      }
    }

    if (code != null && code.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingJoinCode, code);
    }
  }
}
