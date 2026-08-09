import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'firebase_options.dart';       // 🆕 CORRIGÉ : options explicites (voir plus bas)
import 'notification_service.dart';   // 🆕 affichage effectif au premier plan
import 'notification_router.dart';    // 🆕 ouverture de l'écran concerné au toucher

// Handler arrière-plan — doit être une fonction top-level (hors classe).
// Tourne dans un ISOLATE SÉPARÉ créé par le système (app fermée) : il ne
// partage rien avec l'initialisation faite dans main.dart, donc il a
// réellement besoin de son propre Firebase.initializeApp(). 🆕 CORRIGÉ :
// options explicites + try/catch — sans les options, l'initialisation
// dépend uniquement de la config native (google-services.json côté
// Android), absente ou incomplète selon l'appareil ; sans le try/catch,
// un échec ici empêchait silencieusement toute alerte plein écran de
// s'afficher app fermée, sans laisser aucune trace exploitable.
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // App Firebase déjà initialisée dans cet isolate (peut arriver si le
    // système réutilise l'isolate) — pas une vraie erreur, on continue.
  }

  // 🆕 CORRIGÉ : ce gestionnaire ne faisait rien avant — ce qui
  // empêchait l'alerte plein écran façon appel entrant de fonctionner
  // quand l'app était totalement fermée (le cas le plus important pour
  // la proposition de commande, puisqu'un producteur n'a pas forcément
  // l'app ouverte en permanence). Ne concerne QUE ce type de message —
  // envoyé volontairement en "données pures" (voir
  // helpers.php::envoyerFCMAppelEntrant()) pour que ce gestionnaire soit
  // systématiquement déclenché par Android, même app fermée. Tous les
  // autres types de notification continuent d'utiliser un message avec
  // bloc "notification", auto-affiché normalement par le système —
  // aucun changement de comportement pour eux.
  if (message.data['type'] == 'proposition_commande') {
    await NotificationService.afficherAlerteUrgente(
      id: 9000, // plage dédiée, distincte de toutes les autres notifications
      titre: message.data['titre'] ?? '🚨 Nouvelle commande à accepter !',
      corps: message.data['corps'] ?? 'Vous avez 2 minutes pour répondre.',
      payload: jsonEncode(message.data),
    );
  }
}

