import 'package:flutter/material.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕

// =============================================================
//  ESPACE GROSSISTE — Lot 7 (client)
//  Les offres sont montrées de façon anonymisée (jamais le nom ni le
//  téléphone du producteur). La demande d'achat ne notifie personne
//  d'autre que l'équipe Allo Guinaar, qui gère la mise en relation
//  manuellement — les deux parties ne se rencontrent jamais dans
//  l'app.
// =============================================================
class GrossisteScreen extends StatefulWidget {
  final String telephone;
  final String nom;

  const GrossisteScreen({super.key, required this.telephone, required this.nom});

  @override
  State<GrossisteScreen> createState() => _GrossisteScreenState();
}

class _GrossisteScreenState extends State<GrossisteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loadingOffres = true;
  bool _loadingHistorique = true;
  String? _errorOffres;
  List<dynamic> _offres = [];
  List<dynamic> _historique = [];
  bool _revendeur = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _chargerOffres();
    _chargerHistorique();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _chargerOffres() async {
    setState(() { _loadingOffres = true; _errorOffres = null; });
    final r = await ApiService.offresGrossisteDisponibles();
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _offres = r['data'] ?? []; _loadingOffres = false; });
    } else {
      setState(() { _errorOffres = r['message'] ?? "Erreur de chargement"; _loadingOffres = false; });
    }
  }

  Future<void> _chargerHistorique() async {
    setState(() => _loadingHistorique = true);
    final r = await ApiService.mesDemandesGrossiste(widget.telephone);
    if (!mounted) return;
    setState(() {
      _historique = r['status'] == 'success' ? (r['data'] ?? []) : [];
      _loadingHistorique = false;
    });
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Future<void> _devenirRevendeur() async {
    final r = await ApiService.demanderRevendeur(widget.telephone);
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') setState(() => _revendeur = true);
  }

  void _ouvrirFormAchat(Map offre) {
    final qteCtrl = TextEditingController(text: offre['quantite_min'].toString());
    final nomCtrl = TextEditingController(text: widget.nom == "Invité" ? '' : widget.nom);
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
              Text(offre['produit'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text("${offre['prix_unitaire']} F / pièce — minimum ${offre['quantite_min']} pièces",
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200)),
                child: const Text(
                  "Votre demande sera transmise à notre équipe, qui vous recontactera pour finaliser la commande. La livraison est à négocier séparément et reste à votre charge.",
                  style: TextStyle(fontSize: 11, color: Colors.black87)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nomCtrl,
                decoration: InputDecoration(labelText: "Votre nom", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qteCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Quantité souhaitée", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: envoi ? null : () async {
                  final qte = int.tryParse(qteCtrl.text.trim()) ?? 0;
                  if (nomCtrl.text.trim().isEmpty) { _snack("Indiquez votre nom", false); return; }
                  if (qte < (int.tryParse(offre['quantite_min'].toString()) ?? 100)) {
                    _snack("Quantité minimum : ${offre['quantite_min']} pièces", false);
                    return;
                  }
                  setS(() => envoi = true);
                  final r = await ApiService.soumettreDemandeGrossiste(
                    offreId: int.parse(offre['id'].toString()),
                    telephone: widget.telephone,
                    nom: nomCtrl.text.trim(),
                    quantite: qte,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _snack(r['message'] ?? '', r['status'] == 'success');
                  if (r['status'] == 'success') { _chargerOffres(); _chargerHistorique(); }
                },
                child: envoi
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("ENVOYER LA DEMANDE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Espace Grossiste", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [HomeNavigator.bouton()], // 🆕 retour à l'accueil à tout moment
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFFFF6F00),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6F00),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          tabs: const [Tab(text: "Offres"), Tab(text: "Mes demandes")],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [_tabOffres(), _tabHistorique()]),
    );
  }

  Widget _tabOffres() {
    return RefreshIndicator(
      color: const Color(0xFFFF6F00),
      onRefresh: _chargerOffres,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau "devenir revendeur"
          if (!_revendeur) Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: [
              const Icon(Icons.storefront, color: Colors.orange), const SizedBox(width: 10),
              const Expanded(child: Text("Vous achetez pour revendre ? Signalez-vous comme revendeur.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              TextButton(onPressed: _devenirRevendeur, child: const Text("Je suis revendeur")),
            ]),
          ),
          if (_loadingOffres) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6F00))))
          else if (_errorOffres != null) Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorOffres!, style: const TextStyle(color: Colors.grey))))
          else if (_offres.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("Aucune offre grossiste disponible pour le moment",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))
          else ..._offres.map((o) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['produit'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _infoChip(Icons.payments_outlined, "${o['prix_unitaire']} F/pièce")),
                const SizedBox(width: 8),
                Expanded(child: _infoChip(Icons.inventory_2_outlined, "${o['quantite_disponible']} dispo.")),
              ]),
              const SizedBox(height: 6),
              _infoChip(Icons.production_quantity_limits, "Minimum ${o['quantite_min']} pièces"),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 42, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => _ouvrirFormAchat(o),
                child: const Text("DEMANDER CETTE OFFRE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)))),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String texte) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey), const SizedBox(width: 4),
      Flexible(child: Text(texte, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]));

  Widget _tabHistorique() {
    if (_loadingHistorique) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)));
    if (_historique.isEmpty) {
      return const Center(child: Text("Aucune demande envoyée pour l'instant",
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
    }
    return RefreshIndicator(
      color: const Color(0xFFFF6F00),
      onRefresh: _chargerHistorique,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historique.length,
        itemBuilder: (ctx, i) {
          final d = _historique[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['produit'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 6),
              Text("${d['quantite_demandee']} pièces × ${d['prix_unitaire_snapshot']} F = ${d['montant_total']} F",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF6F00).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text((d['statut'] ?? '').toString().toUpperCase(),
                  style: const TextStyle(color: Color(0xFFFF6F00), fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ]),
          );
        },
      ),
    );
  }
}
