
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'payment_screen.dart';
import 'analytics_service.dart'; // 🆕 Lot 11

class CheckoutScreen extends StatefulWidget {
  final Map<String, int> panier;
  final int totalPrice;
  final double? latitude;
  final double? longitude;
  final String nomClient;
  final String telClient;
  final List<dynamic> produits;
  // 🆕 apiag-beta : nécessaire pour consommer un crédit "livraison
  // gratuite" obtenu par parrainage (voir mon_espace_screen.dart).
  // Ni surgithup ni apiag-beta ne transmettaient ce champ à l'API
  // commander() — la fonctionnalité de parrainage restait donc
  // inopérante côté mobile ; complété ici pour rendre le parrainage
  // pleinement fonctionnel de bout en bout.
  final int userId;

  const CheckoutScreen({
    super.key,
    required this.panier,
    required this.totalPrice,
    this.latitude,
    this.longitude,
    this.nomClient = "",
    this.telClient = "",
    this.produits  = const [],
    this.userId    = 0,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final TextEditingController _nomController;
  late final TextEditingController _telController;
  final TextEditingController _adresseController = TextEditingController();

  bool _isLoading  = false;
  bool _isLocating = false;
  bool _gpsPret    = false;

  double? _lat;
  double? _lng;

  String _modePaiement = "livraison";

  // Frais livraison retournés par l'API
  int? _fraisLivraison;
  int? _totalFinal;
  int? _basePriceFinal;

  static const int _fraisMinimum = 600;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.nomClient);
    _telController = TextEditingController(text: widget.telClient);

    if (widget.latitude != null && widget.longitude != null) {
      _lat     = widget.latitude;
      _lng     = widget.longitude;
      _gpsPret = true;
    } else {
      _chargerGpsDepuisCache();
    }
  }

  Future<void> _chargerGpsDepuisCache() async {
    final coords = await LocationService.obtenirCoordonnees();
    if (coords != null && mounted) {
      setState(() {
        _lat     = coords['lat'];
        _lng     = coords['lng'];
        _gpsPret = true;
      });
    }
  }

  Future<void> _relocaliser() async {
    setState(() => _isLocating = true);
    final coords = await LocationService.obtenirCoordonnees();
    if (!mounted) return;
    if (coords != null) {
      setState(() {
        _lat     = coords['lat'];
        _lng     = coords['lng'];
        _gpsPret = true;
      });
    } else {
      await LocationService.ouvrirParametres();
    }
    setState(() => _isLocating = false);
  }

  String _getNomProduit(String id) {
    try {
      final p = widget.produits.firstWhere((p) => p['id'] == id);
      return p['short'] ?? id;
    } catch (_) { return id; }
  }

  int _getPrixProduit(String id) {
    try {
      final p = widget.produits.firstWhere((p) => p['id'] == id);
      final prix = p['prix'];
      return prix is String ? int.parse(prix) : (prix as int);
    } catch (_) { return 0; }
  }

  int _getTotalItems() => widget.panier.values.fold(0, (s, v) => s + v);

  // Texte affiché pour la livraison avant commande
  String get _livLabel {
    if (_getTotalItems() >= 10) return "GRATUITE 🎉";
    if (!_gpsPret) return "-- F";
    return "$_fraisMinimum F minimum";
  }

  Color get _livColor {
    if (_getTotalItems() >= 10) return Colors.green;
    if (!_gpsPret) return Colors.grey;
    return Colors.orange.shade800;
  }

  // Total estimé avant commande
  int get _totalEstime {
    if (_getTotalItems() >= 10) return widget.totalPrice;
    if (!_gpsPret) return widget.totalPrice;
    return widget.totalPrice + _fraisMinimum;
  }

