#!/usr/bin/env bash
# DevOS Pre-Commit Hook
# Runs pre-commit validation gates before allowing a commit to proceed.
# Delegates to the validation scripts in scripts/hooks/.
#
# Exit 0 = allow commit
# Exit non-0 = block commit (output shown to user)

# On macOS, git invokes hooks via /usr/bin/env bash which resolves to /bin/bash
# (3.2). Re-exec under a Homebrew bash 4+ if available so sub-hooks that source
# scripts/lib/logger.sh (Bash 4+ required) don't bail out.
if [[ "${BASH_VERSINFO[0]}" -lt 4 && -z "${DEVOS_BASH_REEXEC:-}" ]]; then
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$candidate" ]]; then
            candidate_major="$("$candidate" -lc 'printf "%s" "${BASH_VERSINFO[0]}"' 2>/dev/null || printf "0")"
            if [[ "$candidate_major" =~ ^[0-9]+$ ]] && [[ "$candidate_major" -ge 4 ]]; then
                exec env DEVOS_BASH_REEXEC=1 "$candidate" "$0" "$@"
            fi
        fi
    done
fi

set -uo pipefail

DEVOS_DIR="${DEVOS_DIR:-$HOME/.dev-os}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Use $BASH (the interpreter running this script) for sub-hooks so they inherit
# the bash 4+ chosen above, regardless of PATH ordering at hook invocation time.

# Run secret scanner (first gate — blocks credential leaks before any other check)
if [[ -f "${PROJECT_ROOT}/scripts/hooks/pre-commit-secret-scan.sh" ]]; then
  "$BASH" "${PROJECT_ROOT}/scripts/hooks/pre-commit-secret-scan.sh" || exit 1
fi

# Run branch discipline check
if [[ -f "${PROJECT_ROOT}/scripts/hooks/pre-commit-branch-discipline.sh" ]]; then
  "$BASH" "${PROJECT_ROOT}/scripts/hooks/pre-commit-branch-discipline.sh" || exit 1
fi

# Warn on duplicate fix commits within 72h (non-blocking)
if [[ -f "${PROJECT_ROOT}/scripts/hooks/pre-commit-duplicate-fix-guard.sh" ]]; then
  "$BASH" "${PROJECT_ROOT}/scripts/hooks/pre-commit-duplicate-fix-guard.sh"
fi

# Run documentation validation (G-DO-18 spec-dir tasks.md gate, README counts)
if [[ -f "${PROJECT_ROOT}/scripts/hooks/pre-commit-doc-validation.sh" ]]; then
  "$BASH" "${PROJECT_ROOT}/scripts/hooks/pre-commit-doc-validation.sh" || exit 1
fi

# Run posture validation
if [[ -f "${PROJECT_ROOT}/scripts/hooks/pre-commit-posture-validation.sh" ]]; then
  "$BASH" "${PROJECT_ROOT}/scripts/hooks/pre-commit-posture-validation.sh" || exit 1
fi

# Run skill/chain registry parity gate (G-CA-04 / G-DO-08 migration replacement).
# Skip with DEVOS_SKIP_PARITY=1 when registry has pre-existing drift not caused by this commit.
if [[ "${DEVOS_SKIP_PARITY:-0}" != "1" ]] && [[ -f "${PROJECT_ROOT}/scripts/lib/registry-surface-parity.sh" ]]; then
  if ! "$BASH" "${PROJECT_ROOT}/scripts/lib/registry-surface-parity.sh" 2>&1; then
    echo "registry-surface-parity: FAILED — fix skill/chain registry drift before committing" >&2
    echo "  Skip with: DEVOS_SKIP_PARITY=1 git commit ..." >&2
    exit 1
  fi
fi

# Optional strict gap-velocity gate (P2-F03 / G-DO-19 enforcement half).
# Opt-in via DEVOS_GAP_STRICT=1 — blocks when today's net_delta > 0 (more gaps opened
# than closed). Off by default so it never surprises contributors; enable in CI or
# for release-gate commits.
if [[ "${DEVOS_GAP_STRICT:-0}" == "1" ]] && [[ -f "${PROJECT_ROOT}/scripts/lib/gap-velocity.sh" ]]; then
  if ! "$BASH" "${PROJECT_ROOT}/scripts/lib/gap-velocity.sh" check 2>&1; then
    echo "gap-velocity: FAILED — today's net_delta > 0 (more gaps opened than closed)" >&2
    echo "  Review with: $BASH ${PROJECT_ROOT}/scripts/lib/gap-velocity.sh summary" >&2
    exit 1
  fi
fi

exit 0
