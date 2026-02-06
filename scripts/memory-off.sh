#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Disable Memory Status
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

epistemic_set_memory_status "OFF"

echo ""
echo "Memory/Retention status set to: DISABLED"
echo ""
echo "IMPORTANT: Also disable memory in your AI assistant's settings:"
echo "  - Claude: https://claude.ai/settings/capabilities"
echo "  - Cursor: Settings > AI > Memory"
echo "  - Copilot: GitHub settings"
echo ""
echo "All projects are now accessible."
echo ""
