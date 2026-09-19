import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dibaca dari android/key.properties, yang sengaja TIDAK masuk git
// (lihat .gitignore). Selama berkas itu belum ada, build rilis jatuh ke kunci
// debug supaya `flutter build apk --release` tetap jalan untuk uji coba.
val berkasKunci = rootProject.file("key.properties")
val kunciRilis = Properties().apply {
    if (berkasKunci.exists()) berkasKunci.inputStream().use { load(it) }
}
val pakaiKunciRilis = berkasKunci.exists() &&
    kunciRilis.getProperty("storeFile") != null

android {
    namespace = "com.shineemad.struk_bangunan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shineemad.struk_bangunan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (pakaiKunciRilis) {
            create("release") {
                storeFile = file(kunciRilis.getProperty("storeFile"))
                storePassword = kunciRilis.getProperty("storePassword")
                keyAlias = kunciRilis.getProperty("keyAlias")
                keyPassword = kunciRilis.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (pakaiKunciRilis) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
