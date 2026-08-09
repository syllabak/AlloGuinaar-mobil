import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 🆕 apiag-beta (photos livreur)
import 'api_service.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import 'privacy_policy_screen.dart'; // 🆕
import 'session_service.dart';       // 🆕
import 'fcm_service.dart';           // 🆕 enregistrer le jeton FCM dès la connexion
import 'analytics_service.dart';     // 🆕 Lot 11
import 'deep_link_service.dart';     // 🆕 Lot 11
import 'location_service.dart';      // 🆕 Lot 8 (position GPS producteur)
import 'livreur_screen.dart';        // 🆕 apiag-beta
import 'producteur_screen.dart';     // 🆕 Lot 8

// ══════════════════════════════════════════════════════════════
//  ÉCRAN PRINCIPAL — Onglets Client / Livreur / Prod
//  L'onglet Livreur est une fonctionnalité ajoutée depuis
//  apiag-beta (voir RAPPORT_FUSION.md). L'onglet Prod (producteur/
//  fournisseur) reproduit le portail web existant (Lot 8, voir
//  RAPPORT_LOT8.md). L'onglet Client reprend à l'identique l'écran
//  de connexion/inscription de surgithup.
// ══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Mon Espace",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        // 🆕 sélecteur Client / Livreur / Prod
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF8B0000),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B0000),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 18), text: "Client"),
            Tab(icon: Icon(Icons.two_wheeler, size: 18), text: "Livreur"),
            Tab(icon: Icon(Icons.storefront, size: 18), text: "Prod"), // 🆕 Lot 8
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ClientTab(), _LivreurTab(), _ProducteurTab()],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ONGLET CLIENT — reprise intégrale de l'écran surgithup existant
//  (connexion, inscription, consentement RGPD). Aucun changement de
//  logique ; seule la coquille (Scaffold → widget d'onglet) change.
// ══════════════════════════════════════════════════════════════
class _ClientTab extends StatefulWidget {
  const _ClientTab();

  @override
  State<_ClientTab> createState() => _ClientTabState();
}

class _ClientTabState extends State<_ClientTab> {
  // --- Connexion ---
  final _loginPhoneController    = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // --- Inscription ---
  final _regNomController      = TextEditingController();
  final _regPhoneController    = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regCodeParrainController = TextEditingController(); // 🆕 Parrainage

  bool _isLoading    = false;
  bool _isLogin      = true;
  bool _consentAccepted = false; // Case à cocher politique de confidentialité

  @override
  void initState() {
    super.initState();
    // 🆕 Lot 11 : préremplir le code parrain si l'app a été ouverte
    // via un lien de parrainage (ex. partagé par WhatsApp)
    DeepLinkService.lireCodeParrainEnAttente().then((code) {
      if (code != null && code.isNotEmpty && mounted) {
        setState(() {
          _regCodeParrainController.text = code;
          _isLogin = false; // ouvrir directement l'onglet inscription
        });
      }
    });
  }

