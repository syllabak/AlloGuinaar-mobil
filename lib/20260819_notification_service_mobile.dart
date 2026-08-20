import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '20260817_notification_router.dart';

// =============================================================
//  NOTIFICATION SERVICE — réécrit à neuf.
//
//  Rôle de ce fichier, et UNIQUEMENT ce rôle :
//   - affichage des notifications locales (canal standard + canal
//     urgent façon appel entrant) ;
//   - polling de statut de commande (fallback indépendant du push,
//     inchangé) ;
//   - demande précoce de la permission de notification, au tout
//     démarrage de l'app.
//
//  Ce fichier n'écoute PLUS FirebaseMessaging.onMessage ni
//  onMessageOpenedApp — cette écoute est centralisée dans
//  fcm_service_mobile.dart pour éviter les notifications en double
//  constatées précédemment (les deux fichiers écoutaient les mêmes
//  flux en parallèle une fois l'utilisateur connecté).
// =============================================================
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialise = false;
  static const _androidIcon = '@mipmap/ic_launcher';

  static const _channel = AndroidNotificationChannel(
    'alloguinaar_channel',
    'Allo Guinaar',
    description: 'Notifications de commandes, messages et alertes Allo Guinaar',
    importance: Importance.max,
    playSound: true,
  );

  static const _canalUrgent = AndroidNotificationChannel(
    'alloguinaar_urgent_channel',
    'Allo Guinaar — Commandes urgentes',
    description: 'Proposition de commande nécessitant une réponse rapide (façon appel entrant)',
    importance: Importance.max,
    playSound: true,
  );

  // ── Initialisation ────────────────────────────────────────
  static Future<void> initialiser() async {
    if (_initialise) return;

    try {
      const android = AndroidInitializationSettings(_androidIcon);
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (details) {
          final payload = details.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            NotificationRouter.ouvrir(data);
          } catch (_) {
            // Ancien format (juste un id de commande en texte) — ignoré
            // proprement plutôt que de planter.
          }
        },
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.createNotificationChannel(_canalUrgent);
      final granted = await androidPlugin?.requestNotificationsPermission();
      print("[Notif] Permission notifications locales (Android) : $granted");

      // Demande précoce de la permission FCM, dès le démarrage de l'app
      // (avant même la connexion) — n'écoute rien, ne fait que demander.
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      print("[Notif] Permission FCM (précoce) : ${permission.authorizationStatus}");

      _initialise = true;
      print("[Notif] Initialisation locale terminée avec succès");
    } catch (e, stack) {
      print("[Notif] ERREUR pendant l'initialisation : $e");
      print(stack);
    }
  }

  // ── Afficher une notification standard ──────────────────────
  static Future<void> afficher({
    required int id,
    required String titre,
    required String corps,
    String? payload,
  }) async {
    if (!_initialise) await initialiser();

    final android = AndroidNotificationDetails(
      _channel.id, _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max, priority: Priority.max,
      icon: _androidIcon, color: const Color(0xFF8B0000),
      playSound: true, enableVibration: true,
      fullScreenIntent: false,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );

    try {
      await _plugin.show(id, titre, corps,
          NotificationDetails(android: android, iOS: ios), payload: payload);
      print("[Notif] Affichée (id=$id) : $titre");
    } catch (e) {
      print("[Notif] ERREUR affichage (id=$id) : $e");
    }
  }

  /// Alerte plein écran façon appel entrant (WhatsApp/Yango) — utilisée
  /// uniquement pour la proposition de commande au producteur. La
  /// sirène en boucle elle-même est jouée par PropositionCommandeScreen
  /// via audioplayers (un son de notification système ne peut pas
  /// boucler) — cette méthode ne fait que réveiller l'écran et afficher
  /// l'alerte visuelle/vibratoire.
  static Future<void> afficherAlerteUrgente({
    required int id,
    required String titre,
    required String corps,
    String? payload,
  }) async {
    if (!_initialise) await initialiser();

    final android = AndroidNotificationDetails(
      _canalUrgent.id, _canalUrgent.name,
      channelDescription: _canalUrgent.description,
      importance: Importance.max, priority: Priority.max,
      icon: _androidIcon, color: const Color(0xFF8B0000),
      playSound: true, enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: android, iOS: ios);

    try {
      await _plugin.show(id, titre, corps, details, payload: payload);
      print("[Notif] Alerte urgente affichée (id=$id)");
    } catch (e) {
      // USE_FULL_SCREEN_INTENT peut être révoquée par Google Play tant
      // qu'une déclaration officielle n'a pas été validée (Play Console
      // → Contenu de l'app → usage Appel/Alarme). On retente sans, pour
      // que l'alerte reste sonore/vibrante même sans réveiller l'écran.
      print("[Notif] fullScreenIntent refusé, repli sans plein écran : $e");
      final androidSecours = AndroidNotificationDetails(
        _canalUrgent.id, _canalUrgent.name,
        channelDescription: _canalUrgent.description,
        importance: Importance.max, priority: Priority.max,
        icon: _androidIcon, color: const Color(0xFF8B0000),
        playSound: true, enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
        fullScreenIntent: false,
        visibility: NotificationVisibility.public,
      );
      try {
        await _plugin.show(id, titre, corps,
            NotificationDetails(android: androidSecours, iOS: ios), payload: payload);
      } catch (e2) {
        print("[Notif] ERREUR alerte urgente (repli inclus) : $e2");
      }
    }
  }

  // ── Polling de statut (fallback indépendant du push, inchangé) ──
  static Future<void> sauvegarderStatutsInitiaux(String telephone) async {
    if (telephone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle = 'commandes_statuts_$telephone';
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

  static Future<void> verifierChangementsStatut(String telephone) async {
    if (telephone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle = 'commandes_statuts_$telephone';

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
        final String id = cmd['id'].toString();
        final String statut = cmd['statut'] ?? '';
        nouveauxStatuts[id] = statut;

        final String? ancien = anciensStatuts[id];
        if (ancien != null && ancien != statut) {
          await afficher(
            id: notifId++,
            titre: _titreNotif(statut),
            corps: _corpsNotif(statut, id, cmd['classe_poids'] ?? ''),
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
      case 'En route': return '🚚 Votre commande est en route !';
      case 'Livrée et payée': return '✅ Commande livrée et payée !';
      case 'Annulée': return '❌ Commande annulée';
      case 'Prête pour le livreur': return '📦 Commande prête !';
      default: return 'Allo Guinaar — Mise à jour';
    }
  }

  static String _corpsNotif(String statut, String cmdId, String articles) {
    final r = articles.length > 40 ? articles.substring(0, 40) + '...' : articles;
    switch (statut) {
      case 'En cours de préparation': return 'Cmd #$cmdId • $r\nEn cours de préparation.';
      case 'En route': return 'Cmd #$cmdId • $r\nLe livreur est en chemin.';
      case 'Livrée et payée': return 'Cmd #$cmdId • Merci ! Votre facture est disponible.';
      case 'Annulée': return 'Cmd #$cmdId a été annulée.';
      case 'Prête pour le livreur': return 'Cmd #$cmdId • En attente du livreur.';
      default: return 'Cmd #$cmdId — Statut : $statut';
    }
  }
}
