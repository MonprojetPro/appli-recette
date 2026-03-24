import 'package:appli_recette/core/auth/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider singleton du service d'authentification.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// L'utilisateur Supabase connecté, ou null.
final currentUserProvider = Provider<User?>((ref) {
  // Se ré-évalue à chaque changement de session
  ref.watch(authServiceProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// True si une session active existe.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
