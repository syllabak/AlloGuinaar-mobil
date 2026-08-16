// STUB WEB — toutes les méthodes sont des no-ops silencieux
class NotificationService {
  static Future<void> initialiser() async {}
  static Future<void> afficher({required int id, required String titre, required String corps, String? payload}) async {}
  static Future<void> afficherAlerteUrgente({required int id, required String titre, required String corps, String? payload}) async {} // 🆕
  static Future<void> verifierChangementsStatut(String telephone) async {}
  static Future<void> sauvegarderStatutsInitiaux(String telephone) async {}
}