import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "to.veritan.pv.provenance_verified_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            val signingPass = System.getenv("ANDROID_SIGNING_PASSWORD") ?: ""
            storePassword = signingPass
            keyPassword = signingPass
        }
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
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
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
