import 'dart:async'; // 🆕 CORRIGÉ : Timer de sondage des propositions (voir plus bas)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🆕 Clipboard (copier le détail d'une erreur)
import 'api_service.dart';
import 'session_service.dart';
import 'location_service.dart'; // 🆕 Lot 8 (position GPS stock)
import 'login_screen.dart';
import 'message_screen.dart'; // 🆕 Lot 5
import 'formations_screen.dart'; // 🆕 Lot 9
import 'publicite_service.dart'; // 🆕 Lot 10
import 'proposition_commande_screen.dart'; // 🆕 Dispatch Uber/Yango
import 'parametres_screen.dart'; // 🆕 Paramètres

// =============================================================
//  ESPACE PRODUCTEUR / FOURNISSEUR (Lot 3 + Lot 8)
//
//  4 onglets : En attente / Historique (modifications de commande,
//  Lot 3) + Commandes / Stock (Lot 8, reproduit le portail web
//  existant — alloguinaar.zip, non modifié, utilisé comme
//  référence). Statistiques, revenus, horaires et profil ne sont
//  pas dans le périmètre (ils n'existent pas non plus sur le web
//  aujourd'hui) — voir RAPPORT_LOT8.md.
// =============================================================
class ProducteurScreen extends StatefulWidget {
  final String telephone;
  final String nom;

  const ProducteurScreen({super.key, required this.telephone, required this.nom});

  @override
  State<ProducteurScreen> createState() => _ProducteurScreenState();
}

