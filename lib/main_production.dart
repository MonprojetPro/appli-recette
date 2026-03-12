import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:appli_recette/app/app.dart';
import 'package:appli_recette/bootstrap.dart';
import 'package:appli_recette/core/auth/email_confirmation_handler.dart';
import 'package:appli_recette/core/auth/join_code_handler.dart';
import 'package:appli_recette/core/config/app_config.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // DOIT être appelé AVANT ensureInitialized() pour que GoRouter
  // voie les URLs path-based (/join, /login, etc.) au lieu du hash (#/).
  usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig(
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://placeholder.supabase.co',
    ),
    supabaseAnonKey: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'placeholder-anon-key',
    ),
    flavor: AppFlavor.production,
  );

  final database = AppDatabase();

  // Capturer le code d'invitation depuis l'URL AVANT tout le reste.
  await JoinCodeHandler.captureFromUrl();

  // Détecter le fragment de confirmation email AVANT Supabase.initialize()
  // car l'init consomme le fragment URL (#access_token=...).
  await EmailConfirmationHandler.detectBeforeInit();

  await bootstrap(
    () async {
      await Supabase.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
      );
      // Sign out la session temporaire créée par le fragment de confirmation
      await EmailConfirmationHandler.signOutIfNeeded();
      return App(database: database, config: config);
    },
  );
}
