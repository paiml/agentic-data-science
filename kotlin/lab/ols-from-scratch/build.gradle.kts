// One suite, two code trees. `-Pvariant=starter` (the default) grades the
// code the learner edits; `-Pvariant=solution` grades the reference answer.
// The tests under tests/ are the same files for both.
plugins {
    alias(libs.plugins.kotlin.jvm)
}

val variant: String = (findProperty("variant") as String?) ?: "starter"
require(variant in setOf("starter", "solution") || variant.startsWith("cheat-")) {
    "variant must be starter, solution or cheat-<name>"
}
require(Regex("[a-z0-9-]+").matches(variant)) { "variant name must match [a-z0-9-]+" }
val variantDir = if (variant.startsWith("cheat-")) "cheats/${variant.removePrefix("cheat-")}" else variant

require(file(variantDir).isDirectory) { "no such variant directory: $variantDir" }

kotlin { jvmToolchain(25) }

sourceSets {
    main { kotlin.setSrcDirs(listOf("$variantDir/src")) }
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
