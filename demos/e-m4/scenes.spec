# E-M4 scene spec: the lines the camera types, one native command at a time,
# each followed by its own exit echo. The terminal starts in `@cwd`.
# `>` lines are real output that scripts/scene-spec.sh replay must find.
# v01 and v10 have no scene output of their own: the typed tool prints it.

== v01
$ grep -nE "^(structure|def|theorem) " AgenticDS/Pipeline.lean
$ echo "exit=$?"
> structure ValidRow
> exit=0

== v02
$ lake exe scene-m4 v02
$ echo "exit=$?"
> features
> exit=0

== v03
$ lake exe scene-m4 v03
$ echo "exit=$?"
> kept
> exit=0

== v04
$ lake exe scene-m4 v04
$ echo "exit=$?"
> exit=0

== v05
$ lake exe scene-m4 v05
$ echo "exit=$?"
> train
> exit=0

== v06
$ lake exe scene-m4 v06
$ echo "exit=$?"
> leaky train
> exit=0

== v07
$ lake exe scene-m4 v07
$ echo "exit=$?"
> exit=0

== v08
$ lake exe scene-m4 v08
$ echo "exit=$?"
> n_rows
> rmse
> exit=0

== v09
$ lake exe scene-m4 v09
$ echo "exit=$?"
$ grep -n 1000000 AgenticDSTest/P4.lean
$ echo "exit=$?"
> pipeline ms
> exit=0

== v10
@gate
@cwd .
$ make gate-lean
$ echo "exit=$?"
> lean OK
> exit=0
