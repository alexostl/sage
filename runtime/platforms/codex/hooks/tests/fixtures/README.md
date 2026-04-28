# Sage hook test fixtures

Generated trees consumed by the test suites under
`runtime/platforms/codex/hooks/tests/`. Build with:

    bash runtime/platforms/codex/hooks/tests/fixtures/build_fixtures.sh

All output lands in `runtime/platforms/codex/hooks/tests/tmp/` which is
gitignored (see `tests/.gitignore`). The builder is idempotent —
re-run wipes and rebuilds, leaving the working tree clean.

## Test runner

Tests are written for **`python3 -m unittest discover`** — no third-party
dependency required, works on any modern Python 3. Pytest is optional;
the same tests pass under `pytest` if installed.

Run from repo root:

    cd runtime/platforms/codex/hooks
    python3 -m unittest discover -s tests -p 'test_*.py' -v

Bash test scripts (`tests/test_*.sh`) are invoked directly:

    bash runtime/platforms/codex/hooks/tests/test_pre_prompt_sticky.sh

## Fixtures and their consumers

| Fixture | Consumer task | Purpose |
|---|---|---|
| `sage_no_active/` | T4 sticky context | "no active initiative" path |
| `sage_brief_only/` | T4 sticky context | phase = brief |
| `sage_spec_only/` | T4 sticky context | phase = spec |
| `sage_plan_only/` | T4 sticky context | phase precedence (plan > spec) |
| `sage_verification_pending/` | T4 + T5 | "ready to close" sticky line |
| `sage_multi_active/` | T4 tie-breaker | 3 active inits, init-c wins by mtime |
| `sage_lightweight/` | T6 | scope: lightweight → ungated |
| `verifications/valid.md` | T2 | happy-path validator returns (True, []) |
| `verifications/missing_*.md` | T2 | each required heading missing case |
| `verifications/no_frontmatter.md` | T2 | no frontmatter |
| `verifications/empty_test_block.md` | T2 | fenced block with only command line |
| `verifications/no_fenced_block.md` | T2 | test section has no fenced block |
| `verifications/wrong_order.md` | T2 | headings present but out of order |
| `verifications/valid_closed.md` | T5 | `closed: true` for idempotence |
| `git_repo/` | T5 + T6 | throwaway repo with `self-host/main` + `codex-port` |

## Conventions

- Fixture names are `snake_case`. Directory names under each fixture
  match the layout the consumer expects (`.sage/`, `.git/`, etc.).
- Frontmatter in fixture artifacts is intentionally minimal — only the
  fields that the validator or hook actually reads.
- The git fixture initial branch is `self-host/main` (the project's
  inner-work branch per `.sage/work/20260423-branch-worktree-operating-model/`).
- The valid verification template shape mirrors what `T3` will publish at
  `.agents/skills/sage:build/templates/verification-template.md`.
