#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Epistemic Guardrails for AI Agents - Installer
# ═══════════════════════════════════════════════════════════════════════════
# Detects installed AI coding assistants and configures hooks for each
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Epistemic Guardrails for AI Agents - Installer${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation directory
INSTALL_DIR="$HOME/.epistemic"

# ═══════════════════════════════════════════════════════════════════════════
# Check dependencies
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Checking dependencies...${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed.${NC}"
    echo "  jq is required for hook functionality."
    echo "  Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════
# Create installation directory
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"/{core,adapters,scripts}

# ═══════════════════════════════════════════════════════════════════════════
# Copy core files
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Installing core library...${NC}"
cp "$SCRIPT_DIR/core/epistemic-core.sh" "$INSTALL_DIR/core/"
chmod +x "$INSTALL_DIR/core/epistemic-core.sh"

# ═══════════════════════════════════════════════════════════════════════════
# Copy adapters
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Installing platform adapters...${NC}"
cp "$SCRIPT_DIR/adapters/"*.sh "$INSTALL_DIR/adapters/"
chmod +x "$INSTALL_DIR/adapters/"*.sh

# ═══════════════════════════════════════════════════════════════════════════
# Copy scripts
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Installing utility scripts...${NC}"
cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts/"*.sh

# ═══════════════════════════════════════════════════════════════════════════
# Create config if not exists
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo -e "${BLUE}Creating default configuration...${NC}"
    cp "$SCRIPT_DIR/config/config.example.json" "$INSTALL_DIR/config.json"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Initialize memory status
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$INSTALL_DIR/.memory-status" ]; then
    echo "OFF" > "$INSTALL_DIR/.memory-status"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Detect and configure AI assistants
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}Detecting installed AI coding assistants...${NC}"
echo ""

INSTALLED_ANY=false

# --- Claude Code ---
if [ -d "$HOME/.claude" ]; then
    echo -e "${GREEN}✓ Claude Code detected${NC}"
    INSTALLED_ANY=true

    # Create hooks directory
    mkdir -p "$HOME/.claude/hooks"

    # Create wrapper scripts that call the adapters
    cat > "$HOME/.claude/hooks/epistemic-file-guard.sh" << 'HOOKEOF'
#!/bin/bash
exec "$HOME/.epistemic/adapters/claude-code.sh" "pre-tool-use"
HOOKEOF
    chmod +x "$HOME/.claude/hooks/epistemic-file-guard.sh"

    cat > "$HOME/.claude/hooks/epistemic-session-guard.sh" << 'HOOKEOF'
#!/bin/bash
exec "$HOME/.epistemic/adapters/claude-code.sh" "session-start"
HOOKEOF
    chmod +x "$HOME/.claude/hooks/epistemic-session-guard.sh"

    echo "  Created: ~/.claude/hooks/epistemic-file-guard.sh"
    echo "  Created: ~/.claude/hooks/epistemic-session-guard.sh"
    echo ""
    echo -e "  ${YELLOW}Add to ~/.claude/settings.json:${NC}"
    cat << 'CONFIGEOF'
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/epistemic-session-guard.sh"}]}],
    "PreToolUse": [{"matcher": "Read|Write|Edit|Glob|Grep", "hooks": [{"type": "command", "command": "~/.claude/hooks/epistemic-file-guard.sh"}]}]
  }
CONFIGEOF
    echo ""
fi

# --- Cursor ---
if [ -d "$HOME/.cursor" ] || [ -d "$HOME/Library/Application Support/Cursor" ]; then
    echo -e "${GREEN}✓ Cursor detected${NC}"
    INSTALLED_ANY=true

    CURSOR_CONFIG="$HOME/.cursor"
    mkdir -p "$CURSOR_CONFIG/hooks"

    cat > "$CURSOR_CONFIG/hooks/epistemic-guard.sh" << 'HOOKEOF'
#!/bin/bash
exec "$HOME/.epistemic/adapters/cursor.sh" "pre-tool-use"
HOOKEOF
    chmod +x "$CURSOR_CONFIG/hooks/epistemic-guard.sh"

    echo "  Created: ~/.cursor/hooks/epistemic-guard.sh"
    echo ""
    echo -e "  ${YELLOW}Add to Cursor settings (Settings > Hooks):${NC}"
    echo '  preToolUse: ~/.cursor/hooks/epistemic-guard.sh'
    echo ""
fi

# --- GitHub Copilot CLI ---
if command -v gh &> /dev/null && gh extension list 2>/dev/null | grep -q "copilot"; then
    echo -e "${GREEN}✓ GitHub Copilot CLI detected${NC}"
    INSTALLED_ANY=true

    COPILOT_CONFIG="$HOME/.config/gh-copilot"
    mkdir -p "$COPILOT_CONFIG/hooks"

    cat > "$COPILOT_CONFIG/hooks/epistemic-guard.sh" << 'HOOKEOF'
#!/bin/bash
exec "$HOME/.epistemic/adapters/github-copilot.sh" "pre-tool-use"
HOOKEOF
    chmod +x "$COPILOT_CONFIG/hooks/epistemic-guard.sh"

    echo "  Created: ~/.config/gh-copilot/hooks/epistemic-guard.sh"
    echo ""
    echo -e "  ${YELLOW}Add to ~/.config/gh-copilot/hooks.json:${NC}"
    cat << 'CONFIGEOF'
  {
    "version": 1,
    "hooks": {
      "preToolUse": [{"type": "command", "bash": "~/.config/gh-copilot/hooks/epistemic-guard.sh"}]
    }
  }
CONFIGEOF
    echo ""
fi

if [ "$INSTALLED_ANY" = false ]; then
    echo -e "${YELLOW}No supported AI coding assistants detected.${NC}"
    echo "  Supported: Claude Code, Cursor, GitHub Copilot CLI"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════
# Add shell aliases
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Setting up shell aliases...${NC}"

SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    # Check if aliases already exist
    if ! grep -q "epistemic-memory-status" "$SHELL_RC" 2>/dev/null; then
        cat >> "$SHELL_RC" << 'ALIASEOF'

# Epistemic Guardrails
alias epistemic-memory-status="$HOME/.epistemic/scripts/memory-status.sh"
alias epistemic-memory-on="$HOME/.epistemic/scripts/memory-on.sh"
alias epistemic-memory-off="$HOME/.epistemic/scripts/memory-off.sh"
ALIASEOF
        echo "  Added aliases to $SHELL_RC"
    else
        echo "  Aliases already configured in $SHELL_RC"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# Complete
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Installed to: $INSTALL_DIR"
echo ""
echo "Commands available (after restarting shell):"
echo "  epistemic-memory-status  - Check current memory status"
echo "  epistemic-memory-on      - Enable memory tracking"
echo "  epistemic-memory-off     - Disable memory tracking"
echo ""
echo "Configuration: $INSTALL_DIR/config.json"
echo ""
echo -e "${YELLOW}IMPORTANT: Follow the platform-specific instructions above${NC}"
echo -e "${YELLOW}to complete hook configuration for your AI assistant(s).${NC}"
echo ""
