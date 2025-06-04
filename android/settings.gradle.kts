pluginManagement {
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        props.getProperty("flutter.sdk")
            ?: error("flutter.sdk not set in local.properties")
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application")      version "8.2.1" apply false
    id("org.jetbrains.kotlin.android")version "1.8.22" apply false
    id("com.google.gms.google-services") version "4.4.0" apply false
}

rootProject.name = "citypizza_app"
include(":app")