  // -------------------------------------------------------
  // 1. CONNEXION — avec sauvegarde de session
  // -------------------------------------------------------
  void _seConnecter() async {
    if (_loginPhoneController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      _showSnack("Veuillez remplir tous les champs", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final response = await ApiService.login(
      _loginPhoneController.text,
      _loginPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      final user = response['user'];
      final int userId = int.tryParse(user['id'].toString()) ?? 0;
      final String role = user['role'] ?? 'client';

      // Sauvegarder la session pour les prochains lancements
      await SessionService.sauvegarder(
        nom:    user['nom_complet']  ?? '',
        tel:    user['telephone']    ?? _loginPhoneController.text,
        role:   role,
        userId: userId,
        // 🆕 apiag-beta : code d'invitation renvoyé par /login
        inviteCode: user['invite_code'] ?? '',
      );
      // 🆕 Enregistrer le jeton FCM dès la connexion, pas seulement au
      // prochain redémarrage de l'app (sans quoi les notifications ne
      // marchaient qu'après avoir fermé/rouvert l'app une première fois).
      FcmService.initialiser(user['telephone'] ?? _loginPhoneController.text);
      AnalyticsService.connexion('client'); // 🆕 Lot 11
      AnalyticsService.definirUtilisateur(telephone: user['telephone'] ?? _loginPhoneController.text, role: 'client');

      _showSnack("Bienvenue ${user['nom_complet']} !", Colors.green);

      Navigator.pop(context, {
        'nom': user['nom_complet'],
        'tel': user['telephone'] ?? _loginPhoneController.text,
        // 🆕 apiag-beta : user_id manquait ici alors qu'il est stocké en
        // session — corrigé pour que l'appelant (catalogue_screen) puisse
        // l'utiliser immédiatement (ex. parrainage) sans attendre un
        // redémarrage de l'app.
        'user_id': userId,
        'role': role,
      });
    } else {
      _showSnack(response['message'] ?? "Identifiants incorrects", Colors.red);
    }
  }

  // -------------------------------------------------------
  // 2. INSCRIPTION — avec vérification du consentement
  // -------------------------------------------------------
  void _sInscrire() async {
    if (_regNomController.text.isEmpty ||
        _regPhoneController.text.isEmpty ||
        _regPasswordController.text.isEmpty) {
      _showSnack("Veuillez remplir tous les champs", Colors.orange);
      return;
    }

    // Vérifier que la politique de confidentialité a été acceptée
    if (!_consentAccepted) {
      _showSnack("Veuillez accepter la politique de confidentialité", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final response = await ApiService.registerClient({
      "nom_client": _regNomController.text,
      "tel_client": _regPhoneController.text,
      "pwd_client": _regPasswordController.text,
      if (_regCodeParrainController.text.trim().isNotEmpty) // 🆕 Parrainage
        "code_parrain": _regCodeParrainController.text.trim().toUpperCase(),
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      // Enregistrer le consentement RGPD une bonne fois
      await SessionService.enregistrerConsentement();

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(telephone: _regPhoneController.text),
        ),
      );

      if (result != null && result is Map) {
        // Sauvegarder la session après validation OTP
        await SessionService.sauvegarder(
          nom:    result['nom']   ?? _regNomController.text,
          tel:    result['tel']   ?? _regPhoneController.text,
          role:   result['role']  ?? 'client',
          userId: int.tryParse(result['user_id']?.toString() ?? '0') ?? 0,
        );
        FcmService.initialiser(result['tel'] ?? _regPhoneController.text); // 🆕
        AnalyticsService.inscription('client'); // 🆕 Lot 11
        AnalyticsService.definirUtilisateur(telephone: result['tel'] ?? _regPhoneController.text, role: 'client');
        DeepLinkService.effacerCodeParrainEnAttente(); // 🆕 Lot 11

        if (mounted) Navigator.pop(context, result);
      }
    } else {
      _showSnack(response['message'] ?? "Erreur lors de l'inscription", Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // -------------------------------------------------------
  // BUILD
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.lock_person, size: 60, color: Color(0xFF8B0000)),
          const SizedBox(height: 16),

          // --- Onglets Connexion / Inscription ---
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                _onglet("Se Connecter", _isLogin, () => setState(() => _isLogin = true)),
                _onglet("S'inscrire", !_isLogin, () => setState(() => _isLogin = false)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- Formulaires ---
          if (_isLogin) ..._buildConnexion() else ..._buildInscription(),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // FORMULAIRE CONNEXION
  // -------------------------------------------------------
  List<Widget> _buildConnexion() {
    return [
      _champ(_loginPhoneController, "Numéro de téléphone", Icons.phone, TextInputType.phone),
      const SizedBox(height: 16),
      _champ(_loginPasswordController, "Mot de passe", Icons.lock, TextInputType.text, obscure: true),
      const SizedBox(height: 32),
      _isLoading
          ? const CircularProgressIndicator(color: Color(0xFF8B0000))
          : _bouton("SE CONNECTER", Colors.black, _seConnecter),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
        child: const Text("Mot de passe oublié ?",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
      ),
    ];
  }

  // -------------------------------------------------------
  // FORMULAIRE INSCRIPTION
  // -------------------------------------------------------
  List<Widget> _buildInscription() {
    return [
      _champ(_regNomController, "Prénom et Nom", Icons.person, TextInputType.name),
      const SizedBox(height: 16),
      _champ(_regPhoneController, "Numéro de téléphone", Icons.phone, TextInputType.phone),
      const SizedBox(height: 16),
      _champ(_regPasswordController, "Créer un mot de passe", Icons.lock, TextInputType.text, obscure: true),
      const SizedBox(height: 16),

      // 🆕 Code de parrainage (optionnel) — reprend le champ du web
      // (auth_modal.php : "Ex: AB12CD — offert par un ami")
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.card_giftcard, size: 14, color: Colors.orange),
            SizedBox(width: 6),
            Text("Un ami vous a invité ? (optionnel)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _regCodeParrainController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: "Ex: AB12CD",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Case à cocher Politique de confidentialité
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _consentAccepted ? const Color(0xFF8B0000) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _consentAccepted,
              activeColor: const Color(0xFF8B0000),
              onChanged: (val) => setState(() => _consentAccepted = val ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  // Ouvrir la politique et cocher automatiquement si acceptée
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivacyPolicyScreen(
                        showAcceptButton: true,
                        onAccepted: () {
                          setState(() => _consentAccepted = true);
                          Navigator.pop(context, true);
                        },
                      ),
                    ),
                  );
                  if (result == true) {
                    setState(() => _consentAccepted = true);
                  }
                },
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      TextSpan(text: "J'accepte la "),
                      TextSpan(
                        text: "Politique de Confidentialité",
                        style: TextStyle(
                          color: Color(0xFF8B0000),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: " d'Allo Guinaar"),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),
      _isLoading
          ? const CircularProgressIndicator(color: Color(0xFF8B0000))
          : _bouton("CRÉER MON COMPTE", const Color(0xFF8B0000), _sInscrire),
    ];
  }

  // -------------------------------------------------------
  // WIDGETS UTILITAIRES (onglet Client)
  // -------------------------------------------------------
  Widget _onglet(String label, bool actif, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: actif ? const Color(0xFF8B0000) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: actif ? Colors.white : Colors.grey)),
        ),
      ),
    );
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icon, TextInputType type,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _bouton(String label, Color couleur, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: couleur,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ONGLET LIVREUR — fonctionnalité ajoutée depuis apiag-beta.
//  Connexion, inscription (avec photos permis + moto) et
//  récupération de mot de passe par token SMS.
//  Adapté pour utiliser PrivacyPolicyScreen (surgithup) au lieu de
//  dupliquer un second texte de politique de confidentialité.
// ══════════════════════════════════════════════════════════════
class _LivreurTab extends StatefulWidget {
  const _LivreurTab();

  @override
  State<_LivreurTab> createState() => _LivreurTabState();
}

class _LivreurTabState extends State<_LivreurTab> {
  bool _showRegister      = false;
  bool _showForgotToken   = false;
  bool _loading           = false;
  bool _acceptePolitique  = false;

  // Connexion
  final _telCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  // Inscription
  final _nomCtrl    = TextEditingController();
  final _rTelCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _rPwdCtrl   = TextEditingController();
  final _zoneCtrl   = TextEditingController();
  final _imatCtrl   = TextEditingController(); // immatriculation moto

  // Images
  String? _permisRectoPath;
  String? _permisVersoPath;
  String? _photoMotoPath;

  // Mot de passe oublié livreur
  final _fTelCtrl      = TextEditingController();
  final _tokenCtrl     = TextEditingController(); // token reçu à l'inscription
  final _newPwdLivCtrl = TextEditingController(); // nouveau mot de passe
  bool _tokenEnvoye    = false; // token renvoyé par SMS

  final _picker = ImagePicker();

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Future<void> _pickImage(String type) async {
    try {
      final img = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 60, maxWidth: 1024);
      if (img == null) return;
      setState(() {
        if (type == 'permis_recto') _permisRectoPath = img.path;
        if (type == 'permis_verso') _permisVersoPath = img.path;
        if (type == 'photo_moto')   _photoMotoPath   = img.path;
      });
    } catch (_) {
      _snack("Impossible d'accéder à la galerie", false);
    }
  }

  Future<String?> _toBase64(String? path) async {
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final r = await ApiService.login(_telCtrl.text.trim(), _pwdCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;

    if (r['status'] == 'success') {
      final user = r['user'] as Map;
      if ((user['role'] ?? '') != 'livreur') {
        _snack("Ce compte n'est pas un compte livreur.", false);
        return;
      }
      if ((user['statut_compte'] ?? '') == 'En attente') {
        _snack("Compte en cours de validation par notre équipe.", false);
        return;
      }
      await SessionService.sauvegarder(
        nom:    user['nom_complet'] ?? '',
        tel:    user['telephone']  ?? user['username'] ?? '',
        userId: int.tryParse(user['id']?.toString() ?? '0') ?? 0,
        role:   'livreur',
      );
      FcmService.initialiser(user['telephone'] ?? user['username'] ?? ''); // 🆕
      AnalyticsService.connexion('livreur'); // 🆕 Lot 11
      AnalyticsService.definirUtilisateur(telephone: user['telephone'] ?? user['username'] ?? '', role: 'livreur');
      if (!mounted) return;
      // 🆕 Même correctif que pour le producteur (voir plus haut)
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (_) => LivreurScreen(
              telephone: user['telephone'] ?? user['username'] ?? '',
              nom:       user['nom_complet'] ?? '')),
          (route) => false);
    } else {
      _snack(r['message'] ?? 'Identifiants incorrects', false);
    }
  }

