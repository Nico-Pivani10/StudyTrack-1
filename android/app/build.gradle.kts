
plugins {
    id("com.android.application")

    // Configuración de Firebase.
    id("com.google.gms.google-services")

    id("kotlin-android")

    // Plugin de Flutter.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.studytrack"

    // SDK necesario para las notificaciones.
    compileSdk = maxOf(35, flutter.compileSdkVersion)

    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Compatibilidad con notificaciones programadas.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.studytrack"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Compatibilidad con múltiples archivos DEX.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Configuración de prueba actual.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Dependencia para las notificaciones programadas.
dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}

flutter {
    source = "../.."
}
