# Chrome CDP Browser Session Workflow

Automate interactions with authenticated or watchable local-review web dashboards using the user's real Chrome browser via Chrome DevTools Protocol. Per `profiles/general/standards/global/browser-review-policy.md`, CDP is the default visible local review target when a human-watchable browser is appropriate and the hard-auth escape hatch when storage state is insufficient; Playwright CLI remains the default automation driver.

## When to Use

- Target site requires login the user has already completed in Chrome
- CAPTCHA-protected pages that block headless browsers
- Dashboard configuration not accessible via API (BetterStack, PostHog, Vercel, etc.)
- Sites that need browser extensions to function
- Any task where headless Chromium fails but a real browser succeeds


Do not use CDP in CI/PR workflows. Do not use it for API-accessible operations. For non-watchable public-page checks where a managed browser is sufficient, follow the browser-review policy fallback target order instead of forcing CDP.
## Prerequisites

- Google Chrome installed (`/usr/bin/google-chrome`)
- `chrome-cdp-*` functions sourced from `${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/chrome-cdp.sh` (via `~/.zshrc` / `~/.bashrc`)
- `agent-browser` CLI installed
- Authenticated sessions at `~/.chrome-cdp-profile/Default/` (cookies preserved between sessions)

## Constraints

- **Chromium-only** — does NOT work with Firefox/Gecko browsers (Zen Browser, Firefox)
- **Port 9222** — default CDP port; use `--port <N>` if occupied
- **No concurrent Chrome on same profile** — close personal Chrome before launching with CDP on `~/.chrome-cdp-profile`, or use a separate profile for personal browsing

## Steps

### Step 1: Check / start CDP session

```bash
# Check if already running and get current state
chrome-cdp-status

# Optional: check auth cookies for target domain before navigating
chrome-cdp-check-cookies app.example.com

# Start Chrome with CDP — loads authenticated session from ~/.chrome-cdp-profile/Default
chrome-cdp-start

# Verify window is visible in Hyprland
hyprctl clients 2>/dev/null | grep -i "google-chrome" \
  && echo "Window confirmed" \
  || echo "WARNING: Chrome window not detected. Check /tmp/chrome-cdp-launch.log"
```

> **Resume guidance:** If CDP is already running (e.g., resuming a prior task), run `chrome-cdp-status` first to get current URL + open tabs. Only navigate to a new URL if the task requires it.

> **Profile picker:** If Chrome opens to `chrome://profile-picker/`, re-source the script and restart:
> `source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/chrome-cdp.sh" && chrome-cdp-restart`

### Step 2: Navigate to target URL

```bash
# Open target URL
agent-browser --cdp 9222 open https://example-dashboard.com
agent-browser --cdp 9222 wait --load networkidle
```

> **Auth check:** If the snapshot shows a login form, the session cookie expired. Follow the co-work protocol below — announce a co-work pause, let the user log in manually, then resume.

### Step 3: Snapshot and interact

```bash
# Check current URL without full snapshot (fast orientation check)
chrome-cdp-url

# List open tabs
chrome-cdp-tabs

# Full snapshot — only when page changed or element refs are stale
agent-browser --cdp 9222 snapshot -i

# Interact using refs or semantic locators
agent-browser --cdp 9222 click @e5
agent-browser --cdp 9222 fill @e10 "value"
agent-browser --cdp 9222 find role button click --name "Save"
agent-browser --cdp 9222 wait --text "Success"

# Screenshot for verification
agent-browser --cdp 9222 screenshot
```

**Snapshot guidance:** Only snapshot after navigation or when element refs become stale. Within the same page, reuse refs from the last snapshot — re-snapshotting every turn wastes 3–5 seconds and re-parses unchanged DOM.

### Step 4: Co-work handoff (when manual action is needed)

When a task requires manual action in the Chrome window (login, CAPTCHA, 2FA, OAuth, manual navigation):

```
AI announces: "Taking a co-work pause. I need you to [specific action] in the Chrome window.
               Tell me when you're done and I'll take a snapshot and continue."
```