  Future<void> _inscrire() async {
    if (!_acceptePolitique) {
      _snack("Vous devez accepter la politique de confidentialité", false);
      return;
    }
    if (_nomCtrl.text.trim().isEmpty || _rTelCtrl.text.trim().isEmpty || _rPwdCtrl.text.trim().isEmpty) {
      _snack("Remplissez tous les champs obligatoires *", false);
      return;
    }
    if (_permisRectoPath == null || _permisVersoPath == null) {
      _snack("Les photos du permis de conduire (recto et verso) sont obligatoires", false);
      return;
    }
    if (_photoMotoPath == null) {
      _snack("La photo de la moto est obligatoire", false);
      return;
    }

    setState(() => _loading = true);

    final permisR = await _toBase64(_permisRectoPath);
    final permisV = await _toBase64(_permisVersoPath);
    final moto    = await _toBase64(_photoMotoPath);

    final r = await ApiService.registerLivreur({
      "nom":             _nomCtrl.text.trim(),
      "telephone":       _rTelCtrl.text.trim(),
      "email":           _emailCtrl.text.trim(),
      "password":        _rPwdCtrl.text.trim(),
      "zone_livraison":  _zoneCtrl.text.trim(),
      "immatriculation": _imatCtrl.text.trim(),
      if (permisR != null) "cni_recto":   permisR,
      if (permisV != null) "cni_verso":   permisV,
      if (moto    != null) "photo_ferme": moto,
    });

    setState(() => _loading = false);
    if (!mounted) return;

    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') {
      final token = r['token'] ?? '';
      if (token.isNotEmpty) _afficherToken(token, _rTelCtrl.text.trim());
      setState(() => _showRegister = false);
    }
  }

  void _afficherToken(String token, String tel) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.key, color: Color(0xFF8B0000)),
                SizedBox(width: 8),
                Text("Votre token de sécurité",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    "Ce code vous sera envoyé par SMS. Conservez-le précieusement, il vous permet de récupérer votre compte.",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4F7F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B0000), width: 2)),
                    child: Text(token,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: Color(0xFF8B0000)),
                        textAlign: TextAlign.center)),
                const SizedBox(height: 8),
                Text("Numéro : $tel", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("J'ai noté mon token",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              ],
            ));
  }

  Future<void> _renvoyerToken() async {
    if (_fTelCtrl.text.trim().isEmpty) {
      _snack("Entrez votre numéro", false);
      return;
    }
    setState(() => _loading = true);
    final r = await ApiService.renvoyerTokenLivreur(_fTelCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') setState(() => _tokenEnvoye = true);
  }

  Future<void> _changerMotDePasseLivreur() async {
    if (_fTelCtrl.text.trim().isEmpty ||
        _tokenCtrl.text.trim().isEmpty ||
        _newPwdLivCtrl.text.trim().isEmpty) {
      _snack("Remplissez tous les champs", false);
      return;
    }
    setState(() => _loading = true);
    final r = await ApiService.forgotPasswordLivreur(
      telephone:   _fTelCtrl.text.trim(),
      token:       _tokenCtrl.text.trim(),
      newPassword: _newPwdLivCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') {
      setState(() {
        _showForgotToken = false;
        _tokenEnvoye = false;
      });
    }
  }

  void _voirPolitiqueConfidentialite() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),

        // ── Connexion livreur ──────────────────────────────────
        if (!_showRegister && !_showForgotToken) ...[
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFB71C1C)]),
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.two_wheeler, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Espace Livreur",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text("Connectez-vous pour accéder à vos missions",
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
              ])),
          const SizedBox(height: 24),
          _titre("Connexion Livreur"),
          _champLivreur(_telCtrl, "Numéro de téléphone", Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _champLivreur(_pwdCtrl, "Mot de passe", Icons.lock, obscure: true),
          const SizedBox(height: 20),
          _boutonPrimaire("SE CONNECTER", _login, loading: _loading),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _voirPolitiqueConfidentialite,
              icon: const Icon(Icons.privacy_tip_outlined, size: 14, color: Colors.grey),
              label: const Text("Politique de confidentialité",
                  style: TextStyle(color: Colors.grey, fontSize: 11))),
          _lienTexte("Mot de passe oublié ?", () => setState(() => _showForgotToken = true)),
          _lienTexte("Devenir livreur ? S'inscrire", () => setState(() => _showRegister = true)),
        ],

        // ── Mot de passe oublié livreur ────────────────────────
        if (_showForgotToken) ...[
          _titre("Mot de passe oublié"),
          Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        "Utilisez le TOKEN reçu par SMS lors de votre inscription pour changer votre mot de passe.",
                        style: TextStyle(fontSize: 11, color: Colors.black87))),
              ])),
          _champLivreur(_fTelCtrl, "Votre numéro de téléphone *", Icons.phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _champLivreur(_tokenCtrl, "Votre TOKEN (reçu à l'inscription)", Icons.key,
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _champLivreur(_newPwdLivCtrl, "Nouveau mot de passe *", Icons.lock, obscure: true),
          const SizedBox(height: 20),
          _boutonPrimaire("CHANGER MON MOT DE PASSE", _changerMotDePasseLivreur,
              loading: _loading, color: const Color(0xFF8B0000)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text("Vous n'avez plus votre token ?",
              style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (_tokenEnvoye)
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text("Token renvoyé par SMS !",
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ]))
          else
            _boutonPrimaire("RECEVOIR MON TOKEN PAR SMS", _renvoyerToken,
                loading: _loading, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          _lienTexte("Retour à la connexion",
              () => setState(() {
                    _showForgotToken = false;
                    _tokenEnvoye = false;
                  })),
        ],

        // ── Inscription livreur ────────────────────────────────
        if (_showRegister) ...[
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200)),
              child: const Column(children: [
                _AvantageRow("Gagnez de l'argent en livrant"),
                SizedBox(height: 6),
                _AvantageRow("Travaillez à votre rythme"),
                SizedBox(height: 6),
                _AvantageRow("Compte validé sous 24h par notre équipe"),
              ])),
          const SizedBox(height: 20),
          _titre("Devenir Livreur"),
          _soustitre("INFORMATIONS PERSONNELLES"),
          _champLivreur(_nomCtrl, "Nom complet *", Icons.person),
          const SizedBox(height: 12),
          _champLivreur(_rTelCtrl, "Numéro de téléphone *", Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _champLivreur(_emailCtrl, "Email (optionnel)", Icons.email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _champLivreur(_rPwdCtrl, "Mot de passe *", Icons.lock, obscure: true),
          const SizedBox(height: 12),
          _champLivreur(_zoneCtrl, "Zone de livraison *", Icons.location_on),
          const SizedBox(height: 20),
          _soustitre("INFORMATIONS MOTO"),
          _champLivreur(_imatCtrl, "N° d'immatriculation *", Icons.directions_car,
              keyboardType: TextInputType.text),
          const SizedBox(height: 12),
          const Text("Photo de la moto *",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
          const SizedBox(height: 6),
          _ImagePicker(
              label: "Ajouter une photo\nde la moto",
              imagePath: _photoMotoPath,
              onPick: () => _pickImage('photo_moto')),
          const SizedBox(height: 20),
          _soustitre("PERMIS DE CONDUIRE"),
          Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Recto *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              _ImagePicker(
                  label: "Photo\nrecto",
                  imagePath: _permisRectoPath,
                  onPick: () => _pickImage('permis_recto')),
            ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Verso *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              _ImagePicker(
                  label: "Photo\nverso",
                  imagePath: _permisVersoPath,
                  onPick: () => _pickImage('permis_verso')),
            ])),
          ]),
          const SizedBox(height: 20),

          // Politique + avertissement — utilise l'écran surgithup existant
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _acceptePolitique ? const Color(0xFF8B0000) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _acceptePolitique,
                  activeColor: const Color(0xFF8B0000),
                  onChanged: (v) => setState(() => _acceptePolitique = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPolicyScreen(
                            showAcceptButton: true,
                            onAccepted: () {
                              setState(() => _acceptePolitique = true);
                              Navigator.pop(context, true);
                            },
                          ),
                        ),
                      );
                      if (result == true) setState(() => _acceptePolitique = true);
                    },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(text: "J'accepte la "),
                          TextSpan(
                            text: "Politique de Confidentialité",
                            style: TextStyle(
                              color: Color(0xFF8B0000),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: " d'Allo Guinaar"),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200)),
              child: const Text(
                  "⚠️ Un token de sécurité sera généré et envoyé par SMS. Conservez-le pour récupérer votre compte. Votre dossier sera examiné sous 24h.",
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                  textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          _boutonPrimaire("ENVOYER MA DEMANDE", _inscrire, loading: _loading, color: Colors.green.shade700),
          const SizedBox(height: 12),
          _lienTexte("Déjà inscrit ? Se connecter", () => setState(() => _showRegister = false)),
        ],

        const SizedBox(height: 40),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ONGLET PROD (PRODUCTEUR/FOURNISSEUR) — Lot 8
