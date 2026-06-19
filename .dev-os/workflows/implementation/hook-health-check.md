# Hook Health Check Workflow

Checks the health of all registered DevOS hooks. Used by `project-status` (compact/degraded mode)
and `runtime-diagnostics` (full mode).

## When to Use

Use this workflow as an inline health check inside other commands (e.g., `project-status`) to report on registered hook status without blocking the parent command.

Do not invoke this workflow directly from the user prompt — it is a shared workflow designed to be included in other commands via `{{workflows/}}` reference.


## Process

1. Locate hook files in `.claude/hooks/` and check each exists and is executable.
2. Check circuit breaker state for each hook (open/closed/half-open).
3. Read learnings backlog count from `product/runtime/learnings-log.jsonl`.
4. Check error rate limiter state from `product/runtime/hook-error-state.json`.
5. Render hook health table (OK / MISSING / NOT-EXEC / ERROR per hook).
## Registered Hooks

The canonical list of all registered hooks. **Edit here only** — changes propagate automatically to both `project-status` and `runtime-diagnostics`.

**2026-04-29 (G-CXH-D-02 closure):** This list is now derived from the canonical registry at `scripts/sync/hook-registry.yml`. Add new hooks there — both Claude `settings.json` and Codex `~/.codex/hooks.json` consume it. To list current registry: `grep '^  - name:' scripts/sync/hook-registry.yml`. To probe live state across both CLIs: `bash scripts/sync/hook-probe.sh` (or `--diff` for parity report).

The table below mirrors a subset of the registry — kept here for at-a-glance reference; canonical truth lives in the YAML.

| Hook | Event | Path | applies_to |
|---|---|---|---|
| `user-prompt-submit.sh` | UserPromptSubmit | `${HOME}/.claude/hooks/user-prompt-submit.sh` | claude |
| `memory-context.sh` | UserPromptSubmit | `${DEVOS_DIR}/scripts/hooks/memory-context.sh` | claude, codex |
| `reflect-capture.sh` | UserPromptSubmit | `${HOME}/.claude/hooks/reflect-capture.sh` | claude, codex |
| `learnings-processor.sh` | UserPromptSubmit | `${DEVOS_DIR}/scripts/hooks/learnings-processor.sh` | claude, codex |
| `bundle-injection.sh` | UserPromptSubmit | `${DEVOS_DIR}/scripts/hooks/bundle-injection.sh` | claude, codex |
| `systematic-debugging-skill-marker.sh` | UserPromptSubmit | `${DEVOS_DIR}/scripts/hooks/systematic-debugging-skill-marker.sh` | claude, codex |
| `trace-skill-activation-hook.sh` | UserPromptSubmit | `${DEVOS_DIR}/scripts/hooks/trace-skill-activation-hook.sh` | claude, codex |
| `session-recorder-hook.sh` | Stop | `${DEVOS_DIR}/scripts/hooks/session-recorder-hook.sh` | claude, codex |
| `session-snapshot-hook.sh` | PreToolUse | `${DEVOS_DIR}/scripts/hooks/session-snapshot-hook.sh` | claude, codex |
| `session-start-context-hook.sh` | SessionStart | `${DEVOS_DIR}/scripts/hooks/session-start-context-hook.sh` | claude, codex |
| `post-tool-pruning-hook.sh` | PostToolUse | `${DEVOS_DIR}/scripts/hooks/post-tool-pruning-hook.sh` | claude, codex |
| `precompact-guide.sh` | PreCompact | `${DEVOS_DIR}/scripts/hooks/precompact-guide.sh` | claude |

## Health Check

Run this bash block in the Bash tool.

**Output modes:**
- Default (`HOOK_HEALTH_FULL` unset or `0`): shows `✅ Hooks: all healthy` when OK, or a degraded-only panel listing only failures. Used by `project-status`.
- Full (`HOOK_HEALTH_FULL=1`): always shows all 10 hooks with status, circuit breaker states, and backlog count. Used by `runtime-diagnostics` and `project-status --hooks`.

