import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing keys come from key.properties locally, from env vars on CI.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseStorePath: String =
    System.getenv("KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFile", "")
// Without a release key (fresh fork, no CI secrets) the build still produces an
// installable APK, signed with the debug key; updates then need a reinstall.
val hasReleaseKeystore: Boolean =
    releaseStorePath.isNotEmpty() && file(releaseStorePath).exists()

android {
    namespace = "com.hacan359.tonkatsubox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.axelax12.tonkatsuboxplus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) create("release") {
            // Env vars on CI, key.properties locally.
            storeFile = file(releaseStorePath)
            storePassword =
                System.getenv("KEYSTORE_PASSWORD")
                    ?: keystoreProperties.getProperty("storePassword", "")
            keyAlias =
                System.getenv("KEY_ALIAS")
                    ?: keystoreProperties.getProperty("keyAlias", "")
            keyPassword =
                System.getenv("KEYSTORE_PASSWORD")
                    ?: keystoreProperties.getProperty("keyPassword", "")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
