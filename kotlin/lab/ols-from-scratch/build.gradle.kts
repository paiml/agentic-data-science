// One suite, two code trees. `-Pvariant=starter` (the default) grades the
// code the learner edits; `-Pvariant=solution` grades the reference answer.
// The tests under tests/ are the same files for both.
plugins {
    alias(libs.plugins.kotlin.jvm)
}

val variant: String = (findProperty("variant") as String?) ?: "starter"
require(variant in setOf("starter", "solution")) { "variant must be starter or solution" }

kotlin { jvmToolchain(25) }

sourceSets {
    main { kotlin.setSrcDirs(listOf("$variant/src")) }
    test { kotlin.setSrcDirs(listOf("tests")) }
}

dependencies {
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    // The penguins file the demo course uses (kotlin/lab/ols-from-scratch -> repo root).
    systemProperty("lab.csv", rootDir.resolve("../../../datasets/penguins/penguins.csv").absolutePath)
    testLogging {
        events("passed", "failed")
        showStandardStreams = false
    }
}
