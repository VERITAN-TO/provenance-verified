allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
// Enforce compileSdk=36 on every Android library plugin after its own build.gradle runs.
// flutter_plugin_android_lifecycle requires minCompileSdk=36; file_picker sets compileSdk=34
// in its own build.gradle AFTER plugins.withId fires, so that approach fails.
// gradle.afterProject fires after each project's configuration is complete — which means
// file_picker's own compileSdk=34 assignment has already run and we can override it.
// This avoids the "already evaluated" error that afterEvaluate hits under evaluationDependsOn.
gradle.afterProject {
    if (plugins.hasPlugin("com.android.library")) {
        val ext = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        // Upgrade-only: never downgrade a plugin that already declares compileSdk >= 36.
        if (ext != null && (ext.compileSdk ?: 0) < 36) {
            ext.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
