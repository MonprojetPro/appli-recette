import 'package:appli_recette/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Service de génération et partage des liens d'invitation foyer.
class InvitationService {
  const InvitationService();

  /// Génère un lien d'invitation complet pour le code foyer donné.
  ///
  /// Format : `https://[DOMAIN]/join?code=XXXXXX`
  String generateInvitationLink(String code) {
    return '${AppConfig.webBaseUrl}/join?code=$code';
  }

  /// Partage le lien d'invitation via la feuille de partage native.
  ///
  /// Utilise `share_plus` — déclenche le partage système (web + mobile).
  Future<void> shareInvitation(String code) async {
    final link = generateInvitationLink(code);
    await Share.share(
      'Rejoins mon foyer sur MenuZen !\n'
      '🔗 $link\n'
      'Ou entre directement le code : $code',
      subject: 'Invitation MenuZen',
    );
  }
}

/// Provider du service d'invitation foyer.
final invitationServiceProvider = Provider<InvitationService>(
  (_) => const InvitationService(),
);
