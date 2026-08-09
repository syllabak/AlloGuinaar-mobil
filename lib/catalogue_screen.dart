import 'dart:async'; // 🆕 Timer (rotation des textes promotionnels)
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_screen.dart';
import 'checkout_screen.dart';
import 'session_service.dart';   // 🆕
import 'location_service.dart';  // 🆕
import 'mon_espace_screen.dart'; // 🆕 apiag-beta (parrainage, avis, suivi)
import 'producteur_screen.dart'; // 🆕 Lot 3
import 'package:url_launcher/url_launcher.dart';

class CatalogueScreen extends StatefulWidget {
  // 🆕 Paramètres injectés depuis main.dart (session persistante)
  final String initialNom;
  final String initialPhone;
  final int    initialUserId; // 🆕 apiag-beta

  const CatalogueScreen({
    super.key,
    this.initialNom    = "Invité",
    this.initialPhone  = "",
    this.initialUserId = 0,   // 🆕 apiag-beta
  });

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  bool _isLoading = true;
  List<dynamic> _produits = [];
  final Map<String, int> _panier = {};

  late String _userName;
  late String _userPhone;
  late int    _userId; // 🆕 apiag-beta

  // 🆕 Textes promotionnels administrables (rotation automatique)
  List<String> _textesPromo = ["Livraison gratuite dès 5 produits. Paiement à la livraison."]; // repli si le chargement échoue
  int _indexPromo = 0;
  Timer? _timerPromo;

  @override
  void initState() {
    super.initState();
    // 🆕 Initialiser depuis la session reçue par main.dart
    _userName  = widget.initialNom;
    _userPhone = widget.initialPhone;
    _userId    = widget.initialUserId; // 🆕 apiag-beta
    _chargerProduits();
    _chargerTextesPromo(); // 🆕
  }

  // 🆕 Charge les slogans actifs et démarre la rotation automatique
  Future<void> _chargerTextesPromo() async {
    try {
      final r = await ApiService.textesPromoActifs();
      if (r['status'] == 'success') {
        final List<dynamic> data = r['data'] ?? [];
        final textes = data.map((t) => t['texte'].toString()).toList();
        if (textes.isNotEmpty && mounted) {
          setState(() => _textesPromo = textes);
        }
      }
    } catch (_) {
      // Silencieux : le texte de repli reste affiché, jamais bloquant
    }
    if (_textesPromo.length > 1) {
      _timerPromo = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() => _indexPromo = (_indexPromo + 1) % _textesPromo.length);
      });
    }
  }

  @override
  void dispose() {
    _timerPromo?.cancel(); // 🆕
    super.dispose();
  }

  // 🆕 apiag-beta : ouvrir l'espace client (commandes, invitations, avis)
  void _ouvrirMonEspace() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonEspaceScreen(
            telephone: _userPhone,
            nom: _userName,
            userId: _userId,
          ),
        ),
      );

  void _chargerProduits() async {
    final response = await ApiService.getCatalogue();
    if (response['status'] == 'success') {
      Map<String, dynamic> dataMap = response['data'];
      setState(() {
        _produits = dataMap.entries.map((entry) {
          var item = entry.value;
          item['id'] = entry.key;
          _panier[entry.key] = 0;
          return item;
        }).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? "Erreur")));
      }
    }
  }

  void _updateQty(String id, int change) {
    setState(() {
      int newQty = (_panier[id] ?? 0) + change;
      _panier[id] = newQty < 0 ? 0 : newQty;
    });
  }

  int _getTotalItems() => _panier.values.fold(0, (sum, v) => sum + v);

  int _getTotalPrice() {
    int total = 0;
    for (var produit in _produits) {
      int qty  = _panier[produit['id']] ?? 0;
      int prix = produit['prix'] is String ? int.parse(produit['prix']) : produit['prix'];
      total   += qty * prix;
    }
    if (_getTotalItems() >= 10) total = (total * 0.95).round();
    return total;
  }

  // 🆕 Déconnexion avec effacement de la session persistante
