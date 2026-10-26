package com.paiml.ads

import java.io.File
import java.nio.file.Files

private val realRoot = File(System.getProperty("ads.root"))
private val scripts = File(System.getProperty("ads.scripts"))

/** Temp dirs a test makes; all are deleted when the JVM exits. */
internal object TempTrash {
    private val made = mutableListOf<File>()

    init {
        Runtime.getRuntime().addShutdownHook(
            Thread { made.forEach { it.deleteRecursively() } },
        )
    }

    @Synchronized
    fun dir(prefix: String): File =
        Files.createTempDirectory(prefix).toFile().also {
            made += it
        }
}

/** One table row: the task, then three more string args. */
private val TABLE_ROW =
    Regex(
        """listOf\(\s*"(\w+)",""" +
            """(?:\s*"[^"]*",){2}\s*"[^"]*",?\s*\)""",
    )

/** Task names listed in the shacl.gradle.kts scene table. */
internal fun shaclTasks(): List<String> =
    TABLE_ROW
        .findAll(File(scripts, "shacl.gradle.kts").readText())
        .map { "verifyShacl${it.groupValues[1]}" }.toList()

internal fun shaclRun(
    dir: File,
    vararg cmd: String,
): Pair<Int, String> {
    val p =
        ProcessBuilder(*cmd).directory(dir)
            .redirectErrorStream(true).start()
    val out = p.inputStream.bufferedReader().readText()
    return p.waitFor() to out
}

/**
 * A throwaway repo (shapes, examples, golden data) whose
 * kotlin/ project applies the real shacl.gradle.kts, so the real
 * task names run on copies the test may break.
 */
internal class ShaclRepoCopy {
    val repo: File = TempTrash.dir("ads-gate")
    private val proj = File(repo, "kotlin")

    init {
        for (d in listOf(
            "ontology/shapes",
            "datasets/golden",
            "kotlin/ads-kotlin/examples",
        )) {
            File(realRoot, d).copyRecursively(File(repo, d))
        }
        proj.mkdirs()
        File(proj, "settings.gradle.kts").writeText("")
        File(proj, "build.gradle.kts").writeText(
            "apply(from = \"${File(
                scripts,
                "shacl.gradle.kts",
            )}\")\n",
        )
    }

    /** Break the data file a task validates, in the copy only. */
    fun breakData(task: String) {
        val f =
            repo.walkTopDown().filter { it.isFile }.first {
                it.name.endsWith(".ttl") &&
                    it.parentFile.let { d ->
                        shaclDirOf(task, d)
                    }
            }
        val text = f.readText()
        val broken =
            text.replace("\"kotlin\"", "\"cobol\"")
                .lines().filterNot { "schemaVersion" in it }
                .joinToString("\n")
        check(broken != text) { "nothing to break in $f" }
        f.writeText(broken)
    }

    private fun shaclDirOf(
        task: String,
        dir: File,
    ): Boolean {
        val rel = dir.relativeTo(repo).path
        return when (task) {
            "verifyShaclP1" -> rel.endsWith("examples/d-m1-p1")
            "verifyShaclP1Profile" ->
                rel.endsWith("examples/d-m1-p1-profile")
            "verifyShaclP4" -> rel == "datasets/golden"
            else -> false
        }
    }

    fun gradle(vararg args: String): Pair<Int, String> =
        shaclRun(
            proj,
            System.getProperty("ads.gradle"),
            "-p",
            "$proj",
            "--offline",
            "--no-daemon",
            "--console=plain",
            *args,
        )
}
