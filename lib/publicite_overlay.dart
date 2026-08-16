import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================
//  FENÊTRE PUBLICITÉ — Lot 10
//  Superposée à l'écran, fermable à tout moment (bouton ✕ ou en
//  tapant en dehors) — l'utilisateur peut continuer à utiliser l'app
//  normalement en dessous une fois fermée.
// =============================================================
class PubliciteOverlay extends StatefulWidget {
  final Map publicite;
  const PubliciteOverlay({super.key, required this.publicite});

  @override
  State<PubliciteOverlay> createState() => _PubliciteOverlayState();
}

class _PubliciteOverlayState extends State<PubliciteOverlay> {
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioEnCours = false;
  bool _pret = false;
  String? _erreur;

  String get _type => widget.publicite['type'] ?? 'image';

  @override
  void initState() {
    super.initState();
    _initialiserMedia();
  }

  Future<void> _initialiserMedia() async {
    if (_type == 'video') {
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.publicite['url_media']));
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.play();
        if (mounted) setState(() => _pret = true);
      } catch (e) {
        if (mounted) setState(() { _erreur = "Vidéo indisponible"; _pret = true; });
      }
    } else {
      // Image et audio n'ont pas besoin d'initialisation préalable
      setState(() => _pret = true);
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioEnCours) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.publicite['url_media']));
    }
    setState(() => _audioEnCours = !_audioEnCours);
  }

  Future<void> _ouvrirLien() async {
    final url = widget.publicite['url_action'];
    if (url == null || url.toString().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titre = widget.publicite['titre'];
    final description = widget.publicite['description'];
    final aUnLien = (widget.publicite['url_action'] ?? '').toString().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(clipBehavior: Clip.none, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 520),
            child: GestureDetector(
              onTap: aUnLien ? _ouvrirLien : null,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _contenuMedia(),
                  if ((titre ?? '').toString().isNotEmpty || (description ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if ((titre ?? '').toString().isNotEmpty)
                          Text(titre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        if ((description ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                        if (aUnLien) ...[
                          const SizedBox(height: 10),
                          const Row(children: [
                            Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF8B0000)),
                            SizedBox(width: 4),
                            Text("Toucher pour en savoir plus",
                              style: TextStyle(color: Color(0xFF8B0000), fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                        ],
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        ),
        // Bouton fermer — toujours visible, l'utilisateur garde le contrôle
        Positioned(
          top: -14, right: -14,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
              child: const Icon(Icons.close, color: Colors.black87, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _contenuMedia() {
    if (!_pret) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF8B0000))));
    }

    switch (_type) {
      case 'video':
        if (_erreur != null || _videoController == null) {
          return _messageErreur(_erreur ?? "Vidéo indisponible");
        }
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio == 0 ? 16 / 9 : _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );

      case 'audio':
        return Container(
          height: 180,
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFB71C1C)])),
          child: Center(
            child: GestureDetector(
              onTap: _toggleAudio,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: Icon(_audioEnCours ? Icons.pause : Icons.play_arrow, color: const Color(0xFF8B0000), size: 36),
              ),
            ),
          ),
        );

      case 'image':
      default:
        return Image.network(
          widget.publicite['url_media'],
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))),
          errorBuilder: (ctx, err, stack) => _messageErreur("Image indisponible"),
        );
    }
  }

  Widget _messageErreur(String msg) => SizedBox(
    height: 160,
    child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))));
}
