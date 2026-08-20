package sn.danov.alloguinaar

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// =============================================================
//  MainActivity — pont natif pour les réglages système qui
//  conditionnent la fiabilité des alertes plein écran (Uber/Yango-
//  style) sur Samsung/Android 14+ :
//
//   1. USE_FULL_SCREEN_INTENT (Android 14+) — sans elle, l'alerte
//      retombe silencieusement sur une notification standard.
//   2. Optimisation de la batterie — si Android/Samsung considère
//      l'app comme "optimisée", il peut retarder ou tuer l'isolate
//      d'arrière-plan avant même que le message FCM soit traité.
//      SEUL réglage de ce lot qu'on peut faire accepter en un clic
//      via une vraie boîte de dialogue système (les autres exigent
//      un aller-retour dans les paramètres).
//   3. Canal de notification urgent — ouvre directement l'écran de
//      réglages du canal "alloguinaar_urgent_channel", où
//      l'utilisateur peut activer l'option de pop-up si Samsung la
//      propose séparément.
//   4. Démarrage automatique (Samsung "Sleeping apps"/"Auto-start")
//      — AUCUNE API Android publique n'existe pour ça. On ne peut
//      qu'ouvrir l'écran de détails de l'app et guider l'utilisateur
//      manuellement ; toute automatisation complète serait un
//      mensonge, Samsung ne l'expose à aucune app tierce.
//
//  flutter_local_notifications ne gère aucun de ces quatre points
//  nativement — d'où ce canal dédié.
// =============================================================
class MainActivity : FlutterActivity() {
    private val CHANNEL = "sn.danov.alloguinaar/full_screen_intent"

    // 🆕 IMPORTANT — pièce manquante probable pour "écran verrouillé et
    // éteint : rien ne se passe", même une fois le handler d'arrière-
    // plan confirmé fonctionnel. `fullScreenIntent: true` côté
    // flutter_local_notifications demande à Android de LANCER cette
    // Activity par-dessus l'écran verrouillé — mais sans ces
    // indicateurs, Android peut recevoir la demande sans jamais
    // réveiller l'écran ni afficher quoi que ce soit tant que
    // l'utilisateur n'a pas lui-même déverrouillé le téléphone.
    // N'ayant qu'une seule Activity pour toute l'app (comme la plupart
    // des projets Flutter), ces indicateurs s'appliquent à CHAQUE
    // lancement — même compromis que les apps d'appel entrant type
    // WhatsApp/Messenger. Le téléphone n'est jamais déverrouillé pour
    // autant : Android affiche l'app par-dessus l'écran de
    // verrouillage, qui reste actif en dessous.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        try {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } catch (e: Exception) {
            // Non bloquant — sur certains OEM/versions cet appel peut
            // échouer sans conséquence, showWhenLocked ci-dessus suffit
            // déjà à afficher l'app par-dessus le verrouillage.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "peutUtiliserPleinEcran" -> {
                    result.success(peutUtiliserPleinEcran())
                }
                "ouvrirReglagesPleinEcran" -> {
                    ouvrirReglagesPleinEcran()
                    result.success(null)
                }
                "batterieDejaExclue" -> {
                    result.success(batterieDejaExclue())
                }
                "demanderExclusionBatterie" -> {
                    demanderExclusionBatterie()
                    result.success(null)
                }
                "ouvrirReglagesCanalUrgent" -> {
                    ouvrirReglagesCanalUrgent()
                    result.success(null)
                }
                "ouvrirReglagesDemarrageAuto" -> {
                    ouvrirReglagesDemarrageAuto()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── 1. Plein écran ──────────────────────────────────────────
    private fun peutUtiliserPleinEcran(): Boolean {
        // Avant Android 14, cette permission est accordée par défaut à
        // toutes les apps qui la déclarent dans le manifeste — donc pas
        // de vérification à faire, toujours autorisé.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun ouvrirReglagesPleinEcran() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }

    // ── 2. Optimisation de la batterie ──────────────────────────
    private fun batterieDejaExclue(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun demanderExclusionBatterie() {
        // C'est la SEULE demande de ce lot qui déclenche une vraie
        // boîte de dialogue "Autoriser"/"Refuser" gérée par Android
        // lui-même — pas un simple raccourci vers un écran de
        // réglages où l'utilisateur doit chercher l'option.
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        }
    }

    // ── 3. Réglages du canal de notification urgent ─────────────
    private fun ouvrirReglagesCanalUrgent() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, "alloguinaar_urgent_channel")
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivity(intent)
        }
    }

    // ── 4. Démarrage automatique ────────────────────────────────
    // 🆕 IMPORTANT — honnêteté technique : il n'existe AUCUNE API
    // Android publique pour activer ce réglage par programmation, sur
    // aucun constructeur. Les intents "magiques" qui circulent en
    // ligne (com.samsung.android.sm...) sont non documentés, changent
    // à chaque version de One UI, et Google les fait régulièrement
    // rejeter du Play Store pour usage d'API privée. On ouvre donc,
    // honnêtement, l'écran de détails de l'app — le geste manuel dans
    // "Maintenance de l'appareil → Batterie → Démarrage automatique"
    // reste nécessaire de ton côté.
    private fun ouvrirReglagesDemarrageAuto() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}