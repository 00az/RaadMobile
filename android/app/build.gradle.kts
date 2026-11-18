import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "sa.raad.raad_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "sa.raad.raad_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The flavours below set the app name with resValue.
    buildFeatures {
        resValues = true
    }

    // One build per environment (US6.2, BR3.8). Each installs side by side
    // with its own identifier and name, and reads only its own C4 file:
    //   flutter build apk --flavor dev --dart-define-from-file=<c4-dev.json>
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "RAAD DEV")
        }
        create("stg") {
            dimension = "environment"
            applicationIdSuffix = ".stg"
            resValue("string", "app_name", "RAAD STG")
        }
        create("prd") {
            dimension = "environment"
            resValue("string", "app_name", "RAAD")
        }
    }

    buildTypes {
        release {
            // Tester builds are signed by the release pipeline with protected
            // CI credentials; locally the debug key keeps `flutter run --release`
            // working. No signing key is kept in the repository.
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

// ---------------------------------------------------------------- C4 check
//
// The app's real entry point (lib/main.dart) refuses at start a C4 file for
// another environment. This check stops such a build before it is made: the
// flavour's build fails when its C4 values are missing, name another
// environment, or carry a key that looks like a secret. The full schema check
// is `dart run tool/check_env_config.dart`, which CI runs on the file first.
// The offline preview and the integration journeys use the contract fakes
// and no C4 file, so their targets are not checked here.

val c4Keys = listOf(
    "configVersion",
    "environment",
    "apiBaseUrl",
    "moneyBasePath",
    "authIssuer",
    "authAudience",
    "authClientId",
)
val secretMarkers = listOf("secret", "password", "token", "privatekey", "clientsecret")

val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines")?.toString() ?: "")
        .split(",")
        .filter { it.isNotEmpty() }
        .mapNotNull {
            val define = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            val split = define.indexOf('=')
            if (split <= 0) null else define.substring(0, split) to define.substring(split + 1)
        }
        .toMap()
val buildTarget: String =
    (project.findProperty("target")?.toString() ?: "lib/main.dart").replace('\\', '/')
val checksRealApp: Boolean = buildTarget.endsWith("lib/main.dart")

fun c4Problems(flavor: String): List<String> {
    val problems = mutableListOf<String>()
    for (key in c4Keys) {
        if (dartDefines[key].isNullOrEmpty()) problems += "missing \"$key\""
    }
    val environment = dartDefines["environment"]
    if (!environment.isNullOrEmpty() && environment != flavor) {
        problems += "the $flavor flavour was given a C4 file for \"$environment\""
    }
    for (key in dartDefines.keys) {
        if (secretMarkers.any { key.lowercase().contains(it) }) {
            problems += "\"$key\" looks like a secret"
        }
    }
    return problems
}

androidComponents {
    onVariants { variant ->
        val flavor = variant.flavorName
        if (flavor.isNullOrEmpty()) return@onVariants
        val variantName = variant.name.replaceFirstChar { it.uppercase() }
        val problems = if (checksRealApp) c4Problems(flavor) else emptyList()
        val check = tasks.register("checkC4$variantName") {
            group = "verification"
            description = "Refuses a $flavor build whose C4 configuration does not match it."
            doLast {
                if (problems.isNotEmpty()) {
                    throw GradleException(
                        "C4 configuration refused for $flavor: ${problems.joinToString("; ")}. " +
                            "Build with --flavor $flavor --dart-define-from-file=<c4-$flavor.json>.",
                    )
                }
            }
        }
        tasks.matching { it.name == "pre${variantName}Build" }.configureEach {
            dependsOn(check)
        }
    }
}
