---
title: "Fix Plan: F-1 Phase 1 bugs (7 bugs — 6 Major + 1 Minor)"
status: completed
phase: completed
priority: high
created: 2026-04-30
updated: 2026-05-07
scope: moderate
files_changed: 6
tests_added: 11
---

## Reviewer notes (independent sub-agent, 2026-04-30)

Verdict: APPROVE_WITH_CHANGES — 8 plan edits applied below before implementation.
Diagnosis sound on all 4 bugs; fix shapes correct; concerns C1–C8 addressed in
revised plan content.

## Plan revision history (2026-04-30)

**1. Initial retraction of BUG-F1-2 (mid-day):** during a first `/sage:fix` pass,
BUG-F1-2 was retracted on the basis of a too-simple yq probe. Probe used
`# heading\nbody text` markdown body — yq parsed cleanly and exited 0. Plan
was reduced to 3 fixes / 3 files / 5 tests; implementation order set to 3→1→4.

**2. Retraction REVERSED (afternoon):** F-1 re-run T2 reproduced BUG-F1-2 on
the very first realistic markdown body the agent wrote. yq v4.53.2 actually
exits non-zero when the body contains bold-syntax mappings like
`**Artifacts:**\n- brief.md: exists` — even though stdout already holds the
correct frontmatter mapping, the post-`---` document trips yq's parser. The
`|| continue` in `active_init.sh` discards the cycle, and PreToolUse blocks
"no active cycle" identically to BUG-F1-1. Fix 2 IS real; retraction was
caused by an unrealistic probe.

**Effects on this plan:**

- Fix 2 (manifest_yaml helper) **restored** — implemented as `lib/active_init.sh`
  helper that extracts the frontmatter doc via awk before piping to yq. Both
  `active_init.sh` (status read) and `pre-tool-validate.sh` (scope read) route
  through it.
- Files changed: 3 → 4 (`active_init.sh` is touched again).
- Tests added: 5 → 7 (2 new `active_init.bats` cases — realistic-body fixture
  + flat-YAML regression).
- Implementation order (as actually executed): 2 → 3 → 1 → 4.
- Block-to-fix mapping updated below (3 blocks now map to 3 fixes — F1-1 covers
  block 1, F1-2 covers block 2 once realistic body lands, F1-3 covers block 3).
- Verification gate retains the manifest-format check as primary evidence that
  Fix 2 is durable across realistic bodies.

# Fix Plan: F-1 Phase 1 Bugs

**Cycle:** [.sage/work/20260430-f1-bugs-fix/](.sage/work/20260430-f1-bugs-fix/)
**Source:** [qa-report.md](.sage/work/20260429-codex-port-rewrite/qa-report.md)
**Scope:** **Moderate** (6 source files / workflow contract files; 12 bats test cases added)
**Mode:** TDD — failing bats test first per fix, then code change, then verify GREEN.

## Overall scope assessment

| Aspect | Detail |
|---|---|
| Source files | 6 — `lib/active_init.sh` (Fix 2), `pre-tool-validate.sh` (Fix 1 + Fix 2 read + Fix 3 + Fix 5), `lib/bootstrap_check.sh` NEW (Fix 1 helper), setup pipeline (Fix 4), `core/workflows/build.workflow.md` (Fix 6), `runtime/platforms/codex/setup/lib/skills-deploy.sh` (Fix 7) |
| Test files | 3 — `pre-tool-validate.bats`, `active_init.bats`, `stage9-bootstrap.bats` |
| New test cases | 7 (4 for Fix 1, 2 for Fix 2, 1 for Fix 3, 3 for Fix 4 — counted across files) |
| Interface changes | None — all internal hook predicate / setup logic |
| New abstractions | One small lib helper (`bootstrap_check.sh`) to keep `pre-tool-validate.sh` ≤ 85 LOC |
| Architectural | None |

**Why Moderate, not Surgical:** the full F-1 cycle spans hook predicate, setup
pipeline, and workflow-contract fixes, crossing the 2-file Surgical ceiling.
Each individual bug is itself Surgical and the fixes don't entangle.

