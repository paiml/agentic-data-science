// Contract line for each scene entry point that is a gradle task.
// The line is built by Kotlin code (Contract.kt) from what the test
// listener measured, and a finalizer prints it after every run: the
// finalizer has no outputs, so it is never up to date.
import org.gradle.api.tasks.SourceSetContainer

val testsResult: String =
    layout.buildDirectory
        .file("contract/tests.txt")
        .get()
        .asFile.absolutePath
val detektXml: String =
    layout.buildDirectory
        .file("reports/detekt/detekt.xml")
        .get()
        .asFile.absolutePath
val inCheck = "${project.path}:check"
val main =
    extensions.getByType<SourceSetContainer>()["main"]

tasks.named<Test>("test") {
    systemProperty("ads.contract.out", testsResult)
    finalizedBy("contractTests")
}

fun relay(
    name: String,
    state: String?,
    vararg files: String,
) = tasks.register<JavaExec>(name) {
    classpath = main.runtimeClasspath
    mainClass = "com.paiml.ads.RelayMainKt"
    val mode = name.removePrefix("contract").lowercase()
    argumentProviders.add(
        CommandLineArgumentProvider {
            val ran = state?.let { tasks.getByPath(it) }
            val passed = ran?.state?.failure == null
            listOf(mode) +
                listOfNotNull(state?.let { "$passed" }) +
                files
        },
    )
}

relay("contractTests", null, testsResult).configure {
    onlyIf { !gradle.taskGraph.hasTask(inCheck) }
}
relay("contractDetekt", "detekt", detektXml).configure {
    onlyIf { !gradle.taskGraph.hasTask(inCheck) }
}
relay("contractGate", "check", testsResult, detektXml)
tasks.named("check") { finalizedBy("contractGate") }
tasks.named("detekt") { finalizedBy("contractDetekt") }
