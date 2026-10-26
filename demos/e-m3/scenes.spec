# E-M3 scene spec: the lines the camera types, one native command at a time,
# each followed by its own exit echo. The terminal starts in `@cwd`.
# `>` lines are real output that scripts/scene-spec.sh replay must find.
# `@expect-exit N` (v09) declares a hold that shows `> exit=N`: the
# planted mismatch makes the scene fail non-zero, and the camera shows it.
# A tool-only scene (v01, v05, v10) is shown by the typed tool's own output.

== v01
$ wc -l AgenticDS/Kmeans.lean AgenticDS/Confusion.lean AgenticDS/Tree.lean
$ echo "exit=$?"
> total
> exit=0

== v02
$ lake exe scene-m3 v02
$ echo "exit=$?"
> objective:
> exit=0

== v03
$ lake exe scene-m3 v03
$ echo "exit=$?"
> never beaten: true
> exit=0

== v04
$ lake exe scene-m3 v04
$ echo "exit=$?"
> species: 3
> exit=0

== v05
@cwd .
$ make lean-scan
$ echo "exit=$?"
> scan: no markers in
> exit=0

== v06
$ lake exe scene-m3 v06
$ echo "exit=$?"
> dev empty:
> exit=0

== v07
$ lake exe scene-m3 v07
$ echo "exit=$?"
> fitTree:
> exit=0

== v08
$ lake exe scene-m3 v08
$ echo "exit=$?"
> file confusion: [[37, 0, 0], [0, 16, 1], [0, 1, 30]]
> accuracy: 83/85 golden
> exit=0

== v09
@expect-exit 1
$ lake exe scene-m3 v09
$ echo "exit=$?"
> expected: [[36, 1, 0], [0, 16, 1], [0, 1, 30]]
> observed: [[37, 0, 0], [0, 16, 1], [0, 1, 30]]
> FAIL v09: confusion differs
> exit=1

== v10
@gate
@cwd .
$ make gate-lean
$ echo "exit=$?"
> lean OK
> exit=0
