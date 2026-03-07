/// Configuration de l'application par flavor (development/production)
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.flavor,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final AppFlavor flavor;

  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://appli-recette.vercel.app',
  );

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;
}

enum AppFlavor { development, production }