## Bug-by-bug fix plan

### Fix 1 — BUG-F1-1: PreToolUse bootstrap chicken-egg

**Root cause** (from QA report):
[pre-tool-validate.sh:43-48](runtime/platforms/codex/hooks/pre-tool-validate.sh:43)
returns `exit 2` when `active_init_path` returns empty. But the agent's first
`apply_patch` on a fresh cycle CREATES the manifest — chicken-egg.

**Change:** in [pre-tool-validate.sh](runtime/platforms/codex/hooks/pre-tool-validate.sh),
when `cycle_dir` is empty, before rejecting, check the **bootstrap exception**:

- All `claimed_paths` confined to a SINGLE new `.sage/work/<id>/` directory + (optionally) `.sage/decisions.md`
- `<id>` matches `YYYYMMDD-<slug>` shape (regex `^[0-9]{8}-[a-z0-9-]+$`)
- The cycle dir does NOT yet exist on disk (otherwise it should have a manifest already)
- At least one of the claimed paths is `manifest.md` in that dir (the agent IS creating the cycle)

If bootstrap exception holds → allow, log to session-mutations with `kind: bootstrap`.
If not → existing rejection.

**Tests** ([pre-tool-validate.bats](runtime/platforms/codex/hooks/tests/pre-tool-validate.bats)):
- ✅ NEW (1): bootstrap path allows fresh cycle creation (paths confined to new
  `<id>/` dir + decisions.md, manifest.md among them) — exit 0
- ✅ NEW (2): bootstrap path REJECTS when paths escape new cycle dir — exit 2
- ✅ NEW (3): bootstrap path REJECTS when no manifest.md among created paths — exit 2
- ✅ NEW (4 — reviewer C1, mixed-paths abuse vector): bootstrap-shape paths +
  out-of-scope path in same patch → exit 2 (one bad path poisons the whole patch)
- ✅ Existing: no-active-cycle reject case still works for non-bootstrap shapes

### Fix 2 — BUG-F1-2: Manifest YAML parsing breaks on realistic markdown body

**Root cause** (reconfirmed by F-1 re-run T2):
[lib/active_init.sh:29](runtime/platforms/codex/hooks/lib/active_init.sh:29) and
[pre-tool-validate.sh:55](runtime/platforms/codex/hooks/pre-tool-validate.sh:55)
both pipe the entire `manifest.md` to `yq eval`. yq v4.53.2 treats the file as
a multi-doc YAML stream split on `---`. For typical Sage manifests, doc 1 is
the empty preamble, doc 2 is the YAML mapping (parses fine), doc 3 is the
markdown body. When the body contains realistic content like
`**Artifacts:**\n- brief.md: exists\n- spec.md: exists`, doc 3 parses as a
malformed mapping (bold-syntax key + sequence of `key: value` pairs underneath
the bold marker) and yq exits non-zero — even though stdout already holds the
correct value from doc 2. The `|| continue` discards the cycle.

**Why the first retraction missed this:** the simple probe used `# heading\nbody`
as the body — a plain markdown heading + paragraph. That doc 3 parses as a
single string and yq exits 0. Real manifests use bold + bullet-list patterns
that yq misinterprets as YAML mappings.

**Change:** add a `manifest_yaml()` helper at the top of
[lib/active_init.sh](runtime/platforms/codex/hooks/lib/active_init.sh) that
extracts only the YAML doc between the first two `---` markers (via `awk`),
with a fallback to `cat` for flat-YAML manifests (no fences). Pipe that
helper's output to yq instead of the raw file.

```bash
manifest_yaml() {
    local manifest="$1"
    if [ -f "$manifest" ] && [ "$(head -1 "$manifest" 2>/dev/null)" = "---" ]; then
        awk 'NR==1 && /^---$/{next} /^---$/{exit} {print}' "$manifest"
    else
        cat "$manifest" 2>/dev/null
    fi
}
```