void _deconnecter() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Mon compte"),
      content: const Text("Que souhaitez-vous faire ?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await SessionService.supprimer();
            if (!mounted) return;
            setState(() {
              _userName  = "Invité";
              _userPhone = "";
              _userId    = 0; // 🆕 apiag-beta
              _panier.updateAll((key, _) => 0);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Vous êtes déconnecté"),
                backgroundColor: Colors.orange,
              ),
            );
          },
          child: const Text(
            "Se déconnecter",
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _confirmerSuppression();
          },
          child: const Text(
            "Supprimer mon compte",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

void _confirmerSuppression() {
  final TextEditingController passCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        "Supprimer mon compte",
        style: TextStyle(color: Colors.red),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Cette action est irréversible. Toutes vos données seront supprimées définitivement.",
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Confirmez votre mot de passe",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: () async {
            final pwd = passCtrl.text;
            Navigator.pop(ctx);
            await _supprimerCompte(pwd);
          },
          child: const Text(
            "Confirmer la suppression",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Future<void> _supprimerCompte(String password) async {
  if (password.isEmpty) return;
  try {
    final response = await ApiService.supprimerCompte(_userPhone, password);
    if (response['status'] == 'success') {
      await SessionService.supprimer();
      if (!mounted) return;
      setState(() {
        _userName  = "Invité";
        _userPhone = "";
        _userId    = 0; // 🆕 apiag-beta
        _panier.updateAll((key, _) => 0);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Compte supprimé avec succès"),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? "Erreur lors de la suppression"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Erreur réseau"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // 🆕 Naviguer vers CheckoutScreen en injectant les coordonnées GPS
  void _allerAuCheckout() async {
    // Récupère les coords depuis le cache (instantané, pas de popup)
    final coords = await LocationService.obtenirCoordonnees();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          panier:     _panier,
          totalPrice: _getTotalPrice(),
          // 🆕 Passe les coordonnées au checkout pour l'API commander()
          latitude:   coords?['lat'],
          longitude:  coords?['lng'],
          nomClient:  _userName  == "Invité" ? "" : _userName,
          telClient:  _userPhone,
           produits:   _produits,  // 🆕 AJOUTER CETTE LIGNE
          userId:     _userId,    // 🆕 apiag-beta (parrainage)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _getTotalItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
              Image.asset(
                'assets/icon/icon.png',
                width: 40,
                height: 40,
              ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                    children: [
                      TextSpan(text: 'ALLO',    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                      TextSpan(text: 'GUINAAR', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8B0000))),
                    ],
                  ),
                ),
                Text(
                  _userName == "Invité" ? "Bienvenue !" : "Bonjour, $_userName",
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_userName == "Invité")
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  // 🆕 login_screen.dart sauvegarde déjà la session ;
                  //    ici on met juste à jour l'UI
                  if (result != null && result is Map) {
                    // 🆕 Lot 3 : un compte producteur connecté via l'onglet
                    // Client (qui ne filtre pas par rôle) est redirigé
                    // directement vers son espace dédié.
                    if ((result['role'] ?? '') == 'producteur') {
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProducteurScreen(
                            telephone: result['tel'] ?? '',
                            nom: result['nom'] ?? 'Producteur',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _userName  = result['nom']     ?? "Invité";
                      _userPhone = result['tel']     ?? "";
                      _userId    = result['user_id'] ?? 0; // 🆕 apiag-beta
                    });
                    // 🆕 CORRIGÉ : au lieu de rester sur CE MÊME écran
                    // (dépilé/repeint, pattern lié à un écran noir signalé
                    // spécifiquement après connexion client, jamais côté
                    // producteur/livreur qui utilisent déjà une approche
                    // différente), on force un écran neuf pour repartir
                    // sur un rendu propre, sans transition de retour.
                    if (!mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (_) => CatalogueScreen(
                        initialNom: _userName,
                        initialPhone: _userPhone,
                        initialUserId: _userId,
                      ),
                    ));
                  }
                },
                icon:  const Icon(Icons.person_outline, color: Color(0xFF8B0000), size: 18),
                label: const Text("Connexion", style: TextStyle(color: Color(0xFF8B0000), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            )
          else
            Row(
              children: [
                // 🆕 apiag-beta : Mon Espace (commandes + suivi + facture,
                // invitations, avis). Le bouton COMMANDES a été retiré :
                // doublon avec l'onglet Commandes déjà présent dans
                // Mon Espace (signalé et confirmé par l'utilisateur).
                GestureDetector(
                  onTap: _ouvrirMonEspace,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text("MON ESPACE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // 🆕 Bouton déconnexion retiré d'ici — centralisé dans
                // Paramètres uniquement (Mon Espace → icône ⚙️), pour
                // éviter le doublon signalé par l'utilisateur.
              ],
            ),
        ],
      ),

      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          else
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(
                  child: Text(
                    "Le marché\nDANS VOTRE POCHE",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1),
                  ),
                ),
                const SizedBox(height: 24),

                // Bannière promotionnelle — 🆕 textes administrables en
                // base (voir textes_promotionnels), rotation automatique
                // si plusieurs slogans actifs.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFEF08A), Color(0xFFFEF9C3)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.local_shipping, color: Colors.amber),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            _textesPromo[_indexPromo % _textesPromo.length],
                            key: ValueKey(_indexPromo),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bannière Fournisseur
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storefront, color: Colors.green, size: 24),
                          SizedBox(width: 8),
                          Expanded(child: Text("Vous êtes éleveur ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Vendez vos poulets directement à des milliers de clients.", style: TextStyle(color: Colors.black87, fontSize: 12)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final Uri url = Uri.parse('https://alloguinaar.danov.sn/?role=producteur&register=1');
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le navigateur")));
                            }
                          },
                          child: const Text("Devenir Fournisseur", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Titre catalogue
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF8B0000), width: 4))),
                  child: const Text("CATALOGUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey)),
                ),
                const SizedBox(height: 16),

                // Liste des produits
                ..._produits.map((produit) {
                  String id  = produit['id'];
                  int    qty = _panier[id] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80, height: 80,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: (produit['image'] != null && produit['image'].toString().isNotEmpty)
                              ? Image.network(
                            produit['image'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey, size: 30),
                          )
                              : const Icon(Icons.fastfood, color: Colors.grey, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(produit['short'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text("${produit['prix']} F", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8B0000), fontSize: 14)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                color: qty > 0 ? const Color(0xFF8B0000) : Colors.grey,
                                onPressed: () => _updateQty(id, -1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              Text("$qty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                color: Colors.green[700],
                                onPressed: () => _updateQty(id, 1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Espace pour ne pas que le bouton flottant cache le dernier item
                const SizedBox(height: 90),
              ],
            ),

          // Bouton panier flottant
          if (totalItems > 0)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: GestureDetector(
                onTap: _allerAuCheckout, // 🆕 GPS injecté automatiquement
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: Badge(
                              label: Text("$totalItems"),
                              backgroundColor: Colors.amber,
                              child: const Icon(Icons.shopping_bag, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("VOIR MON PANIER",    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text("Valider la commande", style: TextStyle(color: Colors.white,   fontSize: 14, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                      Text("${_getTotalPrice()} F", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
