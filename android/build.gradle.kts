allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://devrepo.kakao.com/nexus/content/groups/public/") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires namespace for all library modules.
// facebook_audience_network (and other old plugins) omit namespace or use low compileSdk.
// gradle.afterProject runs after each project's configuration is complete,
// safely overriding compileSdk even when projects are already evaluated.
gradle.afterProject {
    extensions.findByType(com.android.build.gradle.LibraryExtension::class)?.let { lib ->
        if (lib.namespace == null) {
            lib.namespace = group.toString()
        }
        lib.compileSdk = 36
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
