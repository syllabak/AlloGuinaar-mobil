package sn.danov.alloguinaar

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// =============================================================
//  MainActivity — pont natif pour la permission spéciale
//  USE_FULL_SCREEN_INTENT (Android 14+).
//
//  Depuis Android 14 (API 34), cette permission n'est plus accordée
//  automatiquement à l'installation, sauf pour les apps de type
//  dialer/réveil — ce qui n'est pas notre cas. Sans elle, le système
//  refuse silencieusement l'alerte plein écran façon appel entrant et
//  retombe sur une notification standard (c'est exactement ce qui
//  était observé : notification classique au lieu du plein écran).
//
//  flutter_local_notifications n'expose pas cette vérification/demande
//  nativement — d'où ce petit canal dédié, minimal, sans dépendance
//  supplémentaire.
// =============================================================
class MainActivity : FlutterActivity() {
    private val CHANNEL = "sn.danov.alloguinaar/full_screen_intent"

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
                else -> result.notImplemented()
            }
        }
    }

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
            // Repli : certains OEM n'exposent pas cet écran précis —
            // on ouvre alors la page de paramètres générale de l'app,
            // où l'utilisateur peut trouver l'option manuellement.
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}
