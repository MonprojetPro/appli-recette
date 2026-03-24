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

  await JoinCodeHandler.captureFromUrl();
  await EmailConfirmationHandler.detectBeforeInit();

  await bootstrap(
    () async {
      await Supabase.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
      );
      await EmailConfirmationHandler.signOutIfNeeded();
      return App(database: database, config: config);
    },
  );
}
