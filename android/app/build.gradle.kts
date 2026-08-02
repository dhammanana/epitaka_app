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
        debug {
            // Dev/debug installs get a distinct app id (com.dn.epitaka.dev)
            // so they can coexist with the Play Store release on the same
            // device. This is a build-type suffix, NOT a product flavor — a
            // flavor would rename the release variant to "devRelease" and
            // break `flutter build appbundle --release` (the Flutter tool
            // then can't find app-release.aab under bundle/release/).
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        // NOTE: a `profile` build type cannot be configured here — `profile`
        // collides with a Kotlin DSL extension on NamedDomainObjectContainer
        // and fails script compilation. Flutter's implicit profile build type
        // is used as-is (no .dev suffix).
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
