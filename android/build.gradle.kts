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
    // Asset pack modules (:packs:core_db) are pure Android AssetPack
    // projects with no Flutter/plugin coupling — they must NOT wait on
    // :app evaluation, otherwise Gradle reports a circular dependency
    // (the app references the pack via `assetPacks`).
    if (name != "core_db") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
