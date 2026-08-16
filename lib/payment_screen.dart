import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final int commandeId;
  final int montant;

  const PaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.commandeId,
    required this.montant,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paiementTermine = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            // ✅ PayTech redirige vers l'URL de succès définie côté PHP
            if (url.contains('/success') || url.contains('success')) {
              _afficherResultat(succes: true);
              return NavigationDecision.prevent;
            }

            // ❌ PayTech redirige vers l'URL d'annulation
            if (url.contains('/cancel') || url.contains('cancel')) {
              _afficherResultat(succes: false);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _afficherResultat({required bool succes}) {
    if (_paiementTermine) return;
    _paiementTermine = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Icône animée
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: succes ? Colors.green.shade50 : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                succes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 60,
                color: succes ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              succes ? "Paiement Réussi !" : "Paiement Annulé",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: succes ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              succes
                  ? "Votre commande n°${widget.commandeId} est confirmée.\nMontant payé : ${widget.montant} F"
                  : "Votre paiement n'a pas abouti.\nVotre commande n°${widget.commandeId} reste en attente.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: succes ? Colors.green : const Color(0xFF8B0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  // Ferme dialog + PaymentScreen + CheckoutScreen → retour catalogue
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(succes);
                  if (succes) Navigator.of(context).pop();
                },
                child: Text(
                  succes ? "RETOUR AU CATALOGUE" : "RÉESSAYER PLUS TARD",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: "Annuler",
          onPressed: () => _afficherResultat(succes: false),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.white70, size: 16),
            SizedBox(width: 6),
            Text(
              "Paiement Sécurisé",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: const Color(0xFF6B0000),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_outlined, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Cmd #${widget.commandeId}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${widget.montant} F",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Indicateur de chargement par-dessus la WebView
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF8B0000)),
                    SizedBox(height: 20),
                    Text(
                      "Connexion à PayTech...",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Veuillez patienter",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
