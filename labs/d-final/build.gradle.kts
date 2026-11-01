// One suite, two code trees. `-Pvariant=starter` (default) grades what the learner edits; `-Pvariant=solution` the reference.
// The course library (P1.kt, Ols.kt, the CSV parser in Contract.kt) is compiled from kotlin/ads-kotlin, not copied.
plugins {
    alias(libs.plugins.kotlin.jvm)
}

val variant: String = (findProperty("variant") as String?) ?: "starter"
require(variant in setOf("starter", "solution")) { "variant must be starter or solution" }

// The course pins JDK 25; -Pjdk=<n> overrides it on a host that lacks 25 (recorded in the receipt).
kotlin { jvmToolchain(((findProperty("jdk") as String?) ?: "25").toInt()) }

val course = rootDir.resolve("../../kotlin/ads-kotlin/src/main/kotlin/com/paiml/ads")

sourceSets {
    main {
        kotlin.setSrcDirs(listOf("$variant/src"))
        kotlin.srcDir(course)
        kotlin.include("lab/**", "P1.kt", "Ols.kt", "Contract.kt")
    }
    test { kotlin.setSrcDirs(listOf("tests")) }
}

dependencies {
    implementation(libs.dataframe)
    implementation(libs.commons.math)
    runtimeOnly(libs.slf4j.nop)
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    systemProperty("lab.csv", rootDir.resolve("../../datasets/penguins/penguins.csv").absolutePath)
    testLogging {
        events("passed", "failed")
        showStandardStreams = false
    }
}
