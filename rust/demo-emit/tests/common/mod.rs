//! Shared test helpers: scratch directories that delete only what they made, fake programs, planted row sets.
#![allow(dead_code)]
use demo_emit::sha256::sha256_hex;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};

static N: AtomicUsize = AtomicUsize::new(0);

pub struct Scratch(pub PathBuf);

impl Scratch {
    pub fn new(tag: &str) -> Scratch {
        let n = N.fetch_add(1, Ordering::SeqCst);
        let p = std::env::temp_dir().join(format!(
            "demo-emit-{tag}-{}-{n}",
            std::process::id()
        ));
        fs::create_dir_all(&p).unwrap();
        Scratch(fs::canonicalize(p).unwrap())
    }
    pub fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

/// Write an executable script `name` into `dir`.
pub fn script(dir: &Path, name: &str, body: &str) {
    fs::create_dir_all(dir).unwrap();
    let p = dir.join(name);
    fs::write(&p, format!("#!/bin/sh\n{body}\n")).unwrap();
    fs::set_permissions(&p, fs::Permissions::from_mode(0o755))
        .unwrap();
}

/// The fake `bat` and `cargo` every planted row runs.
pub fn fake_bin(dir: &Path) {
    script(dir, "bat", "echo \"   1   fake bat $*\"");
    script(
        dir,
        "cargo",
        r#"case "$1" in
  test) case "$2" in
    failed) echo "test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s";;
    ignored) echo "test result: ok. 1 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.01s";;
    zero) echo "test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s";;
    none) echo "no result line here";;
    *) echo "running 1 test"; echo "test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s";;
  esac;;
  ok) echo "fine";;
  fail) echo "boom" 1>&2; exit 3;;
  sig) kill -9 $$;;
  slow) exec sleep 30;;
  paths) echo "     Running tests/p1.rs ($CARGO_TARGET_DIR/llvm-cov-target/debug/deps/p1-0123456789abcdef)"; echo "   Compiling x v0.1.0"; echo "root=$PWD"; echo "done in 12.34s";;
  leakhome) echo "$HOME";;
  leakhex) echo "id 0123456789abcdef0123";;
  leakabs) echo "/home/someone/secret";;
  badutf8) printf '\377\376\n';;
  keys) env | cut -d= -f1 | sort;;
  marker) : > ran-marker; echo marked;;
  *) echo "cargo $*";;
esac"#,
    );
}

/// A fake `make` that accepts only the two gate targets and prints the
/// contents of `make-out` (when present in the working directory).
pub fn fake_make(dir: &Path) {
    script(
        dir,
        "make",
        r#"case "$1" in
  gate-shacl|gate-rust) echo "ran $1 in $PWD"; cat make-out 2>/dev/null; true;;
  *) echo "unexpected target $*" 1>&2; exit 2;;
esac"#,
    );
}

/// A planted repository: `<root>/rust/term-demos/` with row files, `<root>/rust/ads-rust/` as the cwd.
pub struct Planted {
    pub scratch: Scratch,
    pub root: PathBuf,
    pub term: PathBuf,
    pub bin: PathBuf,
    pub out: PathBuf,
    pub rows: Vec<String>,
}

pub const ENV_FILE: &str = "TERM=xterm-256color\nPS1=$ \nBAT_STYLE=numbers\nCARGO_INCREMENTAL=0\n";

impl Planted {
    pub fn new(tag: &str) -> Planted {
        let scratch = Scratch::new(tag);
        let root = scratch.path().join("repo");
        let term = root.join("rust/term-demos");
        let bin = scratch.path().join("bin");
        fs::create_dir_all(&term).unwrap();
        fs::create_dir_all(root.join("rust/ads-rust")).unwrap();
        fake_bin(&bin);
        fake_make(&bin);
        fs::write(term.join("env"), ENV_FILE).unwrap();
        let out = scratch.path().join("out/demo.json");
        fs::create_dir_all(out.parent().unwrap()).unwrap();
        Planted {
            scratch,
            root,
            term,
            bin,
            out,
            rows: vec![],
        }
    }

    /// Plant a row and pin it.
    pub fn row(&mut self, id: &str, cmds: &str) -> &mut Planted {
        self.row_in(id, cmds, "rust/ads-rust\n")
    }

    /// Plant a row with its own `.cwd` content and pin it.
    pub fn row_in(
        &mut self,
        id: &str,
        cmds: &str,
        cwd: &str,
    ) -> &mut Planted {
        fs::write(self.term.join(format!("{id}.cmds")), cmds)
            .unwrap();
        fs::write(self.term.join(format!("{id}.cwd")), cwd)
            .unwrap();
        self.rows.push(id.to_string());
        self.write_rows_list();
        self
    }

    pub fn write_rows_list(&self) {
        let mut s = String::from("# pins\n");
        for id in &self.rows {
            let c = fs::read(self.term.join(format!("{id}.cmds")))
                .unwrap();
            let w = fs::read(self.term.join(format!("{id}.cwd")))
                .unwrap();
            s.push_str(&format!(
                "{id} {} {}\n",
                sha256_hex(&c),
                sha256_hex(&w)
            ));
        }
        fs::write(self.term.join("rows.list"), s).unwrap();
    }
}
