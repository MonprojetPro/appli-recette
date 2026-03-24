import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream des changements d'état auth Supabase.
///
/// Émet un événement à chaque connexion, déconnexion, refresh de token, etc.
/// Utilisé par [AppRouterNotifier] et [currentHouseholdIdProvider] pour
/// ré-évaluer les redirects automatiquement.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
