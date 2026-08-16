import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ URL de production actuelle — inchangée lors de la fusion.
  // Si l'API fusionnée (apiag-fusionne) est déployée sous un autre
  // chemin, mettre à jour cette constante en conséquence.
  static const String baseUrl = "https://danov.sn/mes-apis/apiag-fusionne/index.php";

  // ── Helpers HTTP (fonctionnalité apiag-beta : évite la duplication
  //    de code présente dans chaque méthode de la version surgithup) ──
  static Future<Map<String, dynamic>> _post(
      String route, Map<String, dynamic> body) async {
    try {
      final r = await http.post(Uri.parse("$baseUrl?route=$route"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body));
      try {
        return jsonDecode(r.body);
      } catch (_) {
        return {"status": "error", "message": "Erreur serveur : ${r.body}"};
      }
    } catch (e) {
      return {"status": "error", "message": "Erreur réseau : $e"};
    }
  }

  static Future<Map<String, dynamic>> _get(String route) async {
    try {
      final r = await http.get(Uri.parse("$baseUrl?route=$route"));
      return jsonDecode(r.body);
    } catch (e) {
      return {"status": "error", "message": "Erreur réseau : $e"};
    }
  }

  // ── CATALOGUE ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getCatalogue() => _get('catalogue');

  // ── AUTH — client ─────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
          String username, String password) =>
      _post('login', {"username": username, "password": password});

  static Future<Map<String, dynamic>> registerClient(
          Map<String, dynamic> data) =>
      _post('register_client', data);

  /// Producteur/fournisseur : inscription complète (Lot 8), reproduit
  /// le flux du portail web (CNI, photo ferme, GPS, stock initial).
  static Future<Map<String, dynamic>> registerProducteur(
          Map<String, dynamic> data) =>
      _post('register_producteur', data);

  static Future<Map<String, dynamic>> verifyOtp(
          String telephone, String otpCode) =>
      _post('verify_otp', {"telephone": telephone, "otp_code": otpCode});

  static Future<Map<String, dynamic>> resendOtp(String telephone) =>
      _post('resend_otp', {"telephone": telephone});

  static Future<Map<String, dynamic>> forgotPassword(String telephone) =>
      _post('forgot_password', {"telephone": telephone});

  static Future<Map<String, dynamic>> resetPassword(
          String telephone, String token, String newPassword) =>
      _post('reset_password', {
        "telephone": telephone,
        "reset_token": token,
        "new_password": newPassword,
      });

  // --- SUPPRIMER LE COMPTE (spécifique à surgithup, conservé) ---
  static Future<Map<String, dynamic>> supprimerCompte(
          String telephone, String password) =>
      _post('supprimer_compte', {
        "telephone": telephone,
        "password": password,
      });

  // ── AUTH — livreur (fonctionnalité ajoutée depuis apiag-beta) ──
  static Future<Map<String, dynamic>> registerLivreur(
          Map<String, dynamic> data) =>
      _post('register_livreur', data);

  static Future<Map<String, dynamic>> recupererTokenLivreur(String telephone) =>
      _post('recuperer_token_livreur', {"telephone": telephone});

  static Future<Map<String, dynamic>> modifierTokenLivreur(
          String telephone, String newToken) =>
      _post('modifier_token_livreur', {"telephone": telephone, "new_token": newToken});

  /// Livreur : changer mot de passe avec le token reçu à l'inscription
  static Future<Map<String, dynamic>> forgotPasswordLivreur({
    required String telephone,
    required String token,
    required String newPassword,
  }) =>
      _post('forgot_password_livreur', {
        "telephone":    telephone,
        "token":        token,
        "new_password": newPassword,
      });

  /// Livreur : renvoyer le token par SMS
  static Future<Map<String, dynamic>> renvoyerTokenLivreur(String telephone) =>
      _post('renvoyer_token_livreur', {"telephone": telephone});

  // ── COMMANDES ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> commander(
          Map<String, dynamic> orderData) =>
      _post('commander', orderData);

  static Future<Map<String, dynamic>> getMesCommandes(String telephone) =>
      _post('mes_commandes', {"telephone": telephone});

  static Future<Map<String, dynamic>> updateStatut({
    required int cmdId,
    required String statut,
  }) =>
      _post('update_statut', {"cmd_id": cmdId, "nouveau_statut": statut});

  // ── MON ESPACE (fonctionnalité ajoutée depuis apiag-beta :
  //    parrainage, avis clients) ──────────────────────────────
  static Future<Map<String, dynamic>> getInfosClient(String telephone) =>
      _post('infos_client', {"telephone": telephone});

  static Future<Map<String, dynamic>> getMesInvitations(String telephone) =>
      _post('mes_invitations', {"telephone": telephone});

  static Future<Map<String, dynamic>> getMesAvis(String telephone) =>
      _post('mes_avis', {"telephone": telephone});

  static Future<Map<String, dynamic>> laisserAvis({
    required String telephone,
    required int commandeId,
    required int note,
    required String commentaire,
  }) =>
      _post('laisser_avis', {
        "telephone":   telephone,
        "commande_id": commandeId,
        "note":        note,
        "commentaire": commentaire,
      });

  static Future<void> partagerAvis(int avisId) async {
    try {
      await _post('partager_avis', {"avis_id": avisId});
    } catch (_) {}
  }

  // ── NOTIFICATIONS FCM (fonctionnalité ajoutée depuis apiag-beta) ──
  static Future<void> saveFcmToken(String telephone, String token) async {
    try {
      await _post('save_fcm_token', {"telephone": telephone, "fcm_token": token});
    } catch (_) {}
  }

  // ── LIVRAISON TEMPS RÉEL (fonctionnalité ajoutée depuis apiag-beta) ──

  /// Livreur : activer/désactiver disponibilité
  static Future<Map<String, dynamic>> livreurToggle({
    required String telephone,
    required String statut,
    double? lat,
    double? lng,
  }) =>
      _post('livreur_toggle', {
        "telephone": telephone,
        "statut":    statut,
        if (lat != null) "lat": lat,
        if (lng != null) "lng": lng,
      });

  /// Livreur : envoyer sa position GPS (toutes les 5s)
  static Future<Map<String, dynamic>> livreurPosition(
          String telephone, double lat, double lng) =>
      _post('livreur_position', {"telephone": telephone, "lat": lat, "lng": lng});

  /// Livreur : répondre à une mission
  static Future<Map<String, dynamic>> livreurRepondre({
    required String telephone,
    required int cmdId,
    required String action,
  }) =>
      _post('livreur_repondre', {
        "telephone": telephone,
        "cmd_id":    cmdId,
        "action":    action,
      });

  /// Livreur : ses missions
  static Future<Map<String, dynamic>> mesMissions(String telephone) =>
      _post('mes_missions', {"telephone": telephone});

  /// Livreur : missions disponibles autour de lui
  static Future<Map<String, dynamic>> missionsProches(
          String telephone, double lat, double lng) =>
      _post('missions_proches', {"telephone": telephone, "lat": lat, "lng": lng});

  /// Tracking : position livreur pour une commande
  static Future<Map<String, dynamic>> trackLivreur(int cmdId) =>
      _post('track_livreur', {"cmd_id": cmdId});

  // ── LOT 3 — MODIFICATION DE COMMANDE ─────────────────────────

  /// Client : demander une modification sur une commande (appliquée
  /// immédiatement si possible, sinon transmise au producteur pour
  /// approbation). Ne passer que les champs à modifier.
  static Future<Map<String, dynamic>> demanderModification({
    required int cmdId,
    required String telephone,
    int? quantite,
    String? adresse,
    String? telephoneLivraison,
    String? dateLivraisonSouhaitee,
    String? heureLivraisonSouhaitee,
    String? commentaireClient,
  }) =>
      _post('demander_modification', {
        "cmd_id":    cmdId,
        "telephone": telephone,
        if (quantite != null)                 "quantite": quantite,
        if (adresse != null)                  "adresse": adresse,
        if (telephoneLivraison != null)       "telephone_livraison": telephoneLivraison,
        if (dateLivraisonSouhaitee != null)   "date_livraison_souhaitee": dateLivraisonSouhaitee,
        if (heureLivraisonSouhaitee != null)  "heure_livraison_souhaitee": heureLivraisonSouhaitee,
        if (commentaireClient != null)        "commentaire_client": commentaireClient,
      });

  /// Client : historique de ses demandes de modification
  static Future<Map<String, dynamic>> mesDemandesModification(String telephone) =>
      _post('mes_demandes_modification', {"telephone": telephone});

  /// Producteur : demandes en attente pour ses commandes
  static Future<Map<String, dynamic>> demandesProducteur(String telephone) =>
      _post('demandes_producteur', {"telephone": telephone});

  /// Lot 8 — Producteur : toutes ses commandes (onglet "Commandes")
  static Future<Map<String, dynamic>> commandesProducteur(String telephone) =>
      _post('commandes_producteur', {"telephone": telephone});

  /// Lot 8 — Producteur : lire son stock actuel (onglet "Stock")
  static Future<Map<String, dynamic>> monStock(String telephone) =>
      _post('mon_stock', {"telephone": telephone});

  /// Lot 8 — Producteur : mettre à jour son stock (déjà utilisée
  /// côté web via la même route ; réutilisée telle quelle ici)
  static Future<Map<String, dynamic>> updateStock({
    required String telephone,
    required Map<String, int> stockQte,
    double? lat,
    double? lng,
    Map<String, Map<String, int>>? seuils, // 🆕 Lot 2 : {"produit_id": {"min":10,"critique":3}}
  }) =>
      _post('update_stock', {
        "telephone": telephone,
        "stock_qte": stockQte,
        if (lat != null) "lat": lat,
        if (lng != null) "lng": lng,
        if (seuils != null) "seuils": seuils,
      });

  /// Producteur : historique des modifications déjà traitées (avec les
  /// nouvelles données), pour voir les mises à jour après coup.
  static Future<Map<String, dynamic>> commandesModifieesProducteur(String telephone) =>
      _post('commandes_modifiees_producteur', {"telephone": telephone});

  /// Producteur : approuver une demande de modification
  static Future<Map<String, dynamic>> approuverModification({
    required int modificationId,
    required String telephone,
  }) =>
      _post('approuver_modification', {
        "modification_id": modificationId,
        "telephone":        telephone,
      });

  /// Producteur : refuser une demande de modification
  static Future<Map<String, dynamic>> refuserModification({
    required int modificationId,
    required String telephone,
    String motif = '',
  }) =>
      _post('refuser_modification', {
        "modification_id": modificationId,
        "telephone":        telephone,
        "motif":            motif,
      });

  // ── LOT 5 — MESSAGERIE (client ↔ producteur, par commande) ───

  /// Envoyer un message texte ou vocal sur une commande
  static Future<Map<String, dynamic>> envoyerMessage({
    required int cmdId,
    required String telephone,
    required String type, // 'texte' | 'vocal' | 'image'
    required String contenu,
    int? dureeSecondes,
  }) =>
      _post('envoyer_message', {
        "cmd_id":    cmdId,
        "telephone": telephone,
        "type":      type,
        "contenu":   contenu,
        if (dureeSecondes != null) "duree_secondes": dureeSecondes,
      });

  /// Historique des messages d'une commande (marque les messages
  /// reçus comme lus au passage)
  static Future<Map<String, dynamic>> mesMessages({
    required int cmdId,
    required String telephone,
  }) =>
      _post('mes_messages', {"cmd_id": cmdId, "telephone": telephone});

  /// Supprimer un de ses propres messages
  static Future<Map<String, dynamic>> supprimerMessage({
    required int messageId,
    required String telephone,
  }) =>
      _post('supprimer_message', {"message_id": messageId, "telephone": telephone});

  /// Nombre de messages non lus (badge), par commande
  static Future<Map<String, dynamic>> messagesNonLus(String telephone) =>
      _post('messages_non_lus', {"telephone": telephone});

  // ── LOT 9 — FORMATIONS VIDÉO ──────────────────────────────

  /// Catégories de formation visibles pour ce téléphone (filtrées
  /// automatiquement par rôle côté serveur : client ou producteur)
  static Future<Map<String, dynamic>> formationCategories(String telephone) =>
      _post('formation_categories', {"telephone": telephone});

  /// Formations d'une catégorie, avec résumé de progression
  static Future<Map<String, dynamic>> formationsParCategorie({
    required String telephone,
    required int categorieId,
  }) =>
      _post('formations_categorie', {"telephone": telephone, "categorie_id": categorieId});

  /// Vidéos d'une formation, avec statut verrouillé/débloqué
  static Future<Map<String, dynamic>> formationVideos({
    required String telephone,
    required int formationId,
  }) =>
      _post('formation_videos', {"telephone": telephone, "formation_id": formationId});

  /// Enregistrer la progression de visionnage (temps cumulé, pas un delta)
  static Future<Map<String, dynamic>> enregistrerProgressionVideo({
    required String telephone,
    required int videoId,
    required int tempsVisionneSecondes,
  }) =>
      _post('formation_progression', {
        "telephone": telephone,
        "video_id": videoId,
        "temps_visionne_secondes": tempsVisionneSecondes,
      });

  /// Historique global des formations suivies
  static Future<Map<String, dynamic>> mesFormationsHistorique(String telephone) =>
      _post('mes_formations_historique', {"telephone": telephone});

  // ── LOT 7 — ESPACE GROSSISTE / REVENDEUR ──────────────────

  /// Producteur : activer/désactiver son statut grossiste
  static Future<Map<String, dynamic>> activerGrossiste({
    required String telephone,
    required bool actif,
  }) =>
      _post('grossiste_activer', {"telephone": telephone, "actif": actif});

  /// Producteur (grossiste) : publier une offre en gros
  static Future<Map<String, dynamic>> creerOffreGrossiste({
    required String telephone,
    required String produit,
    required double prixUnitaire,
    required int quantiteDisponible,
    int quantiteMin = 100,
  }) =>
      _post('grossiste_creer_offre', {
        "telephone": telephone,
        "produit": produit,
        "prix_unitaire": prixUnitaire,
        "quantite_disponible": quantiteDisponible,
        "quantite_min": quantiteMin,
      });

  /// Producteur : ses propres offres
  static Future<Map<String, dynamic>> mesOffresGrossiste(String telephone) =>
      _post('grossiste_mes_offres', {"telephone": telephone});

  /// Client : offres grossiste disponibles (anonymisées)
  static Future<Map<String, dynamic>> offresGrossisteDisponibles() =>
      _post('grossiste_offres_disponibles', {});

  /// Client : se déclarer revendeur (badge de suivi)
  static Future<Map<String, dynamic>> demanderRevendeur(String telephone) =>
      _post('revendeur_demander', {"telephone": telephone});

  /// Client : soumettre une demande d'achat en gros sur une offre
  static Future<Map<String, dynamic>> soumettreDemandeGrossiste({
    required int offreId,
    required String telephone,
    required String nom,
    required int quantite,
  }) =>
      _post('grossiste_soumettre_demande', {
        "offre_id": offreId,
        "telephone": telephone,
        "nom": nom,
        "quantite": quantite,
      });

  /// Client : historique de ses demandes grossiste
  static Future<Map<String, dynamic>> mesDemandesGrossiste(String telephone) =>
      _post('mes_demandes_grossiste', {"telephone": telephone});

  // ── LOT 10 — PUBLICITÉS ───────────────────────────────────

  /// Publicités actives à l'instant (filtrées par rôle côté serveur
  /// si un téléphone est fourni ; sinon uniquement les pubs "tous")
  static Future<Map<String, dynamic>> publicitesActives(String telephone) =>
      _post('publicites_actives', {"telephone": telephone});

  // ── PARAMÈTRES (profil, mot de passe, notifications, suppression) ──

  static Future<Map<String, dynamic>> obtenirProfil(String telephone) =>
      _post('parametres_obtenir_profil', {"telephone": telephone});

  static Future<Map<String, dynamic>> modifierProfil({
    required String telephone,
    String? nomComplet,
    String? email,
    String? adresse,
    String? photoProfilBase64,
  }) =>
      _post('parametres_modifier_profil', {
        "telephone": telephone,
        if (nomComplet != null) "nom_complet": nomComplet,
        if (email != null) "email": email,
        if (adresse != null) "adresse": adresse,
        if (photoProfilBase64 != null) "photo_profil": photoProfilBase64,
      });

  static Future<Map<String, dynamic>> modifierMotDePasse({
    required String telephone,
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) =>
      _post('parametres_modifier_mot_de_passe', {
        "telephone": telephone,
        "ancien_mot_de_passe": ancienMotDePasse,
        "nouveau_mot_de_passe": nouveauMotDePasse,
      });

  static Future<Map<String, dynamic>> modifierTelephone({
    required String telephone,
    required String nouveauTelephone,
    required String password,
  }) =>
      _post('parametres_modifier_telephone', {
        "telephone": telephone,
        "nouveau_telephone": nouveauTelephone,
        "password": password,
      });

  static Future<Map<String, dynamic>> modifierNotifications({
    required String telephone,
    required bool actif,
  }) =>
      _post('parametres_modifier_notifications', {"telephone": telephone, "actif": actif});

  static Future<Map<String, dynamic>> supprimerCompteUnifie({
    required String telephone,
    required String password,
  }) =>
      _post('parametres_supprimer_compte', {"telephone": telephone, "password": password});

  // ── TEXTES PROMOTIONNELS ADMINISTRABLES ───────────────────

  /// Slogans actifs pour un emplacement donné (ex. 'accueil_banniere'),
  /// modifiables/désactivables en base sans toucher au code.
  static Future<Map<String, dynamic>> textesPromoActifs({String emplacement = 'accueil_banniere'}) =>
      _post('textes_promo_actifs', {"emplacement": emplacement});

  // ── DISPATCH (attribution façon Uber/Yango) ───────────────

  /// Le producteur répond à une proposition de commande.
  static Future<Map<String, dynamic>> repondreProposition({
    required int propositionId,
    required String telephone,
    required String reponse, // 'accepter' | 'refuser'
  }) =>
      _post('repondre_proposition', {
        "proposition_id": propositionId,
        "telephone": telephone,
        "reponse": reponse,
      });

  /// Propositions en attente pour ce producteur (filet de sécurité,
  /// en complément de la notification push).
  static Future<Map<String, dynamic>> mesPropositionsEnAttente(String telephone) =>
      _post('mes_propositions_en_attente', {"telephone": telephone});

  /// Statut du dispatch d'une commande (utile côté client en attente).
  static Future<Map<String, dynamic>> statutDispatchCommande(int cmdId) =>
      _post('statut_dispatch_commande', {"cmd_id": cmdId});
}