//  Reproduit exactement le flux du portail web (alloguinaar.zip,
//  non modifié, utilisé comme référence) : connexion, et inscription
//  avec photo ferme, CNI recto/verso, position GPS obligatoire,
//  stock initial par produit, acceptation du contrat. Compte créé
//  avec statut "En attente" — validation manuelle par l'admin, comme
//  pour le livreur. Voir RAPPORT_LOT8.md.
// ══════════════════════════════════════════════════════════════
class _ProducteurTab extends StatefulWidget {
  const _ProducteurTab();

  @override
  State<_ProducteurTab> createState() => _ProducteurTabState();
}

class _ProducteurTabState extends State<_ProducteurTab> {
  bool _showRegister     = false;
  bool _loading          = false;
  bool _acceptePolitique = false;
  bool _accepteContrat   = false;

  // Connexion
  final _telCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  // Inscription
  final _nomFermeCtrl = TextEditingController();
  final _rTelCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _rPwdCtrl     = TextEditingController();

  // Position GPS (obligatoire, comme sur le web)
  double? _lat;
  double? _lng;
  bool _gpsEnCours = false;

  // Images
  String? _photoFermePath;
  String? _cniRectoPath;
  String? _cniVersoPath;

  // Stock initial : produit_id => quantité saisie
  final Map<String, TextEditingController> _stockCtrls = {};
  List<dynamic> _produits = [];
  bool _catalogueCharge = false;

