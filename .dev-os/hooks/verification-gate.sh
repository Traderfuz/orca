#!/usr/bin/env bash
# Stop hook: verification-gate
#
# Fires when Claude is about to end its response (Stop event).
# Reads the transcript file to extract the last assistant turn text,
# then emits a verification gate advisory if completion-signal language is detected.
#
# Non-blocking — always exits 0. Stop hook stdout must stay empty unless the
# hook emits valid JSON; human-readable advisories go to stderr.
# Input: JSON on stdin with session_id, transcript_path, cwd, stop_hook_active.
# Transcript format: JSONL where assistant turns have type="assistant",
#   message.content = [{type: "text", text: "..."}]
#
# Part of: wire-systematic-debugging-verification spec (2026-02-27)

set -euo pipefail
trap 'exit 0' ERR

# Require python3
if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

# Parse transcript_path from stdin JSON
input_json="$(cat 2>/dev/null || true)"
if [[ -z "$input_json" ]]; then
    exit 0
fi

# Extract last assistant turn text from transcript
last_assistant_text="$(python3 -c "
import json, sys, os

try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)

transcript_path = data.get('transcript_path', '')
if not transcript_path or not os.path.exists(transcript_path):
    sys.exit(0)

last_text = ''
try:
    with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
        for raw_line in f:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            try:
                entry = json.loads(raw_line)
            except Exception:
                continue
            if entry.get('type') != 'assistant':
                continue
            # Extract text from message.content array
            msg = entry.get('message', {})
            content = msg.get('content', [])
            for item in content:
                if isinstance(item, dict) and item.get('type') == 'text':
                    last_text = item.get('text', '')
except Exception:
    pass

print(last_text)
" <<< "$input_json" 2>/dev/null || true)"

if [[ -z "$last_assistant_text" ]]; then
    exit 0
fi

# Completion-signal keywords (case-insensitive)
# Signals the assistant is claiming work is done or working
COMPLETION_PATTERN='done|fixed|complete|all tests pass|it works|resolved|implemented|should work|looks good|finished|great|perfect|that.s it|there we go'

if echo "$last_assistant_text" | command grep -qiE "$COMPLETION_PATTERN" 2>/dev/null; then
    cat >&2 <<'GATE'

[verify] Claim detected. Gate required.
Before this claim stands:
□ What command proves this claim? (identify it)
□ Run it fresh — not from a previous session
□ Read full output including exit code
□ Cite the output in your response
Uncited claims are not verified claims.

GATE
fi

exit 0
