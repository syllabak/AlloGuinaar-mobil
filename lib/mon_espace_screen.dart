import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // 🆕 Parrainage (partage natif)
import 'api_service.dart';
import 'tracking_screen.dart';
import 'message_screen.dart'; // 🆕 Lot 5
import 'formations_screen.dart'; // 🆕 Lot 9
import 'grossiste_screen.dart'; // 🆕 Lot 7
import 'parametres_screen.dart'; // 🆕 Paramètres

class MonEspaceScreen extends StatefulWidget {
  final String telephone;
  final String nom;
  final int    userId;

  const MonEspaceScreen({super.key,
    required this.telephone,
    required this.nom,
    this.userId = 0});

  @override State<MonEspaceScreen> createState() => _MonEspaceScreenState();
}

class _MonEspaceScreenState extends State<MonEspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Map<String, dynamic>? _infosClient;
  List<dynamic> _commandes = [];
  List<dynamic> _avis      = [];
  List<dynamic> _modifications = []; // 🆕 Lot 3 : historique des modifications
  String? _errorCmds;   // message d'erreur commandes
  String? _errorInfos;  // message d'erreur infos client

  bool _loadingInfos = true;
  bool _loadingCmds  = true;
  bool _loadingAvis  = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this); // 🆕 Lot 7
    _chargerTout();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _chargerTout() async {
    _chargerInfos();
    _chargerCommandes();
    _chargerAvis();
    _chargerModifications(); // 🆕 Lot 3
  }

  /// 🆕 Lot 3 : charge l'historique des demandes de modification pour
  /// pouvoir marquer "Commande modifiée" sur les commandes concernées.
  Future<void> _chargerModifications() async {
    final r = await ApiService.mesDemandesModification(widget.telephone);
    if (mounted && r['status'] == 'success') {
      setState(() => _modifications = r['data'] ?? []);
    }
  }

  /// 🆕 Lot 3 : une commande a-t-elle une modification déjà appliquée
  /// (auto ou approuvée) ? Sert à afficher le badge "Commande modifiée".
  bool _estModifiee(dynamic cmdId) => _modifications.any((m) =>
      m['commande_id'].toString() == cmdId.toString() &&
      (m['statut_approbation'] == 'auto_appliquee' || m['statut_approbation'] == 'approuvee'));

  Future<void> _chargerInfos() async {
    setState(() => _loadingInfos = true);
    final r = await ApiService.getInfosClient(widget.telephone);
    if (mounted) setState(() {
      if (r['status'] == 'success' && r['data'] != null) {
        _infosClient = r['data'];
        _errorInfos  = null;
      } else {
        _infosClient = null;
        // Stocker le vrai message d'erreur pour l'afficher
        _errorInfos  = r['message']?.toString() ?? 'Erreur inconnue (status: ${r['status']})';
      }
      _loadingInfos = false;
    });
  }

  Future<void> _chargerCommandes() async {
    final r = await ApiService.getMesCommandes(widget.telephone);
    if (mounted) setState(() {
      if (r['status'] == 'success') {
        _commandes  = r['data'] ?? [];
        _errorCmds  = null;
      } else {
        _commandes  = [];
        _errorCmds  = r['message'] ?? 'Erreur de chargement';
      }
      _loadingCmds = false;
    });
  }

  Future<void> _chargerAvis() async {
    final r = await ApiService.getMesAvis(widget.telephone);
    if (mounted) setState(() {
      _avis        = r['status'] == 'success' ? (r['data'] ?? []) : [];
      _loadingAvis = false;
    });
  }

  Color _statutColor(String s) {
    if (s == 'Livrée et payée') return Colors.green;
    if (s == 'Annulée')         return Colors.red;
    return Colors.orange;
  }

  Widget _etoiles(int note) => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < note ? Icons.star_rounded : Icons.star_outline_rounded,
      color: Colors.amber, size: 16)));

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Mon Espace",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(widget.nom,
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          // 🆕 Paramètres (profil, sécurité, notifications, suppression de compte)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            tooltip: "Paramètres",
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ParametresScreen(telephone: widget.telephone, nom: widget.nom))),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: const Color(0xFF8B0000),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B0000),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: "Commandes"),
            Tab(icon: Icon(Icons.person_add_outlined, size: 18),  text: "Invitations"),
            Tab(icon: Icon(Icons.star_outline_rounded, size: 18), text: "Mes Avis"),
            Tab(icon: Icon(Icons.play_circle_outline, size: 18),  text: "Formations"), // 🆕 Lot 9
            Tab(icon: Icon(Icons.storefront_outlined, size: 18),  text: "Grossiste"), // 🆕 Lot 7
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_tabCommandes(), _tabInvitations(), _tabAvis(), _tabFormations(), _tabGrossiste()], // 🆕 Lot 7
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ONGLET 1 — COMMANDES
  // ══════════════════════════════════════════════════════════
  Widget _tabCommandes() {
    if (_loadingCmds) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));

    if (_errorCmds != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text("Impossible de charger vos commandes",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(_errorCmds!, style: const TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _chargerCommandes,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text("Réessayer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        ])));
    }

    if (_commandes.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text("Aucune commande pour le moment",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text("Vos commandes apparaîtront ici",
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]));
    }

    return RefreshIndicator(color: const Color(0xFF8B0000), onRefresh: _chargerCommandes,
      child: ListView.builder(padding: const EdgeInsets.all(16),
        itemCount: _commandes.length,
        itemBuilder: (ctx, i) {
          final cmd        = _commandes[i];
          final col        = _statutColor(cmd['statut'] ?? '');
          final estLivree  = cmd['statut'] == 'Livrée et payée';
          final enRoute    = cmd['statut'] == 'En route';
          final aLivreur   = int.tryParse(cmd['livreur_id']?.toString() ?? '0') != 0;
          final dateStr    = cmd['date_commande']?.toString().substring(0, 16) ?? '';

          return GestureDetector(
            onTap: () => _voirDetailCommande(cmd),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Column(children: [
                Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // En-tête
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Text("Commande #${cmd['id']}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      // 🆕 Lot 3 : badge si la commande a été modifiée
                      if (_estModifiee(cmd['id'])) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200)),
                          child: const Text("✏️ Modifiée",
                            style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ]),
                    Text("${cmd['prix_total']} F",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF8B0000))),
                  ]),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                  const SizedBox(height: 8),
                  // Articles
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
                    child: Text(cmd['classe_poids'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(height: 10),
                  // Adresse de livraison
                  if ((cmd['adresse'] ?? '').toString().isNotEmpty) Row(children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(cmd['adresse'].toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),
                  // Statut + paiement
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text((cmd['statut'] ?? '').toUpperCase(),
                        style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 9))),
                    Row(children: [
                      const Icon(Icons.payments_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(cmd['mode_paiement'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                  ]),
                ])),

                // Actions selon statut ────────────────────────

                // Suivi livreur
                if (enRoute && aLivreur) ...[
                  const Divider(height: 1),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TrackingScreen(
                        cmdId: int.parse(cmd['id'].toString()),
                        nomClient: widget.nom))),
                    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      color: const Color(0xFFE3F2FD),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.location_on, color: Colors.blue, size: 16), SizedBox(width: 6),
                        Text("🚚 Suivre le livreur en temps réel",
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 12)),
                      ]))),
                ],

                // Facture + avis
                if (estLivree) ...[
                  const Divider(height: 1),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse("https://alloguinaar.danov.sn/?facture=${cmd['id']}");
                      try {
                        // 🆕 Corrigé : canLaunchUrl() a des faux négatifs connus
                        // sur Android (même avec les <queries> déclarées) — on
                        // tente directement l'ouverture, avec un message clair
                        // en cas d'échec réel, plutôt que de ne rien faire.
                        final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
                        if (!ok && mounted) {
                          _snack("Impossible d'ouvrir la facture. Vérifiez qu'un navigateur est installé.", false);
                        }
                      } catch (e) {
                        if (mounted) _snack("Erreur à l'ouverture de la facture : $e", false);
                      }
                    },
                    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: Colors.green.shade50,
                        borderRadius: _avis.any((a) => a['commande_id'].toString() == cmd['id'].toString())
                          ? const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
                          : BorderRadius.zero),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.receipt_long, color: Colors.green, size: 16), SizedBox(width: 6),
                        Text("Voir ma facture",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 12)),
                      ]))),
                  if (!_avis.any((a) => a['commande_id'].toString() == cmd['id'].toString()))
                    _boutonAvis(cmd),
                ],
              ]),
            ));
        }));
  }

  // Détail commande en bottom sheet
  void _voirDetailCommande(Map cmd) {
    final col    = _statutColor(cmd['statut'] ?? '');
    final String date = cmd['date_commande']?.toString() ?? '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        // 🆕 Correctif débordement : limite la hauteur et rend le
        // contenu défilable (nécessaire depuis l'ajout de l'historique
        // de modification et du bouton messagerie, qui pouvaient
        // dépasser la hauteur de l'écran sur certains appareils).
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          // Titre
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Commande #${cmd['id']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text((cmd['statut'] ?? '').toUpperCase(),
                style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 10))),
          ]),
          if (date.isNotEmpty) Text(date.substring(0, date.length > 16 ? 16 : date.length),
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const Divider(height: 24),
          // Articles
          const Text("ARTICLES",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(10)),
            child: Text(cmd['classe_poids'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const SizedBox(height: 16),
          // Détails
          _lignDetail(Icons.payments_outlined, "Mode de paiement", cmd['mode_paiement'] ?? '—'),
          _lignDetail(Icons.location_on_outlined, "Adresse de livraison", cmd['adresse'] ?? '—'),
          _lignDetail(Icons.person_outline, "Client", cmd['nom_client'] ?? '—'),
          // 🆕 Lot 3 : historique des modifications de cette commande
          if (_modifications.any((m) => m['commande_id'].toString() == cmd['id'].toString())) ...[
            const SizedBox(height: 4),
            const Text("HISTORIQUE DES MODIFICATIONS",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 8),
            ..._modifications
                .where((m) => m['commande_id'].toString() == cmd['id'].toString())
                .map((m) {
              final champs = (m['champs_modifies'] as Map?) ?? {};
              final statut = m['statut_approbation'];
              final couleur = statut == 'refusee' ? Colors.red
                  : (statut == 'en_attente' ? Colors.orange : Colors.green);
              final label = statut == 'refusee' ? 'Refusée' : (statut == 'en_attente' ? 'En attente' : 'Appliquée');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: couleur.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: couleur.withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(color: couleur, fontWeight: FontWeight.w900, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(champs.entries.map((e) => "${e.key} → ${e.value['apres']}").join(', '),
                    style: const TextStyle(fontSize: 11)),
                ]),
              );
            }),
          ],
          const Divider(height: 24),
          // Total
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            Text("${cmd['prix_total']} FCFA",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF8B0000))),
          ]),
          // 🆕 Lot 5 : messagerie avec le producteur
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MessageScreen(
                  cmdId: int.parse(cmd['id'].toString()),
                  telephone: widget.telephone,
                  monRole: 'client',
                ),
              ));
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text("Contacter le producteur",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          // 🆕 Lot 3 : demander une modification (tant que la commande
          // n'est pas livrée/annulée/clôturée)
          if (!_commandeCloturee(cmd['statut'] ?? '')) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context); // ferme le détail
                _ouvrirFormModification(cmd);
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("Modifier ma commande",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B0000),
                side: const BorderSide(color: Color(0xFF8B0000)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ],
          const SizedBox(height: 24),
        ]),
      )));
  }

  /// 🆕 Lot 3 : une commande n'est plus modifiable une fois livrée,
  /// annulée, ou clôturée en fin de journée.
  bool _commandeCloturee(String statut) =>
      statut == 'Livrée et payée' || statut == 'Annulée' || statut.startsWith('Clôturée');

  /// 🆕 Lot 3 : formulaire de demande de modification. Les champs
  /// laissés vides ne sont pas envoyés. Si la commande est encore
  /// "En attente" et que seuls des champs logistiques changent, la
  /// modification est appliquée immédiatement ; sinon elle part en
  /// approbation producteur (la quantité y passe toujours, car elle
  /// affecte le prix et le stock).
  void _ouvrirFormModification(Map cmd) {
    final adresseCtrl = TextEditingController(text: cmd['adresse']?.toString() ?? '');
    final dateCtrl     = TextEditingController();
    final heureCtrl    = TextEditingController();
    final commentCtrl  = TextEditingController();
    final quantiteCtrl = TextEditingController();
    bool envoi = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Modifier la commande #${cmd['id']}",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                "Laissez vide un champ que vous ne souhaitez pas changer. "
                "Une modification de quantité doit être approuvée par le producteur.",
                style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 16),
              _champModif(adresseCtrl, "Nouvelle adresse", Icons.location_on_outlined),
              const SizedBox(height: 10),
              _champModif(quantiteCtrl, "Nouvelle quantité (nombre de pièces)", Icons.numbers,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _champModif(dateCtrl, "Date de livraison souhaitée (JJ/MM/AAAA)", Icons.calendar_today_outlined),
              const SizedBox(height: 10),
              _champModif(heureCtrl, "Créneau horaire souhaité (ex: 14h-16h)", Icons.access_time),
              const SizedBox(height: 10),
              _champModif(commentCtrl, "Commentaire", Icons.comment_outlined, maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: envoi ? null : () async {
                  final champsVides =
                      adresseCtrl.text.trim().isEmpty && quantiteCtrl.text.trim().isEmpty &&
                      dateCtrl.text.trim().isEmpty && heureCtrl.text.trim().isEmpty &&
                      commentCtrl.text.trim().isEmpty;
                  if (champsVides) {
                    _snack("Renseignez au moins un champ à modifier", false);
                    return;
                  }
                  setS(() => envoi = true);
                  final r = await ApiService.demanderModification(
                    cmdId: int.parse(cmd['id'].toString()),
                    telephone: widget.telephone,
                    quantite: quantiteCtrl.text.trim().isEmpty ? null : int.tryParse(quantiteCtrl.text.trim()),
                    adresse: adresseCtrl.text.trim().isEmpty ? null : adresseCtrl.text.trim(),
                    dateLivraisonSouhaitee: dateCtrl.text.trim().isEmpty ? null : dateCtrl.text.trim(),
                    heureLivraisonSouhaitee: heureCtrl.text.trim().isEmpty ? null : heureCtrl.text.trim(),
                    commentaireClient: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _snack(r['message'] ?? '', r['status'] == 'success');
                  if (r['status'] == 'success') { _chargerCommandes(); _chargerModifications(); }
                },
                child: envoi
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("ENVOYER LA DEMANDE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      )));
  }

  Widget _champModif(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8B0000)),
      filled: true, fillColor: const Color(0xFFF4F7F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );

  Widget _lignDetail(IconData icon, String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ]));

  Widget _boutonAvis(Map cmd) => InkWell(
    onTap: () => _ouvrirFormAvis(cmd),
    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.amber.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.amber.shade200))),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: 16), SizedBox(width: 6),
        Text("Laisser un avis", style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w900)),
      ])));

  void _ouvrirFormAvis(Map cmd) {
    int note = 5;
    final ctrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) =>
        Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Votre avis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text("Commande #${cmd['id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
              GestureDetector(onTap: () => setS(() => note = i + 1),
                child: Icon(i < note ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber, size: 40)))),
            const SizedBox(height: 16),
            TextField(controller: ctrl, maxLines: 3,
              decoration: InputDecoration(hintText: "Partagez votre expérience...",
                filled: true, fillColor: const Color(0xFFF4F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                final r = await ApiService.laisserAvis(
                  telephone: widget.telephone,
                  commandeId: int.parse(cmd['id'].toString()),
                  note: note, commentaire: ctrl.text.trim());
                if (mounted) {
                  _snack(r['message'] ?? "Avis envoyé", r['status'] == 'success');
                  if (r['status'] == 'success') _chargerAvis();
                }
              },
              child: const Text("ENVOYER MON AVIS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
          ]))));
  }

  // ══════════════════════════════════════════════════════════
  //  ONGLET 2 — INVITATIONS / PARRAINAGE
  //  FIX : bouton "Réessayer" si _infosClient == null
  // ══════════════════════════════════════════════════════════
  Widget _tabInvitations() {
    if (_loadingInfos) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));

    // FIX : bouton Réessayer si données non disponibles
    final d = _infosClient;
    if (d == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text("Impossible de charger les données",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Afficher le vrai message d'erreur pour diagnostic
          if (_errorInfos != null) Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: SelectableText(
              "Erreur : " + (_errorInfos ?? "") + "\nNumero : " + widget.telephone,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _chargerInfos,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text("Réessayer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        ])));
    }

    final int nbInvit     = int.tryParse(d['nb_invitations'].toString()) ?? 0;
    final int livGratuite = int.tryParse(d['livraison_gratuite'].toString()) ?? 0;
    final int restantes   = int.tryParse(d['invitations_restantes'].toString()) ?? 5;
    final double progress = (double.tryParse(d['progress_pct'].toString()) ?? 0) / 100;
    final String code     = d['invite_code'] ?? '';
    final String lien     = d['lien_invite'] ?? '';

    return RefreshIndicator(color: const Color(0xFF8B0000), onRefresh: _chargerInfos,
      child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Bannière livraison gratuite
          if (livGratuite == 1) Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.green, Color(0xFF2E7D32)]),
              borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Text("🎁", style: TextStyle(fontSize: 32)), SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Livraison Gratuite !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text("Votre prochaine commande est livrée gratuitement",
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ]),
          ),

          // Code d'invitation
          _carte(child: Column(children: [
            const Text("MON CODE D'INVITATION",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 2)),
              child: Text(code,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 44)),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (mounted) _snack("Code $code copié !", true);
              },
              icon: const Icon(Icons.copy, color: Colors.white, size: 16),
              label: const Text("Copier le code",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          ])),
          const SizedBox(height: 16),

          // Progression
          _carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Invitations validées", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              Text("$nbInvit",
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8B0000), fontSize: 18)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress,
                backgroundColor: Colors.grey.shade200, color: const Color(0xFF8B0000), minHeight: 10)),
            const SizedBox(height: 8),
            Text(
              restantes == 0
                ? "🎉 Palier atteint ! Livraison gratuite débloquée."
                : "Encore $restantes invitation(s) pour une livraison gratuite 🎁",
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          ])),
          const SizedBox(height: 16),

          // Lien de partage
          _carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("LIEN D'INVITATION",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
              child: Text(lien, style: const TextStyle(fontSize: 11, color: Colors.black54),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                // 🆕 Partage natif (WhatsApp, SMS, etc.) — reprend exactement le
                // texte de partagerLien() côté web (views/layout/footer.php)
                try {
                  await Share.share(
                    "Utilise mon code pour t'inscrire :\n$lien",
                    subject: "Rejoins Allo Guinaar !",
                  );
                } catch (_) {
                  await Clipboard.setData(ClipboardData(text: lien));
                  if (mounted) _snack("Lien copié ! Partagez-le avec vos amis.", true);
                }
              },
              icon: const Icon(Icons.share, color: Colors.white, size: 16),
              label: const Text("Partager le lien",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
            const SizedBox(height: 6),
            const Text("Vos amis utilisent votre code à l'inscription",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 10)),
          ])),
        ])));
  }

  // ══════════════════════════════════════════════════════════
  //  ONGLET 3 — MES AVIS
  // ══════════════════════════════════════════════════════════
  Widget _tabAvis() {
    if (_loadingAvis) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));

    final nbAvis     = _infosClient?['nb_avis']          ?? _avis.length;
    final nbPartages = _infosClient?['nb_partages_total'] ?? 0;

    return RefreshIndicator(color: const Color(0xFF8B0000), onRefresh: _chargerAvis,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: _statCard("$nbAvis",    "Avis laissés",  const Color(0xFF8B0000))),
          const SizedBox(width: 12),
          Expanded(child: _statCard("$nbPartages", "Partages",     Colors.blue)),
        ]),
        const SizedBox(height: 16),

        if (_avis.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(child: Column(children: [
            Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text("Vous n'avez pas encore laissé d'avis",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text("Après une livraison, notez votre expérience",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
        ] else ..._avis.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(a['classe_poids'] ?? "Commande #${a['commande_id']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              _etoiles(int.tryParse(a['note'].toString()) ?? 5),
            ]),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
              child: Text('"${a['commentaire'] ?? ''}"',
                style: const TextStyle(color: Colors.black87, fontSize: 12, fontStyle: FontStyle.italic))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(a['date_created']?.toString().substring(0, 10) ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
              Text("${a['nb_partages'] ?? 0} partage(s)",
                style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ]))),
      ]));
  }

  // ══════════════════════════════════════════════════════════
  //  ONGLET 4 — FORMATIONS (Lot 9)
  //  Simple lanceur vers l'écran dédié (catégories → formations →
  //  vidéos), pour éviter d'imbriquer une navigation à 3 niveaux
  //  directement dans un onglet de TabBarView.
  // ══════════════════════════════════════════════════════════
  Widget _tabFormations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: const Color(0xFF8B0000).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.play_circle_outline, size: 44, color: Color(0xFF8B0000)),
          ),
          const SizedBox(height: 20),
          const Text("Espace Formations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            "Apprenez à mieux utiliser Allo Guinaar avec de courtes vidéos.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
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

  // ══════════════════════════════════════════════════════════
  //  ONGLET 5 — GROSSISTE (Lot 7)
  //  Lanceur vers l'écran dédié, même pattern que Formations.
  // ══════════════════════════════════════════════════════════
  Widget _tabGrossiste() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: const Color(0xFFFF6F00).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.storefront_outlined, size: 44, color: Color(0xFFFF6F00)),
          ),
          const SizedBox(height: 20),
          const Text("Espace Grossiste", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            "Achetez en grande quantité (100 pièces minimum) directement auprès de nos fournisseurs, en toute confidentialité.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => GrossisteScreen(telephone: widget.telephone, nom: widget.nom))),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            label: const Text("VOIR LES OFFRES",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
        ]),
      ),
    );
  }

  Widget _carte({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: child);

  Widget _statCard(String val, String label, Color col) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: col)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
    ]));
}