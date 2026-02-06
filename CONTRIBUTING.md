# Contributing to Epistemic Guardrails for AI Agents

Thank you for your interest in contributing to Epistemic Guardrails for AI Agents! This project is maintained by Theios Research Institute, Inc. and we welcome contributions from the community.

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Check existing issues before creating a new one
- Include your operating system, shell (bash/zsh), and which AI assistant you're using (Claude Code, Cursor, GitHub Copilot, etc.)
- Provide steps to reproduce any bugs

### Suggesting Enhancements

We're particularly interested in:

- Support for additional AI coding assistants (Windsurf, Cody, etc.)
- New platform adapters
- Integration with other security frameworks
- Improvements to the core detection logic
- Documentation improvements
- Cross-platform compatibility (Windows support)

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Test thoroughly on your system
5. Commit with clear messages (`git commit -m "Add: description of change"`)
6. Push to your fork (`git push origin feature/your-feature`)
7. Open a Pull Request

### Code Style

- Shell scripts require **bash** (use `#!/bin/bash` shebang)
- Bash-specific features like `[[ ]]` and `=~` are acceptable
- Use clear variable names
- Include comments for complex logic
- Follow existing formatting patterns

### Testing

Before submitting:

- Test on macOS and/or Linux
- Test with both bash and zsh
- Verify the install script works on a clean system
- Test all memory status transitions (on/off)
- Verify hooks fire correctly on supported platforms (Claude Code, Cursor, GitHub Copilot)
- Test any new adapters against their target platform's hook format

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## Questions?

For questions about contributing, reach out to:

**Neil Sargisian** — [research@theios.org](mailto:research@theios.org)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

*Thank you for contributing to Epistemic Guardrails for AI Agents!*
