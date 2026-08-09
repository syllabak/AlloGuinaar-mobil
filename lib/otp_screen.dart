import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🆕 apiag-beta (copier le code d'invitation)
import 'api_service.dart';

class OtpScreen extends StatefulWidget {
  final String telephone;

  const OtpScreen({super.key, required this.telephone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  void _verifierCode() async {
    if (_otpController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saisissez le code à 4 chiffres"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    final response = await ApiService.verifyOtp(widget.telephone, _otpController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      final user = response['user'] ?? {};
      // 🆕 apiag-beta : le compte peut désormais avoir un code de
      // parrainage — on l'affiche s'il est présent avant de continuer.
      final String code = user['invite_code'] ?? '';

      // Résultat renvoyé à l'appelant (contrat inchangé : nom/tel/role/user_id)
      final result = {
        "nom":     user['nom_complet'] ?? '',
        "tel":     user['telephone']   ?? widget.telephone,
        "role":    user['role']        ?? 'client',
        "user_id": user['id'] ?? 0,
      };

      if (code.isNotEmpty && mounted) {
        _showInviteCode(code, result);
      } else {
        Navigator.pop(context, result);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? "Code incorrect"), backgroundColor: Colors.red));
    }
  }

  // ── Modal code d'invitation (fonctionnalité apiag-beta : parrainage) ──
  void _showInviteCode(String code, Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("🎉", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text("Compte activé !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text("Votre code d'invitation :",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Text(code, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 8)),
          ),
          const SizedBox(height: 10),
          const Text(
            "Partagez ce code avec vos amis.\n5 filleuls = 1 livraison gratuite !",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Code $code copié !"), backgroundColor: Colors.green),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copier le code"),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF8B0000)),
                foregroundColor: const Color(0xFF8B0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);          // ferme le dialogue
                Navigator.pop(context, result);  // retourne à l'écran appelant
              },
              child: const Text("Commencer mes achats",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }

  void _renvoyerCode() async {
    setState(() => _isResending = true);
    final response = await ApiService.resendOtp(widget.telephone);
    if (!mounted) return;
    setState(() => _isResending = false);

    if (response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Un nouveau code a été envoyé !"), backgroundColor: Colors.green));
      _otpController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? "Erreur"), backgroundColor: Colors.red));
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
            const Icon(Icons.security, size: 80, color: Color(0xFF8B0000)),
            const SizedBox(height: 24),
            const Text("Sécurité du compte", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text("Entrez le code envoyé au\n${widget.telephone}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(fontSize: 32, letterSpacing: 24, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                counterText: "", hintText: "0000", filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF8B0000))
                : SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _verifierCode,
                      child: const Text("VALIDER MON COMPTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),

            const SizedBox(height: 24),
            _isResending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _renvoyerCode,
                    child: const Text("Je n'ai rien reçu. Renvoyer le code", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  )
          ],
        ),
      ),
    );
  }
}
