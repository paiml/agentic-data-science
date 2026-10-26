package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

/** The shacl table this PR ships; a dropped row must fail. */
internal val PINNED =
    listOf(
        "verifyShaclP1",
        "verifyShaclP1Profile",
        "verifyShaclP4",
    )

private val root = File(System.getProperty("ads.root"))
private val scenesDir = File(System.getProperty("ads.scenes"))
private val shaclSrc =
    File(scenesDir.parentFile, "shacl.gradle.kts").readText()

/** Contracts of this PR that carry a cwd: losing one must fail. */
private const val CWD_CONTRACTS = 6

/** Gate tasks the scenes of this PR run on camera. */
private val SCENE_TASKS =
    setOf(
        "verifyShaclP1",
        "verifyShaclP1Profile",
    )

private val idRe = Regex("m(\\d)v(\\d+)")
private val cwdRe = Regex("(?m)^\\s+cwd:\\s*(\\S+)\\s*\$")
private val runRe = Regex("""verifyShacl\w+""")
private val dep =
    Regex(
        """(?s)it\.name == "check" \}\s*""" +
            """\.configureEach """ +
            """\{ dependsOn\("verifyShaclAll"\) \}""",
    )

private fun scenes() =
    scenesDir.listFiles { f -> f.extension == "scene" }.orEmpty()
        .sorted().map { it.nameWithoutExtension to sceneKeys(it) }

/** C1/C3: contracts, scenes and the shacl table agree. */
class GateWiringTest {
    @Test
    fun contractCwdEqualsSceneCwd() {
        var seen = 0
        for ((id, keys) in scenes()) {
            val m = idRe.matchEntire(id) ?: continue
            val (a, b) = m.destructured
            val pre = "ads-kotlin-m$a-v$b-"
            val files =
                File(root, "contracts")
                    .listFiles { f -> f.name.startsWith(pre) }
                    .orEmpty()
            for (f in files) {
                val hit = cwdRe.find(f.readText())
                val c = hit?.groupValues?.get(1)
                seen += if (c != null) 1 else 0
                if (c != null) assertEquals(keys["cwd"], c, f.name)
            }
        }
        assertEquals(CWD_CONTRACTS, seen, "cwd count")
    }

    @Test
    fun checkDependsOnVerifyShaclAll() {
        assertTrue(dep.containsMatchIn(shaclSrc))
    }

    @Test
    fun tableIsPinnedAndEveryShaclSceneNamesARow() {
        assertEquals(PINNED, shaclTasks())
        val ran =
            scenes().flatMap { (id, keys) ->
                runRe.findAll(keys.getValue("run"))
                    .map { id to it.value }.toList()
            }.filter { it.second != "verifyShaclAll" }
        for ((id, t) in ran) {
            assertTrue(t in PINNED, "$id runs $t, not in the table")
        }
        assertEquals(SCENE_TASKS, ran.map { it.second }.toSet())
    }
}
