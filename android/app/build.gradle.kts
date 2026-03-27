import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─────────────────────────────────────────────────────────────
// Release 서명 키(업로드 키) 설정 로드
// root의 key.properties 파일을 읽습니다.
// 예)
// storePassword=******
// keyPassword=******
// keyAlias=upload
// storeFile=app/upload-keystore.jks
// ─────────────────────────────────────────────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

val hasKeystore: Boolean = keystorePropertiesFile.exists()

if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tnbsoft.growth_tracking_graph"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tnbsoft.growth_tracking_graph"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ release 서명 설정 (key.properties가 있을 때만)
    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
        // debug는 기본 debug keystore를 사용하므로 별도 설정 불필요
    }

    buildTypes {
        getByName("debug") {
            // ✅ 디버그 실행은 key.properties가 없어도 무조건 가능해야 합니다.
            // (서명 설정을 건드리지 않습니다.)
        }

        getByName("release") {
            // ✅ key.properties가 있을 때만 release 키로 서명
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // ❗여기서 throw 하면, 환경/빌드 캐시/플러그인 동작에 따라
                // 디버그 빌드까지 영향을 주는 경우가 생길 수 있어 안전하지 않습니다.
                // Play 업로드용 릴리스 빌드는 key.properties를 준비한 뒤 진행하세요.
                // (release 서명 없이는 Play 업로드가 불가)
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}