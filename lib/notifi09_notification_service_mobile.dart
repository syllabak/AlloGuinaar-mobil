import 'dart:convert';
import 'dart:typed_data'; // 🆕 Int64List (motif de vibration)
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_router.dart'; // 🆕 ouverture de l'écran concerné au toucher

class NotificationService {
  static final _plugin   = FlutterLocalNotificationsPlugin();
  static bool _initialise = false;
  static const _androidIcon = '@mipmap/ic_launcher';

  // 🆕 Canal unique, haute importance + son — utilisé aussi bien par les
  // notifications locales que par celles reçues via FCM (même channel_id
  // envoyé côté serveur, voir helpers.php::envoyerFCM()).
  static const _channel = AndroidNotificationChannel(
    'alloguinaar_channel',
    'Allo Guinaar',
    description: 'Notifications de commandes, messages et alertes Allo Guinaar',
    importance: Importance.max,
    playSound: true,
  );

  // ── Initialisation ────────────────────────────────────────
  static Future<void> initialiser() async {
    if (_initialise) return;

    const android = AndroidInitializationSettings(_androidIcon);
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      // 🆕 Toucher une notification (locale ou FCM auto-affichée en arrière-
      // plan) → ouvrir l'écran concerné, plutôt que juste rouvrir l'app.
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          NotificationRouter.ouvrir(data);
        } catch (_) {
          // Ancien format (juste un id de commande en texte) — on
          // ignore proprement plutôt que de planter.
        }
      },
    );

    // 🆕 Créer explicitement le canal AVANT toute notification — sans
    // ça, le canal n'existait qu'après le premier appel à afficher(),
    // ce qui pouvait faire échouer silencieusement l'affichage (son et
    // priorité par défaut, voire notification ignorée) pour toute
    // notification FCM reçue avant ce premier appel.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    // 1. Demander explicitement la permission FCM (affichage précoce de
    // la demande, dès le démarrage de l'app — avant même la connexion).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🆕 CORRIGÉ (doublon de notifications) : l'écoute de
    // FirebaseMessaging.onMessage / onMessageOpenedApp a été retirée
    // d'ici. Ce service est initialisé dès le démarrage de l'app (avant
    // connexion), tandis que FcmService.initialiser() est appelé après
    // connexion et met en place sa propre écoute — les deux tournant en
    // parallèle une fois l'utilisateur connecté, CHAQUE notification
    // standard reçue au premier plan s'affichait deux fois, et un
    // toucher déclenchait la navigation deux fois. FcmService est
    // désormais l'unique point d'écoute pour tout ce qui vient de FCM ;
    // ce service continue de fournir l'affichage local (afficher(),
    // afficherAlerteUrgente()), le canal Android, et le polling de
    // statut (sauvegarderStatutsInitiaux/verifierChangementsStatut).

    _initialise = true;
  }

  // ── Afficher une notification ─────────────────────────────
  static Future<void> afficher({
    required int     id,
    required String titre,
    required String corps,
    String?         payload,
  }) async {
    if (!_initialise) await initialiser();

    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority:   Priority.max,
      icon:       _androidIcon,
      color:      const Color(0xFF8B0000),
      playSound:  true,
      enableVibration: true,
      fullScreenIntent: false,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      titre,
      corps,
      NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // 🆕 Canal dédié à l'alerte urgente (proposition de commande) — séparé
  // du canal standard pour que l'utilisateur puisse les distinguer dans
  // les réglages système, et pour que le fullScreenIntent ne s'applique
  // jamais aux notifications normales.
  static const _canalUrgent = AndroidNotificationChannel(
    'alloguinaar_urgent_channel',
    'Allo Guinaar — Commandes urgentes',
    description: 'Proposition de commande nécessitant une réponse rapide (façon appel entrant)',
    importance: Importance.max,
    playSound: true,
  );

  /// 🆕 Alerte plein écran façon appel entrant (WhatsApp/Yango) — utilisée
  /// uniquement pour la proposition de commande au producteur. Réveille
  /// l'écran et s'affiche par-dessus l'écran verrouillé quand le système
  /// l'autorise, même si l'app est totalement fermée. La sonnerie
  /// insistante/répétée elle-même est gérée par l'écran plein écran une
  /// fois ouvert (PropositionCommandeScreen, lecture audio en boucle) —
  /// un son de notification, lui, ne peut techniquement pas boucler au
  /// niveau du système.
  static Future<void> afficherAlerteUrgente({
    required int    id,
    required String titre,
    required String corps,
    String?         payload,
  }) async {
    if (!_initialise) await initialiser();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_canalUrgent);

    final android = AndroidNotificationDetails(
      _canalUrgent.id,
      _canalUrgent.name,
      channelDescription: _canalUrgent.description,
      importance: Importance.max,
      priority:   Priority.max,
      icon:       _androidIcon,
      color:      const Color(0xFF8B0000),
      playSound:  true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      fullScreenIntent: true, // 🆕 réveille l'écran, s'affiche par-dessus le verrouillage
      category: AndroidNotificationCategory.call, // 🆕 traité comme un appel entrant par le système
      visibility: NotificationVisibility.public, // visible sur écran verrouillé
      ongoing: true, // reste affichée tant qu'aucune action n'est prise
      autoCancel: false,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // 🆕 Fait passer la notification devant Ne pas déranger/Concentration,
      // sans nécessiter l'autorisation "Alertes critiques" (très restreinte,
      // accordée au cas par cas par Apple — hors de portée ici). C'est le
      // meilleur niveau d'insistance atteignable sans cette autorisation
      // spéciale.
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: android, iOS: ios);

    // 🆕 Sécurité obligatoire depuis Android 14 : USE_FULL_SCREEN_INTENT
    // est une permission spéciale, révoquée automatiquement par Google
    // Play à l'installation tant qu'une déclaration officielle
    // (Play Console → Contenu de l'app → usage Appel/Alarme) n'a pas été
    // complétée et approuvée. Sans cette précaution, tenter d'afficher
    // en plein écran sans la permission réellement accordée PEUT FAIRE
    // PLANTER L'APP. On retente donc sans fullScreenIntent en cas
    // d'échec — l'alerte reste très prioritaire (son fort, vibration,
    // visible sur écran verrouillé), juste sans réveiller l'écran tout
    // seul.
    try {
      await _plugin.show(id, titre, corps, details, payload: payload);
    } catch (e) {
      final androidSecours = AndroidNotificationDetails(
        _canalUrgent.id, _canalUrgent.name,
        channelDescription: _canalUrgent.description,
        importance: Importance.max, priority: Priority.max,
        icon: _androidIcon, color: const Color(0xFF8B0000),
        playSound: true, enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
        fullScreenIntent: false, // 🆕 repli sans plein écran
        visibility: NotificationVisibility.public,
      );
      await _plugin.show(id, titre, corps,
        NotificationDetails(android: androidSecours, iOS: ios), payload: payload);
    }
  }

  // ── Sauvegarder les statuts initiaux ─────────────────────
  static Future<void> sauvegarderStatutsInitiaux(String telephone) async {
    if (telephone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle   = 'commandes_statuts_$telephone';
      if (prefs.containsKey(cle)) return;

      final res = await ApiService.getMesCommandes(telephone);
      if (res['status'] != 'success') return;

      final Map<String, String> statuts = {};
      for (final cmd in (res['data'] ?? [])) {
        statuts[cmd['id'].toString()] = cmd['statut'] ?? '';
      }
      await prefs.setString(cle, jsonEncode(statuts));
    } catch (_) {}
  }

  // ── Vérifier les changements de statut ───────────────────
  static Future<void> verifierChangementsStatut(String telephone) async {
    if (telephone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle   = 'commandes_statuts_$telephone';

      final res = await ApiService.getMesCommandes(telephone);
      if (res['status'] != 'success') return;

      final List<dynamic> commandes = res['data'] ?? [];
      if (commandes.isEmpty) return;

      final String? jsonSauvegarde = prefs.getString(cle);
      final Map<String, String> anciensStatuts = jsonSauvegarde != null
          ? Map<String, String>.from(jsonDecode(jsonSauvegarde))
          : {};

      final Map<String, String> nouveauxStatuts = {};
      int notifId = 1000;

      for (final cmd in commandes) {
        final String id     = cmd['id'].toString();
        final String statut = cmd['statut'] ?? '';
        nouveauxStatuts[id] = statut;

        final String? ancien = anciensStatuts[id];
        if (ancien != null && ancien != statut) {
          await afficher(
            id:      notifId++,
            titre:   _titreNotif(statut),
            corps:   _corpsNotif(statut, id, cmd['classe_poids'] ?? ''),
            payload: jsonEncode({'id': id}),
          );
        }
      }

      await prefs.setString(cle, jsonEncode(nouveauxStatuts));
    } catch (_) {}
  }

  static String _titreNotif(String statut) {
    switch (statut) {
      case 'En cours de préparation': return '🍗 Votre commande est en préparation';
      case 'En route':                return '🚚 Votre commande est en route !';
      case 'Livrée et payée':         return '✅ Commande livrée et payée !';
      case 'Annulée':                 return '❌ Commande annulée';
      case 'Prête pour le livreur':   return '📦 Commande prête !';
      default:                        return 'Allo Guinaar — Mise à jour';
    }
  }

  static String _corpsNotif(String statut, String cmdId, String articles) {
    final r = articles.length > 40 ? articles.substring(0, 40) + '...' : articles;
    switch (statut) {
      case 'En cours de préparation': return 'Cmd #$cmdId • $r\nEn cours de préparation.';
      case 'En route':                return 'Cmd #$cmdId • $r\nLe livreur est en chemin.';
      case 'Livrée et payée':         return 'Cmd #$cmdId • Merci ! Votre facture est disponible.';
      case 'Annulée':                 return 'Cmd #$cmdId a été annulée.';
      case 'Prête pour le livreur':   return 'Cmd #$cmdId • En attente du livreur.';
      default:                        return 'Cmd #$cmdId — Statut : $statut';
    }
  }
}