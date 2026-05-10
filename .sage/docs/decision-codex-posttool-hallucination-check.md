---
title: "ADR — Codex post-write hallucination check"
status: proposed
date: 2026-04-30
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/review-2026-04-30/synthesis.md (CRIT-2 Option C)
  - .sage/docs/decision-codex-mcp-stack.md (ADR-3 — adds new MCP tool)
  - .sage/docs/decision-codex-stop-hook-scope.md (ADR-7 — incident log consumer)
  - .sage/docs/decision-codex-validate-mutation-predicate.md (ADR-1 — pairs Pre + Post)
---

# ADR — Codex post-write hallucination check

## Context

After `apply_patch` mutates a file, there is a window where the agent
may have **lied** about what it just did. Three categories of lie are
common in agent output:

1. **Diff-claim mismatch** — agent writes "I changed `parse_config` in
   `config.py`" but `git diff` shows a different file or no change.
2. **Imagined symbols** — agent inserts `from utils import format_date`
   but `utils.py` has no `format_date`. The code won't compile, but the
   hallucination passed the agent's own self-check.
3. **Broken `.sage/` frontmatter** — agent edits `.sage/work/.../spec.md`
   and accidentally breaks YAML frontmatter (bad indent, missing quote,
   duplicate key). ADR-1 validator depends on that frontmatter for
   workflow state — if it doesn't parse, the next mutation is blocked
   not because of policy, but because of corruption.

The Claude port has a hallucination-check capability for this. The
Codex rewrite needs the equivalent surface.

**CRIT-2 closure (Option C, 2026-04-30):** port the hallucination
check; explicitly **exclude** the visual-gate variant (Codex CLI has
no UI affordance to gate against). This ADR is for the
hallucination-check only.

## Cross-port truth

Claude port has `PostToolUse` hooks running hallucination checks
(diff-claim mismatch only). Antigravity has nothing equivalent.
Generic ports rely on agent self-report. **Codex is the second Sage
port to implement post-write verification**; we copy what Claude
proved works (diff-claim) and add frontmatter validation (cheap, Sage-
specific, no Claude analog needed because Claude port doesn't gate
on `.sage/` state the same way).

## Decision

A new hook `runtime/platforms/codex/hooks/post-tool-check.sh` runs on
`PostToolUse` matched to `apply_patch`. It performs **two checks** in
v1 (Sprawdzenie A and Sprawdzenie C from the design discussion). The
third candidate (Sprawdzenie B — symbol existence) is **deferred to
v2** with an explicit upgrade path.

### Check A — Diff vs claim consistency (stateless)

Mechanism:
1. Read `apply_patch` arguments from PostToolUse payload — extract the
   list of file paths the patch claimed to touch.
2. Run `git diff --name-only HEAD -- <claimed_paths>` to get the
   actual list of files modified relative to HEAD.
3. Compare the two sets:
   - **Files claimed but not modified** → incident `claim_no_op`.
   - **Files modified but not claimed** → incident `unclaimed_change`
     (less common but possible if patch syntax is malformed).
4. v1 does **not** compare hunk content (line-level claims like "I
   changed function `foo`"). That is a v2 candidate; it requires
   either an LLM call or a parser per language. v1 settles for
   file-level granularity.

Stateless: no Pre/Post coupling, no new agent contract, no extra
fields in hook payloads. Codex gives us the patch; git gives us the
diff; we diff the lists.

### Check C — `.sage/` frontmatter health

Mechanism:
1. Filter the modified-file list to entries under `.sage/` ending in
   `.md` (frontmatter is only meaningful for those).
2. For each, read the file head, extract the frontmatter block
   (between leading `---` and the next `---`).
3. Try `yaml.safe_load`. On parse error → incident
   `broken_frontmatter` with the file path and parser error message.

This is Sage-internal hygiene, not a generic code check. It exists
because ADR-1 validator reads frontmatter as workflow state — broken
YAML there is a higher-impact failure than broken YAML in any other
file.

### Check B — Symbol existence (DEFERRED to v2)

The third candidate ("imagined import / imagined function call") was
considered and **deferred**. Rationale:

- **Cost in v1:** requires a parser per language. `ast.parse` covers
  Python; JS/TS needs `tree-sitter`. Each parser adds dependency
  surface, edge cases (syntax errors in mid-edit state), and tests.
- **Coverage in v1 without B:** Check A catches "agent claimed file X
  but didn't touch it" (the highest-rate hallucination per Claude port
  outcome data). Check C catches Sage-state corruption. The remaining
  uncovered class is "agent touched file X correctly but referenced
  a symbol that doesn't exist". That class is real but smaller, and
  caught downstream by language-native tools (linter, type-checker)
  if the project runs them.
- **v2 trigger:** outcome harness counts incidents where a session
  produced a commit that fails CI on import/symbol error within N
  turns of the mutation. If rate exceeds threshold, v2 adds Check B
  starting with Python (`ast.parse`), JS/TS in v3.

