#!/bin/bash
# bottom pane: versions read back at run time, then a clean bash. Env: PV_REPO PV_TARGET
cd "$PV_REPO" || exit 1
export RUSTUP_TOOLCHAIN=1.99.1
v=$(vim --version | sed -nE '1s/.*IMproved ([0-9.]+).*/\1/p;/Included patches/s/.*-([0-9]+)$/.\1/p' | tr -d '\n')
echo "rustc $(rustc --version | cut -d' ' -f2) | cargo $(cargo --version | cut -d' ' -f2) | vim $v"
cat > "$PV_TMP/bashrc" <<RC
PS1='\$ '
cd "$PV_REPO"
export RUSTUP_TOOLCHAIN=1.99.1 CARGO_TARGET_DIR="$PV_TARGET"
RC
exec env PS1='$ ' bash --rcfile "$PV_TMP/bashrc" -i
