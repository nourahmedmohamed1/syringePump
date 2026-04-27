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
    if (project.name != "app") {
        afterEvaluate {
            if (project.plugins.hasPlugin("com.android.library")) {
                val androidExtension = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                if (androidExtension != null && androidExtension.namespace.isNullOrEmpty()) {
                    val manifest = file("${project.projectDir}/src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val packageName = javax.xml.parsers.DocumentBuilderFactory.newInstance()
                            .newDocumentBuilder()
                            .parse(manifest)
                            .documentElement
                            .getAttribute("package")
                        if (packageName.isNotEmpty()) {
                            androidExtension.namespace = packageName
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
