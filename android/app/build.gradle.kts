import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured from android/key.properties, which is
// gitignored and never committed (see android/key.properties.example for
// the placeholder format). Release builds require this file and a complete
// set of signing properties; there is no fallback to the debug key. See the
// gradle.taskGraph.whenReady check below for where that is enforced.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasKeystoreProperties) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

fun missingOrBlankSigningProperties(): List<String> =
    requiredSigningProperties.filter { keystoreProperties.getProperty(it).isNullOrBlank() }

val releaseSigningHelp = """
    |To build a signed release:
    |  1. Copy android/key.properties.example to android/key.properties.
    |  2. Fill in your local upload-keystore settings in android/key.properties.
    |  3. Keep both android/key.properties and the keystore file out of version control.
""".trimMargin()

android {
    namespace = "com.cowbullgame.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cowbullgame.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile", ""))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasKeystoreProperties && missingOrBlankSigningProperties().isEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Otherwise left unset: the taskGraph check below fails the build
            // before any release task runs, so an unsigned/mis-signed release
            // artifact is never produced.
        }
    }
}

// Enforced here (configuration time, gated on the requested tasks) rather
// than unconditionally, so ordinary non-release tasks — flutter analyze,
// flutter test, flutter build apk --debug — keep working without
// android/key.properties.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") }
    if (!buildingRelease) {
        return@whenReady
    }
    if (!hasKeystoreProperties) {
        throw GradleException(
            "android/key.properties not found — release build requires a " +
                "real local signing configuration.\n\n$releaseSigningHelp",
        )
    }
    val missing = missingOrBlankSigningProperties()
    if (missing.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing or has a blank value for: " +
                "${missing.joinToString(", ")}.\n\n$releaseSigningHelp",
        )
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
