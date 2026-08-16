import 'package:flutter/material.dart';
import 'api_service.dart';
import 'home_navigator.dart'; // 🆕
import 'video_player_screen.dart';

// =============================================================
//  FORMATIONS VIDÉO — Lot 9
//  Contenu filtré par rôle côté serveur (client / producteur).
//  Un seul écran, réutilisé par les deux : le rôle n'a pas besoin
//  d'être passé, l'API le détermine à partir du téléphone.
// =============================================================
class FormationsScreen extends StatefulWidget {
  final String telephone;
  final String nom;

  const FormationsScreen({super.key, required this.telephone, required this.nom});

  @override
  State<FormationsScreen> createState() => _FormationsScreenState();
}

class _FormationsScreenState extends State<FormationsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.formationCategories(widget.telephone);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _categories = r['data'] ?? []; _loading = false; });
    } else {
      setState(() { _error = r['message'] ?? "Erreur de chargement"; _loading = false; });
    }
  }

  IconData _icone(String? nom) {
    switch (nom) {
      case 'shopping_bag': return Icons.shopping_bag_outlined;
      case 'inventory': return Icons.inventory_2_outlined;
      case 'local_shipping': return Icons.local_shipping_outlined;
      case 'star': return Icons.star_outline_rounded;
      default: return Icons.play_circle_outline;
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
        title: const Text("Formations", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [HomeNavigator.bouton()], // 🆕 retour à l'accueil à tout moment
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _charger,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text("Réessayer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                  ])))
              : _categories.isEmpty
                  ? const Center(child: Text("Aucune formation disponible pour le moment",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                  : RefreshIndicator(
                      color: const Color(0xFF8B0000),
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final c = _categories[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                            child: Material(color: Colors.transparent, child: ListTile( // 🆕 corrige "ListTile ink splash invisible"
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(color: const Color(0xFF8B0000).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(_icone(c['icone']), color: const Color(0xFF8B0000))),
                              title: Text(c['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              subtitle: Text("${c['nb_formations']} formation(s)",
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => _FormationsListeScreen(
                                  telephone: widget.telephone,
                                  categorieId: int.parse(c['id'].toString()),
                                  categorieNom: c['nom'] ?? '',
                                ))),
                            )),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Liste des formations d'une catégorie
// ─────────────────────────────────────────────────────────────
class _FormationsListeScreen extends StatefulWidget {
  final String telephone;
  final int categorieId;
  final String categorieNom;

  const _FormationsListeScreen({required this.telephone, required this.categorieId, required this.categorieNom});

  @override
  State<_FormationsListeScreen> createState() => _FormationsListeScreenState();
}

class _FormationsListeScreenState extends State<_FormationsListeScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _formations = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.formationsParCategorie(telephone: widget.telephone, categorieId: widget.categorieId);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _formations = r['data'] ?? []; _loading = false; });
    } else {
      setState(() { _error = r['message'] ?? "Erreur de chargement"; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.categorieNom, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [HomeNavigator.bouton()], // 🆕
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  color: const Color(0xFF8B0000),
                  onRefresh: _charger,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _formations.length,
                    itemBuilder: (ctx, i) {
                      final f = _formations[i];
                      final pct = int.tryParse(f['progression_pct'].toString()) ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _VideosListeScreen(
                              telephone: widget.telephone,
                              formationId: int.parse(f['id'].toString()),
                              formationTitre: f['titre'] ?? '',
                            ))).then((_) => _charger()),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f['titre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            if ((f['description'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(f['description'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(value: pct / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: pct == 100 ? Colors.green : const Color(0xFF8B0000), minHeight: 8))),
                              const SizedBox(width: 10),
                              Text("$pct%", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12,
                                color: pct == 100 ? Colors.green : const Color(0xFF8B0000))),
                            ]),
                            const SizedBox(height: 4),
                            Text("${f['nb_videos_terminees'] ?? 0} / ${f['nb_videos'] ?? 0} vidéos terminées",
                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Liste des vidéos d'une formation (avec verrouillage séquentiel)
// ─────────────────────────────────────────────────────────────
class _VideosListeScreen extends StatefulWidget {
  final String telephone;
  final int formationId;
  final String formationTitre;

  const _VideosListeScreen({required this.telephone, required this.formationId, required this.formationTitre});

  @override
  State<_VideosListeScreen> createState() => _VideosListeScreenState();
}

class _VideosListeScreenState extends State<_VideosListeScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.formationVideos(telephone: widget.telephone, formationId: widget.formationId);
    if (!mounted) return;
    if (r['status'] == 'success') {
      setState(() { _videos = r['data'] ?? []; _loading = false; });
    } else {
      setState(() { _error = r['message'] ?? "Erreur de chargement"; _loading = false; });
    }
  }

  String _dureeTexte(int secondes) {
    final m = secondes ~/ 60;
    final s = secondes % 60;
    return "${m}min${s > 0 ? ' ${s}s' : ''}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.formationTitre, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [HomeNavigator.bouton()], // 🆕
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _videos.length,
                  itemBuilder: (ctx, i) {
                    final v = _videos[i];
                    final debloquee = v['debloquee'] == true;
                    final termine = v['termine'] == 1 || v['termine'] == true;
                    final pct = int.tryParse(v['pourcentage'].toString()) ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Opacity(
                        opacity: debloquee ? 1.0 : 0.5,
                        child: Material(color: Colors.transparent, child: ListTile( // 🆕 corrige "ListTile ink splash invisible"
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: termine ? Colors.green.shade50
                                : (debloquee ? const Color(0xFF8B0000).withOpacity(0.1) : Colors.grey.shade200),
                            child: Icon(
                              termine ? Icons.check_circle : (debloquee ? Icons.play_arrow : Icons.lock_outline),
                              color: termine ? Colors.green : (debloquee ? const Color(0xFF8B0000) : Colors.grey),
                              size: 20,
                            ),
                          ),
                          title: Text(v['titre'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            debloquee
                                ? "${_dureeTexte(int.tryParse(v['duree_secondes'].toString()) ?? 0)} • $pct%"
                                : "Terminez la vidéo précédente pour débloquer",
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          onTap: !debloquee ? null : () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                telephone: widget.telephone,
                                videoId: int.parse(v['id'].toString()),
                                titre: v['titre'] ?? '',
                                urlVideo: v['url_video'] ?? '',
                                dureeSecondes: int.tryParse(v['duree_secondes'].toString()) ?? 0,
                                tempsDejaVisionne: int.tryParse(v['temps_visionne_secondes'].toString()) ?? 0,
                              ),
                            ));
                            _charger(); // recharger pour mettre à jour verrouillage/progression
                          },
                        )),
                      ),
                    );
                  },
                ),
    );
  }
}
