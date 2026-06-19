#!/usr/bin/env bash
# DevOS Documentation Fetch Hook
# UserPromptSubmit hook that detects implementation keywords and fetches docs

# =============================================================================
# CRITICAL: Global hooks must ALWAYS exit 0
# =============================================================================
# This trap ensures we never block user prompts, even on unexpected errors
trap 'exit 0' ERR

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get DevOS directory
DEVOS_DIR="${DEVOS_DIR:-$HOME/.dev-os}"

# Logging directory
LOG_DIR="${HOME}/.claude/logs/user-prompt-submit"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

# Source dependencies
if [[ -f "$DEVOS_DIR/scripts/lib/logger.sh" ]]; then
    source "$DEVOS_DIR/scripts/lib/logger.sh"
fi

if [[ -f "$DEVOS_DIR/scripts/lib/fetch-docs.sh" ]]; then
    source "$DEVOS_DIR/scripts/lib/fetch-docs.sh"
fi

# =============================================================================
# CONSTANTS
# =============================================================================

# Implementation keywords that trigger doc fetching
readonly IMPLEMENTATION_KEYWORDS=(
    "implement"
    "create"
    "build"
    "add"
    "write"
    "develop"
    "integrate"
)

# Common tech stack patterns
readonly TECH_PATTERNS=(
    "react|vue|angular|svelte"          # Frontend frameworks
    "next|nuxt|gatsby"                   # Meta-frameworks
    "express|fastify|koa|hapi"           # Node.js backends
    "flask|django|fastapi|tornado"       # Python backends
    "gin|echo|fiber|buffalo"             # Go backends
    "spring|rails|laravel|symfony"       # Other backends
    "typescript|javascript|python|go|rust|java|php"  # Languages
    "prisma|sequelize|mongoose|typeorm"  # ORMs
    "postgres|mysql|sqlite|mongodb|redis" # Databases
    "tailwind|bootstrap|mui|chakra"      # UI libraries
)

# =============================================================================
# FUNCTIONS
# =============================================================================

# Detect if prompt contains implementation keywords
# Arguments:
#   $1 - prompt: The user prompt to check
# Returns:
#   0 if implementation keywords found, 1 otherwise
has_implementation_keywords() {
    local prompt="$1"
    local prompt_lower
    prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    for keyword in "${IMPLEMENTATION_KEYWORDS[@]}"; do
        if [[ "$prompt_lower" =~ $keyword ]]; then
            return 0
        fi
    done

    return 1
}

# Extract library/technology names from prompt
# Arguments:
#   $1 - prompt: The user prompt to extract from
# Output:
#   Space-separated list of detected libraries
extract_libraries_from_prompt() {
    local prompt="$1"
    local prompt_lower
    prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
    local libraries=()

    for pattern in "${TECH_PATTERNS[@]}"; do
        if [[ "$prompt_lower" =~ $pattern ]]; then
            # Match the word that triggered
            local matched="${BASH_REMATCH[0]}"
            # Avoid duplicates
            if [[ ! " ${libraries[*]} " =~ " ${matched} " ]]; then
                libraries+=("$matched")
            fi
        fi
    done

    echo "${libraries[@]:-}"
}

# Detect libraries from project files
# Arguments:
#   $1 - project_dir: Project directory to scan (default: .)
# Output:
#   List of detected libraries, one per line
detect_libraries_from_project() {
    local project_dir="${1:-.}"
    local libraries=()

    # Check for package.json
    if [[ -f "$project_dir/package.json" ]]; then
        # Extract common dependency names
        while IFS= read -r dep; do
            [[ -n "$dep" ]] && libraries+=("$dep")
        done < <(grep -oE '"(@?[a-z0-9-]+/[a-z0-9-]+|[a-z0-9-]+)"[[:space:]]*:' "$project_dir/package.json" 2>/dev/null | \
                 tr -d '":' | \
                 grep -vE '^(dev|peer|optional|resolution)' | \
                 head -20)
    fi

    # Check for requirements.txt
    if [[ -f "$project_dir/requirements.txt" ]]; then
        while IFS= read -r dep; do
            [[ -n "$dep" ]] && libraries+=("$dep")
        done < <(grep -v '^#' "$project_dir/requirements.txt" 2>/dev/null | \
                 grep -v '^[[:space:]]*$' | \
                 cut -d'=' -f1 | \
                 cut -d'[' -f1 | \
                 head -20)
    fi

    # Check for go.mod
    if [[ -f "$project_dir/go.mod" ]]; then
        while IFS= read -r dep; do
            [[ -n "$dep" ]] && libraries+=("$dep")
        done < <(grep -E '^\s+[a-z0-9./-]+\s+v' "$project_dir/go.mod" 2>/dev/null | \
                 awk '{print $1}' | \
                 rev | cut -d'/' -f1 | rev | \
                 head -20)
    fi

    # Check for Cargo.toml
    if [[ -f "$project_dir/Cargo.toml" ]]; then
        while IFS= read -r dep; do
            [[ -n "$dep" ]] && libraries+=("$dep")
        done < <(grep -E '^\s+[a-z0-9_-]+\s*=' "$project_dir/Cargo.toml" 2>/dev/null | \
                 awk '{print $1}' | \
                 head -20)
    fi

    printf '%s\n' "${libraries[@]:-}"
}

