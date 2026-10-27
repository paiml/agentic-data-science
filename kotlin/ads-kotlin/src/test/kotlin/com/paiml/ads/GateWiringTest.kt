package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

/** The shacl table this module ships; a dropped row must fail. */
internal val PINNED =
    listOf(
        "verifyShaclP1",
        "verifyShaclP1Profile",
        "verifyShaclP3",
        "verifyShaclP4",
    )

private val shaclSrc =
    File(System.getProperty("ads.scripts"), "shacl.gradle.kts")
        .readText()

private val dep =
    Regex(
        """(?s)it\.name == "check" \}\s*""" +
            """\.configureEach """ +
            """\{ dependsOn\("verifyShaclAll"\) \}""",
    )

/** The shacl gate table is pinned and wired into `check`. */
class GateWiringTest {
    @Test
    fun checkDependsOnVerifyShaclAll() {
        assertTrue(dep.containsMatchIn(shaclSrc))
    }

    @Test
    fun tableIsPinned() {
        assertEquals(PINNED, shaclTasks())
    }
}
