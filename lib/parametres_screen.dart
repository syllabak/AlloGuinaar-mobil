import 'package:flutter/material.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕
import 'session_service.dart';
import 'login_screen.dart';

// =============================================================
//  PARAMÈTRES — écran unique réutilisé par Client, Producteur et
//  Livreur. Centralise : informations personnelles, sécurité
//  (mot de passe, téléphone), notifications, déconnexion et
//  suppression de compte (anonymisation).
// =============================================================
class ParametresScreen extends StatefulWidget {
  final String telephone;
  final String nom;

  const ParametresScreen({super.key, required this.telephone, required this.nom});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profil;
  bool _notifActives = true;

  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Future<void> _charger() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.obtenirProfil(widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      final d = r['data'];
      setState(() {
        _profil = d;
        _nomCtrl.text = d['nom_complet'] ?? '';
        _emailCtrl.text = d['email'] ?? '';
        _adresseCtrl.text = d['adresse'] ?? '';
        _notifActives = d['notifications_actives'] == true;
        _loading = false;
      });
    } else {
      setState(() { _error = r['message'] ?? "Erreur de chargement"; _loading = false; });
    }
  }

  Future<void> _enregistrerProfil() async {
    final r = await ApiService.modifierProfil(
      telephone: widget.telephone,
      nomComplet: _nomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim(),
    );
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
  }

  Future<void> _toggleNotifications(bool v) async {
    setState(() => _notifActives = v);
    final r = await ApiService.modifierNotifications(telephone: widget.telephone, actif: v);
    if (!mounted) return;
    if (r['status'] != 'success') {
      setState(() => _notifActives = !v); // annuler si échec
      _snack(r['message'] ?? "Erreur", false);
    }
  }

  void _ouvrirChangerMotDePasse() {
    final ancienCtrl = TextEditingController();
    final nouveauCtrl = TextEditingController();
    final confirmerCtrl = TextEditingController();
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
              const Text("Changer le mot de passe", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: ancienCtrl, obscureText: true,
                decoration: InputDecoration(labelText: "Mot de passe actuel", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: nouveauCtrl, obscureText: true,
                decoration: InputDecoration(labelText: "Nouveau mot de passe (6 caractères min.)", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: confirmerCtrl, obscureText: true,
                decoration: InputDecoration(labelText: "Confirmer le nouveau mot de passe", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: envoi ? null : () async {
                  if (nouveauCtrl.text != confirmerCtrl.text) {
                    _snack("Les deux mots de passe ne correspondent pas", false);
                    return;
                  }
                  setS(() => envoi = true);
                  final r = await ApiService.modifierMotDePasse(
                    telephone: widget.telephone,
                    ancienMotDePasse: ancienCtrl.text,
                    nouveauMotDePasse: nouveauCtrl.text,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _snack(r['message'] ?? '', r['status'] == 'success');
                },
                child: envoi
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("VALIDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      )));
  }

  void _ouvrirChangerTelephone() {
    final nouveauTelCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
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
              const Text("Changer de numéro de téléphone", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text("Ce numéro sert aussi à vous connecter — vous devrez l'utiliser la prochaine fois.",
                style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 16),
              TextField(controller: nouveauTelCtrl, keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: "Nouveau numéro", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: passwordCtrl, obscureText: true,
                decoration: InputDecoration(labelText: "Mot de passe (pour confirmer)", filled: true, fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: envoi ? null : () async {
                  setS(() => envoi = true);
                  final r = await ApiService.modifierTelephone(
                    telephone: widget.telephone,
                    nouveauTelephone: nouveauTelCtrl.text.trim(),
                    password: passwordCtrl.text,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _snack(r['message'] ?? '', r['status'] == 'success');
                  if (r['status'] == 'success') {
                    _snack("Reconnectez-vous avec votre nouveau numéro.", true);
                    await SessionService.supprimer();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                  }
                },
                child: envoi
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("VALIDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      )));
  }

  Future<void> _seDeconnecter() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Se déconnecter ?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Vous devrez vous reconnecter pour accéder à votre compte."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Se déconnecter", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmer != true) return;
    await SessionService.supprimer();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  void _ouvrirSuppressionCompte() {
    final passwordCtrl = TextEditingController();
    bool envoi = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8),
          Text("Supprimer mon compte", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Cette action est irréversible. Votre nom, e-mail, mot de passe et photos seront définitivement effacés. "
            "Votre numéro de téléphone sera conservé uniquement à titre de référence sur vos anciennes commandes/factures, "
            "qui restent inchangées.",
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          TextField(controller: passwordCtrl, obscureText: true,
            decoration: InputDecoration(labelText: "Confirmez avec votre mot de passe", filled: true, fillColor: const Color(0xFFF4F7F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: envoi ? null : () async {
              if (passwordCtrl.text.isEmpty) { _snack("Mot de passe requis", false); return; }
              setS(() => envoi = true);
              final r = await ApiService.supprimerCompteUnifie(telephone: widget.telephone, password: passwordCtrl.text);
              if (!mounted) return;
              if (r['status'] == 'success') {
                Navigator.pop(context);
                await SessionService.supprimer();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              } else {
                setS(() => envoi = false);
                _snack(r['message'] ?? "Erreur", false);
              }
            },
            child: envoi
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Supprimer définitivement", style: TextStyle(color: Colors.white))),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Paramètres", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [HomeNavigator.bouton()], // 🆕 retour à l'accueil à tout moment
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.grey))))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 🆕 Photo de profil retirée pour l'instant (voir
                    // RAPPORT_PARAMETRES.md §8) : la enregistrer en base64
                    // fonctionne, mais l'afficher correctement depuis le
                    // site web nécessiterait de la stocker comme un vrai
                    // fichier (comme le fait déjà le web pour les CNI) —
                    // changement que je n'ai pas pu vérifier sur le vrai
                    // serveur de production. Un simple avatar fixe en
                    // attendant, rien de cassé, juste pas encore modifiable.
                    const Center(child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Color(0x1A8B0000),
                      child: Icon(Icons.person, size: 48, color: Color(0xFF8B0000)),
                    )),
                    const SizedBox(height: 24),

                    _carte("INFORMATIONS PERSONNELLES", [
                      TextField(controller: _nomCtrl,
                        decoration: InputDecoration(labelText: "Nom complet", filled: true, fillColor: const Color(0xFFF4F7F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                      const SizedBox(height: 10),
                      TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(labelText: "E-mail", filled: true, fillColor: const Color(0xFFF4F7F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                      const SizedBox(height: 10),
                      TextField(controller: _adresseCtrl, maxLines: 2,
                        decoration: InputDecoration(labelText: "Adresse", filled: true, fillColor: const Color(0xFFF4F7F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: _enregistrerProfil,
                        child: const Text("ENREGISTRER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)))),
                    ]),
                    const SizedBox(height: 16),

                    _carte("SÉCURITÉ", [
                      Material(color: Colors.transparent, child: ListTile( // 🆕 corrige "ListTile ink splash invisible"
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined, color: Color(0xFF8B0000)),
                        title: const Text("Numéro de téléphone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(_profil?['telephone'] ?? widget.telephone, style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _ouvrirChangerTelephone,
                      )),
                      const Divider(height: 1),
                      Material(color: Colors.transparent, child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline, color: Color(0xFF8B0000)),
                        title: const Text("Mot de passe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text("••••••••", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _ouvrirChangerMotDePasse,
                      )),
                    ]),
                    const SizedBox(height: 16),

                    _carte("NOTIFICATIONS", [
                      Material(color: Colors.transparent, child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notifActives,
                        activeColor: const Color(0xFF8B0000),
                        title: const Text("Recevoir les notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text("Statut de commande, messages, promotions...", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        onChanged: _toggleNotifications,
                      )),
                    ]),
                    const SizedBox(height: 16),

                    // Déconnexion + suppression
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Column(children: [
                        Material(color: Colors.transparent, child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.grey),
                          title: const Text("Se déconnecter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onTap: _seDeconnecter,
                        )),
                        const Divider(height: 1),
                        Material(color: Colors.transparent, child: ListTile(
                          leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                          title: const Text("Supprimer mon compte", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                          onTap: _ouvrirSuppressionCompte,
                        )),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _carte(String titre, List<Widget> enfants) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titre, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
      const SizedBox(height: 12),
      ...enfants,
    ]));
}
