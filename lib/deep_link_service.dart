import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================
//  DEEP LINKS — Lot 11
//  Capture les liens https://alloguinaar.danov.sn/?ref=CODE (ou avec
//  role=client&ref=CODE, format déjà utilisé pour le partage de
//  parrainage depuis le Lot 1) quand l'app est ouverte via ce lien —
//  que ce soit à froid (app fermée), en arrière-plan, ou au premier
//  plan. Le code est mémorisé localement pour être proposé
//  automatiquement au moment de l'inscription.
//
//  ⚠️ Nécessite une configuration côté Android (déjà faite dans
//  AndroidManifest.xml) ET côté serveur (fichier assetlinks.json à
//  héberger vous-même — voir GUIDE_MARKETING_SOCIAL.md, je n'ai pas
//  accès à votre serveur pour le déposer moi-même).
// =============================================================
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;
  static const _cleCodeParrainEnAttente = 'code_parrain_en_attente';

  /// À appeler tôt dans le cycle de vie de l'app (main.dart), avant
  /// même le premier écran si possible, pour ne rater aucun lien.
  static Future<void> initialiser() async {
    try {
      // Lien ayant lancé l'app à froid (app totalement fermée)
      final lienInitial = await _appLinks.getInitialLink();
      if (lienInitial != null) _traiterLien(lienInitial);
    } catch (_) {
      // Jamais bloquant : un souci de deep link ne doit jamais empêcher l'app de démarrer
    }

    // Liens reçus pendant que l'app tourne déjà (premier plan ou arrière-plan)
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      _traiterLien,
      onError: (_) {},
    );
  }

  static void _traiterLien(Uri uri) {
    final code = uri.queryParameters['ref'];
    if (code != null && code.isNotEmpty) {
      _memoriserCodeParrain(code);
    }
  }

  static Future<void> _memoriserCodeParrain(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleCodeParrainEnAttente, code);
  }

  /// À appeler depuis l'écran d'inscription pour préremplir le champ
  /// code parrain, s'il y en a un en attente suite à un lien ouvert.
  static Future<String?> lireCodeParrainEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cleCodeParrainEnAttente);
  }

  /// À appeler une fois le code effectivement utilisé (inscription
  /// terminée), pour ne pas le reproposer indéfiniment.
  static Future<void> effacerCodeParrainEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleCodeParrainEnAttente);
  }

  static void disposer() {
    _subscription?.cancel();
    _subscription = null;
  }
}
