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

// Some plugins (e.g. file_picker) compile their Java with target 17 but let
// Kotlin default to the running JDK (21), which fails the build with an
// "Inconsistent JVM-target compatibility" error. Pin every Kotlin compile task
// to JVM 17 so it matches the Java target across all modules.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

// The Kotlin pin above cuts the other way for in_app_update (U48): the plugin
// declares Java *and* Kotlin at 1.8, so forcing only its Kotlin to 17 recreates
// the same mismatch from the Java side. Raise that one module's Java
// compileOptions to 17 to match. In `afterEvaluate` deliberately: registered
// from here (root evaluation) it runs after the plugin's own `android { 1.8 }`
// block but before AGP's own afterEvaluate creates the compile tasks, so 17 is
// what the tasks are born with — configuring the tasks directly is too late.
subprojects {
    if (name == "in_app_update") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