The deferral is documented here, not silently dropped — when v2
arrives, this ADR's "Decision" section gets a sub-section
"### Check B — Symbol existence (added v2)" rather than a new ADR.

### Severity model — always warn-only (consistent with ADR-7)

All incidents from this hook are **warn-only**. Hook always exits 0.
No `exit 2` (no stderr injection, no `decision: "block"` continuation).

This is locked-in alignment with ADR-7 D5 v1 invariant ("NEVER hard-
block") and the Codex Stop hook output semantics callout (ADR-7 D4-
bis). Two reasons to stay warn-only here:

1. **The mutation already happened.** PostToolUse fires after
   `apply_patch` succeeded. Blocking the next turn does not undo the
   mutation; it just creates friction for the agent which has no path
   to "fix" the issue (the lie is already on disk).
2. **False-positive blast radius.** Check A's "files claimed but not
   modified" can fire legitimately if a patch contained a no-op (e.g.
   identical content). Blocking on a noisy signal damages trust in v1
   before we have data on signal quality.

`sage doctor` surfaces the incident log on next run; the user decides
whether to act on it.

### MCP integration

A new MCP tool `sage_check_post_mutation` is added to the Sage MCP
server (per ADR-3). It is the engine; the hook is a thin shim that:

1. Reads PostToolUse payload from STDIN.
2. Calls `sage_check_post_mutation` with `{patch_args, modified_files}`.
3. On MCP success: writes returned incidents (if any) to
   `.sage/.mcp-incidents.log` with `severity: warn`.
4. On MCP unreachable: same fallback path as ADR-3 D6 — append a
   single `dead_validator_post` incident directly to the log via
   plain `echo >>` (no MCP dependency on the writer side), exit 0.

The MCP tool itself does the work (Check A diff, Check C YAML parse).
This keeps platform-specific logic out of shell and makes the same
checks reusable from `sage doctor` (which can run them retroactively
on a worktree).

ADR-3's `enabled_tools` list gains `sage_check_post_mutation` —
explicit opt-in pattern stays consistent.

### Hook registration

In `.codex/hooks.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": ".codex/hooks/post-tool-check.sh" }
        ]
      }
    ]
  }
}
```

Multi-hook ordering: per ADR-1 amendment 2026-04-30, all entries fire
in non-deterministic order (PASS_ALL_FIRE_UNORDERED). This hook is
order-independent by construction (reads disk state, writes append-
only log).

## What this ADR does NOT do (explicit non-goals)

- **No visual-gate.** Excluded per CRIT-2 Option C decision. Codex CLI
  has no UI surface to verify against.
- **No symbol existence check.** Deferred to v2 (Check B above).
- **No line-level diff-claim parsing.** Check A is file-level only.
- **No hard-block on incidents.** v1 invariant.
- **No coupling to PreToolUse via shared payload fields.** Stateless;
  PostToolUse stands alone, reads its own payload + git.

## Failure modes

- **Patch hunks claim files outside cwd / in submodules:** treat as
  "out of scope", do not incident. Log to `.sage/.skipped-checks.log`
  (informational).
- **`git diff` runs against an unborn HEAD (brand-new repo, first
  commit):** Check A degrades — there is no HEAD baseline. Skip
  Check A for that turn, still run Check C. Log `no_head_baseline`
  once per session.
- **Frontmatter file is binary or non-UTF-8:** treat as "not a
  markdown frontmatter target", skip silently.
- **MCP tool returns slow / times out:** PostToolUse waits for return
  before exiting. Codex defaults give MCP tool calls a multi-second
  timeout; `sage_check_post_mutation` is bounded (Check A is one
  `git diff`, Check C is N small YAML parses) — empirical budget < 1s
  for typical patches. If observed timeouts in outcome harness, add
  hook-side `timeout` wrapper as a v1.1 amendment.
- **Race with Stop hook reading `.mcp-incidents.log`:** both writers
  use append-only with line-based JSON. ADR-7 already accounts for
  this in C6/C7 — no special handling needed here.

## Empirical anchor — needed before cutover

This ADR has **no PoC anchor yet**. Required PoC before v1:

1. **PoC C2 — PostToolUse fires after `apply_patch`.** Confirm Codex
   0.126 fires the event with a payload that includes the patch args
   we need to extract (or at minimum the file list). If payload is
   thin, fall back to "compare against last commit's diff" (more
   complex; preferable to confirm payload first).
2. **PoC C3 — Hook timing.** Measure latency `apply_patch return →
   PostToolUse fire` to confirm there is no race with the agent
   reading the patched file.

Both flagged as pre-cutover gates in spec.md (along with existing
CC-2/Claim-D follow-ups).

## Status: proposed

Awaiting user approval at design checkpoint along with spec.md.
