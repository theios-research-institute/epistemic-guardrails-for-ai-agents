# Changelog

All notable changes to Epistemic Guardrails for AI Agents will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-27

### Added
- Outbound action protection via `ALLOWED_REMOTES` in `.epistemic-tier`
- `epistemic_check_outbound()` core function — checks outbound commands against allowed destinations
- `epistemic_resolve_git_remote()` helper — resolves git remote names to URLs
- `epistemic_match_remote()` helper — pattern matching with exact and wildcard support
- `epistemic_get_allowed_remotes()` helper — reads ALLOWED_REMOTES from nearest `.epistemic-tier`
- Bash tool interception in Claude Code, Cursor, and GitHub Copilot adapters
- Detection for: `git push`, `git remote add/set-url`, `gh repo create`, `npm publish`, `cargo publish`, `pip/twine upload`, `rsync`, `scp`, `aws s3 cp/sync`
- `epistemic_normalize_git_url()` helper — normalizes SSH, HTTPS, `ssh://`, and `git://` URLs to `host/path` form
- Outbound action test suite (14 new tests including SSH, git://, Bitbucket, self-hosted, and set-url --push)

### Fixed
- `git remote set-url --push` no longer misidentifies the `--push` flag as the remote name
- `rsync`/`scp` destination extraction now finds the remote argument (containing `:`) instead of always using the last token
- `cargo publish --registry <name>` now extracts the named registry for matching
- `twine upload --repository <name>` now extracts the named repository; `--repository-url` takes priority when both are present
- `npm publish --registry` flag extraction uses POSIX character classes for cross-platform compatibility

## [1.0.0] - 2026-02-05

### Added
- Initial release
- Cross-platform core library (`epistemic-core.sh`)
- Platform adapters for Claude Code, Cursor, and GitHub Copilot CLI
- Unified memory status tracking
- Auto-detection of installed AI coding assistants
- Per-project `.epistemic-tier` configuration support
- Global configuration via `~/.epistemic/config.json`
- Word-boundary keyword matching for sensitive path detection
- Fail-closed security design

---

*Epistemic Guardrails for AI Agents — Theios Research Institute, Inc.*
