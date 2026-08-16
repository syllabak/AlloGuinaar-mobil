import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕

// =============================================================
//  LECTEUR VIDÉO — Lot 9
//  Suit le temps de visionnage réel (position de lecture, pas juste
//  le temps écoulé à l'écran) et l'envoie périodiquement à l'API,
//  qui calcule le % et débloque la vidéo suivante côté serveur.
// =============================================================
class VideoPlayerScreen extends StatefulWidget {
  final String telephone;
  final int videoId;
  final String titre;
  final String urlVideo;
  final int dureeSecondes;
  final int tempsDejaVisionne;

  const VideoPlayerScreen({
    super.key,
    required this.telephone,
    required this.videoId,
    required this.titre,
    required this.urlVideo,
    required this.dureeSecondes,
    this.tempsDejaVisionne = 0,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _pret = false;
  String? _erreur;
  Timer? _timerSync;
  int _tempsMaxAtteint = 0; // position de lecture la plus loin atteinte (secondes)
  bool _dejaEnvoyeFinal = false;

  @override
  void initState() {
    super.initState();
    _tempsMaxAtteint = widget.tempsDejaVisionne;
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.urlVideo));
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _pret = true);
      _controller.play();

      // Reprendre là où l'utilisateur s'était arrêté
      if (widget.tempsDejaVisionne > 0 && widget.tempsDejaVisionne < widget.dureeSecondes) {
        await _controller.seekTo(Duration(seconds: widget.tempsDejaVisionne));
      }

      // Synchronisation périodique de la progression (toutes les 5s)
      _timerSync = Timer.periodic(const Duration(seconds: 5), (_) => _synchroniserProgression());

      _controller.addListener(_onPositionChanged);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Impossible de lire cette vidéo : $e");
    }
  }

  void _onPositionChanged() {
    if (!_controller.value.isInitialized) return;
    final position = _controller.value.position.inSeconds;
    if (position > _tempsMaxAtteint) {
      _tempsMaxAtteint = position;
    }
    // Vidéo terminée naturellement
    if (!_dejaEnvoyeFinal &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration.inSeconds > 0) {
      _dejaEnvoyeFinal = true;
      _synchroniserProgression(forcerTermine: true);
    }
  }

  Future<void> _synchroniserProgression({bool forcerTermine = false}) async {
    final temps = forcerTermine ? widget.dureeSecondes : _tempsMaxAtteint;
    if (temps <= 0) return;
    try {
      await ApiService.enregistrerProgressionVideo(
        telephone: widget.telephone,
        videoId: widget.videoId,
        tempsVisionneSecondes: temps,
      );
    } catch (_) {
      // Silencieux : la prochaine synchronisation périodique réessaiera
    }
  }

  @override
  void dispose() {
    _timerSync?.cancel();
    // Dernière synchronisation à la fermeture, pour ne pas perdre la
    // progression si l'utilisateur quitte avant le prochain tick.
    _synchroniserProgression();
    if (_pret) {
      _controller.removeListener(_onPositionChanged);
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.titre, style: const TextStyle(color: Colors.white, fontSize: 14)),
        actions: [IconButton( // 🆕 retour à l'accueil à tout moment
          icon: const Icon(Icons.home_outlined, color: Colors.white),
          tooltip: "Retour à l'accueil",
          onPressed: () => HomeNavigator.allerAccueil(context),
        )],
      ),
      body: Center(
        child: _erreur != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_erreur!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              )
            : !_pret
                ? const CircularProgressIndicator(color: Colors.white)
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
                    child: Stack(alignment: Alignment.bottomCenter, children: [
                      VideoPlayer(_controller),
                      _ControlesVideo(controller: _controller),
                    ]),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Contrôles simples : play/pause + barre de progression
// ─────────────────────────────────────────────────────────────
class _ControlesVideo extends StatefulWidget {
  final VideoPlayerController controller;
  const _ControlesVideo({required this.controller});

  @override
  State<_ControlesVideo> createState() => _ControlesVideoState();
}

class _ControlesVideoState extends State<_ControlesVideo> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rafraichir);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rafraichir);
    super.dispose();
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(40),
          child: Icon(
            c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white.withOpacity(0.85),
            size: 56,
          ),
        ),
      ),
      VideoProgressIndicator(c, allowScrubbing: true,
        colors: const VideoProgressColors(playedColor: Color(0xFF8B0000), bufferedColor: Colors.white24)),
    ]);
  }
}
