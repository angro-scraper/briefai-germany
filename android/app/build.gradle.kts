import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `flutterfire configure` places google-services.json in this directory.
// Keep the local development build usable until a Firebase project is selected.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.exists()) {
        signingPropertiesFile.inputStream().use(::load)
    }
}

android {
    namespace = "com.briefai.briefai_germany"
    // Google Play requires Android 16 / API 36 for new updates from Aug 2026.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable production application ID; do not change after Play release.
        applicationId = "com.briefai.briefai_germany"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase, ML Kit and modern encrypted storage require Android 23+.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (signingPropertiesFile.exists()) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = signingProperties.getProperty("keyAlias")
                    keyPassword = signingProperties.getProperty("keyPassword")
                    storeFile = file(signingProperties.getProperty("storeFile"))
                    storePassword = signingProperties.getProperty("storePassword")
                }
            } else {
                // This permits local configuration but release task execution is blocked below.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

tasks.configureEach {
    if (name.contains("Release") && (name.startsWith("package") || name.startsWith("bundle"))) {
        doFirst {
            check(signingPropertiesFile.exists()) {
                "Release signing is not configured. Copy android/key.properties.example to android/key.properties and provide the production keystore."
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