class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialise = false;
  static int _idCompteur = 2000; // plage dédiée, distincte du polling de statut (1000+)

  static Future<void> initialiser(String telephone) async {
    if (telephone.isEmpty || _initialise) return;

    // 🆕 CORRIGÉ — cause racine probable de "le jeton FCM n'est jamais
    // enregistré après connexion" : Firebase.initializeApp() était
    // rappelé ICI, alors que main.dart l'a déjà fait une première fois
    // au tout démarrage de l'app (avant même l'écran de connexion). Un
    // second appel sur l'app par défaut ("[DEFAULT]") peut lever une
    // exception "duplicate-app" selon la plateforme/version du plugin.
    // Comme les 4 appels à FcmService.initialiser() depuis
    // login_screen.dart ne sont ni "await"-és ni entourés d'un
    // try/catch (volontairement, pour ne pas bloquer l'écran de
    // connexion), cette exception partait alors totalement en silence —
    // et TOUT le reste de cette méthode (permission, récupération du
    // jeton, enregistrement serveur, écoute des messages) ne s'exécutait
    // jamais. Plus besoin de réinitialiser Firebase ici : c'est déjà
    // fait avant que cet écran soit même atteignable.
    _initialise = true;

    // 🆕 CORRIGÉ : tout le corps ci-dessous est désormais protégé par un
    // seul try/catch englobant. Avant, la moindre exception au milieu de
    // cette méthode (permission refusée par le système, jeton
    // indisponible, etc.) l'interrompait en plein milieu SANS laisser de
    // trace — impossible de distinguer "l'utilisateur n'a pas de jeton"
    // de "une erreur a coupé le processus avant même d'essayer". Chaque
    // échec est maintenant tracé, et surtout _initialise repasse à false
    // pour qu'une nouvelle tentative soit possible à la prochaine
    // connexion plutôt que de rester bloqué en silence pour toujours.
    try {
      // Handler arrière-plan
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      // Demander la permission (Android 13+ et iOS)
      await _fcm.requestPermission(
        alert:        true,
        badge:        true,
        sound:        true,
        announcement: false,
        carPlay:      false,
        criticalAlert: false,
        provisional:  false,
      );

      // 🆕 CORRIGÉ — cause racine confirmée par les données réelles à
      // plusieurs reprises : sur 102 comptes producteurs réels, un seul
      // avait un jeton enregistré. La cause : ce code s'arrêtait
      // complètement si la permission n'était pas accordée, AVANT même de
      // tenter d'obtenir le jeton. Or sur Android, un jeton peut très
      // souvent être obtenu même sans permission accordée (la permission
      // ne conditionne que l'AFFICHAGE des notifications, pas l'obtention
      // du jeton lui-même). On tente donc désormais l'enregistrement dans
      // tous les cas — un utilisateur qui accorde la permission plus tard
      // (réglages système) profite immédiatement d'un jeton déjà en place.

      // Récupérer le token FCM et l'envoyer au serveur
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.saveFcmToken(telephone, token);
      } else {
        // ignore: avoid_print
        print("[FCM] Aucun jeton obtenu pour $telephone — rien à enregistrer.");
      }

      // Mettre à jour le token si Firebase le renouvelle
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(telephone, newToken);
      });

      // 🆕 CORRIGÉ : au premier plan, Android/iOS n'affichent JAMAIS une
      // notification système automatiquement pour un message FCM reçu —
      // c'est à l'app de le faire (contrairement à ce que laissait croire
      // le commentaire précédent). Sans ce correctif, toute notification
      // reçue pendant que l'app était ouverte était totalement silencieuse.
      //
      // 🆕 CORRIGÉ (doublon) : c'est désormais l'UNIQUE écoute de
      // FirebaseMessaging.onMessage / onMessageOpenedApp dans toute
      // l'app — notification_service_mobile.dart avait sa propre écoute
      // en parallèle (mise en place dès le démarrage, avant connexion),
      // ce qui faisait apparaître CHAQUE notification standard deux fois
      // dès qu'un utilisateur était connecté, et déclenchait la
      // navigation en double au toucher. Un seul point d'écoute, ici,
      // qui gère aussi bien la proposition de commande prioritaire que
      // toutes les autres notifications.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // 🆕 Proposition de commande (dispatch Uber/Yango) : priorité
        // absolue — ouvrir directement l'écran plein écran plutôt que
        // d'afficher une simple notification à toucher, l'app étant déjà
        // ouverte. Le délai de réponse est court (2 min), chaque seconde
        // compte.
        if (message.data['type'] == 'proposition_commande') {
          NotificationRouter.ouvrir(message.data);
          return;
        }
        final titre = message.notification?.title ?? 'Allo Guinaar';
        final corps = message.notification?.body  ?? '';
        NotificationService.afficher(
          id: _idCompteur++,
          titre: titre,
          corps: corps,
          payload: _encoderPayload(message.data),
        );
      });

      // 🆕 Toucher une notification FCM auto-affichée par le système
      // (app en arrière-plan) → ouvrir l'écran concerné.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        NotificationRouter.ouvrir(message.data);
      });

      // 🆕 App lancée DEPUIS une notification (elle était totalement
      // fermée) → même routage, une fois le premier écran affiché.
      final messageInitial = await _fcm.getInitialMessage();
      if (messageInitial != null) {
        NotificationRouter.ouvrir(messageInitial.data);
      }
    } catch (e) {
      // ignore: avoid_print
      print("[FCM] Echec de l'initialisation pour $telephone : $e");
      _initialise = false; // permet une nouvelle tentative à la prochaine connexion
    }
  }

  static String _encoderPayload(Map<String, dynamic> data) => jsonEncode(data);

  static Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }
}