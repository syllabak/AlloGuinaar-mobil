import 'package:flutter/material.dart';

/// Clé de navigation globale — permet d'ouvrir un écran depuis une
/// notification (FCM ou locale), sans BuildContext disponible à cet
/// endroit (callback de tap, parfois déclenché hors de l'arbre de
/// widgets actif). Isolée dans son propre fichier pour éviter un
/// import circulaire entre main.dart et notification_router.dart.
final navigatorKey = GlobalKey<NavigatorState>();
