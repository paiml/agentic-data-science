package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

private val root = File(System.getProperty("ads.root"))

private fun run(
    dir: File,
    vararg cmd: String,
): Pair<Int, String> {
    val p =
        ProcessBuilder(*cmd).directory(dir)
            .redirectErrorStream(true).start()
    val out = p.inputStream.bufferedReader().readText()
    return p.waitFor() to out
}

private fun onPath(tool: String) =
    System.getenv("PATH").orEmpty().split(":")
        .any { File(it, tool).canExecute() }

private fun has(
    out: String,
    text: String,
) = assertTrue(text in out, out)

private const val EX = "kotlin/ads-kotlin/examples"
private const val SHAPE = "ontology/shapes/example.shape.ttl"

private fun asDir(
    repo: File,
    rel: String,
) {
    val f = File(repo, rel)
    f.delete()
    f.mkdir()
}

private fun notADir(
    repo: File,
    rel: String,
) {
    val d = File(repo, rel)
    d.deleteRecursively()
    d.writeText("not a directory")
}

/** The tools shown on camera exit non-zero on a bad input. */
class ToolsCanFailTest {
    @Test
    fun sha256sumFailsOnAChangedByte() {
        assertTrue(onPath("sha256sum"), "sha256sum not on PATH")
        val src = File(root, "datasets/penguins")
        val tmp = TempTrash.dir("ads-sha")
        File(src, "SHA256SUMS").copyTo(File(tmp, "SHA256SUMS"))
        val csv = File(tmp, "penguins.csv")
        File(src, "penguins.csv").copyTo(csv)
        assertEquals(
            0,
            run(tmp, "sha256sum", "-c", "SHA256SUMS").first,
        )
        csv.appendText("x")
        assertNotEquals(
            0,
            run(tmp, "sha256sum", "-c", "SHA256SUMS").first,
        )
    }

    /**
     * Real Jena, a hard failure when it is missing. Jena's shacl
     * exits 0 on a finding (measured, 5.2.0): its report is the
     * verdict, and each verify task turns a non-conforming
     * report into a failed build. The real task names run on a
     * throwaway repo copy: good, then one file broken at a time.
     */
    @Test
    fun everyVerifyTaskPassesGoodAndFailsBroken() {
        assertTrue(onPath("shacl"), "shacl (Jena) not on PATH")
        val tasks = shaclTasks()
        assertEquals(PINNED, tasks, "table changed")
        val good = ShaclRepoCopy().gradle("verifyShaclAll")
        assertEquals(0, good.first, good.second)
        has(good.second, "BUILD SUCCESSFUL")
        for (t in tasks) {
            val hit = Regex("> Task :$t\\s")
            assertTrue(hit.containsMatchIn(good.second), t)
        }
        assertEquals(
            tasks.size,
            Regex("sh:conforms  true").findAll(good.second).count(),
            good.second,
        )
        for (t in tasks) {
            val copy = ShaclRepoCopy()
            copy.breakData(t)
            val bad = copy.gradle(t)
            assertNotEquals(
                0,
                bad.first,
                "$t passed: ${bad.second}",
            )
            has(bad.second, "does not conform")
            has(bad.second, "sh:conforms  false")
        }
    }

    @Test
    fun jenaExitsZeroOnAFindingSoTheTaskMustDecide() {
        assertTrue(onPath("shacl"), "shacl (Jena) not on PATH")
        val copy = ShaclRepoCopy()
        copy.breakData("verifyShaclP1")
        val d =
            File(copy.repo, "kotlin/ads-kotlin/examples/d-m1-p1")
        val shape =
            File(copy.repo, "ontology/shapes/example.shape.ttl")
        val r =
            run(
                d,
                "shacl",
                "v",
                "-s",
                "$shape",
                "-d",
                "example.ttl",
            )
        has(r.second, "sh:conforms  false")
        assertEquals(0, r.first, r.second)
    }

    @Test
    fun theGateFailsClosedOnAMissingDataShapeOrDirIsAFile() {
        val cases =
            listOf<Pair<(File) -> Unit, String>>(
                Pair(
                    { r ->
                        File(
                            r,
                            "$EX/d-m1-p1/example.ttl",
                        ).delete()
                    },
                    "example.ttl",
                ),
                Pair(
                    { r -> File(r, SHAPE).delete() },
                    "example.shape.ttl",
                ),
                Pair({ r -> notADir(r, "$EX/d-m1-p1") }, "d-m1-p1"),
                Pair(
                    { r -> asDir(r, "$EX/d-m1-p1/example.ttl") },
                    "d-m1-p1/example.ttl",
                ),
                Pair({ r -> asDir(r, SHAPE) }, "example.shape.ttl"),
            )
        for ((breakIt, named) in cases) {
            val copy = ShaclRepoCopy()
            breakIt(copy.repo)
            val r = copy.gradle("verifyShaclAll")
            assertNotEquals(0, r.first, r.second)
            has(r.second, "fail closed")
            has(r.second, named)
        }
    }

    @Test
    fun theGateFailsClosedOnAMissingFileAndIgnoresAnyDashP() {
        val copy = ShaclRepoCopy()
        val ex = File(copy.repo, "kotlin/ads-kotlin/examples")
        ex.deleteRecursively()
        val gone = copy.gradle("verifyShaclAll")
        assertNotEquals(0, gone.first, gone.second)
        has(gone.second, "fail closed")
        val fresh = ShaclRepoCopy()
        val empty =
            TempTrash.dir("ads-empty").toString()
        val names = listOf("shaclRepo", "dir", "data", "names")
        for (p in names + listOf("repo", "ex", "verdict")) {
            val r = fresh.gradle("-P$p=$empty", "verifyShaclAll")
            assertEquals(0, r.first, r.second)
            for (t in shaclTasks()) {
                val hit = Regex("> Task :$t\\s")
                val ok = hit.containsMatchIn(r.second)
                assertTrue(ok, "$t: ${r.second}")
            }
        }
    }
}
