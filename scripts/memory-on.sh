#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Enable Memory Status
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

epistemic_set_memory_status "ON"

echo ""
echo "Memory/Retention status set to: ENABLED"
echo ""
echo "IMPORTANT: Also enable memory in your AI assistant's settings:"
echo "  - Claude: https://claude.ai/settings/capabilities"
echo "  - Cursor: Settings > AI > Memory"
echo "  - Copilot: GitHub settings"
echo ""
echo "Restricted projects will now BLOCK file access."
echo ""
