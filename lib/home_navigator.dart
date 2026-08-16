import 'package:flutter/material.dart';
import 'session_service.dart';
import 'catalogue_screen.dart';
import 'producteur_screen.dart';
import 'livreur_screen.dart';

// =============================================================
//  RETOUR À L'ACCUEIL — permet de revenir à l'écran d'accueil du
//  rôle courant (client, producteur, livreur) à tout moment, quel
//  que soit l'endroit où l'on se trouve dans l'app. Sert aussi de
//  filet de sécurité en cas de comportement inattendu d'un écran.
// =============================================================
class HomeNavigator {
  static Future<void> allerAccueil(BuildContext context) async {
    final session = await SessionService.lire();
    if (!context.mounted) return;

    final String tel  = session?['tel'] ?? '';
    final String nom  = session?['nom'] ?? '';
    final String role = session?['role'] ?? 'client';

    Widget ecran;
    switch (role) {
      case 'producteur':
        ecran = ProducteurScreen(telephone: tel, nom: nom);
        break;
      case 'livreur':
        ecran = LivreurScreen(telephone: tel, nom: nom);
        break;
      default:
        ecran = CatalogueScreen(initialNom: nom.isEmpty ? "Invité" : nom, initialPhone: tel);
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ecran),
      (route) => false,
    );
  }

  /// Bouton prêt à l'emploi pour une AppBar : `actions: [HomeNavigator.bouton()]`
  static Widget bouton() => Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.home_outlined, color: Colors.grey),
      tooltip: "Retour à l'accueil",
      onPressed: () => allerAccueil(context),
    ),
  );
}
