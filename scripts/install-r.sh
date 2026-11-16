#!/usr/bin/env bash
# Install pinned R 4.6.1 (Posit r-builds, ubuntu-2404, sha256-verified) under $1.
# The tarball is built for /opt/R/4.6.1; paths are rewritten and Rscript is
# replaced by a wrapper because the Rscript binary hard-codes /opt.
set -euo pipefail
dest="${1:?usage: install-r.sh DESTDIR}"
v=4.6.1
h=c44d786de1f4129c357eab8995dbc04c71ec83cfaf502104d720b75c2bf7a4fd
case "$dest" in *..*) echo "install-r: DESTDIR must not contain .." >&2; exit 1 ;; esac
mkdir -p "$dest"
curl -fsSL -o "$dest/R.tgz" "https://cdn.posit.co/r/ubuntu-2404/R-$v-ubuntu-2404.tar.gz"
echo "$h  $dest/R.tgz" | sha256sum -c -
tar -xzf "$dest/R.tgz" -C "$dest"
rm "${dest:?}/R.tgz"
grep -rIl "/opt/R/$v" "$dest/$v" | xargs sed -i "s|/opt/R/$v|$dest/$v|g"
rm "${dest:?}/${v:?}/bin/Rscript" "${dest:?}/${v:?}/lib/R/bin/Rscript"
cat > "$dest/$v/bin/Rscript" <<RS
#!/usr/bin/env bash
# Rscript stand-in: leading options and every -e pair go to R; a file becomes --file= plus --args.
a=(--no-echo --no-restore)
while [ \$# -gt 0 ]; do
  case "\$1" in
    -e) [ \$# -ge 2 ] || { echo "Rscript: -e needs an expression" >&2; exit 2; }; a+=(-e "\$2"); shift 2 ;;
    --args) shift; exec "$dest/$v/bin/R" "\${a[@]}" --args "\$@" ;;
    --*) a+=("\$1"); shift ;;
    *) if [ "\${#a[@]}" -gt 2 ] && [[ " \${a[*]} " == *" -e "* ]]; then exec "$dest/$v/bin/R" "\${a[@]}" --args "\$@"; fi; f="\$1"; shift; exec "$dest/$v/bin/R" "\${a[@]}" --file="\$f" --args "\$@" ;;
  esac
done
exec "$dest/$v/bin/R" "\${a[@]}"
RS
chmod +x "$dest/$v/bin/Rscript"
cp "$dest/$v/bin/Rscript" "$dest/$v/lib/R/bin/Rscript"
echo "$dest/$v/bin"
