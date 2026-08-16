import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'session_service.dart';
import 'message_screen.dart';
import 'catalogue_screen.dart';
import 'producteur_screen.dart';
import 'livreur_screen.dart';
import 'proposition_commande_screen.dart'; // dispatch Uber/Yango

// =============================================================
//  ROUTEUR DE NOTIFICATIONS — réécrit à neuf.
//  Ouvre l'écran concerné au toucher d'une notification (FCM premier
//  plan/arrière-plan/app fermée, ou notification locale). Point d'entrée
//  UNIQUE partagé entre fcm_service_mobile.dart et
//  notification_service_mobile.dart, pour ne jamais dupliquer cette
//  logique de routage à deux endroits différents.
// =============================================================
class NotificationRouter {
  static Future<void> ouvrir(Map<String, dynamic> data) async {
    print("[Routeur] ouvrir() appelé avec type=${data['type']}");

    final session = await SessionService.lire();
    if (session == null) {
      print("[Routeur] Aucune session active — rien à ouvrir");
      return;
    }

    final String tel  = session['tel'] ?? '';
    final String nom  = session['nom'] ?? '';
    final String role = session['role'] ?? 'client';
    if (tel.isEmpty) {
      print("[Routeur] Session sans téléphone — rien à ouvrir");
      return;
    }

    // 🆕 Robustesse : au lancement à froid depuis une notification
    // (app totalement fermée), le premier frame peut ne pas encore être
    // monté au moment où ce code s'exécute. On patiente un court instant
    // plutôt que d'abandonner silencieusement.
    NavigatorState? navState = navigatorKey.currentState;
    var tentatives = 0;
    while (navState == null && tentatives < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      navState = navigatorKey.currentState;
      tentatives++;
    }
    if (navState == null) {
      print("[Routeur] ERREUR : navigatorKey.currentState toujours null après ${tentatives * 200}ms — abandon");
      return;
    }

    final String type = (data['type'] ?? '').toString();

    // 🚨 Proposition de commande (dispatch Uber/Yango) : écran plein
    // écran Accepter/Refuser avec sonnerie, prioritaire sur tout le reste.
    if (type == 'proposition_commande' && data['proposition_id'] != null) {
      print("[Routeur] Ouverture PropositionCommandeScreen (cmd #${data['cmd_id']})");
      navState.push(MaterialPageRoute(
        builder: (_) => PropositionCommandeScreen(
          telephone: tel,
          propositionId: int.tryParse(data['proposition_id'].toString()) ?? 0,
          cmdId: int.tryParse(data['cmd_id'].toString()) ?? 0,
          delaiSecondes: int.tryParse(data['delai_secondes']?.toString() ?? '') ?? 120,
        ),
      ));
      return;
    }

    // 💬 Messagerie : ouvrir directement la conversation concernée
    if (type == 'nouveau_message' && data['cmd_id'] != null) {
      print("[Routeur] Ouverture MessageScreen (cmd #${data['cmd_id']})");
      navState.push(MaterialPageRoute(
        builder: (_) => MessageScreen(
          cmdId: int.tryParse(data['cmd_id'].toString()) ?? 0,
          telephone: tel,
          monRole: role == 'producteur' ? 'producteur' : 'client',
        ),
      ));
      return;
    }

    // Tout le reste (statut de commande, stock, grossiste, mission...) :
    // ouvrir l'espace du rôle concerné, qui affiche déjà l'information
    // pertinente (commandes, stock, missions selon le rôle).
    print("[Routeur] Ouverture de l'espace rôle='$role' (type de notification générique)");
    Widget ecran;
    switch (role) {
      case 'producteur':
        ecran = ProducteurScreen(telephone: tel, nom: nom);
        break;
      case 'livreur':
        ecran = LivreurScreen(telephone: tel, nom: nom);
        break;
      default:
        ecran = CatalogueScreen(initialNom: nom, initialPhone: tel);
    }
    navState.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => ecran), (r) => false);
  }
}
