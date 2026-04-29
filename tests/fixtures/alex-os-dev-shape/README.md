# Fixture: alex-os-dev-shape

Reproduces the contract mismatch documented in
`.sage/work/20260428-codex-enforcement-activation-brief/brief.md` —
a pre-cycle Codex project where:

- `[features].codex_hooks = true` declared in `.codex/config.toml`,
- but `.codex/hooks.json` contains only a custom user `SessionStart`
  entry — framework hooks were never wired (L4 DORMANT),
- `core.hooksPath = .git/hooks` (custom, not `.githooks`) — Sage L5
  pre-commit gate cannot fire (L5 DORMANT),
- 3 direct skille (`simplify`, `specify`, `evaluate`) installed
  bez `agents/openai.yaml` — per ADR-4 v3 should auto-suggest, but
  enforcement of `policy.allow_implicit_invocation: false` is missing
  (M3 task).
- 1 workflow skill (`sage`) jako baseline — workflow skille NIE
  dostają yaml, retain full reactive routing.

## Layout

```
.codex/
  config.toml                    # codex_hooks = true (declared)
  hooks.json                     # custom SessionStart only — no framework hooks
  hooks/                         # empty (M1 will populate)
.git/
  config                         # core.hooksPath = .git/hooks (custom)
  hooks/
    pre-commit                   # custom user script (NOT sage)
sage/
  skills/
    simplify/SKILL.md            # direct, no openai.yaml (pre-cycle)
    specify/SKILL.md             # direct, no openai.yaml
    evaluate/SKILL.md            # direct, no openai.yaml
    sage/SKILL.md                # workflow, no yaml expected
```

## Expected post-cycle state

After all of M1+M2+M3 ship and `sage update` runs in this fixture:

- L1 + L2 + L4 = ACTIVE.
- L5 = DORMANT (custom path), with hint pointing to
  `sage init --force-githooks` to override.
- `agents/openai.yaml` exists for `simplify`, `specify`, `evaluate`;
  not for `sage`.
- `.codex/hooks/*.sh` populated; `.codex/hooks.json` merged with
  framework `SessionStart` entries appended (custom user entry preserved).

## Usage

This fixture is read-only. Tests copy it to a `mktemp -d` worktree
before mutating, so the same fixture can be reused across test cases
without state leaking between runs.
