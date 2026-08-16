import 'package:firebase_analytics/firebase_analytics.dart';

// =============================================================
//  ANALYTICS (GA4 via Firebase) — Lot 11
//  Nécessite que Google Analytics soit activé dans la console
//  Firebase du projet (pas encore fait au moment de l'écriture de ce
//  fichier) — voir GUIDE_MARKETING_SOCIAL.md. Le SDK ne plante jamais
//  si ce n'est pas encore activé : les événements sont simplement
//  ignorés côté serveur en attendant.
// =============================================================
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Observateur à ajouter à MaterialApp.navigatorObservers pour un
  /// suivi automatique des écrans visités (screen_view), sans avoir
  /// à instrumenter chaque écran manuellement.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Identifie l'utilisateur courant (appelé après connexion), ou
  /// efface l'identifiant (appelé à la déconnexion, avec null).
  static Future<void> definirUtilisateur({required String? telephone, required String role}) async {
    try {
      await _analytics.setUserId(id: telephone);
      await _analytics.setUserProperty(name: 'role', value: role);
    } catch (_) {
      // Jamais bloquant : l'analytics ne doit jamais empêcher l'usage de l'app
    }
  }

  static Future<void> connexion(String role) async {
    try {
      await _analytics.logLogin(loginMethod: role);
    } catch (_) {}
  }

  static Future<void> inscription(String role) async {
    try {
      await _analytics.logSignUp(signUpMethod: role);
    } catch (_) {}
  }

  static Future<void> commandePassee({
    required double montant,
    required int quantite,
    String devise = 'XOF',
  }) async {
    try {
      await _analytics.logPurchase(
        currency: devise,
        value: montant,
        parameters: {'quantite': quantite},
      );
    } catch (_) {}
  }

  /// Événement générique pour tout ce qui ne rentre pas dans les
  /// méthodes prédéfinies ci-dessus (ex. ouverture d'une formation,
  /// demande grossiste, avis laissé...).
  static Future<void> evenement(String nom, {Map<String, Object>? parametres}) async {
    try {
      await _analytics.logEvent(name: nom, parameters: parametres);
    } catch (_) {}
  }
}
