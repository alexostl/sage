# Codex Port Upstream PR TODO

This checklist tracks remaining cleanup before opening a PR from `codex-port`
to upstream.

## Required Before PR

- Remove the old git-hook close-out model from `self-host/main`:
  `.githooks/pre-commit`, `bin/sage-close`, `bin/sage-install-hooks`,
  `sage install-hooks`, and README references. The current Codex port uses
  Codex hooks (`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`) instead.
- Add CI for the Codex port Bats suites:
  `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`.
- Run one real Codex smoke/harness pass before marking the upstream PR ready:
  `runtime/platforms/codex/harness/run-harness.sh`.

## Optional Later

- Reintroduce git pre-commit ergonomics only as a new design, without the old
  `sage-close` / `verification_check.py` dependency.
