import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'publicite_overlay.dart';
import 'package:flutter/material.dart';

// =============================================================
//  SERVICE PUBLICITÉS — Lot 10
//  Limite d'affichage : 3 fois par tranche de 24h, gérée entièrement
//  en local (SharedPreferences) — pas d'appel serveur supplémentaire
//  à chaque affichage. Une publicité déjà vue 3 fois dans les
//  dernières 24h n'est simplement pas proposée à nouveau.
// =============================================================
class PubliciteService {
  // 🆕 DÉSACTIVÉ TEMPORAIREMENT — repasser à true pour réactiver les
  // publicités. Rien d'autre à toucher, tout le reste du fichier reste
  // inchangé et prêt à fonctionner normalement dès que c'est remis à true.
  static const bool _publicitesActivees = false;

  static const _cle = 'publicite_vues'; // { "12": ["2026-07-25T10:00:00Z", ...], ... }
  static const int _maxVuesParJour = 3;
  static const Duration _fenetre = Duration(hours: 24);

  /// Vérifie s'il y a une publicité active et éligible (pas déjà vue
  /// 3 fois dans les dernières 24h), et l'affiche en superposition si
  /// c'est le cas. À appeler après le premier rendu de l'écran
  /// d'accueil (post-frame), pour ne pas bloquer le lancement de l'app.
  static Future<void> verifierEtAfficher(BuildContext context, String telephone) async {
    if (!_publicitesActivees) return;
    try {
      final r = await ApiService.publicitesActives(telephone);
      if (r['status'] != 'success') return;
      final List<dynamic> pubs = r['data'] ?? [];
      if (pubs.isEmpty) return;

      final vues = await _chargerVues();
      _nettoyerVuesExpirees(vues);

      for (final pub in pubs) {
        final id = pub['id'].toString();
        final historique = vues[id] ?? [];
        if (historique.length < _maxVuesParJour) {
          await _enregistrerVue(id, vues);
          if (!context.mounted) return;
          showDialog(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black87,
            builder: (_) => PubliciteOverlay(publicite: pub),
          );
          return; // une seule pub affichée à la fois
        }
      }
    } catch (_) {
      // Silencieux : une publicité qui ne charge pas ne doit jamais
      // bloquer ou perturber l'usage normal de l'app.
    }
  }

  static Future<Map<String, List<String>>> _chargerVues() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle);
    if (brut == null) return {};
    try {
      final Map<String, dynamic> decode = jsonDecode(brut);
      return decode.map((k, v) => MapEntry(k, List<String>.from(v)));
    } catch (_) {
      return {};
    }
  }

  static void _nettoyerVuesExpirees(Map<String, List<String>> vues) {
    final maintenant = DateTime.now();
    vues.forEach((id, dates) {
      dates.removeWhere((d) {
        final dt = DateTime.tryParse(d);
        if (dt == null) return true;
        return maintenant.difference(dt) > _fenetre;
      });
    });
  }

  static Future<void> _enregistrerVue(String id, Map<String, List<String>> vues) async {
    vues.putIfAbsent(id, () => []).add(DateTime.now().toIso8601String());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(vues));
  }
}