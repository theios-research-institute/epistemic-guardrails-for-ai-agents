#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Core Library
# ═══════════════════════════════════════════════════════════════════════════
# Platform-agnostic functions for epistemic access control
# Used by adapters for Claude Code, Cursor, GitHub Copilot, and others
#
# Part of the Epistemic Guardrails framework by Theios Research Institute
# https://github.com/theios-research-institute/epistemic-guardrails-for-ai-agents
# ═══════════════════════════════════════════════════════════════════════════

# Configuration paths (can be overridden via environment variables)
EPISTEMIC_CONFIG_FILE="${EPISTEMIC_CONFIG_FILE:-$HOME/.epistemic/config.json}"
EPISTEMIC_STATUS_FILE="${EPISTEMIC_STATUS_FILE:-$HOME/.epistemic/.memory-status}"

# ═══════════════════════════════════════════════════════════════════════════
# Function: Check if jq is available
# ═══════════════════════════════════════════════════════════════════════════
epistemic_check_jq() {
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Get current memory/retention status
# Returns: "ON" or "OFF"
# ═══════════════════════════════════════════════════════════════════════════
epistemic_get_memory_status() {
    if [ -f "$EPISTEMIC_STATUS_FILE" ]; then
        cat "$EPISTEMIC_STATUS_FILE"
    else
        # Default to OFF (safe default)
        echo "OFF"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Set memory/retention status
# Args: $1 = "ON" or "OFF"
# ═══════════════════════════════════════════════════════════════════════════
epistemic_set_memory_status() {
    local STATUS="$1"
    mkdir -p "$(dirname "$EPISTEMIC_STATUS_FILE")"
    echo "$STATUS" > "$EPISTEMIC_STATUS_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Check for .epistemic-tier file in path hierarchy
# Args: $1 = directory path to check
# Returns: 0 if restricted, 1 if not
# ═══════════════════════════════════════════════════════════════════════════
epistemic_check_tier_file() {
    local CHECK_DIR="$1"

    # Get directory if file path provided
    if [ -f "$CHECK_DIR" ]; then
        CHECK_DIR=$(dirname "$CHECK_DIR")
    fi

    # Walk up directory tree
    local TIER_DIR="$CHECK_DIR"
    while [ "$TIER_DIR" != "/" ] && [ -n "$TIER_DIR" ]; do
        if [ -f "$TIER_DIR/.epistemic-tier" ]; then
            # Use grep for security (avoid sourcing arbitrary files)
            local TIER=$(grep -E "^TIER=" "$TIER_DIR/.epistemic-tier" 2>/dev/null | cut -d= -f2)
            local MEMORY_REQ=$(grep -E "^MEMORY_REQUIRED=" "$TIER_DIR/.epistemic-tier" 2>/dev/null | cut -d= -f2)
            if [ "$TIER" = "restricted" ] || [ "$MEMORY_REQ" = "off" ]; then
                return 0  # Is restricted
            fi
        fi
        TIER_DIR=$(dirname "$TIER_DIR")
    done

    return 1  # Not restricted
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Check if path matches configured sensitive paths
# Args: $1 = path to check
# Returns: 0 if sensitive, 1 if not
# ═══════════════════════════════════════════════════════════════════════════
epistemic_check_config_paths() {
    local CHECK_PATH="$1"

    if [ ! -f "$EPISTEMIC_CONFIG_FILE" ]; then
        return 1
    fi

    if ! epistemic_check_jq; then
        return 1
    fi

    # Check configured paths
    while IFS= read -r SENSITIVE_PATH; do
        [ -z "$SENSITIVE_PATH" ] && continue
        # Expand ~ to $HOME
        local EXPANDED_PATH="${SENSITIVE_PATH/#\~/$HOME}"
        if [[ "$CHECK_PATH" == "$EXPANDED_PATH"* ]]; then
            return 0  # Is sensitive
        fi
    done < <(jq -r '.sensitive_projects.paths[]? // empty' "$EPISTEMIC_CONFIG_FILE" 2>/dev/null)

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Check if path contains sensitive keywords
# Args: $1 = path to check
# Returns: 0 if contains keyword, 1 if not
# Uses word-boundary matching (path separators)
# ═══════════════════════════════════════════════════════════════════════════
epistemic_check_keywords() {
    local CHECK_PATH="$1"
    local CHECK_PATH_LOWER=$(echo "$CHECK_PATH" | tr '[:upper:]' '[:lower:]')

    local KEYWORDS=""

    if [ -f "$EPISTEMIC_CONFIG_FILE" ] && epistemic_check_jq; then
        KEYWORDS=$(jq -r '.sensitive_projects.keywords[]? // empty' "$EPISTEMIC_CONFIG_FILE" 2>/dev/null | tr '\n' ' ')
    fi

    # Default keywords if none configured
    if [ -z "$KEYWORDS" ]; then
        KEYWORDS="proprietary confidential restricted patent trade-secret pre-publication"
    fi

    for KEYWORD in $KEYWORDS; do
        # Word-boundary matching using path separators
        if [[ "$CHECK_PATH_LOWER" =~ (^|/)${KEYWORD}(/|$) ]]; then
            return 0  # Contains keyword
        fi
    done

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Main check - is path restricted?
# Args: $1 = path to check
# Returns: 0 if restricted, 1 if not
# ═══════════════════════════════════════════════════════════════════════════
epistemic_is_restricted() {
    local CHECK_PATH="$1"

    # Check .epistemic-tier file
    if epistemic_check_tier_file "$CHECK_PATH"; then
        return 0
    fi

    # Check configured paths
    if epistemic_check_config_paths "$CHECK_PATH"; then
        return 0
    fi

    # Check keywords
    if epistemic_check_keywords "$CHECK_PATH"; then
        return 0
    fi

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Should access be blocked?
# Args: $1 = path to check
# Returns: 0 if should block, 1 if should allow
# Logic: Block if (path is restricted) AND (memory is ON)
# ═══════════════════════════════════════════════════════════════════════════
epistemic_should_block() {
    local CHECK_PATH="$1"
    local MEMORY_STATUS=$(epistemic_get_memory_status)

    # If memory is OFF, always allow
    if [ "$MEMORY_STATUS" = "OFF" ]; then
        return 1  # Don't block
    fi

    # If memory is ON, check if path is restricted
    if epistemic_is_restricted "$CHECK_PATH"; then
        return 0  # Block
    fi

    return 1  # Don't block
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Get block reason message
# Args: $1 = path that was blocked
# ═══════════════════════════════════════════════════════════════════════════
epistemic_get_block_reason() {
    local BLOCKED_PATH="$1"
    echo "EPISTEMIC ACCESS BLOCKED: Cannot access restricted path '$BLOCKED_PATH' while Memory/Retention is ENABLED. Disable memory first or work in a non-restricted directory."
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Get warning message for session start
# Args: $1 = current working directory
# ═══════════════════════════════════════════════════════════════════════════
epistemic_get_session_warning() {
    local CWD="$1"
    echo "EPISTEMIC WARNING: You are in a RESTRICTED project directory ($CWD) but Memory/Retention is ENABLED. This violates epistemic access controls. Disable memory before working here."
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Read ALLOWED_REMOTES from nearest .epistemic-tier
# Args: $1 = directory path (defaults to pwd)
# Output: prints the ALLOWED_REMOTES value (may be empty)
# Returns: 0 if ALLOWED_REMOTES found and non-empty, 1 otherwise
# ═══════════════════════════════════════════════════════════════════════════
epistemic_get_allowed_remotes() {
    local CHECK_DIR="${1:-$(pwd)}"

    # Get directory if file path provided
    if [ -f "$CHECK_DIR" ]; then
        CHECK_DIR=$(dirname "$CHECK_DIR")
    fi

    # Walk up directory tree
    local TIER_DIR="$CHECK_DIR"
    while [ "$TIER_DIR" != "/" ] && [ -n "$TIER_DIR" ]; do
        if [ -f "$TIER_DIR/.epistemic-tier" ]; then
            local ALLOWED=$(grep -E "^ALLOWED_REMOTES=" "$TIER_DIR/.epistemic-tier" 2>/dev/null | cut -d= -f2)
            if [ -n "$ALLOWED" ]; then
                echo "$ALLOWED"
                return 0
            fi
            return 1
        fi
        TIER_DIR=$(dirname "$TIER_DIR")
    done

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Resolve a git remote name to its URL
# Args: $1 = remote name (e.g. "origin")
# Output: prints the remote URL
# Returns: 0 on success, 1 on failure
# ═══════════════════════════════════════════════════════════════════════════
epistemic_resolve_git_remote() {
    local REMOTE_NAME="$1"
    local URL
    URL=$(git remote get-url "$REMOTE_NAME" 2>/dev/null)
    if [ -n "$URL" ]; then
        echo "$URL"
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Normalize a git URL for comparison
# Converts SSH-style URLs to a canonical form matching HTTPS patterns
#   git@github.com:org/repo.git  → github.com/org/repo
#   https://github.com/org/repo.git → github.com/org/repo
#   ssh://git@github.com/org/repo.git → github.com/org/repo
#   git://github.com/org/repo.git → github.com/org/repo
# Args: $1 = URL to normalize
# Output: normalized URL string
# ═══════════════════════════════════════════════════════════════════════════
epistemic_normalize_git_url() {
    local URL="$1"

    # Strip trailing .git
    URL="${URL%.git}"

    # ssh://git@host/path → host/path
    if [[ "$URL" == ssh://* ]]; then
        URL=$(echo "$URL" | sed -E 's|^ssh://[^@]*@||; s|^ssh://||')
    fi

    # git://host/path → host/path (read-only git protocol)
    URL=$(echo "$URL" | sed -E 's|^git://||')

    # https://host/path or http://host/path → host/path
    URL=$(echo "$URL" | sed -E 's|^https?://||')

    # git@host:path → host/path (SSH shorthand)
    URL=$(echo "$URL" | sed -E 's|^[^@]*@([^:]+):|\1/|')

    echo "$URL"
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Check if a URL matches an allowed remote pattern
# Args: $1 = URL to check, $2 = pattern to match against
# Pattern syntax:
#   - Exact substring: "github.com/my-org/my-repo"
#   - Trailing wildcard: "github.com/my-org/*"
# URLs are normalized before matching (SSH and HTTPS both work)
# Returns: 0 if matches, 1 if not
# ═══════════════════════════════════════════════════════════════════════════
epistemic_match_remote() {
    local URL="$1"
    local PATTERN="$2"

    # Trim whitespace
    PATTERN=$(echo "$PATTERN" | xargs)
    [ -z "$PATTERN" ] && return 1

    # Normalize the URL for consistent matching
    local NORMALIZED
    NORMALIZED=$(epistemic_normalize_git_url "$URL")

    if [[ "$PATTERN" == *'*' ]]; then
        # Wildcard: match prefix (everything before the *)
        local PREFIX="${PATTERN%\*}"
        if [[ "$NORMALIZED" == *"$PREFIX"* ]] || [[ "$URL" == *"$PREFIX"* ]]; then
            return 0
        fi
    else
        # Exact substring match (check both normalized and raw)
        if [[ "$NORMALIZED" == *"$PATTERN"* ]] || [[ "$URL" == *"$PATTERN"* ]]; then
            return 0
        fi
    fi

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Function: Extract destination from an outbound command and check it
# Args: $1 = command string, $2 = working directory (optional)
# Returns: 0 if should BLOCK, 1 if should ALLOW
# Output: if blocked, prints a deny reason message
# ═══════════════════════════════════════════════════════════════════════════
epistemic_check_outbound() {
    local COMMAND="$1"
    local CWD="${2:-$(pwd)}"

    # Get ALLOWED_REMOTES (use || to prevent set -e abort)
    local ALLOWED=""
    ALLOWED=$(epistemic_get_allowed_remotes "$CWD") || ALLOWED=""
    if [ -z "$ALLOWED" ]; then
        return 1  # No restrictions declared — allow
    fi

    # Determine destination based on command pattern
    local DESTINATION=""

    # git push [remote] [branch...]
    if echo "$COMMAND" | grep -qE '^\s*git\s+push(\s|$)'; then
        # Extract remote name (first non-flag arg after "git push")
        local REMOTE_NAME
        REMOTE_NAME=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]+//' | awk '{for(i=1;i<=NF;i++){if($i !~ /^-/){print $i; exit}}}')
        if [ -z "$REMOTE_NAME" ]; then
            REMOTE_NAME="origin"
        fi
        DESTINATION=$(cd "$CWD" 2>/dev/null && epistemic_resolve_git_remote "$REMOTE_NAME") || DESTINATION=""

    # git remote add <name> <url>
    elif echo "$COMMAND" | grep -qE '^\s*git\s+remote\s+add\s'; then
        DESTINATION=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*git[[:space:]]+remote[[:space:]]+add[[:space:]]+[^[:space:]]+[[:space:]]+//' | awk '{print $1}')

    # git remote set-url [--push|--delete] <name> <url>
    elif echo "$COMMAND" | grep -qE '^\s*git\s+remote\s+set-url\s'; then
        # Strip "git remote set-url", then skip optional flags (--push, --delete)
        # before extracting remote name and URL
        local SETURL_ARGS
        SETURL_ARGS=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*git[[:space:]]+remote[[:space:]]+set-url[[:space:]]+//')
        # Skip any leading --flag arguments
        while echo "$SETURL_ARGS" | grep -qE '^--[^[:space:]]+'; do
            SETURL_ARGS=$(echo "$SETURL_ARGS" | sed -E 's/^--[^[:space:]]+[[:space:]]*//')
        done
        # Now first word is remote name, second is URL
        DESTINATION=$(echo "$SETURL_ARGS" | awk '{print $2}')

    # gh repo create [owner/repo]
    # Note: gh CLI is GitHub-specific, so github.com/ prefix is correct here
    elif echo "$COMMAND" | grep -qE '^\s*gh\s+repo\s+create\s'; then
        local REPO_ARG
        REPO_ARG=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*gh[[:space:]]+repo[[:space:]]+create[[:space:]]+//' | awk '{for(i=1;i<=NF;i++){if($i !~ /^-/){print $i; exit}}}')
        if [ -n "$REPO_ARG" ]; then
            DESTINATION="github.com/$REPO_ARG"
        fi

    # npm publish [--registry <url>]
    elif echo "$COMMAND" | grep -qE '^\s*npm\s+publish'; then
        local REGISTRY
        REGISTRY=$(echo "$COMMAND" | grep -oE -- '--registry[[:space:]]+[^[:space:]]+' | awk '{print $2}')
        DESTINATION="${REGISTRY:-registry.npmjs.org}"

    # cargo publish [--registry <name|url>]
    elif echo "$COMMAND" | grep -qE '^\s*cargo\s+publish'; then
        local CARGO_REGISTRY
        CARGO_REGISTRY=$(echo "$COMMAND" | grep -oE -- '--registry[[:space:]]+[^[:space:]]+' | awk '{print $2}')
        DESTINATION="${CARGO_REGISTRY:-crates.io}"

    # pip upload / twine upload [--repository <name>] [--repository-url <url>]
    elif echo "$COMMAND" | grep -qE '^\s*(pip|twine)\s+upload'; then
        local REPO_URL REPO_NAME
        REPO_URL=$(echo "$COMMAND" | grep -oE -- '--repository-url[[:space:]]+[^[:space:]]+' | awk '{print $2}')
        REPO_NAME=$(echo "$COMMAND" | grep -oE -- '--repository[[:space:]]+[^[:space:]]+' | grep -v -- '--repository-url' | awk '{print $2}')
        if [ -n "$REPO_URL" ]; then
            DESTINATION="$REPO_URL"
        elif [ -n "$REPO_NAME" ]; then
            DESTINATION="$REPO_NAME"
        else
            DESTINATION="pypi.org"
        fi

    # rsync to remote — find the last non-flag argument containing ':'
    # (remote destinations use host:path syntax)
    elif echo "$COMMAND" | grep -qE '^\s*rsync\s'; then
        DESTINATION=$(echo "$COMMAND" | awk '{for(i=NF;i>=1;i--){if($i !~ /^-/ && $i ~ /:/){print $i; exit}}}')

    # scp to remote — find the last non-flag argument containing ':'
    elif echo "$COMMAND" | grep -qE '^\s*scp\s'; then
        DESTINATION=$(echo "$COMMAND" | awk '{for(i=NF;i>=1;i--){if($i !~ /^-/ && $i ~ /:/){print $i; exit}}}')

    # aws s3 cp/sync to remote
    elif echo "$COMMAND" | grep -qE '^\s*aws\s+s3\s+(cp|sync)\s'; then
        DESTINATION=$(echo "$COMMAND" | grep -oE 's3://[^ ]+' | tail -1)

    else
        return 1  # Not an outbound command — allow
    fi

    # If no destination could be extracted, allow
    if [ -z "$DESTINATION" ]; then
        return 1
    fi

    # Check destination against each allowed pattern
    IFS=',' read -ra PATTERNS <<< "$ALLOWED"
    for PATTERN in "${PATTERNS[@]}"; do
        if epistemic_match_remote "$DESTINATION" "$PATTERN"; then
            return 1  # Matched — allow
        fi
    done

    # No match — block
    echo "OUTBOUND ACTION BLOCKED: Destination '$DESTINATION' is not in ALLOWED_REMOTES. Allowed: $ALLOWED"
    return 0
}
