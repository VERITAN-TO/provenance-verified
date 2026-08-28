plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "to.veritan.pv.provenance_verified_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationId = "to.veritan.pv.dev"
            versionNameSuffix = "-dev"
        }
        create("qualification") {
            dimension = "environment"
            applicationId = "to.veritan.pv.qual"
            versionNameSuffix = "-qual"
        }
        create("production") {
            dimension = "environment"
            applicationId = "to.veritan.pv"
        }
    }

    defaultConfig {
        applicationId = "to.veritan.pv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        compileSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
