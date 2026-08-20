import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 🆕 CORRIGÉ (voir ci-dessous)
import 'firebase_options.dart';
import 'session_service.dart';
import 'location_service.dart';
import 'notification_service.dart'; // 🆕 apiag-beta
import 'fcm_service.dart';          // 🆕 apiag-beta
import 'catalogue_screen.dart';
import 'livreur_screen.dart';       // 🆕 apiag-beta
import 'producteur_screen.dart';    // 🆕 Lot 3
import 'publicite_service.dart';    // 🆕 Lot 10
import 'app_navigator.dart';        // 🆕 navigatorKey (voir ce fichier pour le pourquoi)
import 'analytics_service.dart';    // 🆕 Lot 11
import 'deep_link_service.dart';    // 🆕 Lot 11

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 CORRIGÉ — CAUSE TROUVÉE DE L'ÉCRAN NOIR : Firebase n'était
  // initialisé (Firebase.initializeApp()) qu'à l'intérieur de
  // FcmService.initialiser(), appelé seulement APRÈS connexion. Or
  // AnalyticsService.observer (Lot 11) est utilisé dès la toute
  // première construction de MaterialApp, avant toute connexion —
  // Firebase Analytics tentait donc de s'utiliser avant d'exister,
  // ce qui levait une FirebaseException dès le tout premier écran,
  // avant que quoi que ce soit ait pu s'afficher. Confirmé par la
  // capture d'écran fournie : "FirebaseException... not a subtype of
  // JavaScriptObject". Initialisé ici, une seule fois, avant tout.
  // try {
  //   await Firebase.initializeApp().timeout(const Duration(seconds: 8));
  // } catch (e) {
  //   debugPrint("Firebase init error: $e");
  // }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // 🆕 Filet de sécurité : si un écran plante pendant sa construction
  // (erreur imprévue), afficher un message visible plutôt que de
  // risquer un rendu vide/noir sans aucune information. Aide aussi au
  // diagnostic si un problème similaire à l'écran noir signalé revient.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
    color: Colors.white,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Color(0xFF8B0000), size: 48),
          const SizedBox(height: 12),
          const Text("Une erreur est survenue", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(details.exceptionAsString(),
            style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  // 🆕 CORRIGÉ : chaque initialisation ici est désormais bornée dans le
  // temps (.timeout(...)). Avant ce correctif, un blocage (jamais une
  // erreur, juste une réponse qui ne vient jamais) dans l'un de ces
  // appels natifs empêchait runApp() d'être atteint — l'app restait sur
  // un écran totalement noir indéfiniment, puisque rien n'avait encore
  // été affiché. Un try/catch seul ne protège PAS contre ce cas : il ne
  // capte que les erreurs explicitement levées, pas un blocage silencieux.
  // Cohérent avec le symptôme observé : jamais reproduit via "flutter
  // run" (débogueur attaché, différent), systématique sur appareil réel
  // (Android ET iOS — ce qui écarte aussi toute piste liée à un moteur
  // de rendu propre à une seule plateforme).
  // 🆕 CORRIGÉ — ces deux initialisations n'ont AUCUN rapport avec le
  // premier rendu visuel (contrairement à Firebase.initializeApp(),
  // requis dès le premier widget par AnalyticsService.observer). Les
  // attendre ici retardait l'apparition du splash de jusqu'à 10
  // secondes (5s + 5s de timeout dans le pire cas), écran totalement
  // vide pendant ce temps. On les démarre sans `await` : elles
  // continuent de tourner en tâche de fond après runApp(), leurs
  // propres timeouts internes (déjà en place) les protègent toujours
  // d'un blocage silencieux.
  NotificationService.initialiser().timeout(
    const Duration(seconds: 5),
    onTimeout: () => debugPrint("Notification init : délai dépassé, on continue sans bloquer"),
  ).catchError((e) => debugPrint("Notification init error: $e"));

  DeepLinkService.initialiser().timeout(
    const Duration(seconds: 5),
    onTimeout: () => debugPrint("Deep link init : délai dépassé, on continue sans bloquer"),
  ).catchError((e) => debugPrint("Deep link init error: $e"));

  runApp(const AlloGuinaarApp());
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     // 👈 2. PASSEZ LES OPTIONS DE LA PLATEFORME ICI
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     ).timeout(const Duration(seconds: 8));
//   } catch (e) {
//     debugPrint("Firebase init error: $e");
//   }

//   // Le reste de votre code main reste inchangé...
//   ErrorWidget.builder = (FlutterErrorDetails details) => Material(
//     color: Colors.white,
//     child: Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(mainAxisSize: MainAxisSize.min, children: [
//           const Icon(Icons.error_outline, color: Color(0xFF8B0000), size: 48),
//           const SizedBox(height: 12),
//           const Text("Une erreur est survenue", style: TextStyle(fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Text(details.exceptionAsString(),
//             style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
//         ]),
//       ),
//     ),
//   );

//   try {
//     await NotificationService.initialiser()
//         .timeout(const Duration(seconds: 5), onTimeout: () {
//       debugPrint("Notification init : délai dépassé, on continue sans bloquer");
//     });
//   } catch (e) {
//     debugPrint("Notification init error: $e");
//   }

//   try {
//     await DeepLinkService.initialiser()
//         .timeout(const Duration(seconds: 5), onTimeout: () {
//       debugPrint("Deep link init : délai dépassé, on continue sans bloquer");
//     });
//   } catch (e) {
//     debugPrint("Deep link init error: $e");
//   }

//   runApp(const AlloGuinaarApp());
// }
class AlloGuinaarApp extends StatelessWidget {
  const AlloGuinaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🆕 nécessaire pour naviguer depuis une notification
      navigatorObservers: [AnalyticsService.observer], // 🆕 Lot 11 : suivi automatique des écrans (GA4)
      title: 'Allo Guinaar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B0000)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// =============================================================
//  SPLASH SCREEN — vérifie session + initialise GPS/notifications
// =============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialiserApp();
  }

  Future<void> _initialiserApp() async {
    // Protection globale contre tout crash au démarrage
    try {
      LocationService.initialiser();
    } catch (e) {
      debugPrint("GPS init error: $e");
    }

    Map<String, dynamic>? session;
    try {
      session = await SessionService.lire();
    } catch (e) {
      debugPrint("Session error: $e");
      session = null;
    }

    if (!mounted) return;

    final String tel  = session?['tel'] ?? '';
    final String role = session?['role'] ?? 'client';

    // 🆕 CORRIGÉ — navigation IMMÉDIATE dès que la session locale est
    // lue (quasi instantané, aucun accès réseau). Auparavant, l'écran
    // suivant n'apparaissait qu'après sauvegarderStatutsInitiaux() ET
    // FcmService.initialiser() (jeton APNs iOS jusqu'à 30s + réseau),
    // deux opérations qui n'ont aucun rapport avec l'affichage de
    // l'écran d'accueil/producteur/livreur. Elles partent maintenant
    // en tâche de fond juste après la navigation, sans jamais la
    // retarder — cohérent avec le pattern déjà utilisé pour
    // PubliciteService.verifierEtAfficher() ailleurs dans le code.
    if (role == 'livreur' && tel.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LivreurScreen(
            telephone: tel,
            nom: session?['nom'] ?? 'Livreur',
          ),
        ),
      );
    } else if (role == 'producteur' && tel.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProducteurScreen(
            telephone: tel,
            nom: session?['nom'] ?? 'Producteur',
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppRoot(
            initialNom:    session?['nom']  ?? "Invité",
            initialPhone:  tel,
            initialUserId: int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0,
          ),
        ),
      );
    }

    // 🆕 Tout le reste : en tâche de fond, jamais attendu, jamais
    // bloquant pour l'écran déjà affiché ci-dessus.
    if (tel.isNotEmpty) {
      NotificationService.sauvegarderStatutsInitiaux(tel)
          .catchError((e) => debugPrint("Statuts initiaux error: $e"));
      FcmService.initialiser(tel)
          .catchError((e) => debugPrint("Notification/FCM init error: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF8B0000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "AlloGUINAAR",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// =============================================================
//  APP ROOT — 🆕 apiag-beta : observe le cycle de vie de l'app
//  pour vérifier les changements de statut de commande au retour
//  au premier plan (fallback si une notification push a été manquée).
// =============================================================
class AppRoot extends StatefulWidget {
  final String initialNom;
  final String initialPhone;
  final int    initialUserId;

  const AppRoot({
    super.key,
    required this.initialNom,
    required this.initialPhone,
    required this.initialUserId,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late String _telephone;

  @override
  void initState() {
    super.initState();
    _telephone = widget.initialPhone;
    WidgetsBinding.instance.addObserver(this);
    // 🆕 Lot 10 : vérifier les publicités actives après le premier
    // rendu, pour ne pas retarder l'affichage de l'écran d'accueil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🆕 Réactivé : testé sans les publicités, l'écran noir persistait
      // quand même — cause écartée, pas la peine de priver les clients
      // des publicités pour rien.
      if (mounted) PubliciteService.verifierEtAfficher(context, _telephone);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _telephone.isNotEmpty) {
      try {
        NotificationService.verifierChangementsStatut(_telephone);
      } catch (e) {
        debugPrint("Notification check error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogueScreen(
      initialNom:    widget.initialNom,
      initialPhone:  widget.initialPhone,
      initialUserId: widget.initialUserId,
    );
  }
}