import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère la localisation GPS automatique du client.
/// - Demande les permissions au premier lancement
/// - Met en cache la dernière position connue (usage hors-ligne)
/// - Expose les coordonnées prêtes à envoyer à l'API
class LocationService {
  static const _keyLat = 'last_lat';
  static const _keyLng = 'last_lng';

  // -------------------------------------------------------
  // INITIALISER — appeler au démarrage dans main.dart
  // Retourne la position ou null si refus/GPS désactivé
  // -------------------------------------------------------
  static Future<Position?> initialiser() async {
    try {
      // 1. GPS activé sur l'appareil ?
      bool serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) return _chargerCache();

      // 2. Vérifier / demander la permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return _chargerCache();
      }

      // 3. Obtenir la position (timeout 10s pour ne pas bloquer)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 4. Mémoriser pour usage hors-ligne
      await _sauvegarderCache(position.latitude, position.longitude);
      return position;

    } catch (_) {
      return _chargerCache();
    }
  }

  // -------------------------------------------------------
  // OBTENIR les coordonnées prêtes pour l'API commander()
  // Retourne Map {'lat': x, 'lng': y} ou null
  // -------------------------------------------------------
  static Future<Map<String, double>?> obtenirCoordonnees() async {
    final position = await initialiser();
    if (position == null) return null;
    return {'lat': position.latitude, 'lng': position.longitude};
  }

  // -------------------------------------------------------
  // OUVRIR les paramètres (si permission définitivement refusée)
  // -------------------------------------------------------
  static Future<void> ouvrirParametres() async {
    await Geolocator.openAppSettings();
  }

  // -------------------------------------------------------
  // PRIVÉ : Sauvegarder en cache SharedPreferences
  // -------------------------------------------------------
  static Future<void> _sauvegarderCache(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
  }

  // -------------------------------------------------------
  // PRIVÉ : Lire la dernière position depuis le cache
  // -------------------------------------------------------
  static Future<Position?> _chargerCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat == null || lng == null) return null;

    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}
