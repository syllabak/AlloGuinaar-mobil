import 'package:flutter/material.dart';
import 'session_service.dart';

/// Écran de Politique de Confidentialité.
/// [showAcceptButton] = true  → utilisé à l'inscription (bouton J'accepte)
/// [showAcceptButton] = false → lecture seule (accessible depuis le profil)
class PrivacyPolicyScreen extends StatelessWidget {
  final bool showAcceptButton;
  final VoidCallback? onAccepted;

  const PrivacyPolicyScreen({
    super.key,
    this.showAcceptButton = false,
    this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text(
          "Politique de Confidentialité",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- En-tête rouge ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 44),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Vos données nous engagent",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Dernière mise à jour : Janvier 2025",
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _section(
                    icon: Icons.store_outlined,
                    titre: "1. Qui sommes-nous ?",
                    texte:
                        "Allo Guinaar est une plateforme sénégalaise de commande et livraison de poulets "
                        "directement depuis les fermes locales. L'application est éditée par Danov SN, "
                        "dont le siège est à Dakar, Sénégal.",
                  ),
                  _section(
                    icon: Icons.data_object_outlined,
                    titre: "2. Données collectées",
                    texte: "Nous collectons uniquement les données nécessaires au service :",
                    items: [
                      "Nom et prénom",
                      "Numéro de téléphone (identifiant de connexion)",
                      "Adresse de livraison",
                      "Localisation GPS (calcul de la ferme la plus proche)",
                      "Historique de vos commandes",
                    ],
                  ),
                  _section(
                    icon: Icons.task_alt_outlined,
                    titre: "3. Pourquoi ces données ?",
                    texte: "Vos données sont utilisées exclusivement pour :",
                    items: [
                      "Valider et livrer vos commandes",
                      "Vous notifier par SMS (confirmation, suivi)",
                      "Calculer la ferme la plus proche de votre position",
                      "Vous permettre de consulter votre historique",
                      "Améliorer la qualité de notre service",
                    ],
                  ),
                  _section(
                    icon: Icons.location_on_outlined,
                    titre: "4. Localisation GPS",
                    texte:
                        "L'accès à votre position est demandé pour identifier automatiquement "
                        "la ferme partenaire la plus proche et calculer les frais de livraison.\n\n"
                        "• Utilisée uniquement lors de la passation d'une commande\n"
                        "• Jamais revendue ni partagée avec des tiers non impliqués\n"
                        "• Vous pouvez refuser : saisissez alors votre adresse manuellement",
                  ),
                  _section(
                    icon: Icons.share_outlined,
                    titre: "5. Partage des données",
                    texte: "Vos données ne sont JAMAIS vendues. Elles sont partagées uniquement avec :",
                    items: [
                      "Le producteur assigné à votre commande (préparation et livraison)",
                      "Notre prestataire SMS (notifications de commande)",
                      "PayTech Sénégal (paiement en ligne sécurisé uniquement)",
                    ],
                  ),
                  _section(
                    icon: Icons.schedule_outlined,
                    titre: "6. Durée de conservation",
                    texte:
                        "Vos données sont conservées tant que votre compte est actif. "
                        "Après suppression du compte, toutes vos données personnelles sont effacées "
                        "sous 30 jours, sauf obligation légale (commandes payées).",
                  ),
                  _section(
                    icon: Icons.lock_outline,
                    titre: "7. Sécurité",
                    texte:
                        "Vos mots de passe sont chiffrés via bcrypt et ne sont jamais lisibles, "
                        "même par notre équipe technique. Toutes les communications entre l'application "
                        "et notre serveur sont sécurisées via HTTPS.",
                  ),
                  _section(
                    icon: Icons.gavel_outlined,
                    titre: "8. Vos droits",
                    texte:
                        "Conformément à la Loi sénégalaise n° 2008-12 sur la protection des données "
                        "personnelles, vous disposez des droits suivants :",
                    items: [
                      "Droit d'accès : consulter toutes vos données",
                      "Droit de rectification : corriger des informations inexactes",
                      "Droit d'effacement : supprimer votre compte et vos données",
                      "Droit d'opposition : refuser certains traitements",
                    ],
                  ),
                  _section(
                    icon: Icons.contact_support_outlined,
                    titre: "9. Nous contacter",
                    texte:
                        "Pour exercer vos droits ou pour toute question :\n\n"
                        "📧  contact@danov.sn\n"
                        "📞  +221 76 616 66 57\n"
                        "📍  Dakar, Sénégal",
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // --- Bouton acceptation (inscription uniquement) ---
          if (showAcceptButton)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    "J'AI LU ET J'ACCEPTE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  onPressed: () async {
                    await SessionService.enregistrerConsentement();
                    if (onAccepted != null) {
                      onAccepted!();
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String titre,
    required String texte,
    List<String>? items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF8B0000)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titre,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF8B0000))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.65)),
            if (items != null) ...[
              const SizedBox(height: 8),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("•  ",
                          style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold, fontSize: 14)),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
