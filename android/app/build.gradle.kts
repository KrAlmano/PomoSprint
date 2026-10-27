import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.pomosprint.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications bunu zorunlu kılıyor (Java 8+ API'lerini
        // desugar eder), yoksa Android build'i checkDebugAarMetadata'da düşüyor.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.pomosprint.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa (ör. temiz bir checkout) debug key'e düş,
            // aksi halde `flutter run --release` kırılır. Play Store'a
            // yüklenecek gerçek build mutlaka key.properties'in var olduğu
            // makinede, "release" imza yapılandırmasıyla alınmalı.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // libflutter.so, libapp.so ve Sentry'nin native kütüphanesinin
            // sembol tabloları AAB'ye (BUNDLE-METADATA) girer; Play Console
            // native çökmeleri çözer, "debug symbols" uyarısı vermez. APK'ya
            // eklenmez. Dart sembolleri ayrıca: scripts/build_release.sh.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

// Mağazaya yüklenecek AAB (bundleRelease) asla debug anahtarıyla
// imzalanmamalı: Play Console reddeder, yanlışlıkla dağıtılırsa sonraki
// güncellemeler imza uyuşmazlığına düşer. Yerel `flutter run --release`
// için yukarıdaki debug fallback'i korunuyor; bu yüzden release APK
// (assembleRelease) durdurulmaz, yalnızca uyarı verilir: debug imzalı APK
// dağıtılırsa kullanıcılar Play sürümüne güncelleyemez.
val releaseBundleTaskName = Regex("^bundle(?:[A-Z][A-Za-z0-9]*)?Release$")
val releaseApkTaskName = Regex("^assemble(?:[A-Z][A-Za-z0-9]*)?Release$")
gradle.taskGraph.whenReady {
    if (!keystorePropertiesFile.exists()) {
        // APK derlemesi bağımlı eklentilerin bundleReleaseLocalLintAar
        // görevlerini de çalıştırır; bunlar mağazaya gönderilecek AAB değildir.
        val appTasks = allTasks.filter { it.project == project }
        val buildsStoreBundle = appTasks.any { releaseBundleTaskName.matches(it.name) }
        if (buildsStoreBundle) {
            throw GradleException(
                "android/key.properties bulunamadı: release AAB debug anahtarıyla imzalanamaz. " +
                    "key.properties dosyasını oluşturup tekrar deneyin."
            )
        }
        val buildsReleaseApk = appTasks.any { releaseApkTaskName.matches(it.name) }
        if (buildsReleaseApk) {
            logger.warn(
                "UYARI: android/key.properties bulunamadı; release APK DEBUG anahtarıyla imzalanıyor. " +
                    "Bu APK'yı dağıtmayın: Play sürümüyle imza uyuşmazlığı olur."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
