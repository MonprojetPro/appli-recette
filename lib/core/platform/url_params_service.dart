import 'url_params_stub.dart'
    if (dart.library.js_interop) 'url_params_web.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service cross-platform d'extraction des query params depuis l'URL navigateur.
///
/// Sur web : lit `window.location.href` via [dart:html] (import conditionnel).
/// Sur mobile : retourne toujours null (stub).
class UrlParamsService {
  const UrlParamsService();

  /// Extrait le code d'invitation depuis le query param `?code=` de l'URL.
  ///
  /// Retourne null si absent ou si l'application tourne sur mobile natif.
  String? extractInvitationCode() => extractCodeFromUrl();
}

/// Provider du service de lecture des URL params.
final urlParamsServiceProvider = Provider<UrlParamsService>(
  (_) => const UrlParamsService(),
);