  final _picker = ImagePicker();

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Future<void> _chargerCatalogue() async {
    if (_catalogueCharge) return;
    final r = await ApiService.getCatalogue();
    if (!mounted) return;
    if (r['status'] == 'success') {
      final Map<String, dynamic> dataMap = r['data'];
      setState(() {
        _produits = dataMap.entries.map((e) {
          final item = e.value;
          item['id'] = e.key;
          _stockCtrls[e.key] = TextEditingController(text: "0");
          return item;
        }).toList();
        _catalogueCharge = true;
      });
    }
  }

  Future<void> _obtenirPositionGPS() async {
    setState(() => _gpsEnCours = true);
    final coords = await LocationService.obtenirCoordonnees();
    if (!mounted) return;
    setState(() {
      _gpsEnCours = false;
      if (coords != null) { _lat = coords['lat']; _lng = coords['lng']; }
    });
    if (coords == null) {
      _snack("Impossible d'obtenir votre position. Vérifiez que le GPS est activé.", false);
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 1024);
      if (img == null) return;
      setState(() {
        if (type == 'photo_ferme') _photoFermePath = img.path;
        if (type == 'cni_recto')   _cniRectoPath   = img.path;
        if (type == 'cni_verso')   _cniVersoPath   = img.path;
      });
    } catch (_) {
      _snack("Impossible d'accéder à la galerie", false);
    }
  }

  Future<String?> _toBase64(String? path) async {
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final r = await ApiService.login(_telCtrl.text.trim(), _pwdCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;

    if (r['status'] == 'success') {
      final user = r['user'] as Map;
      if ((user['role'] ?? '') != 'producteur') {
        _snack("Ce compte n'est pas un compte producteur/fournisseur.", false);
        return;
      }
      if ((user['statut_compte'] ?? '') == 'En attente') {
        _snack("Votre dossier est en cours de validation par notre équipe.", false);
        return;
      }
      await SessionService.sauvegarder(
        nom:    user['nom_complet'] ?? '',
        tel:    user['telephone']  ?? user['username'] ?? '',
        userId: int.tryParse(user['id']?.toString() ?? '0') ?? 0,
        role:   'producteur',
      );
      FcmService.initialiser(user['telephone'] ?? user['username'] ?? ''); // 🆕
      AnalyticsService.connexion('producteur'); // 🆕 Lot 11
      AnalyticsService.definirUtilisateur(telephone: user['telephone'] ?? user['username'] ?? '', role: 'producteur');
      if (!mounted) return;
      // 🆕 Corrigé : pushReplacement ne remplace que l'écran de connexion,
      // l'écran catalogue client reste caché dessous dans la pile — le
      // bouton Retour y ramenait, donnant l'impression d'être déconnecté.
      // pushAndRemoveUntil vide toute la pile : le Retour ferme l'app
      // normalement, sans jamais révéler un autre écran.
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (_) => ProducteurScreen(
              telephone: user['telephone'] ?? user['username'] ?? '',
              nom:       user['nom_complet'] ?? '')),
          (route) => false);
    } else {
      _snack(r['message'] ?? 'Identifiants incorrects', false);
    }
  }

  Future<void> _inscrire() async {
    if (!_acceptePolitique) {
      _snack("Vous devez accepter la politique de confidentialité", false);
      return;
    }
    if (!_accepteContrat) {
      _snack("Vous devez accepter le contrat d'Allo Guinaar", false);
      return;
    }
    if (_nomFermeCtrl.text.trim().isEmpty || _rTelCtrl.text.trim().isEmpty || _rPwdCtrl.text.trim().isEmpty) {
      _snack("Remplissez tous les champs obligatoires *", false);
      return;
    }
    if (_lat == null || _lng == null) {
      _snack("La position GPS est obligatoire", false);
      return;
    }
    if (_cniRectoPath == null || _cniVersoPath == null) {
      _snack("Le recto ET le verso de la CNI sont obligatoires", false);
      return;
    }

    setState(() => _loading = true);

    final photoFerme = await _toBase64(_photoFermePath);
    final cniRecto   = await _toBase64(_cniRectoPath);
    final cniVerso   = await _toBase64(_cniVersoPath);

    final stockQte = <String, int>{};
    for (final entry in _stockCtrls.entries) {
      stockQte[entry.key] = int.tryParse(entry.value.text.trim()) ?? 0;
    }

    final r = await ApiService.registerProducteur({
      "nom_ferme": _nomFermeCtrl.text.trim(),
      "telephone": _rTelCtrl.text.trim(),
      "email":     _emailCtrl.text.trim(),
      "password":  _rPwdCtrl.text.trim(),
      "contrat":   true,
      "lat":       _lat,
      "lng":       _lng,
      if (photoFerme != null) "photo_ferme": photoFerme,
      if (cniRecto   != null) "cni_recto":   cniRecto,
      if (cniVerso   != null) "cni_verso":   cniVerso,
      "stock_qte": stockQte,
    });

    setState(() => _loading = false);
    if (!mounted) return;

    _snack(r['message'] ?? '', r['status'] == 'success');
    if (r['status'] == 'success') setState(() => _showRegister = false);
  }

  void _voirPolitiqueConfidentialite() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  @override
  void initState() {
    super.initState();
    _chargerCatalogue();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),

        // ── Connexion producteur ────────────────────────────────
        if (!_showRegister) ...[
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.storefront, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Espace Producteur / Fournisseur",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text("Gérez vos commandes et votre stock",
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
              ])),
          const SizedBox(height: 24),
          _titre("Connexion Producteur"),
          _champLivreur(_telCtrl, "Numéro de téléphone", Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _champLivreur(_pwdCtrl, "Mot de passe", Icons.lock, obscure: true),
          const SizedBox(height: 20),
          _boutonPrimaire("SE CONNECTER", _login, loading: _loading, color: const Color(0xFF1565C0)),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _voirPolitiqueConfidentialite,
              icon: const Icon(Icons.privacy_tip_outlined, size: 14, color: Colors.grey),
              label: const Text("Politique de confidentialité",
                  style: TextStyle(color: Colors.grey, fontSize: 11))),
          _lienTexte("Devenir producteur/fournisseur ? S'inscrire",
              () => setState(() => _showRegister = true)),
        ],

        // ── Inscription producteur ─────────────────────────────
        if (_showRegister) ...[
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200)),
              child: const Column(children: [
                _AvantageRow("Vendez directement aux clients Allo Guinaar"),
                SizedBox(height: 6),
                _AvantageRow("Gérez vos commandes et votre stock en temps réel"),
                SizedBox(height: 6),
                _AvantageRow("Compte validé sous 24h par notre équipe"),
              ])),
          const SizedBox(height: 20),
          _titre("Devenir Producteur / Fournisseur"),
          _soustitre("INFORMATIONS DE LA FERME / DU MAGASIN"),
          _champLivreur(_nomFermeCtrl, "Nom de la ferme / du magasin *", Icons.storefront),
          const SizedBox(height: 12),
          _champLivreur(_rTelCtrl, "Numéro de téléphone *", Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _champLivreur(_emailCtrl, "Email (optionnel)", Icons.email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _champLivreur(_rPwdCtrl, "Créer un mot de passe *", Icons.lock, obscure: true),
          const SizedBox(height: 20),

          _soustitre("POSITION GPS (obligatoire)"),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gpsEnCours ? null : _obtenirPositionGPS,
              icon: _gpsEnCours
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.location_on, size: 16, color: _lat != null ? Colors.green : Colors.red),
              label: Text(
                _lat != null
                    ? "Position GPS enregistrée ✓ (appuyer pour modifier)"
                    : "📍 Position GPS obligatoire — Appuyer ici",
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 11,
                    color: _lat != null ? Colors.green : Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _lat != null ? Colors.green : Colors.red),
              ),
            ),
          ),
          const Text("⚠️ Obligatoire pour être visible sur la carte des clients",
              style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),

          _soustitre("PHOTO DE LA FERME / DU MAGASIN (optionnel)"),
          _ImagePicker(label: "Ajouter une photo", imagePath: _photoFermePath,
              onPick: () => _pickImage('photo_ferme')),
          const SizedBox(height: 20),

          _soustitre("CNI (obligatoire)"),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Recto *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              _ImagePicker(label: "Photo\nrecto", imagePath: _cniRectoPath, onPick: () => _pickImage('cni_recto')),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Verso *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              _ImagePicker(label: "Photo\nverso", imagePath: _cniVersoPath, onPick: () => _pickImage('cni_verso')),
            ])),
          ]),
          const SizedBox(height: 20),

          _soustitre("STOCK INITIAL & PRIX"),
          if (!_catalogueCharge)
            const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          else
            Column(children: _produits.map((p) {
              final ctrl = _stockCtrls[p['id']]!;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['short'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    Text("${p['prix']} F", style: const TextStyle(color: Color(0xFF8B0000), fontSize: 10, fontWeight: FontWeight.bold)),
                  ])),
                  SizedBox(width: 60, child: TextField(
                    controller: ctrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true, fillColor: const Color(0xFFF4F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  )),
                ]),
              );
            }).toList()),
          const SizedBox(height: 20),

          // Politique de confidentialité
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _acceptePolitique ? const Color(0xFF1565C0) : Colors.grey.shade300, width: 1.5),
            ),
            child: Row(children: [
              Checkbox(value: _acceptePolitique, activeColor: const Color(0xFF1565C0),
                onChanged: (v) => setState(() => _acceptePolitique = v ?? false)),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<bool>(context, MaterialPageRoute(
                      builder: (_) => PrivacyPolicyScreen(
                        showAcceptButton: true,
                        onAccepted: () { setState(() => _acceptePolitique = true); Navigator.pop(context, true); },
                      ),
                    ));
                    if (result == true) setState(() => _acceptePolitique = true);
                  },
                  child: RichText(text: const TextSpan(style: TextStyle(fontSize: 13, color: Colors.black87), children: [
                    TextSpan(text: "J'accepte la "),
                    TextSpan(text: "Politique de Confidentialité",
                      style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    TextSpan(text: " d'Allo Guinaar"),
                  ])),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // Contrat & avertissements — reproduit le contenu du portail web
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200, width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text("Contrat & avertissements", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              const Text(
                "• Qualité stricte : tout poulet non conforme entraîne un bannissement définitif.\n"
                "• Sécurité & CNI : votre pièce d'identité reste strictement confidentielle.\n"
                "• Transparence : je certifie que les informations fournies sont véridiques.\n"
                "• Commissions : j'accepte une commission de 10% sur chaque vente.\n"
                "• Respect des délais : je m'engage à préparer les commandes à temps.",
                style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Checkbox(value: _accepteContrat, activeColor: Colors.red,
                  onChanged: (v) => setState(() => _accepteContrat = v ?? false)),
                const Expanded(child: Text("J'accepte les conditions ci-dessus",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          _boutonPrimaire("SOUMETTRE MON DOSSIER", _inscrire, loading: _loading, color: const Color(0xFF1565C0)),
          const SizedBox(height: 12),
          _lienTexte("Déjà inscrit ? Se connecter", () => setState(() => _showRegister = false)),
        ],

        const SizedBox(height: 40),
      ]),
    );
  }
}


class _ImagePicker extends StatelessWidget {
  final String label;
  final String? imagePath;
  final VoidCallback onPick;
  const _ImagePicker({required this.label, this.imagePath, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: imagePath != null ? Colors.green : Colors.grey.shade300,
                width: imagePath != null ? 2 : 1)),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(File(imagePath!), fit: BoxFit.cover, width: double.infinity))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey.shade400),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center),
              ]),
      ),
    );
  }
}

class _AvantageRow extends StatelessWidget {
  final String text;
  const _AvantageRow(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ]);
}

// ─────────────────────────────────────────────────────────────
//  Widgets communs à l'onglet Livreur (apiag-beta)
// ─────────────────────────────────────────────────────────────
Widget _titre(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)));

Widget _soustitre(String t) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.only(left: 8),
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF8B0000), width: 3))),
    child: Text(t, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)));

Widget _champLivreur(TextEditingController ctrl, String label, IconData icon,
        {bool obscure = false, TextInputType? keyboardType}) =>
    TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF8B0000)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));

Widget _boutonPrimaire(String label, VoidCallback onTap, {bool loading = false, Color? color}) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF8B0000),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14))));

Widget _lienTexte(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text(label, style: const TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)));
