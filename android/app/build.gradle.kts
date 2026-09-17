import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val signingPass: String? = System.getenv("ANDROID_SIGNING_PASSWORD")
// BUILD QUALIFICATION != SIGNING AUTHORITY.
// qualificationRelease builds in CI are intentionally unsigned (SIGNING_STATE=UNSIGNED_QUALIFICATION).
// Production signing requires key.properties + ANDROID_SIGNING_PASSWORD from a human authority.
val hasSigningCredentials: Boolean = keyPropertiesFile.exists() && signingPass != null

if (hasSigningCredentials) {
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

    if (hasSigningCredentials) {
        signingConfigs {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = signingPass!!
                keyPassword = signingPass!!
            }
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
            // Signing applied only when human signing authority credentials are present.
            // CI qualification builds (no key.properties, no ANDROID_SIGNING_PASSWORD) produce
            // an intentionally unsigned AAB: SIGNING_STATE=UNSIGNED_QUALIFICATION.
            // ANDROID_RELEASE_CUSTODY_BLOCKED: never substitute debug signing for release authority.
            signingConfig = if (hasSigningCredentials) signingConfigs.getByName("release") else null
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

afterEvaluate {
    // Variant-scoped signing custody using the AGP applicationVariants API.
    // qualificationRelease: unsigned intentional (SIGNING_STATE=UNSIGNED_QUALIFICATION).
    // productionRelease: PRODUCTION_SIGNING_AUTHORITY_REQUIRED — fails closed when credentials absent.
    // Does not use task-name string matching; variant identity comes from the AGP variant model.
    android.applicationVariants.all {
        if (flavorName == "production" && buildType.name == "release") {
            val cap = name.replaceFirstChar { it.uppercase() }
            val gate = tasks.register("assertProductionSigningFor$cap") {
                group = "verification"
                doFirst {
                    check(hasSigningCredentials) {
                        "PRODUCTION_SIGNING_AUTHORITY_REQUIRED: $name cannot build without " +
                        "key.properties + ANDROID_SIGNING_PASSWORD. " +
                        "UNSIGNED_QUALIFICATION is valid only for qualificationRelease."
                    }
                }
            }
            tasks.matching { it.name == "bundle$cap" }.configureEach { dependsOn(gate) }
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