Update both call sites:
- `active_init.sh:29` — `status=$(manifest_yaml "$manifest" | yq eval '.status // ""' - 2>/dev/null) || continue`
- `pre-tool-validate.sh` scope read — `done < <(manifest_yaml "$manifest" | yq eval '.scope[]' - 2>/dev/null || true)`

**Tests** ([active_init.bats](runtime/platforms/codex/hooks/tests/active_init.bats)):
- ✅ NEW: realistic markdown body (`**Artifacts:**\n- brief.md: exists\n…`) →
  cycle still detected (status read succeeds)
- ✅ NEW: flat-YAML manifest (no `---` fences) → still detected (fallback path
  keeps working)

### Fix 3 — BUG-F1-3: Scope check trips on relative-vs-absolute path mismatch

**Root cause** (from QA report + memory entry docu_codharn1):
[pre-tool-validate.sh:53-66](runtime/platforms/codex/hooks/pre-tool-validate.sh:53)
normalizes `claimed_paths` via `normalize_path` (relative-to-cwd), but reads
`scope_globs` directly from manifest without normalizing. If manifest has absolute
paths (the format an agent might naturally write), comparison `case "$path" in $glob)`
fails because `path` is relative and `$glob` is absolute.

**Change:** in [pre-tool-validate.sh](runtime/platforms/codex/hooks/pre-tool-validate.sh),
between line 55 and 57, normalize each scope_glob the same way:

```bash
local i=0
while [ "$i" -lt "${#scope_globs[@]}" ]; do
    scope_globs[$i]="$(normalize_path "${scope_globs[$i]}" "$cwd")"
    i=$((i + 1))
done
```

(Or equivalent with bash 3.2-compatible array iteration.)

**Tests** ([pre-tool-validate.bats](runtime/platforms/codex/hooks/tests/pre-tool-validate.bats)):
- ✅ NEW: manifest with absolute scope paths + agent-claimed relative paths → ALLOW
- ✅ Existing: manifest with relative scope paths → still works (no regression)
- ✅ Existing: out-of-scope paths still rejected (after normalization)

### Fix 4 — BUG-F1-4: Hook-only log files committed to git (Minor)

**Root cause** (from QA report + investigation):
[bin/sage:1490-1493](bin/sage:1490) S4 doctor flags `.sage/.mcp-incidents.log` and
`.sage/.session-mutations.log` as bypass writes when they appear in git history.
[sage-writers.yaml](runtime/platforms/codex/audit/sage-writers.yaml) correctly lists
these as hook-only writers — the warning is technically correct, but the actual cause
is **missing `.gitignore` entries**, so `git add -A` (very common pattern) sweeps them
into commits.

**Change:** add a small step to `bin/sage init/update --platform codex` that ensures
the target's `.gitignore` includes these hook log entries. Idempotent: append-if-missing.

Implementation: add a function in
[runtime/platforms/codex/setup/generate-codex.sh](runtime/platforms/codex/setup/generate-codex.sh)
(or a new `setup/lib/gitignore_ensure.sh`) called from an existing stage (likely Stage 9
bootstrap or Stage 10 tighten — whichever fits cleanly). Entries to ensure:

```
.sage/.mcp-incidents.log
.sage/.session-mutations.log
.sage/.skipped-checks.log
.sage/.approval-pending
.sage/.codex-validated-version
```

If `.gitignore` doesn't exist, create it with these entries. If it exists but lacks
some of these, append a `# Sage hook artifacts (managed)` block with the missing entries.
Never modify existing entries.

**Tests** (per reviewer C6 — pinned location):
[runtime/platforms/codex/setup/tests/stage9-bootstrap.bats](runtime/platforms/codex/setup/tests/stage9-bootstrap.bats):
- ✅ NEW (1): fresh `bin/sage init` creates `.gitignore` with all managed entries
- ✅ NEW (2): existing `.gitignore` with user content gets entries appended in a sentinel
  block (user entries preserved verbatim, no edits to existing lines)
- ✅ NEW (3 — reviewer C6 idempotency): re-running init is idempotent — no duplicate
  entries AND no duplicate sentinel block (must match-or-skip the block, not append again)

