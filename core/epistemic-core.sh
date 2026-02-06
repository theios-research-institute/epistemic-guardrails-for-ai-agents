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
