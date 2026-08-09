import 'package:flutter/material.dart';
import 'api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false; // Passe à true quand le serveur a envoyé le SMS

  void _demanderCode() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    final response = await ApiService.forgotPassword(_phoneController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vérifiez vos SMS !"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? "Erreur"), backgroundColor: Colors.red));
    }
  }

  void _reinitialiserPassword() async {
    if (_tokenController.text.isEmpty || _newPasswordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    final response = await ApiService.resetPassword(_phoneController.text, _tokenController.text, _newPasswordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe modifié avec succès !"), backgroundColor: Colors.green));
      Navigator.pop(context); // Retour à l'écran de connexion
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? "Code expiré ou invalide"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.black),
            const SizedBox(height: 24),
            const Text("Mot de passe oublié", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(!_codeSent ? "Saisissez votre numéro pour recevoir un code de récupération." : "Entrez le code reçu et votre nouveau mot de passe.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            if (!_codeSent) ...[
              // ÉTAPE 1 : DEMANDER LE CODE
              TextField(
                controller: _phoneController, keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: "Numéro de téléphone", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.phone)),
              ),
              const SizedBox(height: 24),
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.black)
                : SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _demanderCode,
                      child: const Text("RECEVOIR LE CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
            ] else ...[
              // ÉTAPE 2 : CHANGER LE MOT DE PASSE
              TextField(
                controller: _tokenController, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Code reçu par SMS", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.message)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController, obscureText: true,
                decoration: InputDecoration(labelText: "Nouveau mot de passe", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.lock)),
              ),
              const SizedBox(height: 24),
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.green)
                : SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _reinitialiserPassword,
                      child: const Text("SAUVEGARDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
            ]
          ],
        ),
      ),
    );
  }
}