# Main hook function
# Arguments:
#   $1 - prompt: The user's prompt
# Output:
#   Modified prompt with docs prepended (if available)
devos_user_prompt_submit_hook() {
    local prompt="$1"

    # Check if we should fetch docs
    if ! has_implementation_keywords "$prompt"; then
        # No implementation keywords, return as-is
        cat <<< "$prompt"
        return 0
    fi

    # Extract libraries from prompt
    local prompt_libs
    prompt_libs=$(extract_libraries_from_prompt "$prompt")

    # Detect libraries from project
    local project_libs
    project_libs=$(detect_libraries_from_project "." 2>/dev/null || echo "")

    # Combine and deduplicate
    local all_libs=()
    while IFS= read -r lib; do
        [[ -n "$lib" ]] && all_libs+=("$lib")
    done <<< "$prompt_libs"
    while IFS= read -r lib; do
        [[ -n "$lib" && ! " ${all_libs[*]} " =~ " ${lib} " ]] && all_libs+=("$lib")
    done <<< "$project_libs"

    # If no libraries detected, return as-is
    if [[ ${#all_libs[@]} -eq 0 ]]; then
        cat <<< "$prompt"
        return 0
    fi

    # Try to get docs for each library
    local docs_context=""
    for lib in "${all_libs[@]:-}"; do
        # Skip very short matches (likely noise)
        [[ ${#lib} -lt 2 ]] && continue

        local lib_docs
        if declare -f get_cached_docs >/dev/null 2>&1; then
            lib_docs=$(get_cached_docs "$lib" 2>/dev/null || echo "")
        else
            lib_docs=""
        fi

        if [[ -n "$lib_docs" ]]; then
            docs_context+="$lib_docs"$'\n\n'
        fi
    done

    # If we got docs, prepend them to the prompt
    if [[ -n "$docs_context" ]]; then
        {
            echo "# Context: Library Documentation"
            echo "$docs_context"
            echo "---"
            echo ""
            echo "$prompt"
        }
    else
        # No docs found, return original prompt
        cat <<< "$prompt"
    fi
}

emit_user_prompt_submit_json() {
    local context="$1"

    python3 -c '
import json
import sys

context = sys.stdin.read()
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": context,
    }
}))
' <<< "$context"
}

# =============================================================================
# MAIN
# =============================================================================

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

# Main entry point - only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if we're in test mode (arguments provided)
    if [[ $# -gt 0 && "$1" == "--test" ]]; then
        # Test mode
        export DEVOS_LOG_LEVEL=2

        echo "DevOS UserPromptSubmit Hook - Test Mode"
        echo "======================================="
        echo ""

        # Test prompts
        test_prompts=(
            "implement a React component"
            "add TypeScript types to the user model"
            "list files in the current directory"
        )

        for test_prompt in "${test_prompts[@]}"; do
            echo "Testing: $test_prompt"
            echo "---"
            devos_user_prompt_submit_hook "$test_prompt"
            echo ""
            echo "---"
            echo ""
        done
    else
        # Normal hook execution - read from stdin, output to stdout.
        # Always exit 0 to never block prompts.
        # codex/pi attach the live TTY as stdin — reading it from a subprocess
        # sends SIGTTIN and suspends the session. Only read on a pipe (non-TTY).
        if [[ ! -t 0 ]]; then
            input_json="$(cat 2>/dev/null || true)"
        else
            input_json=""
        fi
        if [[ -z "$input_json" ]]; then
            exit 0
        fi

        prompt="$(python3 -c '
import json
import sys

try:
    payload = json.loads(sys.stdin.read())
except Exception:
    print("")
    raise SystemExit(0)

print(payload.get("prompt", "") or payload.get("user_input", "") or "")
' <<< "$input_json")"

        if [[ -z "$prompt" ]]; then
            exit 0
        fi

        hook_output="$(devos_user_prompt_submit_hook "$prompt" || true)"
        if [[ -z "$hook_output" || "$hook_output" == "$prompt" ]]; then
            exit 0
        fi

        emit_user_prompt_submit_json "$hook_output" || true
        exit 0
    fi
fi
