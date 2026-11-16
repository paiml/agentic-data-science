# term-<id> demos

Each `<id>.cmds` is a terminal session: the exact lines typed, in order. The ids are
opaque. `scripts/emit-term-demos.sh` runs each file in one bash under a 93x25 pty from
the repo root, with the variables in `env`, and adds a `term-<id>` row to demo.json
(`stdout` = `$ <cmd>` + output per line, ANSI and CR stripped).

Deterministic output, fixed at the source:
1. `make gate-lean` prints an elapsed-seconds line every 2 s; `GATE_LEAN_HEARTBEAT_S=0` (set in `env`) turns those lines off.
2. Tool paths: CI provides `/opt/elan` and `/opt/tools/bin` (bat 0.24.0, sha256-pinned;
   `gmake`), so `PATH` is the same string wherever the sessions run.
3. `lake` progress lines are timing-dependent; they are removed by the normalized comparison, not by a flag.
   `emit-term-demos.sh` warms the toolchain first (outside any recorded stdout), so a cold elan home prints no download lines.
4. `HOME`, `TZ`, `LC_ALL`, `TERM`, `BAT_STYLE` and `PS1` are fixed in `env`; the pty is 93x25.
