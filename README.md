# Epistemic Guardrails for AI Agents

> **Controlling what knowledge systems can access, retain, and operate on.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-green.svg)](https://claude.ai/code)
[![Cursor](https://img.shields.io/badge/Cursor-Compatible-green.svg)](https://cursor.com)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-Compatible-green.svg)](https://github.com/features/copilot)

A contribution from [Theios Research Institute, Inc.](https://theios.org)

---

## Disclaimer

This software is provided as-is with no warranty. The authors are not responsible for data loss, security breaches, or any damages resulting from the use of this software. This tool is an aid, not a guarantee of protection. Users are responsible for verifying their own security configurations and compliance requirements. This is not legal advice.

---

## The Problem

AI coding assistants like Claude Code, Cursor, and GitHub Copilot can retain conversation history through memory features. While useful for continuity, this creates a critical challenge:

**How do you work on sensitive projects (proprietary research, pre-patent work, trade secrets) while using memory for routine development?**

The answer: **Epistemic Guardrails** - a framework that enforces information boundaries based on project sensitivity.

### Three Layers of Protection

1. **Session-Start Guard** - Warns the AI about sensitive directories when memory is enabled (SessionStart hook)
2. **PreToolUse Hook** - Blocks file access to sensitive directories during active sessions (hard enforcement)
3. **Path + Keyword Detection** - Identifies sensitive projects by directory path and naming patterns

---

## Overview

Epistemic Guardrails provides a unified framework for controlling information access across multiple AI coding assistants. One configuration, multiple platforms.

### Supported Platforms

| Platform | Status | Hook Support |
|----------|--------|--------------|
| **Claude Code** | ✅ Full | PreToolUse, SessionStart |
| **Cursor** | ✅ Full | preToolUse, sessionStart |
| **GitHub Copilot CLI** | ✅ Full | preToolUse, sessionStart |
| **Windsurf** | 🔄 Planned | TBD |

---

## How It Works

```
+-------------------------------------------------------------+
|                    EPISTEMIC GUARDRAILS                     |
+-------------------------------------------------------------+
|                                                             |
|  +-------------+   +-------------+   +-------------+        |
|  | Claude Code |   |   Cursor    |   |   Copilot   |        |
|  |   Adapter   |   |   Adapter   |   |   Adapter   |        |
|  +------+------+   +------+------+   +------+------+        |
|         |                 |                 |               |
|         +-----------------+-----------------+               |
|                           |                                 |
|                +----------v----------+                      |
|                |    Core Library     |                      |
|                |  (epistemic-core)   |                      |
|                +----------+----------+                      |
|                           |                                 |
|         +-----------------+-----------------+               |
|         |                 |                 |               |
|  +------v------+   +------v------+   +------v------+        |
|  | .epistemic- |   |   Config    |   |   Memory    |        |
|  |  tier files |   |    Paths    |   |   Status    |        |
|  +-------------+   +-------------+   +-------------+        |
|                                                             |
+-------------------------------------------------------------+
```

### Decision Matrix

| Project Type | Memory Status | Result |
|--------------|---------------|--------|
| Restricted | ON | ⛔ BLOCKED |
| Restricted | OFF | ✅ ALLOWED |
| General | ON | ✅ ALLOWED |
| General | OFF | ✅ ALLOWED |

---

## Installation

### Prerequisites

- macOS or Linux
- bash shell
- **jq** (JSON processor)
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  sudo apt-get install jq
  ```

### Quick Install

```bash
git clone https://github.com/theios-research-institute/epistemic-guardrails-for-ai-agents.git
cd epistemic-guardrails-for-ai-agents
./install.sh
```

The installer will:
1. Install core library to `~/.epistemic/`
2. Detect installed AI assistants (Claude Code, Cursor, Copilot)
3. Create platform-specific hook scripts
4. Provide configuration instructions for each platform

### Manual Install (Platform-Specific)

If you prefer manual installation or the auto-installer doesn't detect your platform:

#### Claude Code

```bash
# 1. Install core library
mkdir -p ~/.epistemic/{core,adapters,scripts}
cp core/epistemic-core.sh ~/.epistemic/core/
cp adapters/claude-code.sh ~/.epistemic/adapters/
cp scripts/*.sh ~/.epistemic/scripts/
chmod +x ~/.epistemic/**/*.sh

# 2. Create hook directory and copy hooks
mkdir -p ~/.claude/hooks
cp adapters/claude-code.sh ~/.claude/hooks/epistemic-file-guard.sh
cp adapters/claude-code-session.sh ~/.claude/hooks/epistemic-session-guard.sh
chmod +x ~/.claude/hooks/*.sh

# 3. Copy configuration template
cp config/config.example.json ~/.epistemic/config.json

# 4. Add hooks to Claude Code settings (see Platform Configuration below)
```

#### Cursor

```bash
# 1. Install core library (same as above)
mkdir -p ~/.epistemic/{core,adapters,scripts}
cp core/epistemic-core.sh ~/.epistemic/core/
cp scripts/*.sh ~/.epistemic/scripts/
chmod +x ~/.epistemic/**/*.sh

# 2. Create hook directory and copy hooks
mkdir -p ~/.cursor/hooks
cp adapters/cursor.sh ~/.cursor/hooks/epistemic-guard.sh
chmod +x ~/.cursor/hooks/*.sh

# 3. Copy configuration template
cp config/config.example.json ~/.epistemic/config.json

# 4. Configure Cursor hooks (see Platform Configuration below)
```

#### GitHub Copilot CLI

```bash
# 1. Install core library (same as above)
mkdir -p ~/.epistemic/{core,adapters,scripts}
cp core/epistemic-core.sh ~/.epistemic/core/
cp scripts/*.sh ~/.epistemic/scripts/
chmod +x ~/.epistemic/**/*.sh

# 2. Create hook directory and copy hooks
mkdir -p ~/.config/gh-copilot/hooks
cp adapters/github-copilot.sh ~/.config/gh-copilot/hooks/epistemic-guard.sh
chmod +x ~/.config/gh-copilot/hooks/*.sh

# 3. Copy configuration template
cp config/config.example.json ~/.epistemic/config.json

# 4. Configure Copilot hooks (see Platform Configuration below)
```

---

## Configuration

### Global Configuration

Edit `~/.epistemic/config.json`:

```json
{
  "sensitive_projects": {
    "paths": [
      "~/proprietary-research",
      "~/patents/pending"
    ],
    "keywords": [
      "proprietary",
      "confidential",
      "restricted"
    ]
  }
}
```

### Per-Project Configuration

Create `.epistemic-tier` in any project root:

```bash
TIER=restricted
MEMORY_REQUIRED=off
```

---

## Usage

### Check Memory Status

```bash
epistemic-memory-status
```

### Toggle Memory State

```bash
# Before working on sensitive projects
epistemic-memory-off

# For general development
epistemic-memory-on
```

**Important:** Also toggle memory in your AI assistant's settings.

---

## Platform Configuration

### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/epistemic-session-guard.sh"
      }]
    }],
    "PreToolUse": [{
      "matcher": "Read|Write|Edit|Glob|Grep",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/epistemic-file-guard.sh"
      }]
    }]
  }
}
```

### Cursor

Add to Cursor settings (Settings > Agent > Hooks):

```json
{
  "preToolUse": {
    "command": "~/.cursor/hooks/epistemic-guard.sh"
  }
}
```

### GitHub Copilot CLI

Add to `~/.config/gh-copilot/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [{
      "type": "command",
      "bash": "~/.config/gh-copilot/hooks/epistemic-guard.sh"
    }]
  }
}
```

---

## Architecture

```
~/.epistemic/
├── core/
│   └── epistemic-core.sh      # Shared detection logic
├── adapters/
│   ├── claude-code.sh         # Claude Code format translator
│   ├── cursor.sh              # Cursor format translator
│   └── github-copilot.sh      # Copilot format translator
├── scripts/
│   ├── memory-status.sh
│   ├── memory-on.sh
│   └── memory-off.sh
├── config.json                 # Sensitive project definitions
└── .memory-status              # Current memory state
```

---

## Why This Matters

### Trade Secret Protection

Under U.S. trade secret law (Defend Trade Secrets Act of 2016, 18 U.S.C. § 1839), information loses protection if the owner fails to take "reasonable measures" to maintain secrecy. Allowing AI memory to retain proprietary information may constitute inadequate protection.

### IP Before Publication

Pre-patent and pre-publication research requires strict confidentiality. Epistemic access control ensures AI assistants cannot inadvertently store or cross-reference sensitive work.

### Client Confidentiality

Professional service providers handling client data can use this system to ensure AI assistants don't retain client information beyond the session.

---

## Integration with Knowledge Tier Framework

This package works seamlessly with [Knowledge Tier Framework for AI Agents](https://github.com/theios-research-institute/knowledge-tier-framework-for-ai-agents), which provides a complete four-tier classification system:

| Tier | Name | Memory | Use Case |
|------|------|--------|----------|
| 1 | Restricted | OFF | Proprietary research, trade secrets |
| 2 | Confidential | Enabled | Competitive advantage projects |
| 3 | Internal | Enabled | Client work, business operations |
| 4 | Public | Enabled | Open source, public documentation |

---

## Why Universal?

Different AI coding assistants use different hook formats:

| Platform | Tool Name Field | Decision Field | Block Mechanism |
|----------|----------------|----------------|-----------------|
| Claude Code | `tool_name` | `permissionDecision` | JSON response |
| Cursor | `tool_name` | `decision` | Exit code 2 |
| Copilot | `toolName` | `permissionDecision` | JSON response |

This framework abstracts these differences, providing:
- **One configuration** for all platforms
- **Consistent behavior** across tools
- **Easy maintenance** - update core logic once

---

## Testing

Run the test suite:

```bash
./test/run-tests.sh
```

---

## Troubleshooting

### "Command not found" after installation

```bash
# Reload your shell configuration
source ~/.zshrc  # or ~/.bashrc
```

### Memory status not updating

The local status tracker and your AI assistant's settings must match:

1. Run `epistemic-memory-off` or `epistemic-memory-on` to update local status
2. Also toggle the setting in your AI assistant's web interface
3. Restart your AI coding session

### Hooks not firing

1. Verify hooks are configured in your AI assistant's settings file
2. Check hook scripts are executable: `chmod +x ~/.epistemic/**/*.sh`
3. Check platform-specific hook directories have the correct scripts

### Still blocked after disabling memory

1. Verify with `epistemic-memory-status` (should show "DISABLED" or "OFF")
2. Check for `.epistemic-tier` file in project or parent directories
3. Review `~/.epistemic/config.json` for path/keyword matches

### Permission denied errors

```bash
# Make all scripts executable
chmod +x ~/.epistemic/**/*.sh
```

---

## Contributing

We welcome contributions. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Citation

If you use Epistemic Guardrails in academic work, please cite:

```bibtex
@software{sargisian2026epistemicuniversal,
  author       = {Sargisian, Neil},
  title        = {Epistemic Guardrails for AI Agents},
  year         = {2026},
  publisher    = {Theios Research Institute, Inc.},
  url          = {https://github.com/theios-research-institute/epistemic-guardrails-for-ai-agents},
  note         = {A framework for controlling AI agent access to sensitive knowledge}
}
```

---

## Transparency

This work is conducted by Theios Research Institute, Inc., a nonprofit research and education organization. The project is currently authored by a single investigator and is released openly to invite external scrutiny, replication, and critique.

An AI coding assistant was used to assist with implementation of memory partitioning and security logic under human-specified constraints. All architectural decisions, threat models, and epistemic guardrails were designed and validated by the author.

---

## Related Projects

- [Knowledge Tier Framework for AI Agents](https://github.com/theios-research-institute/knowledge-tier-framework-for-ai-agents) - Four-tier classification system for AI agent knowledge access

---

## Contact

For academic or research inquiries:

**Neil Sargisian** — [research@theios.org](mailto:research@theios.org)
Theios Research Institute, Inc. — [https://theios.org](https://theios.org)

---

## Funding

- Theios Research Institute, Inc.
- Ecom Economics, LLC

---

## Acknowledgments

This work was inspired by and builds upon:

- **Anthropic's Claude Code** and their engineering blog posts on [sandboxing](https://www.anthropic.com/engineering/claude-code-sandboxing) and [best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- **NIST Special Publication 800-53** and industry data classification standards that informed the tiered access model
- **Related open source projects** in the Claude Code hooks ecosystem:
  - [claude-code-permissions-hook](https://github.com/kornysietsma/claude-code-permissions-hook) - Granular permission controls
  - [claude-code-safety-net](https://github.com/kenryu42/claude-code-safety-net) - Destructive command protection
  - [claude-code-hooks](https://github.com/karanb192/claude-code-hooks) - Hook collection including secret protection
- The broader research community working on information security and data governance

---

## About Theios Research Institute, Inc.

Theios (θεῖος) Research Institute, Inc. is a 501(c)(3) nonprofit organization dedicated to applied discovery science and structural laws of emergence, developing systems that rigorously stress-test ideas through knowledge-system engineering and epistemic framework development. Learn more at [theios.org](https://theios.org).

**Support our work:** [theios.org/donate](https://theios.org/donate) (tax-deductible)

---

*Epistemic Guardrails for AI Agents v1.0.0 — Theios Research Institute, Inc.*