**Sentinel block format (per reviewer C4 — opt-out path):**

```
# Sage hook artifacts (managed by `bin/sage init` — remove this block to commit hook logs)
.sage/.mcp-incidents.log
.sage/.session-mutations.log
.sage/.skipped-checks.log
.sage/.approval-pending
.sage/.codex-validated-version
# end Sage hook artifacts
```

The opening comment self-describes opt-out: a user who wants to commit hook logs
removes the block, and `bin/sage init` will not re-add it because the block presence
is detected by sentinel match (see test 3). No CLI flag needed.

**Optional polish:** improve [bin/sage:1497-1498](bin/sage:1497) S4 message to suggest
`.gitignore` as the most likely fix instead of "investigate which writer mutated":

```
Fix: Add to .gitignore (these are local-only hook logs): .sage/.mcp-incidents.log, .sage/.session-mutations.log
```

## Risk and rollback

| Risk | Mitigation |
|---|---|
| Bootstrap exception too loose, allows scope drift | Strict shape check on `<id>` regex + must include manifest.md + cycle dir must not exist |
| Frontmatter extractor breaks flat-YAML manifests | Fallback to `cat "$manifest"` when no `---` on line 1 (verified in test) |
| Scope normalization regresses already-working scope checks | `normalize_path` is idempotent on already-relative paths (returns unchanged) |
| Gitignore append breaks user's existing .gitignore | Append-only, with sentinel comment block; never modify existing lines |

**Rollback:** each fix lands as a separate commit. Revert single commit if any fix
breaks existing flow. Combined revert order: 4 → 3 → 2 → 1 (reverse of dependency).

## Implementation order (as executed)

1. **Fix 2** (manifest_yaml helper) — landed first after F-1 T2 reproduction
2. **Fix 3** (scope normalization) — simplest predicate change
3. **Fix 1** (bootstrap exception) — most subtle of the hook fixes; extracted
   `bootstrap_cycle_id()` to `lib/bootstrap_check.sh` to stay under 85 LOC
4. **Fix 4** (gitignore) — fully independent, different subsystem
5. **Fix 5** (implicit scope-self) — surfaced by F-1 re-run #1 after Fixes
   1+2+3 cleared bootstrap/parser/normalize blocks. 2-LOC change pre-seeding
   `scope_globs` with normalized `<cycle_dir>/*` + `.sage/decisions.md`.
   Brings file from 84 → 85 LOC (at §6.0 ceiling). 4 new bats cases.
6. **Fix 6** (plan-approved scope handoff) — surfaced by F-1 re-run
   `qa/run-20260506T212108/` after Fix 5. Surgical Build workflow contract
   update: after plan approval, update `manifest.md` to `phase: implement`
   and persist every planned implementation/test path into `scope:` before
   Step 6 edits begin.
7. **Fix 7** (loader source path) — surfaced by F-1 re-run
   `qa/run-20260506T214503/`. Generated Codex skill loaders pointed to
   `core/workflows/<wf>.workflow.md`, but target projects vendor the framework
   under `sage/`. Stage 7 now points loaders at
   `sage/core/workflows/<wf>.workflow.md`.

## Fix 5 — BUG-F1-5: Predicate has no implicit allow for cycle-self + decisions.md

**Surfaced by:** F-1 re-run #1 (`qa/run-20260430T175409/`). After Fixes 1+2+3
cleared T1, three new blocks fired:

| Turn | Block reason | Allowed scope |
|------|-------------|--------------|
| T2 | Update spec.md / manifest.md / plan.md inside the cycle | `(none)` — manifest had no `scope:` field |
| T3 | Add `scripts/health-check.sh` | `(none)` — same |
| T5 | Update plan.md / manifest.md to flip status: completed | `scripts/health-check.sh` — narrowed by then |

**Root cause:** [pre-tool-validate.sh:55](runtime/platforms/codex/hooks/pre-tool-validate.sh:55)
initialized `scope_globs=()` and only filled it from `manifest.scope[]`. Two
failure modes flow from this:
1. Manifest without `scope:` → empty allow-list → cycle's own files blocked
2. Narrowed scope (legitimately, e.g. only source-of-truth file) → cycle-close
   updates to plan.md / manifest.md blocked

