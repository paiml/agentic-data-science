package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

/** The m4v09 task fails on an artifact without a schemaVersion. */
class ArtifactShaclCanFailTest {
    @Test
    fun verifyShaclP4FailsOnAnArtifactWithoutASchemaVersion() {
        val onPath =
            System
                .getenv("PATH")
                .orEmpty()
                .split(":")
                .any { File(it, "shacl").canExecute() }
        assertTrue(onPath, "shacl (Jena) not on PATH")
        val ok = ShaclRepoCopy().gradle("verifyShaclP4")
        assertEquals(0, ok.first, ok.second)
        assertTrue("sh:conforms  true" in ok.second, ok.second)
        val copy = ShaclRepoCopy()
        copy.breakData("verifyShaclP4")
        val no = copy.gradle("verifyShaclP4")
        assertNotEquals(0, no.first, no.second)
        assertTrue("sh:conforms  false" in no.second, no.second)
    }
}
