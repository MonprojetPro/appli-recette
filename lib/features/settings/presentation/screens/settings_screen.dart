import 'package:appli_recette/core/auth/auth_providers.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/invitation_service.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/sync/sync_provider.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Écran Réglages — compte, foyer, déconnexion (Story 8.3).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final householdAsync = ref.watch(householdDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Réglages'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Section Mon compte ─────────────────────────────────────
          _SectionHeader(title: 'Mon compte', theme: theme),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.email_outlined,
            label: 'Email',
            value: currentUser?.email ?? '—',
          ),
          const SizedBox(height: 16),

          // ─── Section Mon foyer ──────────────────────────────────────
          _SectionHeader(title: 'Mon foyer', theme: theme),
          const SizedBox(height: 8),
          householdAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const _InfoCard(
              icon: Icons.home_outlined,
              label: 'Foyer',
              value: 'Erreur de chargement',
            ),
            data: (details) {
              if (details == null) {
                return const _InfoCard(
                  icon: Icons.home_outlined,
                  label: 'Foyer',
                  value: 'Aucun foyer configuré',
                );
              }
              final name = details['name'] as String? ?? 'Mon Foyer';
              final code = details['code'] as String? ?? '------';
              return Column(
                children: [
                  _InfoCard(
                    icon: Icons.home_outlined,
                    label: 'Nom du foyer',
                    value: name,
                  ),
                  const SizedBox(height: 8),
                  // Code foyer en grand
                  _HouseholdCodeCard(code: code),
                  const SizedBox(height: 8),
                  // Bouton copier
                  _ActionButton(
                    icon: Icons.copy_outlined,
                    label: 'Copier le code',
                    onTap: () => _copyCode(context, code),
                  ),
                  const SizedBox(height: 8),
                  // Bouton partager
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Partager le lien d\'invitation',
                    onTap: () => _shareInvitation(context, ref, code),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // ─── Déconnexion ────────────────────────────────────────────
          FilledButton.tonal(
            onPressed: () => _confirmSignOut(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.1),
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_outlined),
                SizedBox(width: 8),
                Text(
                  'Se déconnecter',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copié !'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareInvitation(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    try {
      final service = ref.read(invitationServiceProvider);
      await service.shareInvitation(code);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de partager le lien. Réessayez.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous serez redirigé vers l\'écran de connexion. '
          'Vos données locales seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authService = ref.read(authServiceProvider);
    final db = ref.read(databaseProvider);
    final processor = ref.read(syncQueueProcessorProvider);
    await processor.processQueue(); // flush sync avant de vider
    await db.clearAll();
    // household_id/auth_user_id/household_code restent en prefs au sign-out.
    // HouseholdService.getCurrentHouseholdId() détecte déjà le changement
    // d'utilisateur et purge ces clés si besoin. Les supprimer ici forçait
    // une requête Supabase à chaque reconnexion qui pouvait rediriger vers
    // la création de foyer et réinitialiser l'onboarding.
    ref.invalidate(currentHouseholdIdProvider);
    await authService.signOut();

    // Le router redirige automatiquement vers /login via authStateProvider
    if (context.mounted) context.go('/login');
  }
}

// ── Widgets privés ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdCodeCard extends StatelessWidget {
  const _HouseholdCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Text(
              'Code Foyer',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              code,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
                color: AppColors.primary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