The cycle's OWN dir + `.sage/decisions.md` are structural invariants — they
must be writable whenever a cycle is active, regardless of what the manifest
declares as scope.

**Change:** pre-seed `scope_globs` with normalized `<cycle_dir>/*` and
`.sage/decisions.md` BEFORE reading manifest scope:

```bash
scope_globs=("$(normalize_path "$cycle_dir/*" "$cwd")" "$(normalize_path "$cwd/.sage/decisions.md" "$cwd")")
while IFS= read -r line; do
    [ -n "$line" ] && scope_globs+=("$(normalize_path "$line" "$cwd")")
done < <(...)
```

**Tests** ([pre-tool-validate.bats](runtime/platforms/codex/hooks/tests/pre-tool-validate.bats)):
- ✅ NEW: manifest with empty scope → cycle's own spec.md update ALLOWED
- ✅ NEW: `.sage/decisions.md` always implicitly in-scope
- ✅ NEW: narrowed scope (single source path) → cycle's plan.md still ALLOWED (close-cycle case)
- ✅ NEW: cross-cycle path (other cycle's dir) still REJECTED — implicit allow is per-active-cycle, not blanket

## Verification gate

**F-1 re-run timing (per reviewer C5):** F-1 runs ONLY after all fixes have landed.
Intermediate states are expected to still fail T1 (each fix addresses a different
PreToolUse block; partial fixes won't clear them all). Bats sweep runs after every
commit; F-1 runs once at the end of the cycle.

**After all 7 fixes land:**

1. **Bats sweep:** `bats runtime/platforms/codex/hooks/tests/ runtime/platforms/codex/setup/tests/`
   → **238 GREEN** ✅
2. **Minimal post-Fix-7 verification:** ✅
   - `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
     → 8/8 GREEN
   - `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats --filter 'BUG-F1-5|BUG-F1-3|bootstrap exception'`
     → 7/7 GREEN
   - Generated-loader smoke → `sage:build` points at
     `sage/core/workflows/build.workflow.md`
3. **F-1 re-run:** `bash .sage/work/20260429-codex-port-rewrite/qa/runner.sh`
   → final run: `qa/run-20260506T234800/`
   → T1-T5: **0** `Command blocked by PreToolUse hook` lines ✅
   → T1-T5 doctor: **8 ok / 0 warn / 0 fail** on every turn ✅
   → Signals: workflow_entry 5/5, phase_jump 0, bypass_mutation 0,
     doctor_s1 0 ✅
   → Accepted residual: decisions_missing 1 (non-blocking audit signal)
4. **Aggregator:** [signals-report.json](.sage/work/20260429-codex-port-rewrite/qa/run-*/signals-report.json)
   shows phase_jump ≤ 2, bypass_mutation ≤ 1 (still below v2-promotion thresholds)
5. **Memory storage (per reviewer C7 + Rule 6):** after verification GREEN, store
   sage-memory entries:
   - `[LRN:gotcha]` — bootstrap chicken-egg in PreToolUse predicates (when validating
     mutations require state that the mutation itself creates, predicate must encode
     a bootstrap exception)
   - `[LRN:api-drift]` — yq v4.x emits correct stdout AND exits non-zero on multi-doc
     streams when later docs are malformed. Realistic markdown bodies with
     `**Bold:**\n- key: value` patterns count as malformed YAML mappings. Never pipe
     a manifest's whole-file body into yq; extract the YAML doc explicitly.
   - `[LRN:gotcha]` — premature retraction: a "phantom bug" verdict from a too-simple
     test fixture can be wrong. Reproduce the bug under realistic conditions (real
     templates, real bodies) before declaring no fix is needed.
   - `[LRN:convention]` — Sage manifest.md format is `---` frontmatter + markdown
     body; the canonical reader is `manifest_yaml()` in `lib/active_init.sh`,
     not raw `yq eval` on the file.

If any verification step fails → return to investigation, no shortcuts.

## Block-to-fix mapping (final, after F-1 re-run #1)

PreToolUse blocks observed across F-1 runs map to 4 hook fixes:

| Block | Evidence | Fixed by |
|---|---|---|
| Run-1 T1#1 | "no active cycle" creating brief.md + spec.md + manifest.md in a single patch on a fresh target | Fix 1 (bootstrap exception) |
| Run-1 T1#2 | "no active cycle" repeat — agent retried with flat-YAML manifest as a workaround; still no cycle on disk | Fix 1 (same root cause) |
| Run-1 T1#3 | "paths outside cycle scope" after manifest existed — relative claimed paths vs absolute scope globs | Fix 3 (scope normalization) |
| Run-2 T2 | "no active cycle" while updating spec.md inside an existing in-progress cycle whose manifest body had `**Artifacts:**\n- brief.md: exists` — yq exits 1 on the body, status read returns empty | Fix 2 (manifest_yaml extractor) |
| Re-run-1 T2 | "outside cycle scope. Allowed scope: (none)" — agent wrote manifest without `scope:` field, all cycle-self updates blocked | Fix 5 (implicit scope-self) |
| Re-run-1 T3 | Same — adding `scripts/health-check.sh` blocked by empty allow-list | Fix 5 (same root cause) |
| Re-run-1 T5 | "outside cycle scope. Allowed scope: scripts/health-check.sh" — narrowed scope locked out cycle's own plan.md/manifest.md at close | Fix 5 (same root cause) |

All hook + workflow-contract fixes must land for end-to-end T1-T5 to clear
cleanly. Fix 4 is a separate subsystem (setup pipeline) and is independent.

## Fix 6 — BUG-F1-6: Build plan approval did not persist implementation scope

**Surfaced by:** F-1 re-run `qa/run-20260506T212108/`. T1 and T2 cleared, but
T3 hit one PreToolUse block:

| Turn | Block reason | Allowed scope |
|------|--------------|---------------|
| T3 | Add `scripts/tests/health-check.bats` | `.sage/work/20260506-health-check-script/* .sage/decisions.md` |

**Root cause:** the Build workflow told the agent to proceed from approved
plan to Step 6 without a mandatory manifest handoff step. The approved plan
named `scripts/health-check.sh` and `scripts/tests/health-check.bats`, but
`manifest.scope` still only contained structural cycle paths. The hook rejected
correctly; the workflow failed to persist approved implementation scope before
the first implementation patch.

**Change:** in `core/workflows/build.workflow.md`, both plan approval paths
(`[A] Review` and `[S] Skip review`) now require updating `manifest.md` before
Step 6:

- Set phase to `implement`.
- Add a `scope:` list containing every implementation/test file or glob the
  approved plan will mutate.
- Keep `.sage/work/<cycle-id>/*` and `.sage/decisions.md` in scope.
- If scope is uncertain, stop and ask before implementation.

Step 6 also has a preflight: re-read `manifest.md`, confirm the next task's
files are in scope, and update the manifest first if not.

## Fix 7 — BUG-F1-7: Codex skill loader points at missing workflow source

**Surfaced by:** F-1 re-run `qa/run-20260506T214503/`. During T3 the agent
read `.agents/skills/sage:build/SKILL.md`, followed its loader instruction,
and attempted:

`sed -n '1,260p' core/workflows/build.workflow.md`

The command failed with `No such file or directory` because generated Codex
targets keep the framework under `sage/`. The actual workflow path is
`sage/core/workflows/build.workflow.md`.

**Root cause:** Stage 7 rendered loader stubs with source path
`core/workflows/<wf>.workflow.md`, a path valid in the framework repo root but
invalid in generated target projects. That made workflow contract updates like
Fix 6 unreachable to the agent inside QA targets.

**Change:** in `runtime/platforms/codex/setup/lib/skills-deploy.sh`, render
loader stubs with `sage/core/workflows/<wf>.workflow.md`. Update
`runtime/platforms/codex/setup/tests/stage7-skills.bats` so the regression
test asserts the target-local path.
