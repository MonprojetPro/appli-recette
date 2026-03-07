import 'package:web/web.dart' as web;

/// Implémentation web — lit le query param `?code=` depuis `window.location`.
String? extractCodeFromUrl() {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters['code'];
}
