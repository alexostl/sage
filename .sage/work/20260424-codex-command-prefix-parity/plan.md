---
title: "Fix Plan for Codex Command Prefix Parity"
status: "completed"
phase: "fix-plan"
created: "2026-04-24"
updated: "2026-04-24"
---

# Fix Plan: Codex Command Prefix Parity

**Mode:** fix
**Status:** completed
**Started:** 2026-04-24
**Last updated:** 2026-04-24

## Root Cause

Both `sage-codex` and `alex-os-dev` are configured with `command_prefix: true`,
and both Claude surfaces honor that setting. The Codex adapter does not: its
generator never reads or applies `command_prefix`, so it emits unprefixed Codex
guidance, unprefixed `.agents/skills/<name>/` directories, unprefixed skill
frontmatter names, and unprefixed in-skill workflow references.

Claude is the source of truth for porting conventions. For this fix that means:
- `sage` stays unprefixed
- native Codex `/review` stays native
- the remaining Sage workflow/direct-skill references follow Claude's
  `sage:` convention when `command_prefix: true`

## Files To Change

- `runtime/platforms/codex/setup/generate-codex.sh`
  Read `command_prefix` from `.sage/config.yaml`; add a clear prefix matrix;
  apply prefixing to generated Codex skill directories, `name:` frontmatter,
  AGENTS guidance, and in-skill workflow references with token-aware rewrites;
  keep `sage` unprefixed, keep native `/review` untouched, preserve
  `workflow wins namespace`, and do not expose `sage-navigator` as a new
  public prefixed command surface.
- `runtime/platforms/codex/tests/run-regression.sh`
  Extend regression coverage to automate `command_prefix: false`,
  `command_prefix: true`, and missing-`command_prefix` scenarios; add positive
  and negative assertions for prefixed Codex output without prose corruption.

## Tests

- Run `runtime/platforms/codex/tests/run-regression.sh`.
- In the regression harness, verify default / false behavior keeps:
  - unprefixed `.agents/skills/build/`
  - `name: build`
  - unprefixed Codex guidance
- In the prefixed path, verify:
  - `.agents/skills/sage:build/`
  - `name: sage:build`
  - prefixed Codex guidance such as `$sage:build`
  - no accidental `sage:sage`
  - native `/review` remains `/review`
  - no prose corruption such as `understand/sage:research`
- Verify an update path where the `command_prefix` line is removed from
  `.sage/config.yaml` still regenerates unprefixed Codex output.

## Risks

- Partial prefixing could leave directories correct but guidance text or
  in-skill references inconsistent.
- Naive substring replacement could corrupt prose or rewrite native `/review`.
- The `sage` special case could be broken if Codex diverges from Claude's
  routing convention.
- Direct-skill regression checks can no longer rely on byte-for-byte equality
  once prefixed frontmatter intentionally differs.

## Rollback

Revert the Codex generator prefix-plumbing changes and the new regression
coverage if the resulting Codex output diverges from Claude's convention or
breaks a real workflow.
