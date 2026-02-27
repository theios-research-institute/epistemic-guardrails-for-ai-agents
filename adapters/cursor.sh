#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Cursor Adapter
# ═══════════════════════════════════════════════════════════════════════════
# Translates Cursor hook format to/from epistemic-core
#
# Cursor Hook Format:
#   Input:  {"tool_name": "...", "tool_input": {...}, "hook_event_name": "preToolUse"}
#   Output: {"decision": "deny", "reason": "..."}
#   Exit:   Exit code 2 = block action
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

# ═══════════════════════════════════════════════════════════════════════════
# PreToolUse Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
cursor_pre_tool_use() {
    # Check jq dependency (fail-closed)
    if ! epistemic_check_jq; then
        echo '{"decision": "deny", "reason": "EPISTEMIC ACCESS BLOCKED: jq is not installed. Install jq to enable epistemic access control."}'
        exit 2  # Cursor uses exit code 2 to block
    fi

    # Read input from stdin
    local INPUT=$(cat)

    # Extract tool info (Cursor uses similar format to Claude Code)
    local TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
    local TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
    local CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

    # Check outbound actions for bash/Bash tool
    if [ "$TOOL_NAME" = "bash" ] || [ "$TOOL_NAME" = "Bash" ]; then
        local COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
        if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
            local BLOCK_REASON
            BLOCK_REASON=$(epistemic_check_outbound "$COMMAND" "$CWD")
            if [ $? -eq 0 ] && [ -n "$BLOCK_REASON" ]; then
                echo "{\"decision\": \"deny\", \"reason\": \"$BLOCK_REASON\"}"
                exit 2
            fi
        fi
        exit 0
    fi

    # Extract file path based on tool type
    local FILE_PATH=""
    case "$TOOL_NAME" in
        "view"|"read"|"Read")
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty')
            ;;
        "edit"|"Edit"|"write"|"Write")
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty')
            ;;
        "glob"|"Glob"|"grep"|"Grep")
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // .directory // empty')
            ;;
        *)
            # Unknown tool, allow
            exit 0
            ;;
    esac

    # If no file path, allow
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
        echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
        exit 2  # Cursor uses exit code 2 to block
    fi

    # Allow
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# SessionStart Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
cursor_session_start() {
    if ! epistemic_check_jq; then
        echo '{"agent_message": "EPISTEMIC WARNING: jq not installed. Install jq for epistemic access control."}'
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
        echo "{\"agent_message\": \"$WARNING\"}"
    fi

    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Main - detect which hook is being called
# ═══════════════════════════════════════════════════════════════════════════
case "${1:-pretooluse}" in
    "session-start"|"sessionStart"|"sessionstart")
        cursor_session_start
        ;;
    "pre-tool-use"|"preToolUse"|"pretooluse"|*)
        cursor_pre_tool_use
        ;;
esac
