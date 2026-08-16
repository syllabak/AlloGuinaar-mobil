import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕

// WebView importé seulement sur mobile
import 'tracking_map_mobile.dart'
    if (dart.library.html) 'tracking_map_stub.dart';

class TrackingScreen extends StatefulWidget {
  final int    cmdId;
  final String nomClient;
  const TrackingScreen({super.key, required this.cmdId, required this.nomClient});
  @override State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _tracking;
  Timer?                _timer;
  bool                  _loading = true;

  // Vrai uniquement sur Android et iOS
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _chargerTracking();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _chargerTracking());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _chargerTracking() async {
    final r = await ApiService.trackLivreur(widget.cmdId);
    if (r['status'] == 'success' && mounted) {
      setState(() { _tracking = r['data']; _loading = false; });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Color _couleurStatut(String s) {
    if (s == 'En route')        return Colors.blue;
    if (s == 'Livrée et payée') return Colors.green;
    if (s == 'Annulée')         return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final d          = _tracking;
    final statut     = d?['statut']      ?? 'En attente';
    final dist       = d?['distance_restante_km'];
    final livreur    = d?['livreur_nom'] ?? "Attribution en cours...";
    final livreurTel = d?['livreur_tel'] ?? '';
    final lLat       = d?['livreur_lat'];
    final lLng       = d?['livreur_lng'];
    final cLat       = d?['dest_lat'];
    final cLng       = d?['dest_lng'];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Suivi en temps réel",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
          Text("Cmd #${widget.cmdId}",
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
        actions: [
          Container(margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statut == 'Livrée et payée' ? Colors.green : const Color(0xFF8B0000),
              borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text("LIVE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
            ])),
          HomeNavigator.bouton(), // 🆕 retour à l'accueil à tout moment
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
        : Column(children: [

          // ── Zone carte ────────────────────────────────────────
          Expanded(flex: 3, child: _isMobile
            ? TrackingMapWidget(tracking: _tracking) // WebView Leaflet sur mobile
            : _carteWeb(lLat, lLng, cLat, cLng)),   // Alternative sur web/desktop

          // ── Infos livreur ─────────────────────────────────────
          Container(color: Colors.white, padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.two_wheeler, color: Color(0xFF8B0000), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(livreur,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(statut,
                    style: TextStyle(color: _couleurStatut(statut),
                      fontWeight: FontWeight.bold, fontSize: 11)),
                ])),
                if (dist != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(20)),
                  child: Text("$dist km",
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 13))),
              ]),

              if (livreurTel.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async => await launchUrl(Uri.parse("tel:$livreurTel")),
                  child: Container(width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.phone, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text("Appeler le livreur",
                        style: TextStyle(color: Colors.blue,
                          fontWeight: FontWeight.w900, fontSize: 12)),
                    ]))),
              ],

              const SizedBox(height: 16),
              _etapesLivraison(statut),
            ])),
        ]),
    );
  }

  // Carte alternative sur Chrome/Windows : boutons Google Maps
  Widget _carteWeb(lLat, lLng, cLat, cLng) {
    return Container(
      color: const Color(0xFFF4F7F9),
      child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.map_outlined,
              color: Color(0xFF8B0000), size: 40)),
          const SizedBox(height: 16),
          const Text("Carte disponible sur mobile",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          const Text("Installez l'app Android pour le suivi en temps réel",
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (lLat != null && lLng != null) ...[
            _boutonMaps("📍 Position du livreur", lLat, lLng, Colors.blue),
            const SizedBox(height: 10),
          ],
          if (cLat != null && cLng != null)
            _boutonMaps("🏠 Votre adresse de livraison", cLat, cLng, const Color(0xFF8B0000)),
        ]),
      )));
  }

  Widget _boutonMaps(String label, dynamic lat, dynamic lng, Color color) =>
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 48)),
      onPressed: () async => await launchUrl(
        Uri.parse("https://maps.google.com/?q=$lat,$lng"),
        mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
      label: Text(label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))));

  Widget _etapesLivraison(String statut) {
    final etapes = [
      {'label': 'Confirmée',       'key': 'En attente',              'icon': Icons.check_circle_outline},
      {'label': 'En préparation',  'key': 'En cours de préparation', 'icon': Icons.restaurant},
      {'label': 'Livreur assigné', 'key': 'Prête pour le livreur',   'icon': Icons.two_wheeler},
      {'label': 'En route',        'key': 'En route',                'icon': Icons.location_on},
      {'label': 'Livré ✅',         'key': 'Livrée et payée',         'icon': Icons.done_all},
    ];
    final idx = etapes.indexWhere((e) => e['key'] == statut);
    return Row(children: etapes.asMap().entries.map((entry) {
      final i = entry.key; final e = entry.value;
      final ok = idx >= 0 && i <= idx;
      return Expanded(child: Column(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
            color: ok ? const Color(0xFF8B0000) : Colors.grey.shade200,
            shape: BoxShape.circle),
          child: Icon(e['icon'] as IconData,
            color: ok ? Colors.white : Colors.grey, size: 14)),
        const SizedBox(height: 4),
        Text(e['label'] as String,
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold,
            color: ok ? const Color(0xFF8B0000) : Colors.grey),
          textAlign: TextAlign.center, maxLines: 2),
      ]));
    }).toList());
  }
}