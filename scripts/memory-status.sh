#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails - Memory Status
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/epistemic-core.sh"

STATUS=$(epistemic_get_memory_status)

echo ""
echo "Epistemic Guardrails - Memory Status"
echo "========================================="
echo ""

if [ "$STATUS" = "ON" ]; then
    echo "  Memory/Retention: ENABLED"
    echo ""
    echo "  Conversations may create long-term memories."
    echo "  Restricted projects will BLOCK file access."
    echo ""
    echo "  To disable: epistemic-memory-off"
else
    echo "  Memory/Retention: DISABLED"
    echo ""
    echo "  No long-term memory retention active."
    echo "  All projects accessible."
    echo ""
    echo "  To enable: epistemic-memory-on"
fi

echo ""