```bash
#!/usr/bin/env bash
# Hook health check — shared by project-status and runtime-diagnostics
# Set HOOK_HEALTH_FULL=1 for always-full output (runtime-diagnostics / --hooks mode)
# Default (HOOK_HEALTH_FULL=0 or unset): degraded-only output

_DEVOS_DIR="${DEVOS_DIR:-$HOME/.dev-os}"
_STATE_DIR="${HOME}/.claude/state"
_HOOKS_DIR="${HOME}/.claude/hooks"
_DEVOS_HOOKS_DIR="${_DEVOS_DIR}/scripts/hooks"
_LEARNINGS_LOG="${_DEVOS_DIR}/product/runtime/learnings-log.jsonl"
_FULL="${HOOK_HEALTH_FULL:-0}"

# Ordered hook name list (display order)
_HOOK_NAMES=(
    "user-prompt-submit.sh"
    "memory-context.sh"
    "reflect-capture.sh"
    "learnings-processor.sh"
    "bundle-injection.sh"
    "session-recorder-hook.sh"
    "session-snapshot-hook.sh"
    "session-start-context-hook.sh"
    "post-tool-pruning-hook.sh"
    "precompact-guide.sh"
)

# Hook paths (parallel array — same index as _HOOK_NAMES)
_HOOK_PATHS=(
    "${_HOOKS_DIR}/user-prompt-submit.sh"
    "${_HOOKS_DIR}/memory-context.sh"
    "${_HOOKS_DIR}/reflect-capture.sh"
    "${_DEVOS_HOOKS_DIR}/learnings-processor.sh"
    "${_DEVOS_HOOKS_DIR}/bundle-injection.sh"
    "${_DEVOS_HOOKS_DIR}/session-recorder-hook.sh"
    "${_DEVOS_HOOKS_DIR}/session-snapshot-hook.sh"
    "${_DEVOS_HOOKS_DIR}/session-start-context-hook.sh"
    "${_DEVOS_HOOKS_DIR}/post-tool-pruning-hook.sh"
    "${_DEVOS_HOOKS_DIR}/precompact-guide.sh"
)

# --- Step 1: Hook file checks (parallel) ---
_tmpdir=$(mktemp -d)

for i in "${!_HOOK_NAMES[@]}"; do
    _name="${_HOOK_NAMES[$i]}"
    _path="${_HOOK_PATHS[$i]}"
    (
        if [[ ! -f "$_path" ]]; then
            echo "MISSING"
        elif [[ ! -x "$_path" ]]; then
            echo "NOT-EXEC"
        else
            echo "OK"
        fi
    ) > "${_tmpdir}/${_name}.status" &
done
wait

# Collect results into indexed array
declare -a _HOOK_RESULTS
for i in "${!_HOOK_NAMES[@]}"; do
    _name="${_HOOK_NAMES[$i]}"
    _HOOK_RESULTS[$i]=$(cat "${_tmpdir}/${_name}.status" 2>/dev/null || echo "UNKNOWN")
done
command rm -rf "$_tmpdir"

# --- Step 2: Circuit breaker states ---
_cb_issues=()
for _cb_file in \
    "${_STATE_DIR}/memory-context-breaker.json" \
    "${_STATE_DIR}/learnings-processor-breaker.json"; do
    if [[ ! -f "$_cb_file" ]]; then
        continue
    fi
    _cb_name=$(basename "$_cb_file" .json)
    _cb_parsed=$(python3 -c "
import json, sys
try:
    with open('${_cb_file}') as f:
        d = json.load(f)
    state = d.get('state', '')
    failures = d.get('failures', 0)
    since = (d.get('open_since') or d.get('last_failure') or '')[:16]
    print(f'{state}|{failures}|{since}')
except Exception as e:
    print(f'unknown|0|')
" 2>/dev/null || echo "unknown|0|")
    _cb_state="${_cb_parsed%%|*}"
    _cb_rest="${_cb_parsed#*|}"
    _cb_failures="${_cb_rest%%|*}"
    _cb_since="${_cb_rest#*|}"
    if [[ "$_cb_state" == "open" ]]; then
        _cb_issues+=("${_cb_name} — OPEN (${_cb_failures} failures since ${_cb_since})")
    fi
done

# --- Step 3: Learnings backlog ---
_backlog_msg=""
if [[ -f "$_LEARNINGS_LOG" ]]; then
    _pending=$(python3 -c "
import json, sys
count = 0
try:
    with open('${_LEARNINGS_LOG}') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if not d.get('processed', False):
                    count += 1
            except Exception:
                pass
except Exception:
    pass
print(count)
" 2>/dev/null || echo "0")
    if [[ "$_pending" -ge 2000 ]]; then
        _backlog_msg="✗ Learnings backlog: ${_pending} entries pending (critically large)"
    elif [[ "$_pending" -ge 500 ]]; then
        _backlog_msg="⚠ Learnings backlog: ${_pending} entries pending"
    fi
fi

# --- Step 4: Error rate limiter ---
_rate_limit_msg=""
if [[ -f "${_STATE_DIR}/error-rate-limiter.json" ]]; then
    _rate_limit_msg="⚠ Error rate limiter active — hook errors being suppressed"
fi

# --- Step 5: Process accounting ---
_accounting_issues=()
if [[ -f "$_LEARNINGS_LOG" ]]; then
    _acct_output=$(python3 -c "
import json, sys
issues = []
try:
    with open('${_LEARNINGS_LOG}') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if d.get('category') != 'process-accounting':
                    continue
                details = d.get('details', {})
                if not isinstance(details, dict):
                    continue
                spec = details.get('spec', '')
                missing = details.get('missing', [])
                incomplete = details.get('incomplete_tasks', False)
                if missing or incomplete:
                    parts = []
                    if missing:
                        parts.append('missing: ' + ', '.join(missing))
                    if incomplete:
                        parts.append('tasks incomplete')
                    issues.append(f'{spec} — {'; '.join(parts)}')
            except Exception:
                pass
except Exception:
    pass
for i in issues:
    print(i)
" 2>/dev/null)
    while IFS= read -r line; do
        [[ -n "$line" ]] && _accounting_issues+=("$line")
    done <<< "$_acct_output"
fi

# --- Step 6: Project discipline hooks (Scope 3) ---
_project_hook_issues=()
_PROJECT_HOOKS_DIR=".claude/hooks"
_PROJECT_SETTINGS=".claude/settings.json"
_PROJECT_DISCIPLINE_HOOKS=(
    "systematic-debugging-gate.sh"
    "verification-gate.sh"
)

# Only check if we're in a DevOS project (has .dev-os/config.yml)
if [[ -f ".dev-os/config.yml" ]]; then
    for _ph in "${_PROJECT_DISCIPLINE_HOOKS[@]}"; do
        _ph_path="${_PROJECT_HOOKS_DIR}/${_ph}"
        if [[ ! -f "$_ph_path" ]]; then
            _project_hook_issues+=("✗ project:${_ph} — MISSING (run start or repair-hooks --claude-hooks)")
        elif [[ ! -x "$_ph_path" ]]; then
            _project_hook_issues+=("✗ project:${_ph} — NOT-EXEC (chmod +x ${_ph_path})")
        fi
    done

    # Check project settings.json has hook registrations
    if [[ -f "$_PROJECT_SETTINGS" ]]; then
        _proj_hooks_registered=$(python3 -c "
import json, sys
try:
    with open('${_PROJECT_SETTINGS}') as f:
        s = json.load(f)
    hooks = s.get('hooks', {})
    has_pre = 'PreToolUse' in hooks
    has_stop = 'Stop' in hooks
    if not has_pre:
        print('PreToolUse')
    if not has_stop:
        print('Stop')
except Exception:
    print('PreToolUse')
    print('Stop')
" 2>/dev/null || echo "")
        while IFS= read -r _missing_event; do
            [[ -n "$_missing_event" ]] && _project_hook_issues+=("✗ project:settings.json — missing ${_missing_event} registration")
        done <<< "$_proj_hooks_registered"
    else
        _project_hook_issues+=("✗ project:.claude/settings.json — MISSING (run start)")
    fi
fi

# --- Aggregate degradation flag ---
_degraded=false
_hook_failures=()

for i in "${!_HOOK_NAMES[@]}"; do
    _name="${_HOOK_NAMES[$i]}"
    _st="${_HOOK_RESULTS[$i]:-UNKNOWN}"
    if [[ "$_st" != "OK" ]]; then
        _degraded=true
        case "$_st" in
            MISSING)  _hook_failures+=("✗ ${_name} — MISSING (file not found)") ;;
            NOT-EXEC) _hook_failures+=("✗ ${_name} — NOT-EXEC (not executable)") ;;
            *)        _hook_failures+=("✗ ${_name} — ${_st}") ;;
        esac
    fi
done

[[ "${#_cb_issues[@]}" -gt 0 ]] && _degraded=true
[[ -n "$_backlog_msg" ]] && _degraded=true
[[ -n "$_rate_limit_msg" ]] && _degraded=true
[[ "${#_accounting_issues[@]}" -gt 0 ]] && _degraded=true
[[ "${#_project_hook_issues[@]}" -gt 0 ]] && _degraded=true

# --- Output ---
if [[ "$_FULL" == "1" ]]; then
    # Full mode: always show everything (runtime-diagnostics / --hooks)
    echo ""
    echo "⚙️  Hook Health (full)"
    for i in "${!_HOOK_NAMES[@]}"; do
        _name="${_HOOK_NAMES[$i]}"
        _st="${_HOOK_RESULTS[$i]:-UNKNOWN}"
        if [[ "$_st" == "OK" ]]; then
            printf "  ✅ %s\n" "$_name"
        else
            printf "  ✗  %s — %s\n" "$_name" "$_st"
        fi
    done
    echo ""
    if [[ "${#_cb_issues[@]}" -gt 0 ]]; then
        for _cb in "${_cb_issues[@]}"; do
            printf "  ⚠ %s\n" "$_cb"
        done
    else
        echo "  Circuit breakers: all closed"
    fi
    if [[ -n "$_backlog_msg" ]]; then
        printf "  %s\n" "$_backlog_msg"
    else
        echo "  Learnings backlog: healthy"
    fi
    if [[ -n "$_rate_limit_msg" ]]; then
        printf "  %s\n" "$_rate_limit_msg"
    else
        echo "  Error rate limiter: inactive"
    fi
    if [[ "${#_accounting_issues[@]}" -gt 0 ]]; then
        echo ""
        echo "  Process accounting issues:"
        for _acct in "${_accounting_issues[@]}"; do
            printf "  ⚠ spec: %s\n" "$_acct"
        done
        echo "  → Retroactively create spec.md/tasks.md or run autonomous --force-skip-spec-gate"
    else
        echo "  Process accounting: clean"
    fi
    echo ""
    if [[ "${#_project_hook_issues[@]}" -gt 0 ]]; then
        echo "  Project discipline hooks:"
        for _phi in "${_project_hook_issues[@]}"; do
            printf "  %s\n" "$_phi"
        done
    else
        echo "  Project discipline hooks: healthy"
    fi

elif [[ "$_degraded" == "true" ]]; then
    # Degraded mode: show only failing items
    echo ""
    echo "⚙️  Hook Health"
    for _f in "${_hook_failures[@]}"; do
        printf "  %s\n" "$_f"
    done
    for _cb in "${_cb_issues[@]}"; do
        printf "  ⚠ %s\n" "$_cb"
    done
    [[ -n "$_backlog_msg" ]] && printf "  %s\n" "$_backlog_msg"
    [[ -n "$_rate_limit_msg" ]] && printf "  %s\n" "$_rate_limit_msg"
    if [[ "${#_accounting_issues[@]}" -gt 0 ]]; then
        echo "  Process accounting issues:"
        for _acct in "${_accounting_issues[@]}"; do
            printf "  ⚠ spec: %s\n" "$_acct"
        done
        echo "  → Retroactively create spec.md/tasks.md or run autonomous --force-skip-spec-gate"
    fi
    for _phi in "${_project_hook_issues[@]}"; do
        printf "  %s\n" "$_phi"
    done
    echo "→ Run runtime-diagnostics for full details"

else
    # All healthy
    echo "✅ Hooks: all healthy"
fi
```

## Display Format

```
Hook Health
  systematic-debugging-gate  [OK | MISSING | NOT-EXEC | ERROR]
  verification-gate          [OK | MISSING | NOT-EXEC | ERROR]
  post-start-verification    [OK | MISSING | NOT-EXEC | ERROR]
  Circuit breakers:          [all closed | [N] open]
  Learnings backlog:         [N] entries
```
