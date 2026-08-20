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
  // 🆕 DIAGNOSTIC — le reste de cette fonction n'utilisait que print(),
  // invisible sans câble ADB branché au moment précis de la réception
  // (impossible à réaliser écran verrouillé). ApiService.debugLog()
  // envoie la ligne aux logs OVH, consultable après coup. C'est la
  // toute première ligne exécutée : si elle n'apparaît jamais dans les
  // logs pour un test donné, ça veut dire qu'Android/Samsung a empêché
  // cet isolate de démarrer — pas un bug dans notre code.
  ApiService.debugLog("[bg-Android] Handler déclenché — type=${message.data['type']}");

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("[FCM][bg] Firebase déjà initialisé dans cet isolate (normal) : $e");
  }

  print("[FCM][bg] Message reçu app fermée — type=${message.data['type']}");

  if (message.data['type'] == 'proposition_commande') {
    ApiService.debugLog("[bg-Android] type=proposition_commande — appel afficherAlerteUrgente()");
    try {
      await NotificationService.afficherAlerteUrgente(
        id: 9000,
        titre: message.data['titre'] ?? '🚨 Nouvelle commande à accepter !',
        corps: message.data['corps'] ?? 'Vous avez 2 minutes pour répondre.',
        payload: jsonEncode(message.data),
      );
      print("[FCM][bg] Alerte urgente affichée avec succès");
      ApiService.debugLog("[bg-Android] afficherAlerteUrgente() terminé SANS exception");
    } catch (e) {
      print("[FCM][bg] ERREUR affichage alerte urgente : $e");
      ApiService.debugLog("[bg-Android] EXCEPTION afficherAlerteUrgente() : $e");
    }
  } else {
    ApiService.debugLog("[bg-Android] type ignoré (pas proposition_commande) — rien affiché");
  }
}

