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
// android/key.properties 파일을 읽습니다.
// 예)
// storePassword=******
// keyPassword=******
// keyAlias=upload
// storeFile=app/upload-keystore.jks
// ─────────────────────────────────────────────────────────────
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tnbsoft.growth_tracking_graph"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ release 서명 설정 추가
    signingConfigs {
        // key.properties가 없으면 release 빌드에서 실패하므로,
        // 파일이 있을 때만 release 설정을 구성합니다.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ✅ Play Console 업로드용: 반드시 release 키로 서명
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // key.properties가 없으면 debug 서명으로 되돌리지 말고,
                // 문제를 바로 알 수 있게 예외를 터뜨립니다.
                throw GradleException("android/key.properties 파일이 없습니다. release 서명을 위해 key.properties를 생성하세요.")
            }

            // Flutter 기본값 유지(원하면 추후 proguard/minify 설정)
            // isMinifyEnabled = false
            // isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
