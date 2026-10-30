package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream

private val okLine = Regex("^contract: [a-z0-9-]+ [^\\r\\n]+ OK$")
private const val NUM = "-?[0-9]+\\.[0-9]+"
private const val EXP = "-?[0-9]\\.[0-9]+e[+-][0-9]{2}"

/** Exact shape of each example's contract line (locale-independent: ASCII digits, '.'). */
private val pinned =
    mapOf(
        "m1v01" to
            Regex(
                "^contract: ads-kotlin-examples-m1-v1 rows [0-9]+ -> [0-9]+ OK$",
            ),
        "m1v02" to
            Regex(
                "^contract: ads-kotlin-examples-m1-v1 golden max gap $EXP OK$",
            ),
        "m2v01" to
            Regex(
                "^contract: ads-kotlin-p2-v1 residuals $EXP slope $NUM OK$",
            ),
        "m3v01" to
            Regex(
                "^contract: ads-kotlin-p3-v1 accuracy $NUM objective $NUM OK$",
            ),
        "m4v01" to
            Regex(
                "^contract: ads-kotlin-examples-m4-v1 rmse $NUM r2 $NUM OK$",
            ),
        "m4v02" to
            Regex(
                "^contract: ads-kotlin-examples-m4-v1 engines agree, timed [0-9]+ OK$",
            ),
    )

private fun out(block: () -> Unit): String {
    val buf = ByteArrayOutputStream()
    val old = System.out
    System.setOut(PrintStream(buf))
    try {
        block()
    } finally {
        System.setOut(old)
    }
    return buf.toString()
}

private fun lines(block: () -> Unit) = out(block).trim().lines()

private val examples =
    mapOf<String, () -> Unit>(
        "m1v01" to {
            com.paiml.ads.m1v01
                .main()
        },
        "m1v02" to {
            com.paiml.ads.m1v02
                .main()
        },
        "m2v01" to {
            com.paiml.ads.m2v01
                .main()
        },
        "m3v01" to {
            com.paiml.ads.m3v01
                .main()
        },
        "m4v01" to {
            com.paiml.ads.m4v01
                .main()
        },
        "m4v02" to {
            com.paiml.ads.m4v02
                .main()
        },
    )

/** Every example ends on exactly one OK contract line. */
class ContractTest {
    init {
        System.setProperty(
            "ads.golden",
            File(
                System.getProperty("ads.root"),
                "datasets/golden/p2.json",
            ).path,
        )
    }

    @Test
    fun everyExampleEndsOnOneContractLineThatIsOk() {
        examples.forEach { (name, run) ->
            val all = lines(run)
            val last = all.last()
            assertTrue(
                okLine.matches(last) &&
                    pinned.getValue(name).matches(last),
                "$name last line: $last",
            )
            assertEquals(
                1,
                all.count { it.startsWith("contract: ") },
                name,
            )
        }
    }

    @Test
    fun theContractNamesAreContractFiles() {
        val contracts =
            File(System.getProperty("ads.root"), "contracts")
        examples.forEach { (name, run) ->
            val contract = lines(run).last().split(" ")[1]
            assertTrue(
                File(contracts, "$contract.yaml").isFile,
                "$name: $contract",
            )
        }
        assertTrue(File(contracts, "$GATE_CONTRACT.yaml").isFile)
    }

    @Test
    fun aFailedCheckPrintsFailedAndThrows() {
        val buf = ByteArrayOutputStream()
        val old = System.out
        System.setOut(PrintStream(buf))
        try {
            assertThrows(IllegalStateException::class.java) {
                emitContract("ads-kotlin-p1-v1", "rows 1", false)
            }
        } finally {
            System.setOut(old)
        }
        assertEquals(
            "contract: ads-kotlin-p1-v1 rows 1 FAILED",
            buf.toString().trim(),
        )
    }

    @Test
    fun aRunNamesTheContractItProves() {
        assertEquals(
            "ads-kotlin-p1-v1",
            contractFor(setOf("com.paiml.ads.P1Test")),
        )
        assertEquals(
            GATE_CONTRACT,
            contractFor(
                setOf(
                    "com.paiml.ads.P1Test",
                    "com.paiml.ads.OlsTest",
                ),
            ),
        )
        assertEquals(
            GATE_CONTRACT,
            contractFor(setOf("com.paiml.ads.ToolsCanFailTest")),
        )
        assertEquals(GATE_CONTRACT, contractFor(emptySet()))
    }

    @Test
    fun aTestRunIsOkOnlyWhenTestsRanAndNoneFailed() {
        val p1 = setOf("com.paiml.ads.P1Test")
        assertEquals(
            "contract: ads-kotlin-p1-v1 tests 5 OK",
            testRunLine(p1, 5, 0),
        )
        assertTrue(testRunLine(p1, 5, 1).endsWith(" FAILED"))
        assertTrue(testRunLine(p1, 0, 0).endsWith(" FAILED"))
    }

    @Test
    fun theRelayPrintsTheLineTheListenerWroteAndFailsOnFailure() {
        val dir = TempTrash.dir("ads-contract")
        val ok =
            File(dir, "ok.txt").apply {
                writeText("contract: x tests 2 OK\n")
            }
        val bad =
            File(dir, "bad.txt").apply {
                writeText("contract: x tests 2 FAILED\n")
            }
        val none = File(dir, "none.txt")
        assertEquals(
            "contract: x tests 2 OK",
            relayLine(listOf("tests", ok.path)),
        )
        assertEquals(
            "contract: x tests 2 OK",
            lines { main(arrayOf("tests", ok.path)) }.single(),
        )
        assertThrows(IllegalStateException::class.java) {
            out { main(arrayOf("tests", bad.path)) }
        }
        assertEquals(
            "contract: $GATE_CONTRACT tests none FAILED",
            relayLine(listOf("tests", none.path)),
        )
    }

    private val dir = TempTrash.dir("ads-contract-detekt")

    private fun file(
        name: String,
        text: String? = null,
    ) = File(dir, name).apply { text?.let { writeText(it) } }.path

    private val clean =
        file("clean.xml", "<checkstyle></checkstyle>")
    private val dirty =
        file(
            "dirty.xml",
            "<checkstyle><file><error line=\"1\"/>" +
                "</file></checkstyle>",
        )
    private val missing = file("missing.xml")

    private fun failed(vararg args: String) =
        relayLine(
            args.toList(),
        ).endsWith(" FAILED")

    @Test
    fun detektLineNeedsAPassAndAnEmptyReport() {
        assertEquals(
            "contract: $GATE_CONTRACT detekt issues 0 OK",
            relayLine(listOf("detekt", "true", clean)),
        )
        assertTrue(failed("detekt", "false", clean))
        assertTrue(failed("detekt", "true", dirty))
        assertTrue(failed("detekt", "true", missing))
    }

    @Test
    fun gateLineNeedsPassedTestsAndAnEmptyReport() {
        val ok = file("tests.txt", "contract: x tests 7 OK\n")
        val red = file("f.txt", "contract: x tests 7 FAILED\n")
        assertEquals(
            "contract: $GATE_CONTRACT tests 7 detekt issues 0 OK",
            relayLine(listOf("gate", "true", ok, clean)),
        )
        assertTrue(failed("gate", "false", ok, clean))
        assertTrue(failed("gate", "true", ok, dirty))
        assertTrue(failed("gate", "true", red, clean))
        assertTrue(failed("gate", "true", file("none.txt"), clean))
    }
}
