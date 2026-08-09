import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'session_service.dart';
import 'message_screen.dart';
import 'catalogue_screen.dart';
import 'producteur_screen.dart';
import 'livreur_screen.dart';
import 'proposition_commande_screen.dart'; // 🆕 dispatch Uber/Yango

// =============================================================
//  ROUTEUR DE NOTIFICATIONS — ouvre l'écran concerné au toucher
//  d'une notification (FCM en premier plan/arrière-plan, ou
//  notification locale). Partagé entre notification_service_mobile.dart
//  et fcm_service_mobile.dart pour ne pas dupliquer la logique.
// =============================================================
class NotificationRouter {
  static Future<void> ouvrir(Map<String, dynamic> data) async {
    final session = await SessionService.lire();
    if (session == null) return; // pas connecté, rien à ouvrir de précis

    final String tel  = session['tel'] ?? '';
    final String nom  = session['nom'] ?? '';
    final String role = session['role'] ?? 'client';
    if (tel.isEmpty) return;

    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final String type = (data['type'] ?? '').toString();

    // 🚨 Proposition de commande (dispatch Uber/Yango) : écran plein
    // écran Accepter/Refuser avec sonnerie, prioritaire sur tout le reste.
    if (type == 'proposition_commande' && data['proposition_id'] != null) {
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