import 'package:appli_recette/core/config/app_config.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/router/app_router.dart';
import 'package:appli_recette/core/theme/app_theme.dart';
import 'package:appli_recette/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends StatelessWidget {
  const App({
    required this.database,
    required this.config,
    super.key,
  });

  final AppDatabase database;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: _AppContent(config: config),
    );
  }
}

/// Widget interne qui fournit le GoRouter via Riverpod.
///
/// Le GoRouter gère entièrement les redirects d'authentification :
/// - Non authentifié → /login
/// - Authentifié + aucun foyer → /household-setup
/// - Authentifié + foyer + onboarding non fait → /onboarding
/// - Authentifié + foyer + onboarding fait → / (shell principal)
class _AppContent extends ConsumerWidget {
  const _AppContent({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'MenuFacile',
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: config.isDevelopment,
    );
  }
}
