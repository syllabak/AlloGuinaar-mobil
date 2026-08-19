import 'dart:io' show Platform;
import 'package:flutter/services.dart';

// =============================================================
//  FULL SCREEN INTENT PERMISSION — Android 14+ uniquement.
//
//  Sans cette permission spéciale accordée, l'alerte plein écran
//  façon appel entrant (afficherAlerteUrgente() dans
//  notification_service_mobile.dart) retombe silencieusement sur une
//  notification standard — c'est ce comportement qui était observé.
//
//  Sur iOS et sur Android < 14, verifierEtDemander() ne fait rien et
//  considère la permission comme acquise (aucune restriction de ce
//  type là-bas).
// =============================================================
class FullScreenIntentPermission {
  static const _channel = MethodChannel('sn.danov.alloguinaar/full_screen_intent');

  static Future<bool> estAccordee() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? resultat = await _channel.invokeMethod<bool>('peutUtiliserPleinEcran');
      return resultat ?? true;
    } catch (e) {
      // En cas d'erreur de canal (ex. ancienne version de l'app sans
      // ce code natif), on suppose accordée plutôt que de bloquer
      // l'utilisateur avec une demande inutile.
      return true;
    }
  }

  /// Ouvre l'écran système où l'utilisateur peut activer manuellement
  /// la permission — aucun moyen de l'accorder par programmation,
  /// Android exige un geste explicite de l'utilisateur pour ce type de
  /// permission spéciale.
  static Future<void> ouvrirReglages() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('ouvrirReglagesPleinEcran');
    } catch (_) {}
  }
}
