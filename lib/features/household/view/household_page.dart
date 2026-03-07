import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/household/invitation_service.dart';
import 'package:appli_recette/core/router/app_router.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/household/presentation/providers/household_provider.dart';
import 'package:appli_recette/features/household/presentation/widgets/member_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HouseholdPage extends ConsumerWidget {
  const HouseholdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final codeAsync = ref.watch(householdCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foyer'),
        actions: [
          Semantics(
            label: 'Ajouter un membre',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Ajouter un membre',
              onPressed: () => context.push(AppRoutes.memberAdd),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Code foyer ──
          if (codeAsync.value != null)
            _HouseholdCodeBanner(
              code: codeAsync.value!,
              onShare: () => ref
                  .read(invitationServiceProvider)
                  .shareInvitation(codeAsync.value!),
            ),

          // ── Liste des membres ──
          Expanded(
            child: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Erreur : $error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return _EmptyState(
              onAdd: () => context.push(AppRoutes.memberAdd),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return MemberCard(
                member: member,
                onEdit: () => context.push(
                  AppRoutes.memberEditPath(member.id),
                  extra: member,
                ),
                onDelete: () => _confirmDelete(context, ref, member),
              );
            },
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${member.name} ?'),
        content: const Text(
          'Ses préférences alimentaires et son planning de présence '
          'seront également supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(householdNotifierProvider.notifier)
            .deleteMember(member.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression : $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

/// État vide — aucun membre dans le foyer.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Ajoute les membres de ton foyer',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leurs préférences seront prises en compte\ndans la génération des menus.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Ajouter un membre'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau affichant le code d'invitation du foyer.
class _HouseholdCodeBanner extends StatelessWidget {
  const _HouseholdCodeBanner({
    required this.code,
    required this.onShare,
  });

  final String code;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            'Code foyer : ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            code,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copier le code',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copie !'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.share, size: 18),
            tooltip: 'Partager',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
