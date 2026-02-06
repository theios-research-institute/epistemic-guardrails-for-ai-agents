#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails for AI Agents - Test Suite
# ═══════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASSED=0
FAILED=0

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAILED=$((FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (file not found: $file)"
        FAILED=$((FAILED + 1))
    fi
}

assert_executable() {
    local file="$1"
    local test_name="$2"

    if [ -x "$file" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (not executable: $file)"
        FAILED=$((FAILED + 1))
    fi
}

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Epistemic Guardrails for AI Agents - Test Suite${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# File Structure Tests
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}File Structure Tests${NC}"

assert_file_exists "$PROJECT_DIR/install.sh" "install.sh exists"
assert_executable "$PROJECT_DIR/install.sh" "install.sh is executable"
assert_file_exists "$PROJECT_DIR/core/epistemic-core.sh" "core library exists"
assert_file_exists "$PROJECT_DIR/adapters/claude-code.sh" "Claude Code adapter exists"
assert_file_exists "$PROJECT_DIR/adapters/cursor.sh" "Cursor adapter exists"
assert_file_exists "$PROJECT_DIR/adapters/github-copilot.sh" "GitHub Copilot adapter exists"
assert_file_exists "$PROJECT_DIR/scripts/memory-status.sh" "memory-status.sh exists"
assert_file_exists "$PROJECT_DIR/scripts/memory-on.sh" "memory-on.sh exists"
assert_file_exists "$PROJECT_DIR/scripts/memory-off.sh" "memory-off.sh exists"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Script Syntax Tests
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}Script Syntax Tests${NC}"

for script in "$PROJECT_DIR"/core/*.sh "$PROJECT_DIR"/adapters/*.sh "$PROJECT_DIR"/scripts/*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $(basename "$script") has valid syntax"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗${NC} $(basename "$script") has syntax errors"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Core Library Function Tests
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}Core Library Function Tests${NC}"

# Source core library for testing
source "$PROJECT_DIR/core/epistemic-core.sh"

# Test epistemic_check_jq
if command -v jq &> /dev/null; then
    if epistemic_check_jq; then
        echo -e "${GREEN}✓${NC} epistemic_check_jq returns true when jq installed"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} epistemic_check_jq should return true"
        FAILED=$((FAILED + 1))
    fi
fi

# Test epistemic_get_memory_status with temp file
TEMP_STATUS=$(mktemp)
echo "ON" > "$TEMP_STATUS"
EPISTEMIC_STATUS_FILE="$TEMP_STATUS"
source "$PROJECT_DIR/core/epistemic-core.sh"
STATUS=$(epistemic_get_memory_status)
assert_equals "ON" "$STATUS" "epistemic_get_memory_status reads ON"

echo "OFF" > "$TEMP_STATUS"
STATUS=$(epistemic_get_memory_status)
assert_equals "OFF" "$STATUS" "epistemic_get_memory_status reads OFF"
rm -f "$TEMP_STATUS"

# Test keyword detection
if epistemic_check_keywords "/home/user/proprietary/project"; then
    echo -e "${GREEN}✓${NC} epistemic_check_keywords detects 'proprietary'"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} epistemic_check_keywords should detect 'proprietary'"
    FAILED=$((FAILED + 1))
fi

if epistemic_check_keywords "/home/user/myproject"; then
    echo -e "${RED}✗${NC} epistemic_check_keywords should not match 'myproject'"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓${NC} epistemic_check_keywords correctly ignores non-sensitive path"
    PASSED=$((PASSED + 1))
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Configuration Tests
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}Configuration Tests${NC}"

if command -v jq &> /dev/null; then
    if jq empty "$PROJECT_DIR/config/config.example.json" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} config.example.json is valid JSON"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} config.example.json is invalid JSON"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} jq not installed - skipping JSON validation"
    FAILED=$((FAILED + 1))
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Results
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASSED + FAILED))
echo -e "Tests: $TOTAL | ${GREEN}Passed: $PASSED${NC} | ${RED}Failed: $FAILED${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0
