import kotlinx.kover.gradle.plugin.dsl.CoverageUnit

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kover)
    alias(libs.plugins.ktlint)
    alias(libs.plugins.detekt)
    application
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(libs.dataframe)
    implementation(libs.kandy)
    implementation(libs.mordant)
    implementation(libs.commons.math)
    runtimeOnly(libs.slf4j.nop)
    testImplementation(libs.junit.jupiter)
    testImplementation(libs.jackson)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    systemProperty("ads.scenes", file("scenes").absolutePath)
    useJUnitPlatform()
    systemProperty("ads.root", rootDir.parentFile.absolutePath)
    systemProperty("ads.scripts", projectDir.absolutePath)
    systemProperty(
        "ads.gradle",
        File(gradle.gradleHomeDir, "bin/gradle").absolutePath,
    )
    systemProperty(
        "ads.csv",
        rootDir.parentFile.resolve(
            "datasets/penguins/penguins.csv",
        ).absolutePath,
    )
    systemProperty(
        "ads.plot",
        layout.buildDirectory.file(
            "test-plot.png",
        ).get().asFile.absolutePath,
    )
}

detekt {
    config.setFrom(file("detekt.yml"))
    buildUponDefaultConfig = true
}

val lineBound = 100
val branchBound = 95

kover {
    currentProject {
        createVariant("branch") { add("jvm") }
    }
    reports {
        total {
            log {
                header = "kover"
                format =
                    "line coverage <value>% " +
                    "(koverVerify bound: $lineBound%)"
            }
        }
        variant("branch") {
            log {
                header = "kover"
                coverageUnits = CoverageUnit.BRANCH
                format =
                    "branch coverage <value>% " +
                    "(koverVerify bound: $branchBound%)"
            }
        }
        verify {
            rule("line") { minBound(lineBound) }
            rule("branch") {
                bound {
                    minValue = branchBound
                    coverageUnits = CoverageUnit.BRANCH
                }
            }
        }
    }
}

// Example entry points:
// ./gradlew :ads-kotlin:runIngest --args=<csv>
listOf(
    "Ingest" to "IngestMain",
    "Profile" to "ProfileMain",
).forEach {
        (name, cls) ->
    tasks.register<JavaExec>("run$name") {
        classpath = sourceSets["main"].runtimeClasspath
        mainClass = "com.paiml.ads.$cls"
    }
}

// Scene entry point (ADS demo): build/install/ols/bin/ols,
// run from the repo root.
application {
    mainClass = "com.paiml.ads.PenguinsOlsKt"
    applicationName = "ols"
    applicationDefaultJvmArgs =
        listOf(
            "-Dkotlin-logging.logStartupMessage=false",
            "-Djava.awt.headless=true",
        )
}

// Pinned library versions, read by the scene banner
// (single source: libs.versions.toml).
tasks.processResources {
    val pins =
        mapOf(
            "dataframe" to libs.versions.dataframe.get(),
            "kandy" to libs.versions.kandy.get(),
            "mordant" to libs.versions.mordant.get(),
            "commonsMath" to libs.versions.commons.math.get(),
        )
    inputs.properties(pins)
    filesMatching("versions.properties") { expand(pins) }
}

// ./gradlew -q run: the scene reads data and writes the plot at
// the repo root; colour is forced because Gradle pipes stdout.
tasks.named<JavaExec>("run") {
    workingDir = rootDir.parentFile
    environment("FORCE_COLOR", "1")
}

// Scene manifests (scenes/*.scene): one JavaExec task per
// manifest with a main= key, run as ./gradlew -q <task>.
// Tool scenes (no main=) run the real Gradle task instead.
fun manifest(f: File) =
    f.readLines().filter { "=" in it }.associate {
        it.substringBefore("=").trim() to
            it.substringAfter("=").trim()
    }
file("scenes").listFiles { f -> f.extension == "scene" }
    .orEmpty().sorted().forEach { f ->
        val mc = manifest(f)["main"] ?: return@forEach
        tasks.register<JavaExec>(f.nameWithoutExtension) {
            classpath = sourceSets["main"].runtimeClasspath
            mainClass = mc
            jvmArgs("-Dkotlin-logging.logStartupMessage=false")
            workingDir = rootDir.parentFile
            environment("FORCE_COLOR", "1")
        }
    }

// A tool scene runs the tool, never a cached result.
tasks.matching {
    it.name.startsWith("kover") ||
        it.name.startsWith("detekt") ||
        it.name.contains("ktlint", ignoreCase = true)
}.configureEach { outputs.upToDateWhen { false } }
tasks.test { outputs.upToDateWhen { false } }

// The wired shacl gate tasks the shacl scenes run on camera.
apply(from = "shacl.gradle.kts")

// measuredCheck matches each scene's `measured` regex against the
// captured live koverLog output (scripts/gate-kotlin.sh). It is
// not part of `test` or of the coverage run: it needs the
// capture, and fails without it.
tasks.test {
    filter { excludeTestsMatching("*MeasuredRealOutputTest") }
}
tasks.register<Test>("measuredCheck") {
    testClassesDirs = sourceSets.test.get().output.classesDirs
    classpath = sourceSets.test.get().runtimeClasspath
    useJUnitPlatform()
    filter { includeTestsMatching("*MeasuredRealOutputTest") }
    systemProperty("ads.root", rootDir.parentFile.absolutePath)
    systemProperty("ads.scenes", file("scenes").absolutePath)
    systemProperty(
        "ads.koverOut",
        providers.gradleProperty("koverOut").getOrElse(""),
    )
    outputs.upToDateWhen { false }
}
kover {
    currentProject {
        instrumentation {
            disabledForTestTasks.add("measuredCheck")
        }
    }
}
