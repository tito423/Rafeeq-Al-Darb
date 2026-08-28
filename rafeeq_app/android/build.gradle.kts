allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build directory redirect is handled in settings.gradle.kts via
// gradle.beforeProject — only root and :app are redirected (plugin
// subprojects on C:\ drive are left at their default to avoid the
// Kotlin "different roots" cross-drive crash).

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
