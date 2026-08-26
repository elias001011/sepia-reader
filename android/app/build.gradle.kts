import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.elias.sepia_reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.elias.sepia_reader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists() && keyPropsFile.readText().trim().isNotEmpty()) {
        val keyProps = Properties()
        keyProps.load(FileInputStream(keyPropsFile))
        signingConfigs {
            create("release") {
                keyAlias     = keyProps.getProperty("keyAlias")
                keyPassword  = keyProps.getProperty("keyPassword")
                // The workflow drops the keystore next to this file (in
                // android/app/), not next to key.properties (in android/) —
                // `file()` resolves storeFile against this module, matching
                // where it's actually written.
                storeFile    = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropsFile.exists() && keyPropsFile.readText().trim().isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
