---
title: Verification for Codex Enforcement Gate Revision
status: completed
phase: verification
type: verification
parent_initiative: 20260423-codex-enforcement-gap-fix
date: 2026-04-24
---

# Verification — 20260424 Codex Enforcement Gate Revision

Evidence for the Critical + Major + addressed-Minor findings raised by
`/sage:review` on the 20260423 delivery. Closes Rule 5 compliance.

## 1. Smoke scenarios for `pre-prompt.sh`

13 scenarios exercised against the rewritten hook. Each row below is
real hook output captured to `/tmp/smoke-output.txt`.

```
### S1: completed-only initiative + 'build a new widget' (expect BLOCK)
{"decision": "block", "reason": "Sage build gate: `.sage/work/<new-initiative>/spec.md`, `.sage/work/<new-initiative>/plan.md` missing.", "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "Sage workflow gate — build.\n\nThe request above matches the Sage build workflow. Required artifact(s) not found on disk: `.sage/work/<new-initiative>/spec.md`, `.sage/work/<new-initiative>/plan.md`.\n\nBefore responding to the prompt above:\n1. Announce `Sage → build workflow.` in your reply.\n2. Read .sage/decisions.md (last 5 entries) and scan .sage/work/*/ frontmatter for active initiatives.\n3. Call sage_memory_search with domain keywords (limit 5), then again with filter_tags [\"self-learning\"] (limit 5). Parameter types: limit is an integer, filter_tags is an array.\n4. Write the missing artifact(s) to .sage/work/<initiative>/ and present them to the user with [A] Approve / [R] Revise — wait for approval before any code edit.\n\nBuild work requires an active initiative (status: draft / in-progress / under-review) with spec.md and plan.md on disk. No active initiative found.\n\nDo not start implementation in this turn."}}

### S2: active initiative with spec+plan + 'build a new widget' (expect PASS, no output)
(blank = PASS)

### S3: 'fix the typo in README' (expect Tier1 fix passthrough)
{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "Sage note — fix: Tier 1 fix detected (typo / indent / log / rename / import / lint). Proceeding surgically per fix.workflow.md. If the work turns out to touch 3+ files or change behavior broadly, stop and escalate to $fix for a root-cause + scope checkpoint."}}

### S4: 'fix the auth bug' (expect BLOCK)
{"decision": "block", "reason": "Sage fix gate: root cause must be approved before edits.", "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "Sage workflow gate — fix.\n\n…"}}

### S5: '$status debug the build' (expect PASS)
(blank = PASS)

### S6: '/design-review the homepage' (expect PASS)
(blank = PASS)

### S7: 'add tests for the utils module' (expect Tier1 build passthrough)
{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "Sage note — build: Tier 1 build detected (tests / logging / comments / docstrings / type hints / fixtures / mocks). Proceeding surgically. If this turns into a new feature or spans 3+ files with behavior change, stop and escalate to $build for spec + plan."}}

### S8: empty .sage + 'build a new api' (expect BLOCK)
{"decision": "block", ...}

### S9: 'the broken image on landing page needs fixing' (expect BLOCK — broken matches FIX_RE)
{"decision": "block", ...}

### S10: 'fix the lint errors' (expect Tier1 fix passthrough)
{"hookSpecificOutput": {..., "additionalContext": "Sage note — fix: Tier 1 fix detected ..."}}

### S11: 'what is this codebase?' (expect PASS)
(blank = PASS)

### S12: 'ship a beta version' (expect PASS — beta not in nouns)
(blank = PASS)

### S13: 'please implement the payments endpoint' (expect BLOCK)
{"decision": "block", ...}
```

**Outcome:** all 13 scenarios produce the expected decision. Full
verbatim output preserved in `/tmp/smoke-output.txt` during development.

## 2. Regression harness — `rg` dependency removed

```
$ bash runtime/platforms/codex/tests/run-regression.sh
== sage init --platform codex ==
== prepare merge fixture ==
== project-local sage update ==
== summary ==
PASS: Codex adapter regression checks
  Project fixture: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.QwP1yZ/project
  Logs: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.QwP1yZ/logs
EXIT=0
```

`assert_contains` now uses `grep -Fq` (POSIX). Harness passes on a
machine without ripgrep. Closes Major #4.

## 3. AGENTS.md size budget (escape-hatch sanity)

Generated AGENTS.md on the regression fixture:

```
$ wc -c .tmp/codex-adapter-regression.QwP1yZ/project/AGENTS.md
   12397 .tmp/codex-adapter-regression.QwP1yZ/project/AGENTS.md
```

12 397 bytes ≪ Codex's 32 KiB (32 768) cap — ~38% utilization. Split
path documented in HOOKS.md "Future considerations" once the file
approaches ~20 KiB.

## 4. Workflow PREAMBLE coverage

```
$ ls .tmp/codex-adapter-regression.QwP1yZ/project/.agents/skills/*/SKILL.md | wc -l
      51
$ grep -l "RULES (apply to every step" .tmp/codex-adapter-regression.QwP1yZ/project/.agents/skills/*/SKILL.md | wc -l
      16
```

All 15 workflow skills from the command table (build, fix, architect,
research, design, analyze, reflect, continue, qa, map, autoresearch,
design-review, status, review, learn) plus the wrapper `/sage` skill
receive the non-negotiable RULES preamble injection at generation time.

## 5. Review findings closed

| Finding | Severity | Status | Evidence |
|---------|----------|--------|----------|
| #1 Global-scope build gate (any initiative satisfies) | CRITICAL | Closed | S1 blocks when only completed initiatives exist; S2 passes when an active one has spec+plan |
| #2 Fix gate over-blocks Tier 1 | MAJOR | Closed | S3 / S10 (typo, lint) pass with soft hint; S4 still blocks real bugs |
| #3 Missing verification.md for 20260423 | MAJOR | Closed | Both verification.md files written (this file + 20260423 retroactive) |
| #4 `rg` dependency in regression | MAJOR | Closed | `grep -Fq` swap, regression passes |
| #5 Incomplete `$skill` whitelist | MAJOR | Closed | `^\s*[$/][a-z][a-z0-9-]*` pattern — S5 / S6 pass for every current and future skill |
| #7 PEP 585 annotations | MINOR | Closed | Annotations removed (private helpers) |
| #11 BUILD_RE too eager | MINOR | Closed | Verb + noun-whitelist gate; S12 "ship a beta" passes, S13 "implement the payments endpoint" blocks |

## 6. Self-learning captured

The `{N,M}` regex quantifier gets mangled by bash brace expansion
even inside `python3 -c "$(cat <<'PY' ... PY)"` — the comma inside
`{0,60}` is rewritten by the shell before Python ever sees the string.
Mitigation: use `*?` or pre-expand the range. Will be stored via
`sage_memory_store` with `self-learning` + `gotcha` tags at
workflow-close per Rule 6.
