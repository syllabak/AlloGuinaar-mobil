import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';

/// Gère la persistance de la session utilisateur entre les lancements de l'app.
/// Utilise SharedPreferences pour stocker les données localement.
class SessionService {
  static const _keyNom          = 'session_nom';
  static const _keyTel          = 'session_tel';
  static const _keyRole         = 'session_role';
  static const _keyUserId       = 'session_user_id';
  static const _keyInviteCode   = 'session_invite_code';   // 🆕 apiag-beta (parrainage)
  static const _keyConsentGiven = 'consent_privacy_given';

  // -------------------------------------------------------
  // SAUVEGARDER la session après login ou validation OTP
  // -------------------------------------------------------
  static Future<void> sauvegarder({
    required String nom,
    required String tel,
    required String role,
    required int userId,
    String inviteCode = '',                                 // 🆕 apiag-beta
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNom,        nom);
    await prefs.setString(_keyTel,        tel);
    await prefs.setString(_keyRole,       role);
    await prefs.setInt(_keyUserId,        userId);
    await prefs.setString(_keyInviteCode, inviteCode);       // 🆕 apiag-beta
  }

  // -------------------------------------------------------
  // LIRE la session (retourne null si aucune session active)
  // -------------------------------------------------------
  static Future<Map<String, dynamic>?> lire() async {
    final prefs = await SharedPreferences.getInstance();
    final tel = prefs.getString(_keyTel);
    if (tel == null || tel.isEmpty) return null;

    return {
      'nom':         prefs.getString(_keyNom)        ?? '',
      'tel':         tel,
      'role':        prefs.getString(_keyRole)       ?? 'client',
      'user_id':     prefs.getInt(_keyUserId)         ?? 0,
      'invite_code': prefs.getString(_keyInviteCode) ?? '',  // 🆕 apiag-beta
    };
  }

  // -------------------------------------------------------
  // METTRE À JOUR le code d'invitation (fonctionnalité apiag-beta,
  // utilisé par mon_espace_screen une fois le code généré côté API)
  // -------------------------------------------------------
  static Future<void> sauvegarderInviteCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInviteCode, code);
  }

  // -------------------------------------------------------
  // SUPPRIMER la session (déconnexion)
  // Note : le consentement RGPD n'est PAS effacé
  // -------------------------------------------------------
  static Future<void> supprimer() async {
    final prefs = await SharedPreferences.getInstance();
    final ancienTel = prefs.getString(_keyTel);

    await prefs.remove(_keyNom);
    await prefs.remove(_keyTel);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyInviteCode);

    if (ancienTel != null && ancienTel.isNotEmpty) {
      await prefs.remove('commandes_statuts_$ancienTel');
    }

    FcmService.reset();
  }

  // -------------------------------------------------------
  // CONSENTEMENT POLITIQUE DE CONFIDENTIALITÉ
  // -------------------------------------------------------
  static Future<bool> aConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentGiven) ?? false;
  }

  static Future<void> enregistrerConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsentGiven, true);
  }
}
