import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'api_service.dart';

// =============================================================
//  PROPOSITION DE COMMANDE — écran plein écran façon Uber/Yango
//  Sonnerie forte en boucle jusqu'à acceptation, refus, ou
//  expiration du délai de 2 minutes. Le producteur ne peut pas
//  quitter cet écran sans faire un choix explicite (bouton retour
//  désactivé) — cohérent avec "il doit voir clairement les boutons
//  Accepter et Refuser".
// =============================================================
class PropositionCommandeScreen extends StatefulWidget {
  final String telephone;
  final int propositionId;
  final int cmdId;
  final int delaiSecondes; // durée totale du compte à rebours
  // Détails optionnels (préremplis si connus, ex. via mes_propositions_en_attente)
  final String? nomClient;
  final String? adresse;
  final String? articles;
  final String? montant;

  const PropositionCommandeScreen({
    super.key,
    required this.telephone,
    required this.propositionId,
    required this.cmdId,
    this.delaiSecondes = 120,
    this.nomClient,
    this.adresse,
    this.articles,
    this.montant,
  });

  @override
  State<PropositionCommandeScreen> createState() => _PropositionCommandeScreenState();
}

class _PropositionCommandeScreenState extends State<PropositionCommandeScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _sirene = AudioPlayer();
  Timer? _minuteur;
  late int _secondesRestantes;
  bool _enCours = false;
  bool _expiree = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _secondesRestantes = widget.delaiSecondes;
    _demarrerSirene();
    _demarrerMinuteur();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  Future<void> _demarrerSirene() async {
    try {
      await _sirene.setReleaseMode(ReleaseMode.loop);
      await _sirene.play(AssetSource('sounds/alarme_commande.mp3'), volume: 1.0);
    } catch (_) {
      // Si le fichier son est absent, l'écran reste utilisable sans
      // bloquer — mieux vaut un écran silencieux qu'un plantage.
    }
  }

  void _demarrerMinuteur() {
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondesRestantes--);
      if (_secondesRestantes <= 0) {
        _minuteur?.cancel();
        _arreterSirene();
        setState(() => _expiree = true);
      }
    });
  }

  Future<void> _arreterSirene() async {
    try { await _sirene.stop(); } catch (_) {}
  }

  Future<void> _repondre(String reponse) async {
    if (_enCours || _expiree) return;
    setState(() => _enCours = true);
    await _arreterSirene();
    _minuteur?.cancel();

    final r = await ApiService.repondreProposition(
      propositionId: widget.propositionId,
      telephone: widget.telephone,
      reponse: reponse,
    );

    if (!mounted) return;

    if (r['status'] == 'success') {
      _fermerAvecMessage(
        reponse == 'accepter' ? "✅ Commande acceptée !" : "Commande transmise au producteur suivant",
        Colors.green,
      );
    } else {
      // Ex. déjà répondue/expirée côté serveur (quelqu'un d'autre a été
      // plus rapide, ou le délai a expiré juste avant l'action locale)
      _fermerAvecMessage(r['message'] ?? "Cette commande n'est plus disponible", Colors.orange);
    }
  }

  void _fermerAvecMessage(String message, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur, duration: const Duration(seconds: 3)),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _sirene.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _tempsFormate {
    final m = _secondesRestantes ~/ 60;
    final s = _secondesRestantes % 60;
    return "${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 🆕 Le producteur doit faire un choix explicite — pas de sortie
      // accidentelle par le bouton retour tant qu'il n'a pas répondu.
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF8B0000),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (ctx, child) => Transform.scale(
                  scale: 1.0 + (_pulseCtrl.value * 0.08),
                  child: child,
                ),
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(_expiree ? Icons.timer_off : Icons.notifications_active,
                    color: const Color(0xFF8B0000), size: 46),
                ),
              ),
              const SizedBox(height: 16),
              Text(_expiree ? "TEMPS ÉCOULÉ" : "NOUVELLE COMMANDE",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 8),
              if (!_expiree)
                Text(_tempsFormate,
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),

              // Détails de la commande
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Commande #${widget.cmdId}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF8B0000))),
                      const SizedBox(height: 16),
                      if (widget.nomClient != null) _ligneInfo(Icons.person_outline, "Client", widget.nomClient!),
                      if (widget.adresse != null) _ligneInfo(Icons.location_on_outlined, "Adresse", widget.adresse!),
                      if (widget.articles != null) _ligneInfo(Icons.shopping_bag_outlined, "Articles", widget.articles!),
                      if (widget.montant != null) _ligneInfo(Icons.payments_outlined, "Montant", widget.montant!),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            "Si vous ne répondez pas à temps, la commande sera automatiquement proposée à un autre producteur.",
                            style: TextStyle(fontSize: 11, color: Colors.black87))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Boutons Accepter / Refuser
              if (_expiree)
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("FERMER", style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.w900))))
              else
                Row(children: [
                  Expanded(child: SizedBox(height: 60, child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _enCours ? null : () => _repondre('refuser'),
                    child: const Text("REFUSER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))))),
                  const SizedBox(width: 14),
                  Expanded(child: SizedBox(height: 60, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _enCours ? null : () => _repondre('accepter'),
                    child: _enCours
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF8B0000), strokeWidth: 3))
                      : const Text("ACCEPTER", style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.w900, fontSize: 16))))),
                ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String label, String valeur) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, size: 18, color: Colors.grey),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}
