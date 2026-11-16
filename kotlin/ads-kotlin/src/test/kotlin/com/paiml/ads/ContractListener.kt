package com.paiml.ads

import org.junit.platform.engine.TestExecutionResult
import org.junit.platform.engine.support.descriptor.MethodSource
import org.junit.platform.launcher.TestExecutionListener
import org.junit.platform.launcher.TestIdentifier
import org.junit.platform.launcher.TestPlan
import java.io.File

/**
 * Writes the contract line of the run that just finished, for the
 * gradle finalizer to relay. OK only if tests ran and none failed.
 */
class ContractListener : TestExecutionListener {
    private val out =
        System.getProperty("ads.contract.out")?.let {
            File(it)
        }
    private val classes = mutableSetOf<String>()
    private var tests = 0
    private var failed = 0

    override fun testPlanExecutionStarted(testPlan: TestPlan) {
        out?.delete()
    }

    override fun executionFinished(
        id: TestIdentifier,
        result: TestExecutionResult,
    ) {
        if (id.isTest) {
            tests++
            (id.source.orElse(null) as? MethodSource)?.let {
                classes += it.className
            }
        }
        val good = TestExecutionResult.Status.SUCCESSFUL
        if (result.status != good) failed++
    }

    override fun testPlanExecutionFinished(testPlan: TestPlan) {
        out?.let {
            it.parentFile.mkdirs()
            it.writeText(testRunLine(classes, tests, failed) + "\n")
        }
    }
}
