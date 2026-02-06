#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Claude Code Adapter
# ═══════════════════════════════════════════════════════════════════════════
# Translates Claude Code hook format to/from epistemic-core
#
# Claude Code Hook Format:
#   Input:  {"tool_name": "Read", "tool_input": {"file_path": "..."}, "cwd": "..."}
#   Output: {"hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": "..."}}
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

# ═══════════════════════════════════════════════════════════════════════════
# PreToolUse Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
claude_code_pre_tool_use() {
    # Check jq dependency (fail-closed)
    if ! epistemic_check_jq; then
        cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "EPISTEMIC ACCESS BLOCKED: jq is not installed. Install jq to enable epistemic access control."
  }
}
EOF
        return 0
    fi

    # Read input from stdin
    local INPUT=$(cat)

    # Extract tool info
    local TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
    local TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
    local CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

    # Extract file path based on tool type
    local FILE_PATH=""
    case "$TOOL_NAME" in
        "Read"|"Write"|"Edit")
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
            ;;
        "Glob"|"Grep")
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // empty')
            ;;
        *)
            # Unknown tool, allow
            return 0
            ;;
    esac

    # If no file path, allow
    if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "null" ]; then
        return 0
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
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$REASON"
  }
}
EOF
    fi
    # If not blocked, exit silently (allow)
}

# ═══════════════════════════════════════════════════════════════════════════
# SessionStart Hook Handler
# ═══════════════════════════════════════════════════════════════════════════
claude_code_session_start() {
    if ! epistemic_check_jq; then
        echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"EPISTEMIC WARNING: jq not installed. Install jq for epistemic access control."}}' >&2
        return 0
    fi

    local INPUT=$(cat)
    local CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

    if [ -z "$CWD" ]; then
        CWD=$(pwd)
    fi

    local MEMORY_STATUS=$(epistemic_get_memory_status)

    if [ "$MEMORY_STATUS" = "ON" ] && epistemic_is_restricted "$CWD"; then
        local WARNING=$(epistemic_get_session_warning "$CWD")
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$WARNING"
  }
}
EOF
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main - detect which hook is being called
# ═══════════════════════════════════════════════════════════════════════════
case "${1:-pretooluse}" in
    "session-start"|"sessionstart")
        claude_code_session_start
        ;;
    "pre-tool-use"|"pretooluse"|*)
        claude_code_pre_tool_use
        ;;
esac
