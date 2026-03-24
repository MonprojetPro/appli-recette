import 'package:appli_recette/core/auth/auth_providers.dart';
import 'package:appli_recette/core/router/app_router.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Écran "Vérifiez votre email" — affiché après inscription.
///
/// Parcours 1, 2, 3 (étape 3).
/// Bouton "Renvoyer l'email" utilise resend() — JAMAIS signUp() avec mdp vide.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({this.email, super.key});

  /// L'email passé via state.extra depuis SignupScreen.
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isResending = false;
  bool _resent = false;

  @override
  Widget build(BuildContext context) {
    final email = widget.email ?? 'votre adresse';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vérifiez votre email',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Un email de confirmation a été envoyé à\n$email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cliquez sur le lien dans l\'email pour activer '
                    'votre compte, puis revenez ici.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textHint,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Bouton "J'ai confirmé mon email"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'J\'ai confirmé mon email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton "Renvoyer l'email"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (_isResending || widget.email == null)
                          ? null
                          : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isResending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              _resent
                                  ? 'Email renvoyé !'
                                  : 'Renvoyer l\'email',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Retour à la connexion
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text(
                      'Retour à la connexion',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    if (widget.email == null) return;

    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.resendConfirmationEmail(widget.email!);

      if (!mounted) return;
      setState(() {
        _resent = true;
        _isResending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de renvoyer l\'email. Réessayez.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
