import java.io.FileInputStream
import java.util.Properties

// Load key.properties file if present
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.dn.epitaka"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dn.epitaka"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // NOTE: no abiFilters here — the app must ship native libraries for
        // ALL Android ABIs (armeabi-v7a, arm64-v8a, x86_64). Restricting to
        // arm64-v8a crashes on 32-bit devices at startup with
        // "Could not find 'libflutter.so'. Looked for: [armeabi-v7a, ...]"
        // (seen on POCO C61). The AAB carries per-ABI slices and Google Play
        // serves each device its matching slice, so 64-bit devices pay no
        // size penalty. (An old arm64-only filter for sqlite_vector was
        // removed: that package is no longer a dependency.)
    }

    flavorDimensions += "environment"

    productFlavors {
        // Dev flavor: a SEPARATE app (com.dn.epitaka.dev, "-dev" version) so
        // it can coexist with the production app on the same device.
        // Run it with: flutter run --flavor dev
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        // Production flavor: plain app id/version. The CI workflow MUST build
        // with `--flavor prod` — once flavors are declared, a bare
        // `flutter build appbundle --release` emits AABs under
        // bundle/<Flavor>Release/ (e.g. bundle/prodRelease/) and the Flutter
        // tool then fails because it looks for bundle/release/.
        create("prod") {
            dimension = "environment"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    assetPacks += listOf(":packs:core_db")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
