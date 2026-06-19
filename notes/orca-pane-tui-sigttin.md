# Orca Pane TUI SIGTTIN — pi (and other TUIs) suspend on stdin read

> **STATUS: SUPERSEDED 2026-06-18** — the SIGTTIN/Orca-PTY root cause in this note
> was a misdiagnosis. The actual cause of the "pi backgrounds" symptom was
> stale code in dev-os (the install path wasn't installing the
> `pi-yaml-hooks` package or generating `~/.pi/agent/hook/hooks.yaml`, so
> hooks weren't firing reliably). Fixed in
> [`08d6cdc49` fix(pi): install active yaml hook bridge](https://github.com/Traderfuz/dev-os/commit/08d6cdc49).
> Pi is now working.
>
> The Orca PTY/process-group suspicion is plausible (and Orca
> 1.4.72-rc.3 may still have PTY bugs), but **it was not the cause of the
> observed symptom in this session**. The 10-second diagnostic and
> "do not patch pty.spawn" guidance are kept here as reference if a
> future Orca-version issue actually triggers SIGTTIN — they're not
> wrong, just not the right call for this bug. The "fix location" section
> is the most useful to retain for that future case.
>
> **Do not use this note to explain the 2026-06-18 pi-backgrounds bug.**
> Use the commit history on `fix(pi): install active yaml hook bridge`.

## Problem

A TUI CLI agent launched inside an Orca-managed terminal pane — observed with
`pi` (`@earendil-works/pi-coding-agent`) under `openai-codex/gpt-5.5` — renders
its welcome screen, then the host zsh reports:

```
[1]  + <pid> suspended (tty input)  pi
```

The TUI is put into a background process group and suspended on its first
stdin read. Powerlevel10k surfaces this as `TTIN ✘` in the prompt. A mangled
OSC hyperlink fragment (`/7;1:3u`) leaks into the shell input line afterwards —
that is pi mid-write of an OSC 8 sequence at the moment it was suspended, not a
separate cause.

Version observed: `1.4.72-rc.3` (release candidate).

## Root cause

Orca owns the controlling terminal for every pane. The PTY spawn path places
the spawned child (shell + the TUI it execs) such that the TUI ends up in a
**non-foreground process group** of the pane's controlling tty. When the TUI
calls `read()` on stdin to render its interactive UI, the kernel delivers
**SIGTTIN** and the job-control shell suspends it.

This is a process-group / controlling-tty ownership issue at Orca's spawn layer
(`src/main/daemon/pty-subprocess.ts`, the node-pty spawn site). It is **not** in
the TUI agent, its shell config, or any DevOS hook/extension.

## Evidence (ground truth)

- The failing session runs **under Orca**: env carries `ORCA_PANE_KEY`,
  `ORCA_TAB_ID`, `ORCA_WORKTREE_ID`, `ORCA_TERMINAL_HANDLE`, `ORCA_AGENT_HOOK_PORT`,
  `ORCA_ORIG_ZDOTDIR`; `orca-ide` is the live process.
- **Orca's own logs record 452 `sigttin` events** in
  `~/.config/orca/logs/*.ndjson*` — the terminal layer is generating SIGTTIN
  repeatedly, not once.
- **Not reproducible in a bare PTY** (no Orca): `pi` reads stdin fine in the
  foreground and never suspends. Reproduced via a `pty.fork()` + job-controlled
  `bash -m` harness.
- All DevOS code audited clean:
  - `devos-lifecycle.ts` spawns the 7 session-start hooks with
    `stdio: ["pipe","pipe","pipe"]` (stdin is a pipe → `[ -t 0 ]` false →
    health-gate `_health_interactive_ok` returns false → non-interactive path,
    no `read </dev/tty`).
  - `hooks.yaml` is inert — `pi-yaml-hooks` is not installed
    (`settings.json` `"packages": []`), so the `session.created` actions never
    run.
  - All 11 loaded extensions (`devos-*`, `orca-*`, `tui-tokens`) audited: no
    tty reads; `execFileSync("git", …)` uses `stdio:["ignore","pipe","ignore"]`;
    `orca-titlebar-spinner` only animates `agent_start`→`agent_end` (not at idle
    startup) and writes via `ctx.ui.setTitle`, not raw OSC.

## Two prior root-cause fixes that did NOT address this

Both are real and correctly fixed different bugs, but neither is this one:

1. `dev-os` `f86b875cb` — "pi backgrounds" was extension **load** failure
   (`./tui-tokens` relative import unco-located across the overlay symlink
   chain). Fixed by co-locating + no-op default export. Welcome now renders →
   load is healthy here.
2. `dev-os` `24eb36f32` — `session-start-health-gate.sh` tty reads stole
   keystrokes under codex/pi. Fixed by gating interactive reads on a confirmed
   Claude Code session. Verified in place; not the trigger here.

Rule for next time: when pi misbehaves at startup in an Orca pane, check Orca's
own `sigttin` log count first. 452 events = systemic spawn-layer issue, not a
one-off TUI bug.

## Fix location (for the own-build patch) — UPDATED 2026-06-18, NOT yet confirmed

**Initial hypothesis (spawn-time foreground pgrp) is NOT supported by the code.**

Reading `src/main/daemon/pty-subprocess.ts:514` shows a plain
`pty.spawn(shellPath, shellArgs, { cwd, env })` — standard node-pty, which does
`setsid()` + `TIOCSCTTY`, so the child shell is already the foreground process
group of the controlling tty. The `src/main/daemon/shell-ready.ts` attribution
wrapper only restores PATH/env (no `setpgid`/`setsid`/`exec`/backgrounding).

Behavioral evidence agrees the spawn is correct: **pi renders its welcome**
(it reads stdin successfully), then suspends **~53 s later** on a later read.
That means the foreground process group is **displaced under pi after spawn**,
not wrong at spawn. A speculative `tcsetpgrp`-at-spawn patch would be the wrong
layer and would waste a ~2 GB build.

**Do not patch `pty.spawn`.** The real displacing op is unidentified. Confirm
with this runtime diagnostic at the next suspend (different Orca pane):
```bash
PIPID=$(pgrep -xn pi); ps -o pid,pgid,tpgid,stat,tty,comm -p "$PIPID"
```
- `tpgid` ≠ `pgid` → pi backgrounded post-spawn → find the Orca op that
  displaces the foreground pgrp ~53 s in (periodic foreground-process refresh in
  `pty-subprocess.ts:542-584` `scheduleAgentForegroundRefresh`, a spawned child,
  or a re-attach), and patch THAT.
- `tpgid` == `pgid` → SIGTTIN from a different fd/child/master-side race →
  different hunt.

Once the displacing op is named by this evidence, the fix is targeted to it —
not assumed. Re-confirm post-fix: `rg -c sigttin ~/.config/orca/logs/*.ndjson*`
should drop from 452 to ~0.

## Verification plan

- Unit/integration test in `pty-subprocess.test.ts`: spawn a TUI-shaped child
  (one that reads stdin immediately) and assert it is in the foreground pgrp of
  the PTY and does not receive SIGTTIN.
- Manual: in a built Orca, open a pane and run `pi` (or any stdin-reading TUI,
  e.g. `htop`, `btop`, `less`). Confirm no `suspended (tty input)` and no
  `TTIN ✘` in the prompt.
- Telemetry gate: after rollout, `rg -c sigttin ~/.config/orca/logs/*.ndjson*`
  should be near-zero where it was 452.

## Non-Goals

- Do not "fix" this in the DevOS hooks or pi extensions — they are clean.
- Do not change the trust model or disable extensions to work around it.
- Do not treat the OSC leak as a separate bug; it is a symptom of the suspend.

## Research findings (2026-06-18) — canonical mechanism + fix decision

Web research on `node-pty` + Electron + xterm.js TUI SIGTTIN confirms the
mechanism and narrows the fix.

**Canonical mechanism** (node-pty#167, #382; SO tcsetpgrp; glibc job-control
signals): pi SIGTTIN-stops because it is in a process group that is **not the
foreground group of the pty's controlling tty** when it reads stdin. The shell
reads fine because the shell *is* foreground; the handoff of the foreground pgrp
to the child job is what fails. This is shell-agnostic (bash + zsh both stop pi),
which rules out shell job-control config and points at the pty/foreground-pgrp
layer — i.e. Orca.

**Two documented ways the handoff fails in node-pty/Electron terminals:**
1. Job control OFF in the spawned shell (`set +m`) — shell never creates /
   foregrounds a new pgrp for the job.
2. `tcsetpgrp(tty, child_pgrp)` fails with EPERM — something holds or displaces
   the tty's foreground pgrp, so the child is left background → SIGTTIN on read.

`src/relay/pty-handler.ts:100-110` `ALLOWED_SIGNALS` was checked and ruled out —
it is the client→pty signal allowlist; the kernel generates the SIGTTIN on the
read, Orca does not send it.

**10-second test that picks the fix (run in the Orca pane):**
```bash
echo "opts=$-"     # bash: is 'm' present?  (zsh: echo $options[monitor])
htop               # does a DIFFERENT TUI also stop?
```

| Result | Root cause | Fix |
|---|---|---|
| `m` missing AND htop stops | job control OFF in Orca shell spawn | `pty-subprocess.ts`: force interactive + `set -m` in shell-ready wrapper |
| `m` present AND htop stops | foreground-pgrp handoff failing (EPERM) | `pty-subprocess.ts`: re-assert foreground pgrp of the pty after spawn |
| htop runs fine, only pi stops | pi-specific (not Orca) | report upstream to `@earendil-works/pi-coding-agent`; no Orca build |

Both Orca fixes edit `src/main/daemon/pty-subprocess.ts` but are different
changes, each requiring a ~2 GB rebuild — run the test before building. Build +
deploy procedure is pinned at `docs/runbooks/orca-patched-build-deploy.md`.

## Sources

- Live debugging session 2026-06-18 (research-kb, pi under Orca).
- Orca logs: `~/.config/orca/logs/*.ndjson*` (452 `sigttin`).
- DevOS audit: `~/.dev-os/integrations/pi/extensions/*`, `devos-lifecycle.ts`,
  `session-start-health-gate.sh`, `~/.pi/agent/hook/hooks.yaml`,
  `~/.pi/agent/settings.json`.
