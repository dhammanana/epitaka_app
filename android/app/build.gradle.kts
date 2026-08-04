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

        // sqlite_vector 1.0.0 only ships a prebuilt Android binary for
        // arm64-v8a (native_libraries/android/vector_android_arm64.so).
        // Without this filter the default build targets armeabi-v7a and
        // x86_64 as well, and the package's native-assets hook fails with
        // "Pre-built binary not found: vector_android_arm.so". arm64-v8a
        // covers all modern devices (Google Play has required 64-bit
        // support since Aug 2019).
        //
        // If other ABIs are ever needed, the missing binaries can be
        // fetched from the sqlite-vector GitHub release (tag 1.0.0):
        //   vector-android-armeabi-v7a-1.0.0.zip  -> vector_android_arm.so
        //   vector-android-x86_64-1.0.0.zip       -> vector_android_x64.so
        // extracted into the pub cache package dir at
        //   ~/.pub-cache/hosted/pub.dev/sqlite_vector-1.0.0/native_libraries/android/
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
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
