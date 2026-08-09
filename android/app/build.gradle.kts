import java.util.Properties
import java.io.FileInputStream

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // ߆ apiag-beta : traite google-services.json (Firebase / FCM)
    id("com.google.gms.google-services")
}

android {
    namespace = "sn.danov.alloguinaar"
    compileSdk = flutter.compileSdkVersion
    // ߆ Corrigé : la version précédente (27.0.12077973) déclenchait un
    // avertissement, le plugin "jni" exigeant la 28.2.13676358.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ߆ Requis par flutter_local_notifications (utilise des API
        // Java 8+ que ce mécanisme "réécrit" pour les anciennes
        // versions d'Android) — voir la doc Android citée dans
        // l'erreur de build Codemagic.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "sn.danov.alloguinaar"
        minSdk = flutter.minSdkVersion
        // ߆ Corrigé : Google Play exige de cibler Android 16 (API 36)
        // au plus tard le 31 août 2026, sous peine de blocage des mises
        // à jour. Flutter 3.44.8 (déjà utilisé par ce projet) supporte
        // pleinement l'API 36, aucune autre mise à jour nécessaire.
        targetSdk = 36
        // ߆ Corrigé pour Codemagic : ces valeurs étaient figées en dur
        // (versionCode=2, versionName="1.0.3"), donc indépendantes de
        // --build-name/--build-number passés par la CI et du champ
        // "version:" de pubspec.yaml — chaque build Android publiait
        // le même numéro de version, ce qui bloque l'upload sur le
        // Play Store (versionCode strictement croissant exigé).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // ߆ Corrigé : ce bloc plantait tout build (même "flutter run"
            // en debug) sur une machine sans key.properties, car Gradle
            // évalue cette configuration avant même de savoir quelle
            // variante sera construite. key.properties n'existe QUE sur
            // Codemagic (généré à la volée par codemagic.yaml) — en local,
            // on saute simplement la config de signature release.
            if (keyPropertiesFile.exists()) {
                keyAlias      = keyProperties["keyAlias"]      as String
                keyPassword   = keyProperties["keyPassword"]   as String
                storeFile     = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ߆ En local (pas de key.properties), on retombe sur la
            // signature debug pour que le projet compile quand même —
            // seul un vrai build release (Codemagic, avec key.properties)
            // sera correctement signé pour publication.
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled   = false
            isShrinkResources = false
        }
    }

    // ✅ FIX DÉFINITIF : désactive le strip des symboles debug
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

// ߆ Bibliothèque requise par isCoreLibraryDesugaringEnabled ci-dessus
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