  void _validerCommande() async {
    if (_nomController.text.isEmpty || _telController.text.isEmpty) {
      _showSnack("Remplissez vos informations", Colors.red);
      return;
    }
    if (!_gpsPret || _lat == null || _lng == null) {
      _showSnack("Veuillez activer votre GPS 📍", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> panierFormate = [];
    widget.panier.forEach((key, value) {
      if (value > 0) panierFormate.add({"classe": key, "quantite": value});
    });

    final orderData = {
      "nom":           _nomController.text,
      "tel":           _telController.text,
      "adresse":       _adresseController.text.isEmpty ? "Position GPS" : _adresseController.text,
      "lat":           _lat,
      "lng":           _lng,
      "mode_paiement": _modePaiement == "paytech" ? "immédiat" : "livraison",
      "panier":        panierFormate,
      if (widget.userId > 0) "user_id": widget.userId, // 🆕 apiag-beta (parrainage)
    };

    final response = await ApiService.commander(orderData);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      // Récupérer les vrais frais de l'API
      final int frais  = response['frais_livraison'] ?? 0;
      final int base   = response['base_price']      ?? widget.totalPrice;
      final int total  = response['total']            ?? (base + frais);

      // 🆕 Lot 11 : événement d'achat pour GA4
      AnalyticsService.commandePassee(montant: total.toDouble(), quantite: _getTotalItems());

      if (_modePaiement == 'paytech') {
        final String? payUrl = response['paytech_url'] ?? response['payment_url'] ?? response['redirect_url'];
        final int cmdId      = response['commande_id'] ?? 0;
        if (payUrl != null && payUrl.isNotEmpty) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PaymentScreen(paymentUrl: payUrl, commandeId: cmdId, montant: total),
          ));
          return;
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, size: 60, color: Colors.green),
                ),
                const SizedBox(height: 16),
                const Text("Commande Confirmée !",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green)),
                const SizedBox(height: 12),
                // Récapitulatif final
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _dialogRow("Produits", "$base F"),
                      const SizedBox(height: 6),
                      _dialogRow(
                        "Livraison",
                        frais == 0 ? "GRATUITE" : "$frais F",
                        valueColor: frais == 0 ? Colors.green : Colors.orange.shade800,
                      ),
                      const Divider(height: 16),
                      _dialogRow("TOTAL NET", "$total F",
                          bold: true, valueColor: const Color(0xFF8B0000), fontSize: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text("Commande n°${response['commande_id']}",
                    style: const TextStyle(color: Colors.black45, fontSize: 12)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text("RETOUR AU CATALOGUE",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      _showSnack(response['message'] ?? "Erreur réseau", Colors.red);
    }
  }

  Widget _dialogRow(String label, String value,
      {bool bold = false, Color? valueColor, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: Colors.black54)),
        Text(value, style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Colors.black87)),
      ],
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems     = _getTotalItems();
    final bool livGratuite   = totalItems >= 10;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text("Votre Commande",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── RÉCAPITULATIF PANIER ─────────────────────────────
            const Text("🛒 DÉTAIL DU PANIER",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Lignes produits
                  ...widget.panier.entries.where((e) => e.value > 0).map((e) {
                    final nom  = _getNomProduit(e.key);
                    final prix = _getPrixProduit(e.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B0000).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text("${e.value}x",
                                style: const TextStyle(fontWeight: FontWeight.w900,
                                    fontSize: 11, color: Color(0xFF8B0000)))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(nom,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          Text("${e.value * prix} F",
                              style: const TextStyle(fontWeight: FontWeight.w900,
                                  color: Color(0xFF8B0000), fontSize: 13)),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 20),

                  // Sous-total produits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("SOUS-TOTAL",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey)),
                      Text("${widget.totalPrice} F",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Livraison
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("LIVRAISON",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _livColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_livLabel,
                            style: TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 12, color: _livColor)),
                      ),
                    ],
                  ),

                  // Message GPS
                  if (!_gpsPret) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(children: [
                        Icon(Icons.location_off, size: 14, color: Colors.red),
                        SizedBox(width: 6),
                        Expanded(child: Text(
                          "Confirmez votre position GPS pour voir les frais exacts.",
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        )),
                      ]),
                    ),
                  ],

                  // Message livraison gratuite
                  if (livGratuite) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.local_shipping, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Expanded(child: Text("🎉 Livraison gratuite pour votre commande !",
                            style: TextStyle(fontSize: 11, color: Colors.green,
                                fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  ],

                  // Encouragement livraison gratuite
                  if (!livGratuite && _gpsPret) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          "Livraison gratuite dès 10 articles. Il vous manque ${10 - totalItems} article(s).",
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                        )),
                      ]),
                    ),
                  ],

                  const Divider(height: 20),

                  // TOTAL NET
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TOTAL NET",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          if (_gpsPret && !livGratuite)
                            Text("livraison min. incluse",
                                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                      Text("${_gpsPret ? _totalEstime : widget.totalPrice} F",
                          style: const TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 22, color: Color(0xFF8B0000))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── GPS ──────────────────────────────────────────────
            const Text("📍 LOCALISATION",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _gpsPret ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gpsPret ? Colors.green : Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(_gpsPret ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _gpsPret ? Colors.green : Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _gpsPret ? "Position GPS acquise ✅" : "⚠️ Position requise (OBLIGATOIRE)",
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: _gpsPret ? Colors.green : Colors.red, fontSize: 13),
                  )),
                  TextButton.icon(
                    onPressed: _isLocating ? null : _relocaliser,
                    icon: _isLocating
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                        : const Icon(Icons.refresh, size: 14, color: Colors.blueAccent),
                    label: const Text("Confirmer",
                        style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── ADRESSE ──────────────────────────────────────────
            const Text("🏠 OÙ LIVRER ?",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: _nomController,
                  decoration: InputDecoration(
                    labelText: "Nom complet",
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _telController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Téléphone",
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adresseController,
              decoration: InputDecoration(
                hintText: "Adresse détaillée (quartier, rue, repère...)",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // ─── MODE DE PAIEMENT ─────────────────────────────────
            const Text("💳 MODE DE PAIEMENT",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Material(color: Colors.transparent, child: Column( // 🆕 corrige "ListTile ink splash invisible"
                children: [
                  RadioListTile(
                    title: Row(children: [
                      const Text("Paiement immédiat",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("IMMÉDIAT",
                            style: TextStyle(color: Colors.green, fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                    ]),
                    subtitle: const Text("Mobile Money / Carte (PayTech)",
                        style: TextStyle(fontSize: 12)),
                    value: "paytech",
                    groupValue: _modePaiement,
                    activeColor: const Color(0xFF8B0000),
                    onChanged: (val) => setState(() => _modePaiement = val.toString()),
                  ),
                  const Divider(height: 1),
                  RadioListTile(
                    title: const Text("À la livraison",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Paiement en espèces au livreur",
                        style: TextStyle(fontSize: 12)),
                    value: "livraison",
                    groupValue: _modePaiement,
                    activeColor: const Color(0xFF8B0000),
                    onChanged: (val) => setState(() => _modePaiement = val.toString()),
                  ),
                  if (_modePaiement == 'paytech')
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          "Vous serez redirigé vers la page de paiement PayTech.",
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        )),
                      ]),
                    ),
                ],
              )),
            ),
            const SizedBox(height: 32),

            // ─── BOUTON ───────────────────────────────────────────
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
                : SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gpsPret
                            ? (_modePaiement == 'paytech' ? Colors.green[700] : Colors.black)
                            : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _validerCommande,
                      icon: Icon(
                        _modePaiement == "paytech" ? Icons.payment : Icons.check_circle,
                        color: Colors.white,
                      ),
                      label: Text(
                        _modePaiement == "paytech"
                            ? "PROCÉDER AU PAIEMENT"
                            : "CONFIRMER LA COMMANDE",
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
