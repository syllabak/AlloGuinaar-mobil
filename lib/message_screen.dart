import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕

// =============================================================
//  MESSAGERIE — Lot 5
//  Conversation texte + vocale rattachée à une commande précise,
//  entre le client et le producteur. Accessible depuis Mon Espace
//  (client) et l'onglet Commandes (producteur).
// =============================================================
class MessageScreen extends StatefulWidget {
  final int cmdId;
  final String telephone; // numéro de l'utilisateur courant
  final String monRole;   // 'client' ou 'producteur' (affichage seulement)

  const MessageScreen({
    super.key,
    required this.cmdId,
    required this.telephone,
    required this.monRole,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  List<dynamic> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;

  bool _enregistrement = false;
  int _dureeEnregistrement = 0;
  String? _cheminEnregistrement;
  DateTime? _debutEnregistrement;

  String? _messageEnLecture; // id du message en cours de lecture

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));

  Future<void> _charger() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.mesMessages(cmdId: widget.cmdId, telephone: widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _messages = r['data'] ?? []; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBas());
    } else {
      setState(() { _error = r['message'] ?? "Erreur de chargement"; _loading = false; });
    }
  }

  void _scrollBas() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _envoyerTexte() async {
    final texte = _textCtrl.text.trim();
    if (texte.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();

    final r = await ApiService.envoyerMessage(
      cmdId: widget.cmdId,
      telephone: widget.telephone,
      type: 'texte',
      contenu: texte,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (r['status'] == 'success') {
      await _charger();
    } else {
      _snack(r['message'] ?? "Erreur d'envoi", false);
      _textCtrl.text = texte; // on ne perd pas le brouillon
    }
  }

  // ── Enregistrement vocal ──────────────────────────────────
  Future<void> _demarrerEnregistrement() async {
    try {
      final permission = await _recorder.hasPermission();
      if (!permission) {
        _snack("Autorisez l'accès au micro pour envoyer un message vocal", false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/msg_${DateTime.now().millisecondsSinceEpoch}.m4a";
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _enregistrement = true;
        _dureeEnregistrement = 0;
        _cheminEnregistrement = path;
        _debutEnregistrement = DateTime.now();
      });
      _tickEnregistrement();
    } catch (e) {
      // 🆕 Diagnostic : affiche l'erreur exacte au lieu de ne rien faire.
      // Cause la plus fréquente : le plugin natif "record" n'est pas
      // enregistré tant que l'app n'a pas été entièrement recompilée
      // (un simple hot reload/restart ne suffit pas après l'ajout
      // d'une dépendance native — il faut arrêter l'app et refaire
      // `flutter run`, ou `flutter clean` si ça persiste).
      _snack("Impossible de démarrer l'enregistrement : $e", false);
    }
  }

  void _tickEnregistrement() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_enregistrement) return;
      setState(() => _dureeEnregistrement =
          DateTime.now().difference(_debutEnregistrement!).inSeconds);
      _tickEnregistrement();
    });
  }

  Future<void> _arreterEtEnvoyer({bool annuler = false}) async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      setState(() { _enregistrement = false; _dureeEnregistrement = 0; });
      _snack("Erreur à l'arrêt de l'enregistrement : $e", false);
      return;
    }
    final duree = _dureeEnregistrement;
    setState(() { _enregistrement = false; _dureeEnregistrement = 0; });

    if (annuler || path == null) return;
    if (duree < 1) {
      _snack("Enregistrement trop court", false);
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.lengthInBytes > 6 * 1024 * 1024) {
        _snack("Message vocal trop volumineux (max ~6 Mo, réduisez la durée)", false);
        return;
      }
      final base64Audio = base64Encode(bytes);

      setState(() => _sending = true);
      final r = await ApiService.envoyerMessage(
        cmdId: widget.cmdId,
        telephone: widget.telephone,
        type: 'vocal',
        contenu: base64Audio,
        dureeSecondes: duree,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (r['status'] == 'success') {
        await _charger();
      } else {
        _snack(r['message'] ?? "Erreur d'envoi", false);
      }
    } catch (e) {
      _snack("Impossible de lire l'enregistrement", false);
    }
  }

  // ── Lecture d'un message vocal ────────────────────────────
  Future<void> _lireVocal(Map msg) async {
    final id = msg['id'].toString();
    if (_messageEnLecture == id) {
      await _player.stop();
      setState(() => _messageEnLecture = null);
      return;
    }
    try {
      final bytes = base64Decode(msg['contenu']);
      await _player.stop();
      await _player.play(BytesSource(bytes));
      setState(() => _messageEnLecture = id);
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _messageEnLecture = null);
      });
    } catch (_) {
      _snack("Impossible de lire ce message vocal", false);
    }
  }

  Future<void> _supprimer(Map msg) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Supprimer ce message ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    final r = await ApiService.supprimerMessage(
      messageId: int.parse(msg['id'].toString()),
      telephone: widget.telephone,
    );
    if (!mounted) return;
    if (r['status'] == 'success') {
      _charger();
    } else {
      _snack(r['message'] ?? "Erreur", false);
    }
  }

  String _formatDuree(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$m:$sec";
  }

  String _formatHeure(String? dateEnvoi) {
    if (dateEnvoi == null) return '';
    try {
      final d = DateTime.parse(dateEnvoi);
      return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text("Commande #${widget.cmdId}",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
        actions: [HomeNavigator.bouton()], // 🆕 retour à l'accueil à tout moment
      ),
      body: Column(children: [
        Expanded(child: _buildListe()),
        _buildBarreDeSaisie(),
      ]),
    );
  }

  Widget _buildListe() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            SelectableText(_error!, style: const TextStyle(color: Colors.red, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _charger, child: const Text("Réessayer")),
          ]),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text("Aucun message pour l'instant.\nÉcrivez le premier !",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final m = _messages[i];
        final estMoi = m['expediteur_role'] == widget.monRole;
        return _buildBulle(m, estMoi);
      },
    );
  }

  Widget _buildBulle(Map msg, bool estMoi) {
    final couleur = estMoi ? const Color(0xFF8B0000) : Colors.white;
    final texteColeur = estMoi ? Colors.white : Colors.black87;

    return Align(
      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: estMoi ? () => _supprimer(msg) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(estMoi ? 14 : 2),
              bottomRight: Radius.circular(estMoi ? 2 : 14),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msg['type'] == 'texte')
              Text(msg['contenu'] ?? '', style: TextStyle(color: texteColeur, fontSize: 13))
            else if (msg['type'] == 'vocal')
              _buildLecteurVocal(msg, estMoi)
            else
              Text("📷 Image", style: TextStyle(color: texteColeur, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_formatHeure(msg['date_envoi']),
                style: TextStyle(color: texteColeur.withOpacity(0.6), fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  Widget _buildLecteurVocal(Map msg, bool estMoi) {
    final enLecture = _messageEnLecture == msg['id'].toString();
    final couleur = estMoi ? Colors.white : const Color(0xFF8B0000);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _lireVocal(msg),
        child: Icon(enLecture ? Icons.stop_circle : Icons.play_circle_fill, color: couleur, size: 32),
      ),
      const SizedBox(width: 8),
      Icon(Icons.graphic_eq, color: couleur.withOpacity(0.6), size: 18),
      const SizedBox(width: 8),
      Text(_formatDuree(msg['duree_secondes'] ?? 0),
          style: TextStyle(color: estMoi ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildBarreDeSaisie() {
    if (_enregistrement) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Text("Enregistrement… ${_formatDuree(_dureeEnregistrement)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: () => _arreterEtEnvoyer(annuler: true),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => _arreterEtEnvoyer(),
            icon: const Icon(Icons.send, size: 16, color: Colors.white),
            label: const Text("Envoyer", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Écrire un message…",
                filled: true,
                fillColor: const Color(0xFFF4F7F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_textCtrl.text.trim().isEmpty)
            IconButton(
              onPressed: _sending ? null : _demarrerEnregistrement,
              icon: const Icon(Icons.mic, color: Color(0xFF8B0000)),
            )
          else
            IconButton(
              onPressed: _sending ? null : _envoyerTexte,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: Color(0xFF8B0000)),
            ),
        ]),
      ),
    );
  }
}
