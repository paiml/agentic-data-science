package com.paiml.ads

import java.io.File

/** Contract named by a run that touches more than one area. */
const val GATE_CONTRACT = "ads-kotlin-gate-v1"

private val CLASS_CONTRACTS =
    mapOf(
        "P1Test" to "ads-kotlin-p1-v1",
        "OlsTest" to "ads-kotlin-p2-v1",
        "M2ExamplesTest" to "ads-kotlin-p2-v1",
        "M1ExamplesTest" to "ads-kotlin-examples-m1-v1",
        "M3ExamplesTest" to "ads-kotlin-p3-v1",
        "M4ExamplesTest" to "ads-kotlin-examples-m4-v1",
        "P4Test" to "ads-kotlin-p4-v1",
    )

/** The one contract a set of test classes proves. */
fun contractFor(classes: Set<String>): String =
    classes
        .map { CLASS_CONTRACTS[it.substringAfterLast('.')] }
        .toSet()
        .singleOrNull() ?: GATE_CONTRACT

/** `contract: <name> <measured> OK`, or FAILED when the check did not hold. */
fun contractLine(
    name: String,
    measured: String,
    ok: Boolean,
) = "contract: $name $measured ${if (ok) "OK" else "FAILED"}"

/** Print the contract line; a failed check throws, so the exit code is non-zero. */
fun emitContract(
    name: String,
    measured: String,
    ok: Boolean,
) {
    println(contractLine(name, measured, ok))
    check(ok) { "contract $name failed" }
}

/** Line for a finished test run: OK only when tests ran and none failed. */
fun testRunLine(
    classes: Set<String>,
    tests: Int,
    failed: Int,
) = contractLine(
    contractFor(classes),
    "tests $tests",
    tests > 0 && failed == 0,
)

private val ISSUE = Regex("<error ")
private val TESTS = Regex("""tests (\d+) OK$""")

private fun issues(xml: File) =
    if (xml.isFile) {
        ISSUE.findAll(
            xml.readText(),
        ).count()
    } else {
        -1
    }

private fun passedTests(file: File) =
    TESTS.find(testsLine(file))?.let { it.groupValues[1].toInt() }

/** Relay the line the test listener wrote; no result is a failure. */
fun testsLine(file: File) =
    if (file.isFile) {
        file.readText().trim()
    } else {
        contractLine(GATE_CONTRACT, "tests none", false)
    }

/** Detekt line: OK only when the task passed and the report lists no issue. */
fun detektLine(
    passed: Boolean,
    xml: File,
): String {
    val n = issues(xml)
    return contractLine(
        GATE_CONTRACT,
        "detekt issues $n",
        passed && n == 0,
    )
}

/** Whole gate line: the task passed, tests passed and detekt found nothing. */
fun gateLine(
    passed: Boolean,
    tests: File,
    xml: File,
): String {
    val n = issues(xml)
    val t = passedTests(tests) ?: 0
    return contractLine(
        GATE_CONTRACT,
        "tests $t detekt issues $n",
        passed && t > 0 && n == 0,
    )
}
