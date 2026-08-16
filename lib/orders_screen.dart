import 'package:flutter/material.dart';
import 'api_service.dart';

class OrdersScreen extends StatefulWidget {
  final String telephone; // On a besoin du numéro pour chercher les commandes

  const OrdersScreen({super.key, required this.telephone});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _commandes = [];

  @override
  void initState() {
    super.initState();
    _chargerCommandes();
  }

  void _chargerCommandes() async {
    final response = await ApiService.getMesCommandes(widget.telephone);

    if (response['status'] == 'success') {
      setState(() {
        _commandes = response['data'];
        _isLoading = false;
      });
    } else {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? "Erreur"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fonction pour donner une couleur selon le statut
  Color _getStatusColor(String statut) {
    if (statut == 'Livrée et payée') return Colors.green;
    if (statut == 'Annulée') return Colors.red;
    return Colors.orange; // En attente, En cours, En route...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text("Mes Commandes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _commandes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon(Icons.box_open, size: 80, color: Colors.grey),
                      Icon(Icons.inventory_2, size: 80, color: Colors.grey),                      SizedBox(height: 16),
                      Text("Aucune commande pour le moment", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _commandes.length,
                  itemBuilder: (context, index) {
                    final cmd = _commandes[index];
                    Color statusColor = _getStatusColor(cmd['statut']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Cmd #${cmd['id']}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text("${cmd['prix_total']} F", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(cmd['classe_poids'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  cmd['statut'].toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                                ),
                              ),
                              Text("${cmd['quantite']} articles", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}