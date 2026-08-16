import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'session_service.dart';
import 'tracking_screen.dart';
import 'publicite_service.dart'; // 🆕 Lot 10
import 'parametres_screen.dart'; // 🆕 Paramètres
import 'login_screen.dart';

class LivreurScreen extends StatefulWidget {
  final String telephone;
  final String nom;
  const LivreurScreen({super.key, required this.telephone, required this.nom});
  @override State<LivreurScreen> createState() => _LivreurScreenState();
}

class _LivreurScreenState extends State<LivreurScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;

  // ── Statut et missions ──────────────────────────────────────
  bool          _disponible      = false;
  bool          _loading         = true;
  bool          _toggling        = false;
  List<dynamic> _missions        = [];
  List<dynamic> _missionsProches = [];

  // ── GPS ─────────────────────────────────────────────────────
  Timer?  _positionTimer;
  double? _myLat, _myLng;

  // ── Mon compte / invitations ─────────────────────────────────
  Map<String, dynamic>? _infosCompte;
  String? _errorCompte;
  bool _loadingCompte = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _chargerMissions();
    _chargerInfosCompte();
    _demarrerGPS();
    // 🆕 Lot 10 : vérifier les publicités actives (rôle livreur)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🆕 Réactivé : testé sans les publicités, l'écran noir persistait
      // quand même — cause écartée.
      if (mounted) PubliciteService.verifierEtAfficher(context, widget.telephone);
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Chargement complet (init + pull-to-refresh) ─────────────
  // Lit aussi _disponible depuis le serveur
  Future<void> _chargerMissions() async {
    final r = await ApiService.mesMissions(widget.telephone);
    if (mounted) setState(() {
      _missions   = r['data'] ?? [];
      _disponible = r['livreur_statut'] == 'disponible';
      _loading    = false;
    });
  }

  // ── Rechargement missions SEULEMENT (après toggle/action) ───
  // Ne touche PAS à _disponible — évite d'écraser l'état local
  Future<void> _rechargerMissionsSeulement() async {
    final r = await ApiService.mesMissions(widget.telephone);
    if (mounted) setState(() {
      _missions = r['data'] ?? [];
      // _disponible intentionnellement NON modifié ici
    });
  }

  Future<void> _chargerInfosCompte() async {
    setState(() => _loadingCompte = true);
    final r = await ApiService.getInfosClient(widget.telephone);
    if (mounted) setState(() {
      if (r['status'] == 'success' && r['data'] != null) {
        _infosCompte  = r['data'];
        _errorCompte  = null;
      } else {
        _infosCompte  = null;
        _errorCompte  = r['message']?.toString() ?? 'Erreur inconnue';
      }
      _loadingCompte = false;
    });
  }

  // ── GPS toutes les 5s ──────────────────────────────────────
  void _demarrerGPS() async {
    bool ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) return;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _myLat = pos.latitude; _myLng = pos.longitude;
    } catch (_) {}
    _positionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_disponible) return;
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _myLat = pos.latitude; _myLng = pos.longitude;
        final r = await ApiService.livreurPosition(widget.telephone, pos.latitude, pos.longitude);
        if (mounted && (r['missions'] as List?)?.isNotEmpty == true) {
          setState(() => _missionsProches = r['missions']);
        }
      } catch (_) {}
    });
  }

  // ════════════════════════════════════════════════════════════
  //  TOGGLE — FIX PRINCIPAL
  //  On calcule le nouveau statut AVANT l'appel API, et on
  //  l'applique directement sans relire le serveur.
  //  On appelle _rechargerMissionsSeulement (pas _chargerMissions)
  //  pour ne pas écraser _disponible.
  // ════════════════════════════════════════════════════════════
  Future<void> _toggleDisponibilite() async {
    final nouveauStatut = _disponible ? 'hors_ligne' : 'disponible';
    setState(() => _toggling = true);

    final r = await ApiService.livreurToggle(
      telephone: widget.telephone,
      statut:    nouveauStatut,
      lat: _myLat,
      lng: _myLng,
    );

    if (mounted) setState(() {
      _toggling = false;
      if (r['status'] == 'success') {
        _disponible = (nouveauStatut == 'disponible');
        if (!_disponible) _missionsProches = [];
      } else {
        _snack(r['message'] ?? 'Erreur — réessayez', false);
      }
    });

    // Recharger les missions sans toucher à _disponible
    if (_disponible) _rechargerMissionsSeulement();
  }

  Future<void> _accepterMission(int cmdId, double? fLat, double? fLng) async {
    final r = await ApiService.livreurRepondre(
        telephone: widget.telephone, cmdId: cmdId, action: 'accepter');
    if (mounted) {
      _snack(r['message'] ?? '', r['status'] == 'success');
      if (r['status'] == 'success') {
        _rechargerMissionsSeulement();
        if (fLat != null && fLng != null) {
          await launchUrl(Uri.parse("https://maps.google.com/?q=$fLat,$fLng"),
              mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Future<void> _marquerLivre(int cmdId) async {
    final r = await ApiService.updateStatut(cmdId: cmdId, statut: 'Livrée et payée');
    if (mounted) {
      _snack(r['message'] ?? '', r['status'] == 'success');
      if (r['status'] == 'success') _rechargerMissionsSeulement();
    }
  }

  Future<void> _deconnecter() async {
    await ApiService.livreurToggle(telephone: widget.telephone, statut: 'hors_ligne');
    await SessionService.supprimer();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Color _couleurStatut(String s) {
    if (s == 'En route')        return Colors.blue;
    if (s == 'Livrée et payée') return Colors.green;
    if (s == 'Annulée')         return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Espace Livreur",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(widget.nom,
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: () { _chargerMissions(); _chargerInfosCompte(); }),
          // 🆕 Paramètres (inclut la déconnexion — bouton retiré d'ici
          // pour éviter le doublon signalé par l'utilisateur)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            tooltip: "Paramètres",
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ParametresScreen(telephone: widget.telephone, nom: widget.nom))),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF8B0000),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B0000),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.two_wheeler, size: 18), text: "Missions"),
            Tab(icon: Icon(Icons.person_outline, size: 18), text: "Mon Compte"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : TabBarView(controller: _tabCtrl, children: [_tabMissions(), _tabMonCompte()]),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ONGLET 1 — MISSIONS
  // ════════════════════════════════════════════════════════════
  Widget _tabMissions() {
    final enCours = _missions.where((m) =>
        m['statut'] != 'Livrée et payée' && m['statut'] != 'Annulée').toList();
    final hist = _missions.where((m) =>
        m['statut'] == 'Livrée et payée' || m['statut'] == 'Annulée').toList();

    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerMissions,
      child: ListView(padding: const EdgeInsets.all(16), children: [

        // Toggle
        _cardToggle(),
        const SizedBox(height: 20),

        // Missions disponibles proches
        if (_disponible && _missionsProches.isNotEmpty) ...[
          _sectionTitre("MISSIONS DISPONIBLES", Colors.orange),
          ..._missionsProches.map((m) => _carteNouvellesMission(m)),
          const SizedBox(height: 16),
        ],

        // En cours
        _sectionTitre("MES MISSIONS EN COURS", const Color(0xFF8B0000)),
        if (enCours.isEmpty) _vide("Aucune mission en cours")
        else ...enCours.map((m) => _carteMission(m, enCours: true)),
        const SizedBox(height: 16),

        // Historique
        _sectionTitre("HISTORIQUE DES LIVRAISONS", Colors.grey),
        if (hist.isEmpty) _vide("Aucune livraison effectuée")
        else ...hist.map((m) => _carteMission(m, enCours: false)),
      ]),
    );
  }

  Widget _cardToggle() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: _disponible
          ? [Colors.green.shade600, Colors.green.shade800]
          : [Colors.grey.shade600, Colors.grey.shade800]),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
          color: (_disponible ? Colors.green : Colors.grey).withOpacity(0.4),
          blurRadius: 15, offset: const Offset(0, 6))]),
    child: Row(children: [
      Container(width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(_disponible ? Icons.two_wheeler : Icons.bedtime_outlined,
              color: Colors.white, size: 28)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_disponible ? "VOUS ÊTES DISPONIBLE" : "HORS LIGNE",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        Text(_disponible ? "Position GPS partagée — missions possibles"
                        : "Activez pour recevoir des missions",
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ])),
      const SizedBox(width: 12),
      _toggling
          ? const SizedBox(width: 36, height: 36,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          : GestureDetector(
              onTap: _toggleDisponibilite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(_disponible ? "DÉSACTIVER" : "ACTIVER",
                    style: TextStyle(
                        color: _disponible ? Colors.grey.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w900, fontSize: 11)))),
    ]),
  );

  // ════════════════════════════════════════════════════════════
  //  ONGLET 2 — MON COMPTE / INVITATIONS
  // ════════════════════════════════════════════════════════════
  Widget _tabMonCompte() {
    if (_loadingCompte) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));

    if (_infosCompte == null) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text("Impossible de charger les données",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        if (_errorCompte != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: SelectableText(
              "Erreur : " + (_errorCompte ?? "") + "\nNumero : " + widget.telephone,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              textAlign: TextAlign.center)),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _chargerInfosCompte,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text("Reessayer",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      ])));

    final d          = _infosCompte!;
    final int nb     = int.tryParse(d['nb_invitations'].toString()) ?? 0;
    final int livGrat= int.tryParse(d['livraison_gratuite'].toString()) ?? 0;
    final int rest   = int.tryParse(d['invitations_restantes'].toString()) ?? 5;
    final double pg  = (double.tryParse(d['progress_pct'].toString()) ?? 0) / 100;
    final String code= d['invite_code'] ?? '';
    final String lien= d['lien_invite'] ?? '';
    final int total  = _missions.length;
    final int livrees= _missions.where((m) => m['statut'] == 'Livrée et payée').length;

    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerInfosCompte,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Stats
          Row(children: [
            Expanded(child: _statCard("$total",   "Total missions",  const Color(0xFF8B0000))),
            const SizedBox(width: 10),
            Expanded(child: _statCard("$livrees", "Livrées ✅",       Colors.green)),
            const SizedBox(width: 10),
            Expanded(child: _statCard("$nb",      "Parrainages",     Colors.blue)),
          ]),
          const SizedBox(height: 20),

          // Avantage actif
          if (livGrat == 1) Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.green, Color(0xFF2E7D32)]),
                borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Text("🎁", style: TextStyle(fontSize: 28)), SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Avantage débloqué !",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                Text("Priorité sur les prochaines missions",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ])),

          // Code invitation
          _carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("MON CODE D'INVITATION",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 4),
            const Text("Toute personne inscrite avec votre code compte comme un parrainage.",
                style: TextStyle(color: Colors.black54, fontSize: 11)),
            const SizedBox(height: 14),
            Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 2)),
              child: Text(code,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 8)))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) _snack("Code $code copié !", true);
                },
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                label: const Text("Copier",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: lien));
                  if (mounted) _snack("Lien copié !", true);
                },
                icon: const Icon(Icons.share, color: Colors.white, size: 16),
                label: const Text("Partager",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
            ]),
          ])),
          const SizedBox(height: 16),

          // Progression parrainage
          _carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Parrainages validés",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              Text("$nb",
                  style: const TextStyle(fontWeight: FontWeight.w900,
                      color: Color(0xFF8B0000), fontSize: 22)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: pg,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF8B0000), minHeight: 12)),
            const SizedBox(height: 10),
            Text(rest == 0
                ? "🎉 Palier atteint ! Avantage débloqué."
                : "Encore $rest parrainage(s) pour débloquer un avantage 🎁",
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            const Text("AVANTAGES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 10),
            _ligneAvantage("5 parrainages",  "Priorité sur les nouvelles missions", nb >= 5),
            _ligneAvantage("10 parrainages", "Commission majorée sur les livraisons", nb >= 10),
            _ligneAvantage("20 parrainages", "Accès aux missions longue distance (premium)", nb >= 20),
          ])),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _ligneAvantage(String palier, String desc, bool atteint) =>
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 28, height: 28,
              decoration: BoxDecoration(
                  color: atteint ? Colors.green : Colors.grey.shade200,
                  shape: BoxShape.circle),
              child: Icon(atteint ? Icons.check : Icons.lock_outline,
                  color: atteint ? Colors.white : Colors.grey, size: 14)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(palier, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11,
                color: atteint ? Colors.green : Colors.black87)),
            Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ])),
        ]));

  // ── Widgets communs ─────────────────────────────────────────
  Widget _sectionTitre(String t, Color c) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.only(left: 8),
    decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 4))),
    child: Text(t, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w900, fontSize: 10)));

  Widget _vide(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inbox_outlined, color: Colors.grey, size: 18), const SizedBox(width: 8),
      Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]));

  Widget _carte({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: child);

  Widget _statCard(String val, String label, Color col) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: col)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
    ]));

  Widget _carteNouvellesMission(Map m) {
    final double? fLat = m['ferme_lat'] != null ? double.tryParse(m['ferme_lat'].toString()) : null;
    final double? fLng = m['ferme_lng'] != null ? double.tryParse(m['ferme_lng'].toString()) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Cmd #${m['id']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
              child: Text("${m['distance_ferme_km']} km",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10))),
        ]),
        const SizedBox(height: 4),
        Text(m['classe_poids'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2),
        Text("Livrer à : ${m['adresse'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _accepterMission(int.parse(m['id'].toString()), fLat, fLng),
            icon: const Icon(Icons.check, color: Colors.white, size: 16),
            label: const Text("Accepter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await ApiService.livreurRepondre(
                  telephone: widget.telephone, cmdId: int.parse(m['id'].toString()), action: 'refuser');
              _rechargerMissionsSeulement();
            },
            child: const Text("Refuser", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900))),
        ]),
      ]),
    );
  }

  Widget _carteMission(Map m, {required bool enCours}) {
    final col   = _couleurStatut(m['statut'] ?? '');
    final fLat  = m['ferme_lat']  != null ? double.tryParse(m['ferme_lat'].toString())  : null;
    final fLng  = m['ferme_lng']  != null ? double.tryParse(m['ferme_lng'].toString())  : null;
    final cLat  = m['latitude']   != null ? double.tryParse(m['latitude'].toString())   : null;
    final cLng  = m['longitude']  != null ? double.tryParse(m['longitude'].toString())  : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Cmd #${m['id']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text("${m['prix_total']} F", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            Text(m['classe_poids'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2),
            const SizedBox(height: 8),
            if (fLat != null) Row(children: [
              const Icon(Icons.store, color: Colors.blue, size: 14), const SizedBox(width: 4),
              Expanded(child: Text(m['nom_ferme'] ?? 'Ferme',
                  style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold))),
              GestureDetector(onTap: () async => await launchUrl(
                  Uri.parse("https://maps.google.com/?q=$fLat,$fLng"), mode: LaunchMode.externalApplication),
                  child: const Icon(Icons.map, color: Colors.blue, size: 18)),
            ]),
            const SizedBox(height: 4),
            if (cLat != null) Row(children: [
              const Icon(Icons.location_on, color: Colors.green, size: 14), const SizedBox(width: 4),
              Expanded(child: Text(m['adresse'] ?? '',
                  style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              GestureDetector(onTap: () async => await launchUrl(
                  Uri.parse("https://maps.google.com/?q=$cLat,$cLng"), mode: LaunchMode.externalApplication),
                  child: const Icon(Icons.map, color: Colors.green, size: 18)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text((m['statut'] ?? '').toUpperCase(),
                      style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 9))),
              Row(children: [
                GestureDetector(onTap: () async => await launchUrl(Uri.parse("tel:${m['telephone']}")),
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.phone, size: 16, color: Colors.black87))),
                if (m['ferme_tel'] != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(onTap: () async => await launchUrl(Uri.parse("tel:${m['ferme_tel']}")),
                      child: Container(padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.store, size: 16, color: Colors.blue))),
                ],
              ]),
            ]),
          ])),

        if (enCours && m['statut'] == 'En route') ...[
          const Divider(height: 1),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => TrackingScreen(
                    cmdId: int.parse(m['id'].toString()), nomClient: m['nom_client'] ?? ''))),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                color: const Color(0xFFE3F2FD),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.map, color: Colors.blue, size: 16), SizedBox(width: 6),
                  Text("Voir sur la carte",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 12)),
                ]))),
          const Divider(height: 1),
          InkWell(
            onTap: () => _marquerLivre(int.parse(m['id'].toString())),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(color: Color(0xFFF1FAF1),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8),
                  Text("Marquer Livré & Payé",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 13)),
                ]))),
        ],
      ]),
    );
  }
}