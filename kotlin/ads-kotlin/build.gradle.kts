plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kover)
    alias(libs.plugins.ktlint)
    alias(libs.plugins.detekt)
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(libs.dataframe)
    testImplementation(libs.junit.jupiter)
    testImplementation(libs.jackson)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    systemProperty("ads.root", rootDir.parentFile.absolutePath)
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
                    coverageUnits = kotlinx.kover.gradle.plugin.dsl.CoverageUnit.BRANCH
                }
            }
        }
    }
}

// Example entry points: ./gradlew :ads-kotlin:runIngest --args=<csv>
listOf(
    "Ingest" to "IngestMain",
    "Profile" to "ProfileMain",
    "Regress" to "RegressMain",
    "Classify" to "ClassifyMain",
    "Wine" to "WineMain",
    "Bench" to "BenchMain",
).forEach { (name, cls) ->
    tasks.register<JavaExec>("run$name") {
        classpath = sourceSets["main"].runtimeClasspath
        mainClass = "com.paiml.ads.$cls"
        javaLauncher = javaToolchains.launcherFor { languageVersion = JavaLanguageVersion.of(17) }
    }
}