class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialise = false;
  static int _idCompteur = 2000;

  // Reinitialise a la deconnexion (voir SessionService.supprimer()) —
  // sans ca, un changement de compte sur le meme appareil sans fermer
  // l'app pouvait laisser le nouveau compte sans jeton FCM enregistre.
  static void reset() {
    _initialise = false;
  }

  /// 🆕 iOS uniquement : attend que le jeton APNs natif soit disponible,
  /// avec des réessais plus longs (30 x 1s = 30s max). Sans effet sur
  /// Android (retourne immédiatement).
  ///
  /// 🆕 CORRIGÉ — 5 secondes (l'ancienne limite) se sont révélées
  /// insuffisantes en conditions réelles : le log serveur a montré
  /// l'exception exacte "[firebase_messaging/apns-token-not-set] APNS
  /// token has not been set yet" survenant systématiquement juste après
  /// l'ancien délai de 5s. iOS peut légitimement mettre plus de temps à
  /// livrer ce jeton selon la qualité réseau au moment précis de la
  /// connexion — 30s couvre une bien plus large majorité de cas, sans
  /// bloquer l'app pour autant (ça tourne en arrière-plan de
  /// l'initialisation, pas devant l'utilisateur).
  static Future<void> _attendreApnsToken() async {
    if (!Platform.isIOS) return;
    for (int tentative = 1; tentative <= 30; tentative++) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null) {
        print("[FCM][iOS] Jeton APNs disponible après $tentative tentative(s)");
        ApiService.debugLog("Jeton APNs disponible après $tentative tentative(s)");
        return;
      }
      if (tentative == 1 || tentative % 5 == 0) {
        print("[FCM][iOS] Jeton APNs pas encore prêt (tentative $tentative/30)");
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    print("[FCM][iOS] ATTENTION : jeton APNs toujours indisponible après 30s");
    ApiService.debugLog("ÉCHEC — jeton APNs jamais reçu après 30s d'attente");
  }

  static Future<void> initialiser(String telephone) async {
    // 🆕 DIAGNOSTIC TEMPORAIRE — toute la fonction ci-dessous. Sert à
    // savoir si initialiser() est ne serait-ce qu'atteinte, et jusqu'où
    // elle va, sans console Xcode disponible. Chaque ligne "debugLog"
    // envoie un message au serveur (visible dans HTTP error logs, préfixe
    // [FCM][iOS-diag]) — à retirer une fois le blocage identifié.
    ApiService.debugLog("initialiser() appelée, telephone='$telephone'");

    if (telephone.isEmpty) {
      print("[FCM] initialiser() annulé : téléphone vide");
      ApiService.debugLog("ANNULÉ — téléphone vide");
      return;
    }
    if (_initialise) {
      print("[FCM] initialiser() ignoré : déjà initialisé");
      ApiService.debugLog("IGNORÉ — déjà initialisé (_initialise=true)");
      return;
    }
    _initialise = true;
    ApiService.debugLog("_initialise passé à true, entrée dans le try");

    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
      ApiService.debugLog("onBackgroundMessage enregistré, avant requestPermission");

      final permission = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false,
        criticalAlert: false, provisional: false,
      );
      print("[FCM] Permission : ${permission.authorizationStatus}");
      ApiService.debugLog("Permission obtenue : ${permission.authorizationStatus}");

      // 🆕 iOS uniquement — voir _attendreApnsToken() ci-dessus.
      await _attendreApnsToken();
      ApiService.debugLog("Retour de _attendreApnsToken(), avant getToken()");

      // 🆕 CORRIGÉ — getToken() peut encore lever
      // "apns-token-not-set" juste après la fenêtre d'attente, dans de
      // rares cas de course résiduelle. Trois réessais courts
      // supplémentaires ici évitent de faire échouer TOUTE
      // l'initialisation (y compris les écoutes onMessage plus bas,
      // pourtant sans rapport) pour un problème de timing qui se
      // résout généralement en quelques secondes de plus.
      String? token;
      for (int essai = 1; essai <= 3; essai++) {
        try {
          token = await _fcm.getToken();
          break;
        } catch (e) {
          print("[FCM] getToken() essai $essai/3 a échoué : $e");
          if (essai == 3) rethrow;
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      if (token == null || token.isEmpty) {
        print("[FCM] ERREUR : getToken() n'a renvoyé aucun jeton pour $telephone");
        ApiService.debugLog("getToken() a renvoyé NULL ou vide");
      } else {
        print("[FCM] Jeton obtenu (${token.substring(0, 12)}...) — envoi au serveur pour $telephone");
        ApiService.debugLog("Jeton obtenu (${token.substring(0, 12)}...) — appel saveFcmToken");
        final res = await ApiService.saveFcmToken(telephone, token);
        print("[FCM] Réponse serveur save_fcm_token : $res");
        ApiService.debugLog("Réponse saveFcmToken : $res");
      }

      _fcm.onTokenRefresh.listen((newToken) {
        print("[FCM] Jeton renouvelé — ré-enregistrement pour $telephone");
        ApiService.saveFcmToken(telephone, newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("[FCM] Message premier plan — type=${message.data['type']}");
        // 🆕 DIAGNOSTIC TEMPORAIRE — jamais tracé jusqu'ici : c'était un
        // vrai angle mort. Sans cette ligne, impossible de savoir si le
        // message arrive réellement jusqu'à l'app (auquel cas le
        // problème serait dans NotificationRouter.ouvrir()) ou s'il
        // n'arrive jamais du tout sur le téléphone malgré l'envoi
        // confirmé côté serveur (auquel cas le problème serait entre
        // Firebase et APNs/le téléphone, invisible depuis nos propres
        // logs serveur).
        ApiService.debugLog("onMessage REÇU — type=${message.data['type']}, data=${message.data}");
        if (message.data['type'] == 'proposition_commande') {
          ApiService.debugLog("Appel de NotificationRouter.ouvrir() pour proposition_commande");
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
      ApiService.debugLog("Initialisation TERMINÉE AVEC SUCCÈS");
    } catch (e, stack) {
      print("[FCM] ERREUR pendant l'initialisation pour $telephone : $e");
      print(stack);
      ApiService.debugLog("EXCEPTION attrapée : $e");
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