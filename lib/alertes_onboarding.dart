import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'full_screen_intent_permission.dart';

// =============================================================
//  ALERTES ONBOARDING — regroupe les réglages système Samsung/
//  Android qui conditionnent la fiabilité de l'alerte plein écran
//  façon appel entrant, en plus de la permission USE_FULL_SCREEN_INTENT
//  déjà gérée par full_screen_intent_permission.dart.
//
//  IMPORTANT — honnêteté sur ce qui est réellement automatisable :
//   - Batterie : Android propose une VRAIE boîte de dialogue système
//     "Autoriser"/"Refuser" en un clic — c'est le seul des trois
//     réglages ci-dessous qui ne nécessite pas de fouiller dans un
//     écran de paramètres.
//   - Canal urgent : on peut ouvrir DIRECTEMENT l'écran de réglages
//     du bon canal de notification, mais l'utilisateur doit quand
//     même toucher le bon interrupteur lui-même.
//   - Démarrage automatique : AUCUNE app tierce ne peut activer ce
//     réglage par programmation sur Samsung. On ouvre l'écran de
//     détails de l'app en dernier recours, et le geste manuel reste
//     nécessaire — ne jamais laisser croire le contraire à
//     l'utilisateur.
// =============================================================
class AlertesPermissions {
  static const _channel = MethodChannel('sn.danov.alloguinaar/full_screen_intent');

  static Future<bool> batterieDejaExclue() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? r = await _channel
          .invokeMethod<bool>('batterieDejaExclue')
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      return r ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> demanderExclusionBatterie() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('demanderExclusionBatterie');
    } catch (_) {}
  }

  static Future<void> ouvrirReglagesCanalUrgent() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('ouvrirReglagesCanalUrgent');
    } catch (_) {}
  }

  static Future<void> ouvrirReglagesDemarrageAuto() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('ouvrirReglagesDemarrageAuto');
    } catch (_) {}
  }
}

/// Boîte de dialogue unique listant les 4 réglages nécessaires pour
/// des alertes plein écran fiables, avec un bouton d'action pour
/// chacun. L'utilisateur peut les traiter dans l'ordre qu'il veut,
/// revenir dans l'app entre chaque, et fermer quand il a terminé —
/// aucun réglage n'est forcé, et rien n'est automatisé au-delà de ce
/// qu'Android autorise réellement.
Future<void> afficherOnboardingAlertes(BuildContext context) async {
  if (!Platform.isAndroid) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Fiabiliser les alertes de commande",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Certains réglages Samsung peuvent empêcher l'alerte "
                  "façon appel entrant de s'afficher, surtout téléphone "
                  "verrouillé. Configure les points ci-dessous :",
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                _LigneReglage(
                  titre: "Plein écran",
                  description: "Autoriser l'alerte à s'afficher par-dessus l'écran verrouillé.",
                  onTap: () => FullScreenIntentPermission.ouvrirReglages(),
                ),
                _LigneReglage(
                  titre: "Batterie",
                  description: "Empêcher Samsung de mettre l'app en veille et de bloquer les alertes.",
                  onTap: () => AlertesPermissions.demanderExclusionBatterie(),
                ),
                _LigneReglage(
                  titre: "Canal « Commandes urgentes »",
                  description: "Vérifier que l'affichage en pop-up est activé pour ce canal.",
                  onTap: () => AlertesPermissions.ouvrirReglagesCanalUrgent(),
                ),
                _LigneReglage(
                  titre: "Démarrage automatique",
                  description:
                      "Dans l'écran qui s'ouvre, chercher \"Démarrage automatique\" ou "
                      "\"Batterie\" et l'activer pour Allo Guinaar — Android ne permet "
                      "pas à l'app de l'activer elle-même, ce geste reste manuel.",
                  onTap: () => AlertesPermissions.ouvrirReglagesDemarrageAuto(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Terminé"),
            ),
          ],
        );
      },
    ),
  );
}

class _LigneReglage extends StatelessWidget {
  final String titre;
  final String description;
  final VoidCallback onTap;

  const _LigneReglage({
    required this.titre,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: onTap,
            child: const Text("Configurer", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
