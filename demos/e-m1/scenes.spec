# E-M1 scene spec: the lines the camera types, one native command at a time,
# each followed by its own exit echo. The terminal starts in `@cwd`.
# `>` lines are real output that scripts/scene-spec.sh replay must find.

== v01
$ ls AgenticDS/Csv.lean AgenticDS/Profile.lean AgenticDS/Stats.lean
$ echo "exit=$?"
$ lake exe scene-m1 v01
$ echo "exit=$?"
> mean     = 5
> variance = 4
> exit=0

== v02
$ lake exe scene-m1 v02
$ echo "exit=$?"
> false
> exit=0

== v03
$ cat lean-toolchain
$ echo "exit=$?"
$ lake build AgenticDS.Stats
$ echo "exit=$?"
> leanprover/lean4:v4.35.0
> Build completed successfully
> exit=0

== v04
@cwd .
$ make lean-scan
$ echo "exit=$?"
> scan: no markers in
> exit=0

== v05
$ grep -oE "^theorem (mean_const|variance_[a-z]+)" AgenticDS/Stats.lean
$ echo "exit=$?"
> theorem mean_const
> theorem variance_nonneg
> theorem variance_shift
> exit=0

== v06
$ lake exe scene-m1 v06
$ echo "exit=$?"
> contract: ads-lean-p1-v1 OK
> exit=0

== v07
$ lake exe scene-m1 v07
$ echo "exit=$?"
> depends on axioms
> exit=0

== v08
$ lake exe scene-m1 v08
$ echo "exit=$?"
> FALSIFY lines:
> exit=0

== v09
@gate
@cwd .
$ make gate-lean
$ echo "exit=$?"
> lean OK
> exit=0

== v10
$ ls examples
$ echo "exit=$?"
> e-m1-p1
> exit=0
