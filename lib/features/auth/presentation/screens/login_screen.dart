import 'package:appli_recette/core/auth/auth_providers.dart';
import 'package:appli_recette/core/auth/auth_service.dart';
import 'package:appli_recette/core/auth/email_confirmation_handler.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écran de connexion email/mot de passe.
///
/// Gère : connexion (AC-2), navigation vers signup (AC-3),
/// navigation vers mot de passe oublié (AC-5), messages d'erreur humains (AC-7).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.existingAccount = false, super.key});

  final bool existingAccount;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailJustConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkEmailConfirmation();
  }

  Future<void> _checkEmailConfirmation() async {
    final confirmed =
        await EmailConfirmationHandler.consumeConfirmationFlag();
    if (confirmed && mounted) {
      setState(() => _emailJustConfirmed = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Traduit une [AuthException] en message lisible (AC-7).
  String _humanizeError(AuthException e) {
    return switch (e.message) {
      'Invalid login credentials' => 'Email ou mot de passe incorrect.',
      'Email not confirmed' =>
        'Confirmez votre email avant de vous connecter.',
      'User already registered' => 'Un compte existe déjà avec cet email.',
      'Invalid email' => 'Adresse email invalide.',
      _ => 'Une erreur est survenue. Réessayez.',
    };
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final service = ref.read(authServiceProvider);
      await service.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // GoRouter redirect handle navigation automatiquement via authStateProvider
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _humanizeError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Une erreur est survenue. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  FractionallySizedBox(
                    widthFactor: 0.8,
                    child: Image.asset(
                      'assets/icon/logo_menufacile.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour accéder à vos recettes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Bandeau compte existant
                  if (widget.existingAccount) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Un compte existe déjà avec cette adresse. '
                              'Connectez-vous avec votre mot de passe.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bandeau email confirmé
                  if (_emailJustConfirmed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Email confirme ! Connectez-vous '
                              'pour acceder a votre compte.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Champ email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir votre email.';
                      }
                      if (!value.contains('@')) {
                        return 'Adresse email invalide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Champ mot de passe
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir votre mot de passe.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Lien mot de passe oublié (AC-5)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        'Mot de passe oublié ?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Message d'erreur (AC-7)
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Bouton Connexion (AC-2)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ValueListenableBuilder(
                      valueListenable: _emailController,
                      builder: (_, emailVal, __) {
                        return ValueListenableBuilder(
                          valueListenable: _passwordController,
                          builder: (_, passVal, __) {
                            final canSubmit = emailVal.text.isNotEmpty &&
                                passVal.text.isNotEmpty &&
                                !_isLoading;
                            return FilledButton(
                              onPressed: canSubmit ? _signIn : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Connexion',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lien créer un compte (AC-3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pas encore de compte ?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text(
                          'Créer un compte',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
