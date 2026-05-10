---
title: Verification for Codex Enforcement Gap Fix (retroactive)
status: completed
phase: verification
type: verification
date: 2026-04-24
note: Retroactive completion — written during the 20260424 revision cycle to close MAJOR #3 from /sage:review.
---

# Verification — 20260423 Codex Enforcement Gap Fix (retroactive)

This file was missing at the original completion checkpoint. It is
written now (during the 20260424 revision cycle) with the same
evidence the revision cycle captured, plus what was verified in the
original session. Closes Major #3 from `/sage:review`.

## 1. Hook files exist and are executable in the starter pack

```
$ ls -l runtime/platforms/codex/hooks/*.sh
-rwxr-xr-x  pre-prompt.sh
-rwxr-xr-x  post-bash.sh
-rwxr-xr-x  pre-bash.sh
-rwxr-xr-x  session-start.sh
```

`hooks.example.json` wires all four into the proper Codex event slots
(`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `SessionStart`).

## 2. AGENTS.md generation picks up workflow PREAMBLEs

After the 20260423 commit, 15 workflow skills + the `/sage` wrapper
carry a `RULES (apply to every step — non-negotiable):` block.
Current regression-fixture count:

```
$ ls .tmp/codex-adapter-regression.*/project/.agents/skills/*/SKILL.md | wc -l
      51
$ grep -l "RULES (apply to every step" .tmp/codex-adapter-regression.*/project/.agents/skills/*/SKILL.md | wc -l
      16
```

## 3. AGENTS.md size

```
$ wc -c .tmp/codex-adapter-regression.*/project/AGENTS.md
   12397
```

Well under the 32 KiB Codex cap. Escape hatch documented in HOOKS.md
for the future.

## 4. Regression harness passes

```
$ bash runtime/platforms/codex/tests/run-regression.sh
PASS: Codex adapter regression checks
```

(Post-revision, this also no longer depends on ripgrep — see the
20260424 verification.)

## 5. Known gaps closed by the 20260424 revision cycle

- Build gate was global (any initiative satisfied). Fixed: only
  initiatives with non-terminal frontmatter `status` count.
- Fix gate over-blocked Tier 1 maintenance. Fixed: `TIER1_FIX_RE`
  passthrough plus soft nudge.
- `$skill` / `/skill` whitelist was hard-coded. Fixed: pattern
  `^\s*[$/][a-z][a-z0-9-]*`.
- `pre-prompt.sh` smoke scenarios not persisted. Fixed: 13 scenarios
  captured in the 20260424 verification.md.
- Regression depended on `rg`. Fixed: `grep -Fq` swap.

See `../20260424-codex-enforcement-gate-revision/verification.md` for
the full evidence trail behind those closures.
