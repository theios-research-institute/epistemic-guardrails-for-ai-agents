#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - GitHub Copilot Adapter
# ═══════════════════════════════════════════════════════════════════════════
# Translates GitHub Copilot hook format to/from epistemic-core
#
# GitHub Copilot Hook Format:
#   Input:  {"toolName": "bash", "toolArgs": "{\"command\":\"...\"}", "cwd": "..."}
#   Output: {"permissionDecision": "deny", "permissionDecisionReason": "..."}
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

# ═══════════════════════════════════════════════════════════════════════════
# PreToolUse Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
copilot_pre_tool_use() {
    # Check jq dependency (fail-closed)
    if ! epistemic_check_jq; then
        echo '{"permissionDecision": "deny", "permissionDecisionReason": "EPISTEMIC ACCESS BLOCKED: jq is not installed. Install jq to enable epistemic access control."}'
        exit 0
    fi

    # Read input from stdin
    local INPUT=$(cat)

    # Extract tool info (Copilot uses camelCase)
    local TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty')
    local TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs // "{}"')
    local CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

    # Parse toolArgs (it's a JSON string)
    local PARSED_ARGS=$(echo "$TOOL_ARGS" | jq -r '.' 2>/dev/null || echo "{}")

    # Extract file path based on tool type
    local FILE_PATH=""
    case "$TOOL_NAME" in
        "view"|"read")
            FILE_PATH=$(echo "$PARSED_ARGS" | jq -r '.file // .path // empty')
            ;;
        "edit"|"write")
            FILE_PATH=$(echo "$PARSED_ARGS" | jq -r '.file // .path // empty')
            ;;
        "bash")
            # For bash commands, check if accessing sensitive paths
            local COMMAND=$(echo "$PARSED_ARGS" | jq -r '.command // empty')
            # Extract potential file paths from command (basic detection)
            # Check for cat, less, vim, nano, etc. accessing files
            if echo "$COMMAND" | grep -qE '(cat|less|more|vim|nano|head|tail|grep|sed|awk)\s+[^|<>]+'; then
                FILE_PATH=$(echo "$COMMAND" | grep -oE '(cat|less|more|vim|nano|head|tail|grep|sed|awk)\s+([^\s|<>]+)' | awk '{print $2}' | head -1)
            fi
            ;;
        *)
            # Unknown tool, allow
            exit 0
            ;;
    esac

    # If no file path detected, allow
    if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "null" ]; then
        exit 0
    fi

    # Resolve relative paths
    if [[ "$FILE_PATH" != /* ]]; then
        if [ -n "$CWD" ]; then
            FILE_PATH="$CWD/$FILE_PATH"
        fi
    fi

    # Check if should block
    if epistemic_should_block "$FILE_PATH"; then
        local REASON=$(epistemic_get_block_reason "$FILE_PATH")
        echo "{\"permissionDecision\": \"deny\", \"permissionDecisionReason\": \"$REASON\"}"
    fi
    # If not blocked, exit silently (allow)
}

# ═══════════════════════════════════════════════════════════════════════════
# SessionStart Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
copilot_session_start() {
    if ! epistemic_check_jq; then
        echo '{"message": "EPISTEMIC WARNING: jq not installed. Install jq for epistemic access control."}'
        exit 0
    fi

    local INPUT=$(cat)
    local CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

    if [ -z "$CWD" ]; then
        CWD=$(pwd)
    fi

    local MEMORY_STATUS=$(epistemic_get_memory_status)

    if [ "$MEMORY_STATUS" = "ON" ] && epistemic_is_restricted "$CWD"; then
        local WARNING=$(epistemic_get_session_warning "$CWD")
        echo "{\"message\": \"$WARNING\"}"
    fi

    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Main - detect which hook is being called
# ═══════════════════════════════════════════════════════════════════════════
case "${1:-pretooluse}" in
    "session-start"|"sessionStart"|"sessionstart")
        copilot_session_start
        ;;
    "pre-tool-use"|"preToolUse"|"pretooluse"|*)
        copilot_pre_tool_use
        ;;
esac
