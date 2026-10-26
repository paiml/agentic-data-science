# v07: the gates, run natively on the real merged code
export ADS_ROOT="$PWD"
make gate-shacl
echo "exit=$?"
cd r/agenticds
Rscript -e 'cv <- covr::package_coverage()
print(cv)
quit(status = covr::percent_coverage(cv) < 100)'
echo "exit=$?"
Rscript -e 'lints <- lintr::lint_package()
print(lints)
quit(status = length(lints) > 0)'
echo "exit=$?"
Rscript -e 'styler::style_pkg(dry = "fail")'
echo "exit=$?"
