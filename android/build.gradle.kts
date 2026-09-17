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
// Defensive: ensure all Android library subprojects compile against SDK 36.
// flutter_plugin_android_lifecycle requires minCompileSdk=36; file_picker >=8.1.4
// ships with compileSdkVersion 36 in its own build.gradle (root cause fix).
// plugins.withId fires pre-evaluation, which avoids the "already evaluated" error
// that afterEvaluate triggers when evaluationDependsOn(":app") is in scope above.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
