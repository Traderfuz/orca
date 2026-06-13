# Linux AppImage Single-Instance Focus Loop

## Symptom

On Linux, Orca can repeatedly pull focus back to its existing window after desktop/menu launches or terminal activations. The terminal may print:

```text
[single-instance] Another Orca instance is already running
```

That message is expected when a live Electron profile owner already exists. It is not, by itself, evidence of a stale lock.

## Confirmed Cause

On 2026-06-06, the affected machine had a live Electron/Chromium singleton lock owner plus hundreds of leaked activation helpers:

```text
orca-linux.AppImage activate zsh
```

and hundreds of active AppImage mount scopes. Repeated activation requests were redirected to the existing Electron instance and could keep refocusing the running Orca window.

The local desktop entry was launching a CLI shim:

```text
Exec=/home/tafadzwa/projects/tools/scripts/orca %U
```

That shim entered Orca's CLI activation path before reaching the GUI. When the GUI was already running, repeated launches accumulated activation helpers instead of cleanly starting only the existing application window.

## Fix Applied

Back up the desktop entry, then point desktop/menu launches directly at the packaged AppImage:

```bash
cp ~/.local/share/applications/orca-ide.desktop ~/.local/share/applications/orca-ide.desktop.bak-$(date +%Y%m%d-%H%M%S)
```

```ini
Exec=/home/tafadzwa/projects/tools/orca/.local/orca-linux.AppImage %U
```

The concrete backup created during the incident was:

```text
~/.local/share/applications/orca-ide.desktop.bak-20260606-074304
```

## Cleanup Procedure

First close Orca gracefully. Do not remove singleton files while any Orca GUI process is still alive.

After Orca is closed, remove orphaned activation/update workers:

```bash
pkill -f 'orca-linux.AppImage activate zsh'
pkill -f 'orca-linux.AppImage update'
```

Only if no Orca process remains, remove stale Electron singleton files:

```bash
rm -f ~/.config/orca/SingletonLock ~/.config/orca/SingletonSocket ~/.config/orca/SingletonCookie
```

## Verification

The direct AppImage desktop entry should be present:

```bash
sed -n '1,80p' ~/.local/share/applications/orca-ide.desktop
```

There should be no activation/update helper leak:

```bash
ps -eo pid,ppid,stat,comm,args | rg 'orca-linux\.AppImage (activate zsh|update)' | rg -v 'rg|ps -eo'
```

If Orca is running normally, seeing one main `orca-linux.AppImage` process is fine. Hundreds of `activate zsh` helpers or many active `/tmp/.mount_orca-*` scopes indicate the focus-loop failure mode has returned.

## Related Note

The original investigation note was captured in DevOS:

```text
product/research/orca-ide-single-instance-focus-loop-2026-06-06.md
```