class _ProducteurScreenState extends State<ProducteurScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool _loadingDemandes = true;
  bool _loadingHistorique = true;
  String? _errorDemandes;
  String? _errorHistorique;
  List<dynamic> _demandes = [];
  List<dynamic> _historique = [];

  // 🆕 Lot 8
  bool _loadingCommandes = true;
  String? _errorCommandes;
  List<dynamic> _commandes = [];

  bool _loadingStock = true;
  String? _errorStock;
  Map<String, dynamic> _produits = {};       // catalogue complet (id => infos)
  final Map<String, TextEditingController> _stockCtrls = {};
  final Map<String, TextEditingController> _seuilMinCtrls = {};      // 🆕 Lot 2
  final Map<String, TextEditingController> _seuilCritiqueCtrls = {}; // 🆕 Lot 2
  double? _stockLat;
  double? _stockLng;
  bool _enregistrementStock = false;

  static const List<String> _statutsPossibles = [
    'En attente', 'En cours de préparation', 'Prête pour le livreur', 'En route',
    'Livraison en cours', 'Livrée et payée', 'Livrée en attente de paiement', // 🆕
    'Annulée',
  ];

  // 🆕 CORRIGÉ : _verifierPropositionsEnAttente() ne tournait qu'UNE
  // SEULE FOIS, à l'ouverture de l'écran (initState). Si le producteur
  // avait déjà l'app ouverte sur cet écran au moment où une commande lui
  // était proposée, rien ne se passait tant qu'il ne quittait/rouvrait
  // pas l'écran — le "filet de sécurité" ne rattrapait alors plus rien
  // du tout, laissant la notification Push comme SEUL moyen d'être
  // averti. Ce Timer sonde désormais le serveur toutes les 15 secondes,
  // indépendamment du Push — une proposition finit donc toujours par
  // s'afficher, même si la notification a été manquée ou bloquée par le
  // système (veille profonde, permissions, etc.).
  Timer? _sondageProposition;
  bool _propositionAffichee = false; // évite d'ouvrir le même écran deux fois

  // 🆕 Lot 7 : espace grossiste
  bool _estGrossiste = false;
  bool _loadingGrossisteOffres = true;
  List<dynamic> _mesOffresGrossiste = [];
  final _produitOffreCtrl = TextEditingController();
  final _prixOffreCtrl = TextEditingController();
  final _qteDispoOffreCtrl = TextEditingController();
  final _qteMinOffreCtrl = TextEditingController(text: "100");
  bool _envoiOffre = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this); // 🆕 Lot 7
    _chargerDemandes();
    _chargerHistorique();
    _chargerCommandes();   // 🆕 Lot 8
    _chargerStock();       // 🆕 Lot 8
    _chargerMesOffresGrossiste(); // 🆕 Lot 7
    // 🆕 Lot 10 : vérifier les publicités actives (rôle producteur)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🆕 Réactivé : testé sans les publicités, l'écran noir persistait
      // quand même — cause écartée.
      if (mounted) PubliciteService.verifierEtAfficher(context, widget.telephone);
    });
    // 🆕 Dispatch Uber/Yango : filet de sécurité — si une proposition
    // était déjà en attente au moment où l'app s'ouvre (ex. notification
    // manquée pendant que le téléphone était éteint), on l'affiche quand
    // même, sans dépendre uniquement du push.
    _verifierPropositionsEnAttente();

    // 🆕 CORRIGÉ : sondage périodique — voir commentaire sur
    // _sondageProposition ci-dessus pour le pourquoi.
    _sondageProposition = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _verifierPropositionsEnAttente(),
    );
  }

  Future<void> _verifierPropositionsEnAttente() async {
    if (_propositionAffichee) return; // déjà un écran de proposition ouvert
    final r = await ApiService.mesPropositionsEnAttente(widget.telephone);
    if (!mounted || r['status'] != 'success') return;
    final List<dynamic> props = r['data'] ?? [];
    if (props.isEmpty) return;
    final p = props.first; // une seule à la fois, la plus ancienne en premier
    final secondesRestantes = int.tryParse(p['secondes_restantes'].toString()) ?? 0;
    if (secondesRestantes <= 0) return; // déjà expirée, le cron s'en chargera

    _propositionAffichee = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) { _propositionAffichee = false; return; }
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PropositionCommandeScreen(
          telephone: widget.telephone,
          propositionId: int.parse(p['proposition_id'].toString()),
          cmdId: int.parse(p['commande_id'].toString()),
          delaiSecondes: secondesRestantes,
          nomClient: p['nom_client'],
          adresse: p['adresse'],
          articles: p['classe_poids'],
          montant: "${p['prix_total']} F",
        ),
      ));
      // 🆕 L'écran de proposition s'est refermé (acceptée/refusée/expirée)
      // → le sondage peut de nouveau proposer une commande suivante.
      _propositionAffichee = false;
    });
  }

  @override
  void dispose() {
    _sondageProposition?.cancel(); // 🆕 CORRIGÉ : éviter toute fuite de Timer
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _chargerDemandes() async {
    setState(() { _loadingDemandes = true; _errorDemandes = null; });
    final r = await ApiService.demandesProducteur(widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _demandes = r['data'] ?? []; _loadingDemandes = false; });
    } else {
      setState(() { _errorDemandes = r['message'] ?? "Erreur de chargement"; _loadingDemandes = false; });
    }
  }

  /// 🆕 Lot 3 : historique des modifications déjà traitées (auto ou
  /// approuvées), avec les nouvelles données — pour voir les mises à
  /// jour même après coup, pas seulement au moment de l'approbation.
  Future<void> _chargerHistorique() async {
    setState(() { _loadingHistorique = true; _errorHistorique = null; });
    final r = await ApiService.commandesModifieesProducteur(widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _historique = r['data'] ?? []; _loadingHistorique = false; });
    } else {
      setState(() { _errorHistorique = r['message'] ?? "Erreur de chargement"; _loadingHistorique = false; });
    }
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  /// Affiche le message d'erreur en entier (pas tronqué), avec un
  /// bouton pour le copier — utile pour diagnostiquer une "Erreur
  /// serveur" si la réponse de l'API n'est pas du JSON valide.
  Widget _erreurAvecDetail(String message, Future<void> Function() onRetry) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 60),
      const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
      const SizedBox(height: 16),
      const Center(child: Text("Erreur de chargement",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200)),
        child: SelectableText(message,
            style: const TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'monospace')),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
            if (mounted) _snack("Erreur copiée", true);
          },
          icon: const Icon(Icons.copy, size: 14),
          label: const Text("Copier", style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
          label: const Text("Réessayer", style: TextStyle(fontSize: 11, color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
        ),
      ]),
    ]);
  }

  // ── Lot 8 : onglet Commandes ──────────────────────────────
  Future<void> _chargerCommandes() async {
    setState(() { _loadingCommandes = true; _errorCommandes = null; });
    final r = await ApiService.commandesProducteur(widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _commandes = r['data'] ?? []; _loadingCommandes = false; });
    } else {
      setState(() { _errorCommandes = r['message'] ?? "Erreur de chargement"; _loadingCommandes = false; });
    }
  }

  Future<void> _changerStatut(Map cmd, String nouveauStatut) async {
    final r = await ApiService.updateStatut(
      cmdId: int.parse(cmd['id'].toString()),
      statut: nouveauStatut,
    );
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') _chargerCommandes();
  }

  // ── Lot 8 : onglet Stock ──────────────────────────────────
  Future<void> _chargerStock() async {
    setState(() { _loadingStock = true; _errorStock = null; });
    final catalogue = await ApiService.getCatalogue();
    final stock     = await ApiService.monStock(widget.telephone);
    if (!mounted) return;

    if (catalogue['status'] != 'success') {
      setState(() { _errorStock = catalogue['message'] ?? "Erreur de chargement du catalogue"; _loadingStock = false; });
      return;
    }
    if (stock['status'] != 'success') {
      setState(() { _errorStock = stock['message'] ?? "Erreur de chargement du stock"; _loadingStock = false; });
      return;
    }

    final Map<String, dynamic> produitsMap = catalogue['data'];
    final Map<String, dynamic> stockData   = stock['data']['stock']  ?? {};
    final Map<String, dynamic> seuilsData  = stock['data']['seuils'] ?? {}; // 🆕 Lot 2

    setState(() {
      _produits = produitsMap;
      for (final key in produitsMap.keys) {
        _stockCtrls[key] = TextEditingController(text: "${stockData[key] ?? 0}");
        final s = seuilsData[key] as Map?;
        _seuilMinCtrls[key]      = TextEditingController(text: "${s?['min']      ?? 10}"); // 🆕 Lot 2
        _seuilCritiqueCtrls[key] = TextEditingController(text: "${s?['critique'] ?? 3}");  // 🆕 Lot 2
      }
      _stockLat = stock['data']['lat'] != null ? double.tryParse(stock['data']['lat'].toString()) : null;
      _stockLng = stock['data']['lng'] != null ? double.tryParse(stock['data']['lng'].toString()) : null;
      _loadingStock = false;
    });
  }

  Future<void> _obtenirPositionGPSStock() async {
    final coords = await LocationService.obtenirCoordonnees();
    if (!mounted) return;
    if (coords == null) {
      _snack("Impossible d'obtenir votre position. Vérifiez que le GPS est activé.", false);
      return;
    }
    setState(() { _stockLat = coords['lat']; _stockLng = coords['lng']; });
  }

  Future<void> _enregistrerStock() async {
    setState(() => _enregistrementStock = true);
    final stockQte = <String, int>{};
    final seuils = <String, Map<String, int>>{}; // 🆕 Lot 2
    for (final entry in _stockCtrls.entries) {
      stockQte[entry.key] = int.tryParse(entry.value.text.trim()) ?? 0;
      seuils[entry.key] = {
        "min":      int.tryParse(_seuilMinCtrls[entry.key]?.text.trim()      ?? '') ?? 10,
        "critique": int.tryParse(_seuilCritiqueCtrls[entry.key]?.text.trim() ?? '') ?? 3,
      };
    }
    final r = await ApiService.updateStock(
      telephone: widget.telephone,
      stockQte: stockQte,
      lat: _stockLat,
      lng: _stockLng,
      seuils: seuils, // 🆕 Lot 2
    );
    if (!mounted) return;
    setState(() => _enregistrementStock = false);
    _snack(r['message'] ?? '', r['status'] == 'success');
  }

  Future<void> _approuver(Map d) async {
    final r = await ApiService.approuverModification(
      modificationId: int.parse(d['id'].toString()),
      telephone: widget.telephone,
    );
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') { _chargerDemandes(); _chargerHistorique(); }
  }

  Future<void> _refuser(Map d) async {
    final motifCtrl = TextEditingController();
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Refuser la demande", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: motifCtrl,
          decoration: InputDecoration(
            hintText: "Motif (optionnel)",
            filled: true, fillColor: const Color(0xFFF4F7F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Refuser", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    final r = await ApiService.refuserModification(
      modificationId: int.parse(d['id'].toString()),
      telephone: widget.telephone,
      motif: motifCtrl.text.trim(),
    );
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') { _chargerDemandes(); _chargerHistorique(); }
  }

  Future<void> _seDeconnecter() async {
    await SessionService.supprimer();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _resumeChamps(Map champs) {
    final labels = {
      'quantite': 'Quantité',
      'adresse': 'Adresse',
      'telephone_livraison': 'Téléphone',
      'date_livraison_souhaitee': 'Date souhaitée',
      'heure_livraison_souhaitee': 'Heure souhaitée',
      'commentaire_client': 'Commentaire',
    };
    return champs.entries.map((e) {
      final label = labels[e.key] ?? e.key;
      final avant = e.value['avant'] ?? '—';
      final apres = e.value['apres'] ?? '—';
      return "$label : $avant → $apres";
    }).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Espace Producteur", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(widget.nom, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
        actions: [
          // 🆕 Paramètres (inclut la déconnexion — bouton retiré d'ici
          // pour éviter le doublon signalé par l'utilisateur)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            tooltip: "Paramètres",
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ParametresScreen(telephone: widget.telephone, nom: widget.nom))),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: const Color(0xFF8B0000),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B0000),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          tabs: [
            Tab(text: "Commandes${_commandes.isNotEmpty ? ' (${_commandes.length})' : ''}"), // 🆕 Lot 8
            Tab(text: "En attente${_demandes.isNotEmpty ? ' (${_demandes.length})' : ''}"),
            const Tab(text: "Historique"),
            const Tab(text: "Stock"), // 🆕 Lot 8
            const Tab(text: "Formations"), // 🆕 Lot 9
            const Tab(text: "Grossiste"), // 🆕 Lot 7
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_tabCommandes(), _tabEnAttente(), _tabHistorique(), _tabStock(), _tabFormations(), _tabGrossiste()], // 🆕 Lot 7
      ),
    );
  }

  // ── Lot 9 : lanceur vers l'espace formations (contenu producteur) ──
  Widget _tabFormations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.play_circle_outline, size: 44, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          const Text("Espace Formations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            "Des vidéos courtes pour mieux gérer vos commandes et votre stock.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FormationsScreen(telephone: widget.telephone, nom: widget.nom))),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text("VOIR LES FORMATIONS",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
        ]),
      ),
    );
  }

  // ── Onglet 1 : demandes en attente d'approbation ──────────────
  Widget _tabEnAttente() {
    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerDemandes,
      child: _loadingDemandes
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _errorDemandes != null
              ? _erreurAvecDetail(_errorDemandes!, _chargerDemandes)
              : _demandes.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Center(child: Text("Aucune demande en attente",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _demandes.length,
                      itemBuilder: (ctx, i) {
                        final d = _demandes[i];
                        final champs = (d['champs_modifies'] as Map?) ?? {};
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("Commande #${d['commande_id']}",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              Text(d['nom_client'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ]),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
                              child: Text(_resumeChamps(champs),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () => _refuser(d),
                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                label: const Text("Refuser", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton.icon(
                                onPressed: () => _approuver(d),
                                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                label: const Text("Approuver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              )),
                            ]),
                          ]),
                        );
                      },
                    ),
    );
  }

  // ── Onglet 2 : historique des modifications déjà appliquées ──
  Widget _tabHistorique() {
    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerHistorique,
      child: _loadingHistorique
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _errorHistorique != null
              ? _erreurAvecDetail(_errorHistorique!, _chargerHistorique)
              : _historique.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Center(child: Text("Aucune commande modifiée récemment",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _historique.length,
                      itemBuilder: (ctx, i) {
                        final h = _historique[i];
                        final champs = (h['champs_modifies'] as Map?) ?? {};
                        final auto = h['statut_approbation'] == 'auto_appliquee';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("Commande #${h['commande_id']}",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (auto ? Colors.blue : Colors.green).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text(auto ? "AUTO-APPLIQUÉE" : "APPROUVÉE PAR VOUS",
                                  style: TextStyle(color: auto ? Colors.blue : Colors.green,
                                    fontWeight: FontWeight.w900, fontSize: 9)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(h['nom_client'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
                              child: Text(_resumeChamps(champs),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.payments_outlined, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text("Nouveau total : ${h['prix_total']} FCFA",
                                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          ]),
                        );
                      },
                    ),
    );
  }

  // ── Lot 8 : onglet Commandes ──────────────────────────────
  Widget _tabCommandes() {
    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerCommandes,
      child: _loadingCommandes
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _errorCommandes != null
              ? _erreurAvecDetail(_errorCommandes!, _chargerCommandes)
              : _commandes.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Center(child: Text("Aucune commande pour l'instant",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _commandes.length,
                      itemBuilder: (ctx, i) {
                        final c = _commandes[i];
                        final estPaye = c['mode_paiement'] == 'immédiat';
                        String statutActuel = c['statut'] ?? 'En attente';
                        if (!_statutsPossibles.contains(statutActuel)) statutActuel = _statutsPossibles.first;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Cmd #${c['id']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey)),
                                Text(c['nom_client'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                Text(c['telephone'] ?? '', style: const TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text("${c['prix_total']} F", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF8B0000))),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (estPaye ? Colors.green : Colors.orange).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                  child: Text(estPaye ? "PAYÉ EN LIGNE" : "PAIEMENT LIVRAISON",
                                    style: TextStyle(color: estPaye ? Colors.green : Colors.orange, fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ]),
                            ]),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
                              child: Text("${c['classe_poids'] ?? ''}\nQuantité : ${c['quantite'] ?? ''} pcs",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: statutActuel,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true, fillColor: const Color(0xFFF4F7F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                  items: _statutsPossibles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (nouveau) { if (nouveau != null) _changerStatut(c, nouveau); },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 🆕 Lot 5 : messagerie avec le client
                              Container(
                                decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
                                child: IconButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => MessageScreen(
                                      cmdId: int.parse(c['id'].toString()),
                                      telephone: widget.telephone,
                                      monRole: 'producteur',
                                    ),
                                  )),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF8B0000)),
                                  tooltip: "Contacter le client",
                                ),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
    );
  }

  // ── Lot 8 : onglet Stock ──────────────────────────────────
  Widget _tabStock() {
    if (_loadingStock) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));
    }
    if (_errorStock != null) {
      return _erreurAvecDetail(_errorStock!, _chargerStock);
    }
    return RefreshIndicator(
      color: const Color(0xFF8B0000),
      onRefresh: _chargerStock,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("VOS PRODUITS & QUANTITÉS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              ..._produits.entries.map((entry) {
                final p = entry.value;
                final ctrl = _stockCtrls[entry.key]!;
                final seuilMinCtrl      = _seuilMinCtrls[entry.key]!;      // 🆕 Lot 2
                final seuilCritiqueCtrl = _seuilCritiqueCtrls[entry.key]!; // 🆕 Lot 2

                // 🆕 Lot 2 : badge calculé en direct depuis les valeurs affichées
                final qte      = int.tryParse(ctrl.text.trim())            ?? 0;
                final min      = int.tryParse(seuilMinCtrl.text.trim())      ?? 10;
                final critique = int.tryParse(seuilCritiqueCtrl.text.trim()) ?? 3;
                String? badgeLabel; Color? badgeColor;
                if (qte <= critique) { badgeLabel = "RUPTURE"; badgeColor = Colors.red; }
                else if (qte <= min) { badgeLabel = "STOCK FAIBLE"; badgeColor = Colors.orange; }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(10),
                    border: badgeColor != null ? Border.all(color: badgeColor.withOpacity(0.4)) : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(p['short'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                          if (badgeLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: badgeColor!.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ]),
                        Text("${p['prix']} F", style: const TextStyle(color: Color(0xFF8B0000), fontSize: 10, fontWeight: FontWeight.bold)),
                      ])),
                      SizedBox(width: 64, child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}), // 🆕 Lot 2 : recalcule le badge en direct
                        decoration: InputDecoration(
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      )),
                    ]),
                    // 🆕 Lot 2 : seuils d'alerte, repliés dans une ligne compacte
                    const SizedBox(height: 6),
                    Row(children: [
                      const Text("Seuils :", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Text("faible <", style: TextStyle(fontSize: 10, color: Colors.orange)),
                      const SizedBox(width: 4),
                      SizedBox(width: 40, height: 28, child: TextField(
                        controller: seuilMinCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          filled: true, fillColor: Colors.white, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        ),
                      )),
                      const SizedBox(width: 12),
                      const Text("rupture <", style: TextStyle(fontSize: 10, color: Colors.red)),
                      const SizedBox(width: 4),
                      SizedBox(width: 40, height: 28, child: TextField(
                        controller: seuilCritiqueCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          filled: true, fillColor: Colors.white, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        ),
                      )),
                    ]),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _obtenirPositionGPSStock,
            icon: Icon(Icons.map_outlined, size: 16, color: _stockLat != null ? Colors.green : const Color(0xFF1565C0)),
            label: Text(
              _stockLat != null ? "Position GPS enregistrée (modifier)" : "Définir la position GPS",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: _stockLat != null ? Colors.green : const Color(0xFF1565C0)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: _stockLat != null ? Colors.green : const Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: _enregistrementStock ? null : _enregistrerStock,
            icon: _enregistrementStock
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save, color: Colors.white, size: 16),
            label: const Text("ENREGISTRER LES MODIFICATIONS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ONGLET 6 — GROSSISTE (Lot 7)
  //  Le producteur active son statut grossiste puis publie des
  //  offres. Les demandes d'achat des clients n'apparaissent jamais
  //  ici — elles partent uniquement à l'équipe Allo Guinaar, qui
  //  gère la mise en relation manuellement (voir RAPPORT_LOT7.md).
  // ══════════════════════════════════════════════════════════
  Future<void> _chargerMesOffresGrossiste() async {
    setState(() => _loadingGrossisteOffres = true);
    final r = await ApiService.mesOffresGrossiste(widget.telephone);
    if (!mounted) return;
    setState(() {
      _mesOffresGrossiste = r['status'] == 'success' ? (r['data'] ?? []) : [];
      // 🆕 Corrigé : le statut réel n'était jamais relu au chargement,
      // le bouton repartait toujours désactivé même pour un producteur
      // déjà grossiste.
      if (r['status'] == 'success' && r.containsKey('est_grossiste')) {
        _estGrossiste = r['est_grossiste'] == true;
      }
      _loadingGrossisteOffres = false;
    });
  }

  Future<void> _toggleGrossiste(bool valeur) async {
    final r = await ApiService.activerGrossiste(telephone: widget.telephone, actif: valeur);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() => _estGrossiste = valeur);
    } else {
      _snack(r['message'] ?? '', false);
    }
  }

  Future<void> _publierOffre() async {
    final produit = _produitOffreCtrl.text.trim();
    final prix = double.tryParse(_prixOffreCtrl.text.trim()) ?? 0;
    final qteDispo = int.tryParse(_qteDispoOffreCtrl.text.trim()) ?? 0;
    final qteMin = int.tryParse(_qteMinOffreCtrl.text.trim()) ?? 100;

    if (produit.isEmpty || prix <= 0 || qteDispo <= 0) {
      _snack("Remplissez le produit, le prix et la quantité disponible", false);
      return;
    }

    setState(() => _envoiOffre = true);
    final r = await ApiService.creerOffreGrossiste(
      telephone: widget.telephone,
      produit: produit,
      prixUnitaire: prix,
      quantiteDisponible: qteDispo,
      quantiteMin: qteMin < 100 ? 100 : qteMin,
    );
    if (!mounted) return;
    setState(() => _envoiOffre = false);
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') {
      _produitOffreCtrl.clear();
      _prixOffreCtrl.clear();
      _qteDispoOffreCtrl.clear();
      _qteMinOffreCtrl.text = "100";
      _chargerMesOffresGrossiste();
    }
  }

  Widget _tabGrossiste() {
    return RefreshIndicator(
      color: const Color(0xFFFF6F00),
      onRefresh: _chargerMesOffresGrossiste,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Activation du statut grossiste
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: const Color(0xFFFF6F00).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_outlined, color: Color(0xFFFF6F00))),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Statut Grossiste", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                Text("Vendez en grande quantité aux revendeurs", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ])),
              Switch(value: _estGrossiste, activeColor: const Color(0xFFFF6F00), onChanged: _toggleGrossiste),
            ]),
          ),

          if (_estGrossiste) ...[
            const SizedBox(height: 16),
            // Formulaire nouvelle offre
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("PUBLIER UNE OFFRE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
                const SizedBox(height: 12),
                TextField(controller: _produitOffreCtrl, decoration: InputDecoration(labelText: "Produit",
                  filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _prixOffreCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Prix/pièce (F)", filled: true, fillColor: const Color(0xFFF4F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _qteDispoOffreCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Qté disponible", filled: true, fillColor: const Color(0xFFF4F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _qteMinOffreCtrl, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Quantité minimum (100 mini)", filled: true, fillColor: const Color(0xFFF4F7F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _envoiOffre ? null : _publierOffre,
                  child: _envoiOffre
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("PUBLIER L'OFFRE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)))),
              ]),
            ),
            const SizedBox(height: 16),
            const Text("MES OFFRES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 8),
            if (_loadingGrossisteOffres)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFFF6F00))))
            else if (_mesOffresGrossiste.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text("Aucune offre publiée pour l'instant",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
            else ..._mesOffresGrossiste.map((o) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o['produit'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("${o['prix_unitaire']} F • ${o['quantite_disponible']} dispo. • min ${o['quantite_min']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF6F00).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("${o['nb_demandes']} demande(s)",
                    style: const TextStyle(color: Color(0xFFFF6F00), fontSize: 10, fontWeight: FontWeight.w900))),
              ]),
            )),
          ],
        ],
      ),
    );
  }
}
