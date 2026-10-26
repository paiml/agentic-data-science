// Wired gate tasks: a shacl scene runs one of
// these on camera. Jena shacl exits 0 on findings, so each task
// echoes Jena report and fails the build unless it conforms.
// Fail closed: the table is fixed here (no -P override) and every
// directory, shape and data file must exist at configuration time.
val verdict = "sh:conforms  true"
val repo: File = rootDir.parentFile
val ex = "kotlin/ads-kotlin/examples"

// Entries: task, directory, shape file, data file.
val scenes: List<List<String>> =
    listOf(
        listOf("P1", "$ex/d-m1-p1", "example", "example.ttl"),
        listOf(
            "P1Profile",
            "$ex/d-m1-p1-profile",
            "example",
            "example.ttl",
        ),
        listOf("P3", "$ex/d-m3-p3", "example", "example.ttl"),
        listOf(
            "P4",
            "datasets/golden",
            "artifact",
            "p4-artifact.ttl",
        ),
    ).map { (n, d, s, f) ->
        listOf(
            "verifyShacl$n",
            "$repo/$d",
            "$repo/ontology/shapes/$s.shape.ttl",
            f,
        )
    }

scenes.forEach { (name, dir, shape, data) ->
    val dirs = listOf(File(dir))
    val files = listOf(File(shape), File(dir, data))
    val noDir = dirs.filterNot { it.isDirectory }
    val bad = noDir + files.filterNot { it.isFile }
    if (bad.isNotEmpty()) {
        throw GradleException("$name: missing $bad (fail closed)")
    }
}

val names =
    scenes.map { (name, dir, shape, data) ->
        tasks.register<Exec>(name) {
            workingDir = file(dir)
            commandLine("shacl", "v", "-s", shape, "-d", data)
            val seen = java.io.ByteArrayOutputStream()
            standardOutput = seen
            outputs.upToDateWhen { false }
            doLast {
                logger.quiet(seen.toString().trimEnd())
                check(verdict in seen.toString()) {
                    "SHACL: $data does not conform\n$seen"
                }
            }
        }
        name
    }
check(names.isNotEmpty()) { "shacl gate is empty (fail closed)" }
tasks.register("verifyShaclAll") { dependsOn(names) }
tasks.matching { it.name == "check" }
    .configureEach { dependsOn("verifyShaclAll") }