1. **AI stops all `agent-browser` commands** — no `open`, `click`, `fill` until resume
2. **User performs the action** in the Chrome window (full control, no race condition)
3. **User signals ready** — type "done" or "ready" in the chat
4. **AI resumes** — runs `chrome-cdp-url` to confirm state, then `agent-browser --cdp 9222 snapshot -i`, then continues

> **User taking over:** Tell Claude "I'm taking over the browser" — the AI stops all `agent-browser` commands until you say "done."

### Step 5: Save context (for cross-session continuity)

If the task will continue in a new Claude Code conversation:

```bash
# Save current state with a label and optional task description
chrome-cdp-save-context work-invoice-dashboard "Auditing BetterStack monitors — completed step 3"

# In the next conversation, load it:
chrome-cdp-load-context work-invoice-dashboard
```

Context files are saved to `~/.chrome-cdp-contexts/<label>.json` and persist across reboots.

### Step 6: Clean up

```bash
# Stop saves session state to /tmp/cdp-session-state.json before killing Chrome
chrome-cdp-stop
```

## Helper Functions

| Function | What it does |
|----------|-------------|
| `chrome-cdp-start` | Launch Chrome CDP (adaptive 10s startup wait, log rotation) |
| `chrome-cdp-stop` | Kill Chrome, save tab state to `/tmp/cdp-session-state.json` |
| `chrome-cdp-restart` | Stop (with state save) + start in one call |
| `chrome-cdp-status` | Full status: browser + active URL + tab count + window visibility |
| `chrome-cdp-url` | Print active tab URL (fast, no DOM snapshot needed) |
| `chrome-cdp-tabs` | List all open page tabs with titles |
| `chrome-cdp-check-cookies <domain>` | Check if cookies for a domain are present and unexpired |
| `chrome-cdp-save-context <label>` | Save current tabs + URL to `~/.chrome-cdp-contexts/<label>.json` |
| `chrome-cdp-load-context <label>` | Print saved context for a label |
| `chrome-cdp-list-contexts` | List all saved contexts |

## Key Gotchas

| Gotcha | Root Cause | Fix |
|--------|-----------|-----|
| Chrome opens to profile picker | `--profile-directory=Default` missing | Re-source `chrome-cdp.sh` and `chrome-cdp-restart` |
| Login page shown instead of dashboard | Session cookie expired | Co-work pause: log in manually, tell Claude "done" |
| CDP port not binding | Stale Chrome process holding port | `killall google-chrome; sleep 2; chrome-cdp-start` |
| Zen Browser returns 404 on `/json/version` | Zen is Firefox-based, no CDP | Use `google-chrome`, not Zen |
| Chrome starts but no window appears | Missing `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` | Ensure `chrome-cdp.sh` is sourced in `~/.bashrc` |
| Personal Chrome and CDP Chrome conflict | Both using `~/.chrome-cdp-profile` — SingletonLock contention | Close personal Chrome before `chrome-cdp-start` |
| OAuth popup goes black | OAuth opens popup windows that hijack CDP tab | Complete OAuth manually in Chrome window |

## When NOT to Use

- Public pages with no auth — use `agent-browser open <url>` directly
- API-accessible operations — call the API directly (faster, more reliable)
- CI/CD environments — headless Chromium is better for automation pipelines
- Firefox-only sites — CDP doesn't work

## Related

- `scripts/lib/chrome-cdp.sh` — all CDP helper functions (`${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/chrome-cdp.sh`)
- `~/.claude/skills/agent-browser/SKILL.md` — Chrome CDP Bridge framework
- CDP profile: `~/.chrome-cdp-profile/Default/` (persistent, contains your saved login sessions)
- Session state: `/tmp/cdp-session-state.json` (ephemeral, cleared on reboot)
- Context files: `~/.chrome-cdp-contexts/` (persistent, cross-session task context)

## Display

Session lifecycle output:

```
[CDP] Chrome launched — port 9222
[CDP] Session attached — tab: [url]
[CDP] Action: [action description]
[CDP] Session closed
```
