allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The newBuildDir override was removed to prevent Kotlin compiler "different roots" errors when using AGP.
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
