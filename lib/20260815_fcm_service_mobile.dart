import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'notification_router.dart';

// =============================================================
//  FCM SERVICE — version définitive.
//
//  Règles suivies :
//   1. Firebase.initializeApp() n'est JAMAIS appelé ici pour l'isolate
//      principal — uniquement dans main.dart, avant tout le reste.
//   2. Un seul point d'écoute de FirebaseMessaging.onMessage et
//      onMessageOpenedApp dans TOUTE l'app — ici, nulle part ailleurs.
//   3. Chaque étape critique logge son résultat avec le préfixe "[FCM]".
//   4. 🆕 iOS UNIQUEMENT : attente explicite du jeton APNs natif avant
//      d'appeler getToken(). Sur iOS, contrairement à Android,
//      FirebaseMessaging.getToken() dépend du jeton APNs déjà délivré
//      par le système — juste après requestPermission(), ce jeton
//      n'est pas toujours encore disponible, et getToken() peut alors
//      renvoyer null silencieusement, sans qu'aucune erreur n'apparaisse
//      nulle part. Cette attente (avec réessais courts) élimine cette
//      fenêtre de course, sans aucun effet sur Android.
// =============================================================

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("[FCM][bg] Firebase déjà initialisé dans cet isolate (normal) : $e");
  }

  print("[FCM][bg] Message reçu app fermée — type=${message.data['type']}");

  if (message.data['type'] == 'proposition_commande') {
    try {
      await NotificationService.afficherAlerteUrgente(
        id: 9000,
        titre: message.data['titre'] ?? '🚨 Nouvelle commande à accepter !',
        corps: message.data['corps'] ?? 'Vous avez 2 minutes pour répondre.',
        payload: jsonEncode(message.data),
      );
      print("[FCM][bg] Alerte urgente affichée avec succès");
    } catch (e) {
      print("[FCM][bg] ERREUR affichage alerte urgente : $e");
    }
  }
}

class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialise = false;
  static int _idCompteur = 2000;

  /// 🆕 iOS uniquement : attend que le jeton APNs natif soit disponible,
  /// avec de courts réessais (10 x 500 ms = 5 s max). Sans effet sur
  /// Android (retourne immédiatement).
  static Future<void> _attendreApnsToken() async {
    if (!Platform.isIOS) return;
    for (int tentative = 1; tentative <= 10; tentative++) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null) {
        print("[FCM][iOS] Jeton APNs disponible après $tentative tentative(s)");
        return;
      }
      print("[FCM][iOS] Jeton APNs pas encore prêt (tentative $tentative/10) — nouvelle tentative dans 500 ms");
      await Future.delayed(const Duration(milliseconds: 500));
    }
    print("[FCM][iOS] ATTENTION : jeton APNs toujours indisponible après 5 s — getToken() risque de renvoyer null");
  }

  static Future<void> initialiser(String telephone) async {
    if (telephone.isEmpty) {
      print("[FCM] initialiser() annulé : téléphone vide");
      return;
    }
    if (_initialise) {
      print("[FCM] initialiser() ignoré : déjà initialisé");
      return;
    }
    _initialise = true;

    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      final permission = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false,
        criticalAlert: false, provisional: false,
      );
      print("[FCM] Permission : ${permission.authorizationStatus}");

      // 🆕 iOS uniquement — voir _attendreApnsToken() ci-dessus.
      await _attendreApnsToken();

      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        print("[FCM] ERREUR : getToken() n'a renvoyé aucun jeton pour $telephone");
      } else {
        print("[FCM] Jeton obtenu (${token.substring(0, 12)}...) — envoi au serveur pour $telephone");
        final res = await ApiService.saveFcmToken(telephone, token);
        print("[FCM] Réponse serveur save_fcm_token : $res");
      }

      _fcm.onTokenRefresh.listen((newToken) {
        print("[FCM] Jeton renouvelé — ré-enregistrement pour $telephone");
        ApiService.saveFcmToken(telephone, newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("[FCM] Message premier plan — type=${message.data['type']}");
        if (message.data['type'] == 'proposition_commande') {
          NotificationRouter.ouvrir(message.data);
          return;
        }
        final titre = message.notification?.title ?? 'Allo Guinaar';
        final corps = message.notification?.body ?? '';
        NotificationService.afficher(
          id: _idCompteur++,
          titre: titre,
          corps: corps,
          payload: jsonEncode(message.data),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("[FCM] Notification touchée (arrière-plan) — type=${message.data['type']}");
        NotificationRouter.ouvrir(message.data);
      });

      final messageInitial = await _fcm.getInitialMessage();
      if (messageInitial != null) {
        print("[FCM] App lancée depuis une notification — type=${messageInitial.data['type']}");
        NotificationRouter.ouvrir(messageInitial.data);
      }

      print("[FCM] Initialisation terminée avec succès pour $telephone");
    } catch (e, stack) {
      print("[FCM] ERREUR pendant l'initialisation pour $telephone : $e");
      print(stack);
      _initialise = false;
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      print("[FCM] getToken() a échoué : $e");
      return null;
    }
  }
}