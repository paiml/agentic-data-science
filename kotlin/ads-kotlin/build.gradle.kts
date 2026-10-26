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
    useJUnitPlatform()
    systemProperty("ads.root", rootDir.parentFile.absolutePath)
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

kover {
    reports {
        verify {
            rule("line") { minBound(100) }
            rule("branch") {
                bound {
                    minValue = 95
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
