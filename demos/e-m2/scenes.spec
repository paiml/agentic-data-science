# E-M2 scene spec: the lines the camera types, one native command at a time,
# each followed by its own exit echo. The terminal starts in `@cwd`.
# `>` lines are real output that scripts/scene-spec.sh replay must find.

== v01
$ ls AgenticDS
$ echo "exit=$?"
$ sed -n 6,17p AgenticDS/Regression.lean
$ echo "exit=$?"
> Regression.lean
> variable {K : Type*} [Field K]
> exit=0

== v02
$ grep -n "def s" AgenticDS/Regression.lean
$ echo "exit=$?"
$ grep -n -A 2 "def ols" AgenticDS/Regression.lean
$ echo "exit=$?"
> def sx
> def olsSlope
> exit=0

== v03
$ grep -n -B 3 -A 3 "T4" AgenticDS/Regression.lean
$ echo "exit=$?"
$ grep -n "theorem resid" AgenticDS/Regression.lean
$ echo "exit=$?"
> theorem ols_normal_equations
> theorem resid_sum
> exit=0

== v04
$ lake env lean AgenticDS/Scenes/M2V04.lean
$ echo "exit=$?"
> ⊢ (resid d 1 2).sum = sy d - cnt d * 1 - 2 * sx d
> @ols_normal_equations
> exit=0

== v05
$ grep -n -B 3 -A 3 "T5" AgenticDS/Regression.lean
$ echo "exit=$?"
$ lake env lean AgenticDS/Scenes/M2V05.lean
$ echo "exit=$?"
> ols_residuals_sum_zero_real
> exit=0

== v06
$ lake exe scene-m2 v06
$ echo "exit=$?"
$ grep -n "\"intercept\"" ../../datasets/golden/p2.json
$ echo "exit=$?"
$ grep -n "\"slope\"" ../../datasets/golden/p2.json
$ echo "exit=$?"
$ lake env lean --run AgenticDSTest/OlsTest.lean ../..
$ echo "exit=$?"
> slope: 1145743050/23059877
> intercept: -133305260075/23059877
> contract: ads-lean-p2-v1 OK
> exit=0

== v07
$ lake env lean scripts/AxiomsM2.lean
$ echo "exit=$?"
$ make -C ../.. lean-scan
$ echo "exit=$?"
> depends on axioms
> scan: no markers in
> exit=0

== v08
$ lake exe scene-m2 v08
$ echo "exit=$?"
$ grep -n -A 1 "cv_rmse" ../../datasets/golden/p2.json
$ echo "exit=$?"
> cv rmse: 394.312960
> exit=0

== v09
$ lake env lean AgenticDSTest/PlantedWrongSlope.lean
$ echo "exit=$?"
$ lake env lean AgenticDS/Scenes/M2V09.lean
$ echo "exit=$?"
> did not evaluate to `true`
> exit=1
> 5 / 2
> exit=0

== v10
$ lake build AgenticDS scene-m2
$ echo "exit=$?"
$ git -C ../.. log --oneline -1
$ echo "exit=$?"
$ git -C ../.. log -3 --oneline
$ echo "exit=$?"
> Build completed successfully
> exit=0
