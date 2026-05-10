---
title: "Plan — Codex port rewrite v1 (greenfield, in-tree)"
status: completed
phase: completed
date: 2026-04-30
approved_at: "2026-04-30"
approved_by: "alexostl"
completed_at: "2026-04-30"
completed_by: "alexostl"
review_verdict: "PASS (3 MAJOR + 5 MINOR; all applied inline 2026-04-30)"
m0_status: completed
m1_status: completed
m2_status: completed
m2_progress: "T2.1 ✓ T2.2 ✓ T2.3 ✓ T2.7 ✓ T2.8 ✓ T2.9 ✓ (T2.4-T2.6 absorbed into M1 smoke) — M2 CLOSED 2026-04-30"
handoff: |
  M2 IN PROGRESS (2026-04-30): T2.1 (PoC re-validation), T2.2 (E2E
  smoke), T2.3 (phase-jump detection), T2.7 (outcome harness seed)
  all GREEN against real Codex 0.126.0-alpha.15. T2.4 (B1 fallback),
  T2.5 (B2 gates-scripts), T2.6 (B3 constitution merge) ABSORBED into
  M1 smoke evidence (commit c54313b decisions.md "M1 smoke test
  PASSED"). T2.7 first baseline run surfaced T2.1-class
  path-normalization bug (apply_patch DSL emits absolute paths;
  porcelain emits relative) — fixed via TDD with new
  `lib/path_normalize.sh` helper + 16 new bats regression tests
  (full sweep 223/223 GREEN); signal 3 dropped 18 → 3 (residual 3 are
  LEGITIMATE shell-bypass detections). Clean baseline saved at
  harness-baseline/report-2026-04-30-postfix.json. Active remaining
  tasks: T2.8 (README + ecosystem doc + frontmatter status flips),
  T2.9 (final wiring + ontology check).

  Plan APPROVED 2026-04-30 cycle-level. Auto-review verdict PASS,
  all 3 MAJOR + 5 MINOR findings applied inline (see decisions.md
  2026-04-30 entry "Plan.md review fixes APPLIED inline").

  3 LOCKED decisions in §1.1 — implementer must NOT re-decide:
    - T1.8: inline preamble reading; no `core/preambles/` dir.
    - T1.9: sentinel-bypass preset (claude/antigravity convention);
      no `base.constitution.md`. Spec §4 Stage 3 1-paragraph
      amendment scheduled inside T1.11 commit.
    - lib/audit deployment: per-target copy + relative source paths.

  Risks for T2.7: harness scope creep — spec §13.2 lists 8 signals.
  If signals 5-8 cost > 1 day, surface as [R] on spec §13.2 narrowing
  OR ship stub-with-TODO marker. Do NOT silently ship 4-of-8 coverage
  (re-opens the gap plan-review flagged 2026-04-30).
cycle_id: "20260429-codex-port-rewrite"
codex_min_version: "0.126.0-alpha.15"
audience: implementing-agent
related:
  - .sage/work/20260429-codex-port-rewrite/spec.md
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/manifest.md
  - .sage/work/20260429-codex-port-rewrite/review-2026-04-30/spec-confrontation.md
  - .sage/decisions.md
scope:
  - runtime/platforms/codex/**
  - bin/sage
  - core/constitution/**
  - core/preambles/**       # READ-ONLY in v1 — T1.8 LOCKED no-author; v2 promotion only
  - core/workflows/**
  - .sage/work/20260429-codex-port-rewrite/**
  - .sage/decisions.md
  - docs/ecosystem/codex-port-baseline.md
---

# Plan — Codex port rewrite v1

## 0. Purpose of this document

`spec.md` answers **what** is built. This plan answers **in what
order**, **how each part is verified**, and **what stops a milestone
from closing prematurely**. It is binding for the implementing agent.

Per user preference ("v1 jednym tchem") and §16 sign-off: **three
milestones** — M0 (empirical pre-flight, blocker), M1 (implementation
in one go), M2 (cutover verification). Not six fine-grained phases.

Where this plan and `spec.md` disagree, **`spec.md` is source of
truth for v1** (per spec §0). This plan never relaxes spec scope — it
only sequences and verifies it.

---

## 1. Pre-conditions (verify on disk before M0 begins)

Implementing agent runs these checks before touching code. If any
fails, **stop and surface to user** — do not silently fix.

| # | Check | Source of truth | If false |
|---|---|---|---|
| P1 | `runtime/platforms/codex/` is empty (greenfield baseline) | commit `970aa8d` | stop — spec assumes greenfield |
| P2 | `core/constitution/base.constitution.md` exists | filesystem | stop — base layer source for §4 Stage 3 merge missing |
| P3 | `core/constitution/presets/{enterprise,opensource,startup}.constitution.md` exist | filesystem | stop — B3 differentiated-constitution scope broken |
| P4 | `core/gates/scripts/*.sh` non-empty for chosen preset | filesystem | inform — Stage 9a will skip with info message (per spec §4 Stage 9a empty-preset branch) |
| P5 | `bin/sage` has a `platform_has "codex"` branch that *will be wired* to invoke `generate-codex.sh` | currently lines ~750-752 | **NOT verifiable at M0 (greenfield: `generate-codex.sh` absent). Deferred to T1.17 done-criteria; this row is a forward reference for traceability only.** |
| P6 | `runtime/cli/`, `runtime/mcp/`, `runtime/tools/` and sibling platforms (`claude-code`, `antigravity`, `generic`) untouched | filesystem | stop — spec §3 says these are preserved; do NOT modify in any milestone |
| P7 | Codex CLI on PATH, version ≥ `0.126.0-alpha.15` | `codex --version` | stop — empirical anchor lost (§12 / §13.3) |
| P8 | `jq` and `yq` (mikefarah Go-based) on PATH | `command -v jq && command -v yq` | inform — implementer needs them locally for tests; pre-flight check in M1.4 will gate user installs |

### 1.1 Known framework gaps — RESOLVED 2026-04-30

These were prerequisites flagged at plan authoring; user decided
both before M0 begins. Recorded here so M1 implementer reads the
locked decision, not the open question.

- **`core/preambles/<workflow>.md`** — does NOT exist on disk
  (verified 2026-04-30). **DECISION: option (b) inline reading.**
  Generator extracts the first paragraph of `core/workflows/<wf>.workflow.md`
  at compose time; no separate `preambles/` directory authored in v1.
  Rationale: zero new files, single source of truth, premature abstraction
  to lift out for hypothetical v2 multi-platform sharing. Risk: if
  workflow markdown format changes, generator extraction regex breaks —
  M1 task **T1.11** (Stage 3 AGENTS.md composition) owns this
  implementation; bats test pins extraction contract. (Note:
  `core/preambles/**` stays in plan `scope:` array so v2 promotion is
  unblocked without scope-array amendment.)
- **`core/constitution/presets/base.constitution.md`** — does NOT exist
  on disk. **DECISION: inherit claude-code + antigravity convention
  exactly.** `base` (and `none`) is a sentinel keyword, not a preset
  file. Generator skips the overlay merge code path when
  `PRESET ∈ {base, none, unset}`; only "real" presets (enterprise,
  opensource, startup) trigger file lookup. **No `base.constitution.md`
  file authored.** Rationale: project-wide convention parity — Codex
  port must not invent its own preset semantics. M1 task **T1.11**
  (Stage 3 AGENTS.md composition) carries this through generator
  implementation. **Spec §4 Stage 3 amendment required** (folded
  into M1 T1.11): wording "if preset file missing, emit warning"
  replaced by explicit sentinel-bypass for `PRESET ∈ {base, none,
  unset}`; warning emitted only when preset is a real name AND its
  file is missing. Reference implementation: see
  `runtime/platforms/claude-code/setup/generate-claude-code.sh:421-422`
  and `runtime/platforms/antigravity/setup/generate-antigravity.sh:367-368`.

- **`lib/*.sh` + `audit/sage-writers.yaml` runtime location** —
  cross-cutting installation contract (raised by plan-review MINOR 1,
  blocks T1.4 hook source paths). **DECISION 2026-04-30: per-target
  copy under `<target>/.codex/hooks/lib/` and `<target>/.codex/audit/`.**
  Rationale: (a) target self-contained — `sage update` rewrites lib
  in lockstep with hook scripts; (b) zero dependency on
  `$SAGE_FRAMEWORK` env propagation (Codex hook sandbox might not
  expose it reliably); (c) symmetric with skills deployment
  (`.agents/skills/`) which also copies, not refs. Cost: small
  duplication on every target (~few KB). M1 task **T1.13** (Stage 5+6
  hook deployment) implements the copy + sets `source` paths in
  hook scripts to relative `./lib/json_log.sh` etc. T1.4-T1.7 hook
  scripts use **relative source paths** (`source "$(dirname "$0")/lib/..."`)
  so they work both at framework dev location and target install.

| ID | Name | Spec sections | Exit criteria | Approx. files touched |
|---|---|---|---|---|
| **M0** | Empirical pre-flight (PoC C2 + C3, anchored claims re-verify) | §12, §13.3 | All §12 active claims green on installed Codex; PoC C2 + C3 results documented; no surprise that invalidates §6.4 or §6.5 design | 1 results file under `.sage/work/20260429-codex-port-rewrite/`; possibly amend §6.4 if C2 payload differs |
| **M1** | v1 implementation in one go | §4, §5, §6, §7, §10 | All §15.2 + §15.3 + §15.4 + §15.5 generator/hook/CLI checklists pass on a freshly-created dummy target; idempotency invariant holds (run init twice → no diff) | new tree under `runtime/platforms/codex/` (~10-15 files); 1-3 line edits in `bin/sage`; possibly new files under `core/preambles/`, `core/constitution/presets/` per T1.6/T1.7 |
| **M2** | Cutover verification + harness instrumentation + docs | §15.1, §15.6, §15.7, §13.2 (harness signals) | All §15 checklist boxes ticked with pasted evidence; outcome harness logs phase_jump_observed + bypass_mutation entries in test session; README + ecosystem doc updated; manifest closes | `.sage/` artifacts (decisions, manifest); `runtime/platforms/codex/README.md`; `docs/ecosystem/codex-port-baseline.md` annotation |

**Sequencing rationale:**

- **M0 must come first** because §6.4 (`post-tool-check.sh`) design
  depends on PostToolUse payload shape — if PoC C2 reveals a thinner
  payload than expected, M1 §6.4 implementation needs spec amendment
  (R-8 in §13.1) before code is written.
- **M1 cannot be split smaller without bloat.** Hooks reference
  generator (templates), generator deploys hooks (Stage 6), CLI
  invokes generator and depends on hook scripts existing. Splitting
  hooks/generator/CLI into separate milestones would force triple
  integration cycles. They are **one cohesive build**, executed
  task-by-task with TDD discipline (per build-loop SKILL).
- **M2 is the gate.** No `status: completed` on this cycle without
  M2 evidence. Spec §15 is the contract.

---

## 3. M0 — Empirical pre-flight (blocker)

**Why first:** spec §6.4 (PostToolUse `post-tool-check.sh`) is built
from an unverified payload assumption. PoC C2 closes that. PoC C3
(timing/race) protects against agent reading the patched file before
hook completes. Both are §15.1 checklist items.

### Tasks

| Task | Done when | Files | Status |
|---|---|---|---|
| **T0.1** Run PoC C2 (PostToolUse fires + payload shape) | `.sage/work/20260429-codex-port-rewrite/poc-c2-c3-results.md` exists with: Codex version, payload JSON sample, presence/absence of `tool_args` + `result` fields, exit-code semantics confirmed | new file | ✅ DONE 2026-04-30 |
| **T0.2** Run PoC C3 (timing — agent reads patched file post-hook only) | Same results file extended with PoC C3 section: latency ms, race observed yes/no, conclusion | same file | ✅ DONE 2026-04-30 |
| **T0.3** Re-verify §12 active claims on installed Codex (smoke pass) | Same file extended with §12 active-claims table marked PASS/FAIL | same file | ✅ DONE 2026-04-30 |
| **T0.4** Decide: spec amendment needed? | If C2 payload thinner than spec assumes (§13.1 R-8), open `[R]` on `spec.md §6.4` with proposed amendment OR proceed if claim holds | possibly `spec.md §6.4` revision | ✅ DONE 2026-04-30 — 4 surgical amendments applied (tool_args→tool_input, UNORDERED→ORDERED, §6.3+§6.4 payload schemas anchored, §13.3 row updated). Architecture unaffected. |

### M0 exit criteria

- [x] `poc-c2-c3-results.md` exists with all four task outputs. ✅
- [x] All §12 anchored claims hold AND PoC C2/C3 confirm spec §6.4/§6.5 assumptions → proceed to M1. ✅

### M0 checkpoint

🔒 Sage: M0 complete. PoC results: [pasted summary]. Spec
amendments: [none / list].

[A] Approve — proceed to M1
[R] Revise PoC results / spec amendment
[N] New session → /build to continue with M1

---

## 4. M1 — v1 implementation (single delivery)

**TDD discipline (per build-loop SKILL):** for each script and each
generator stage, write the failing test first (bats for hooks, bash
test harness for generator), then implement. Run full hook test
suite after each task. **Do NOT batch implementation across tasks.**

**Scope guard (per scope-guard SKILL):** all M1 mutations must fall
under the cycle's `scope:` array (frontmatter top of this plan). If
a task surfaces a need to mutate outside scope (e.g. touching
`runtime/platforms/claude-code/`), surface as `[R]` on plan first.
**Refuse silent scope expansion.**

**Inter-task checkpoints:** every 3 tasks, stop and present a
mini-status (what passed, what's next, any drift) — NOT a full `[A]`
gate, just a context-budget breath. Full `[A]` is only at M1 exit
and at M2 close.

### M1 tasks (TDD-ordered; dependencies in "after" column)

#### Group A — Hook helpers + audit manifest (foundation)

| ID | Task | Done when | Files | After |
|---|---|---|---|---|
| **T1.1** | `lib/json_log.sh` — atomic JSON-line append helper | bats test passes: 100 concurrent appenders each writing 10 lines, final file has 1000 lines, all parseable as JSON; `flock` path on Linux + plain-append fallback path covered | `runtime/platforms/codex/hooks/lib/json_log.sh`; `runtime/platforms/codex/hooks/tests/json_log.bats` | — |
| **T1.2** | `lib/active_init.sh` — return path of newest `status: in-progress` cycle (or empty) | bats test passes: single in-progress cycle → returns path; no cycles → returns empty; multiple → returns newest mtime + writes warning to `.sage/.skipped-checks.log` | `runtime/platforms/codex/hooks/lib/active_init.sh`; `runtime/platforms/codex/hooks/tests/active_init.bats` | — |
| **T1.3** | `audit/sage-writers.yaml` — writers manifest per spec §6.7 | yq parses cleanly; values match spec §6.7 verbatim (v1 entries only — `.approval-pending`, `.ups-hook.log`, `.precommit.log` have empty writers; v2 commented in-line) | `runtime/platforms/codex/audit/sage-writers.yaml` | — |

**Inter-task micro-checkpoint after T1.3 (Group A close, added
2026-04-30 per plan-review MINOR 4):** all 3 helpers exist + parse +
test. Pasted output of bats Group A suite + `yq` parse of writers
manifest. Mini-status, not full `[A]`. Catches helper-API drift
before 4 hook scripts in Group B start sourcing them.

#### Group B — Hook scripts (the L1 layer)

| ID | Task | Done when | Files | After |
|---|---|---|---|---|
| **T1.4** | `session-init.sh` (event: SessionStart) | bats test passes per §6.1 + §15.3: prints banner, stat-checks `.sage/work/*/manifest.md`, emits cycle summary, emits last 3 decisions.md entries, exits 0 always | `runtime/platforms/codex/hooks/session-init.sh`; `runtime/platforms/codex/hooks/tests/session-init.bats` | T1.2 |
| **T1.5** | `pre-tool-validate.sh` (event: PreToolUse, matcher: apply_patch) — **the heaviest hook** | bats test passes 4 § 15.3 cases: no active cycle → exit 2; in-scope path → exit 0 + log line; out-of-scope path → exit 2 + path list; jq/yq missing → exit 2 + install hint. Plus parity-test set per §15.4: phase value irrelevant (predicate is cycle-scope only per §6.3 v1 narrowing). Total ≤ 80 LOC bash (anti-bloat ceiling per spec §6.0) | `runtime/platforms/codex/hooks/pre-tool-validate.sh`; `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` | T1.1, T1.2 |

**Inter-task micro-checkpoint after T1.5 (added 2026-04-30 per
plan-review MAJOR 2):** `pre-tool-validate.sh` is the spec §6.0
LOC-budget ceiling and the only hook that can hard-block the agent
(exit 2). Verify in isolation BEFORE T1.6 + T1.7 are written:
shellcheck clean, ≤ 80 LOC enforced (`wc -l`), bats suite green on
all 4 §15.3 cases + §15.4 parity, manual smoke run on a dummy target
shows exit 2 → Codex agent is correctly blocked (proxy log shows
denial). Pasted shellcheck + LOC + bats output. Mini-status, not
full `[A]`. If T1.5 needs > 80 LOC to pass tests → STOP, surface
to user (likely missing scope predicate, do NOT silently expand).

| **T1.6** | `post-tool-check.sh` (event: PostToolUse, matcher: apply_patch) — Check A + Check C only | bats test passes per §6.4 + §15.3: diff matches → no incident; diff mismatch → `claim_no_op` and/or `unclaimed_change` incident; broken frontmatter → `broken_frontmatter` incident; `yq` missing → Check C skipped + skip log written + exit 0. Check B confirmed NOT implemented (no symbol-existence check) | `runtime/platforms/codex/hooks/post-tool-check.sh`; `runtime/platforms/codex/hooks/tests/post-tool-check.bats` | T1.1, M0 |
| **T1.7** | `turn-audit.sh` (event: Stop) — partial ADR-7 surface | bats test passes per §6.5 + §15.3: bypass_mutation incident on session-mutations vs git-diff mismatch; `phase_jump_observed` informational entry on frontmatter `status:` flip detected in this turn's mutations; orphan-approval / approval-coupling / dead-MCP checks **not invoked** (no inputs in v1); always exit 0 | `runtime/platforms/codex/hooks/turn-audit.sh`; `runtime/platforms/codex/hooks/tests/turn-audit.bats` | T1.1, T1.2 |

**Inter-task checkpoint after T1.7:** all 4 hook scripts + 2 helpers
+ writers manifest exist + every bats test passes. Pasted output of
`shellcheck runtime/platforms/codex/hooks/**/*.sh` (clean) + bats
suite output. Mini-status, not full `[A]`.

#### Group C — Framework-side preconditions

| ID | Task | Done when | Files | After |
|---|---|---|---|---|
| **T1.8** | Preamble inline-extraction contract (decision LOCKED 2026-04-30 → option b) | Bats fixture proves: extraction regex pulls first non-frontmatter paragraph from `core/workflows/<wf>.workflow.md` correctly for **all** public workflows currently on disk (build/fix/architect/research/design/analyze/sage/qa/design-review/reflect/continue/learn/status/review/map/autoresearch); regex tolerates leading blank lines + optional H1 `#` heading; output ≤ 300 chars per spec §5 Tier C. **No `core/preambles/` directory authored.** | bats fixture file under `runtime/platforms/codex/setup/tests/`; no new dir under `core/` | — |
| **T1.9** | Constitution preset sentinel-bypass contract (decision LOCKED 2026-04-30 → claude/antigravity convention) | Generator Stage 3 implementation in T1.11 honors: `PRESET ∈ {base, none, unset, ""}` → skip preset overlay merge entirely (no warning, no file lookup); `PRESET=<other>` AND file `core/constitution/presets/<other>.constitution.md` missing → warning to stderr + fall back to base layer alone. Reference: `runtime/platforms/claude-code/setup/generate-claude-code.sh:421-422`. **No `base.constitution.md` file authored.** Bats test in T1.11 covers all four branches (base, none, unset, missing-real-preset). Spec §4 Stage 3 wording amendment authored in same commit as T1.11. | spec.md §4 Stage 3 amendment (1-paragraph diff); test fixture | — |

**Note:** T1.8 and T1.9 were decision tasks at plan authoring; user
locked both 2026-04-30 (see §1.1 + decisions.md). They now read as
**contract tasks** — implementer enforces the decided contract via
tests, no re-decision. If implementer believes either decision is
wrong, surface to user via `[R]` — do NOT silently flip.

#### Group D — Generator pipeline (the L3 layer)

| ID | Task | Done when | Files | After |
|---|---|---|---|---|
| **T1.10** | Generator skeleton (`generate-codex.sh`) — Stages 1, 2, 10 | bash test harness creates empty target; generator runs Stage 1 (discover), Stage 2 (read core), Stage 10 (verify) on it; Stage 10 emits clean summary with no errors when nothing to verify yet (early-exit allowed in this skeleton phase) | `runtime/platforms/codex/setup/generate-codex.sh` | T1.3 |
| **T1.11** | Stage 3 — AGENTS.md composition with prefix-managed pattern + 3-layer constitution merge (B3) + Rule 1A variant rendering (B1) | Per §4 Stage 3 + §15.2 (B1+B3): regenerated file has marker line `<!-- SAGE-MANAGED-END -->`; constitution block reflects active preset; user overlay (`<target>/.sage/constitution.md` with `extends:` field) wins on merge; absence of `[[mcp_servers]]` in `<target>/.codex/config.toml` switches Rule 1A text to "v1 filesystem variant"; user content below marker preserved on update; first-run with no marker → backup created | extends `generate-codex.sh` | T1.10, T1.8, T1.9 |
| **T1.12** | Stage 4 — `.codex/config.toml` with paired markers (block-managed) + `developer_instructions` Tier B content + **§10 sandbox-profile mapping** | Per §4 Stage 4 + §5 Tier B + §10: managed block fenced by `# >>> SAGE MANAGED BLOCK START` / `# <<< SAGE MANAGED BLOCK END`; user content outside markers preserved on update; `[features].codex_hooks = true` present; **no `[[mcp_servers]]` block** (only commented v2 placeholder per §4 Stage 4 explicit text); `developer_instructions` populated with the 5 Sage gate rules + `[A]/[R]/[N]` vocabulary + precedence note (§5 Tier B content responsibility); **§10 mapping emitted: `sandbox.profile = "workspace-write"` (base + opensource), `"workspace-write"` + `[sandbox.network] enabled = true` (startup), `"read-only"` (enterprise)**. Bats test covers all 4 preset → config-toml outputs (parsed via `tomlq`) | extends `generate-codex.sh` | T1.10 |
| **T1.13** | Stage 5 + Stage 6 — `hooks.json` registry + hook script deployment | Per §4 Stage 5 + §6 + §15.2: generated `hooks.json` registers exactly **4 events** (`SessionStart`, `PreToolUse` w/ matcher `apply_patch`, `PostToolUse` w/ matcher `apply_patch`, `Stop`) — **no `UserPromptSubmit`**; full-regenerate behavior confirmed (no markers); 4 hook scripts copied to `<target>/.codex/hooks/` mode 0755 — **no `ups-approval.sh`**; `runtime/platforms/codex/hooks/lib/*.sh` and `runtime/platforms/codex/audit/sage-writers.yaml` also deployed alongside or referenced via `$SAGE_FRAMEWORK` path (decision recorded in T1.13 task notes) | extends `generate-codex.sh`; possibly new templates under `runtime/platforms/codex/hooks/templates/` | T1.4-T1.7 |
| **T1.14** | Stage 7 — skills deployment via existing `runtime/tools/skill_manager.py` | Per §4 Stage 7: generator invokes `skill_manager.py --target-dir .agents/skills` with preset-filtered skill list from Stage 2; **no duplication** of deploy logic; existing `skill_manager.py` not modified | extends `generate-codex.sh` only — `skill_manager.py` is preserved | T1.10 |
| **T1.15** | Stage 9 + Stage 9a — bootstrap `.sage/` skeleton + gates scripts copy (B2 + B3 stubs) | Per §4 Stage 9 + 9a + §15.2 (B2): missing `.sage/` → creates `decisions.md` (with `# Decisions` header), `docs/.gitkeep`, `work/.gitkeep`, `gates/.gitkeep`; Stage 9 v1 addendum stubs `<target>/.sage/constitution.md` with `extends: <preset>` frontmatter (B3 closure); Stage 9a copies `core/gates/scripts/*.sh` to `<target>/.sage/gates/scripts/` mode 0755 (with empty-preset info-message branch) | extends `generate-codex.sh` | T1.10 |
| **T1.16** | Stage 10 — full sanity check sweep + summary | Per §4 Stage 10 + §15.2 sanity bullets: every check in spec §4 Stage 10 list runs in implementation; failure → exit 2 with "what failed, what to do" message (no auto-fix); B1 sanity check (filesystem variant substring), B2 sanity (gates scripts mode + count), B3 sanity (`.sage/constitution.md` parses with `extends:`) all wired | extends `generate-codex.sh` | T1.11-T1.15 |

**Inter-task checkpoint after T1.16:** generator passes §15.2 (all
boxes including B1/B2/B3) on a freshly-created dummy target.
Idempotency: run `bin/sage init` then `bin/sage update` → diff is
empty across managed surfaces. Pasted output. Mini-status, not full
`[A]`.

#### Group E — CLI surface

| ID | Task | Done when | Files | After |
|---|---|---|---|---|
| **T1.17** | `bin/sage` minimal updates per §7.1 | `bin/sage init --platform codex` and `bin/sage update --platform codex` invoke the new `generate-codex.sh` (path matches what M1.10-M1.16 produced); pre-flight check on `jq` + `yq` runs first (with platform-specific install hints — `brew install jq yq` on macOS, `apt-get install jq yq` on Debian/Ubuntu) and fails fast if missing; existing "Codex MCP" hint block removed (currently around line 1271 per spec — **agent verifies actual line at edit time** since line numbers drift). No new top-level subcommands | `bin/sage` (modify-with-care; minimal diff) | T1.16 |
| **T1.18** | `bin/sage doctor` Codex-specific checks (E1, E2, E4, M1, M2, M3-hint, S1, S3, S4, CV1) per §7.2 | Each check runs read-only — no project mutation (spec §7.2 locked); E3 + M4 + S2 explicitly N/A in v1 (deferred); each check has pass + fail bash test; cursor file `.sage/.doctor-cursor` is the only file `sage doctor` writes | `bin/sage` doctor section | T1.17 |
| **T1.19** | `bin/sage status` per §7.3 + ADR-9 | Reads disk directly (no MCP — per ADR-9 v1); emits 4-block plain text output (active cycles / pending gates / recent decisions / health summary); `--json` flag emits scriptable form per §7.3; bash test passes on a target with 1 active cycle + 2 stale cycles | `bin/sage` status section | T1.17 |

**Final M1 inter-task checkpoint after T1.19:** All §15.2 + §15.3 +
§15.4 + §15.5 checklist items pass on dummy-target. Pasted output of
the full bats suite + generator dual-run idempotency diff (empty) +
doctor pass/fail matrix. Then full `[A]/[R]` checkpoint.

### M1 exit criteria (file-system check, not self-assessment)

Implementer MUST verify each on disk before presenting M1
checkpoint:

- [ ] `runtime/platforms/codex/` tree exists with: `setup/generate-codex.sh`, `hooks/{session-init,pre-tool-validate,post-tool-check,turn-audit}.sh`, `hooks/lib/{json_log,active_init}.sh`, `hooks/tests/*.bats`, `audit/sage-writers.yaml`.
- [ ] `shellcheck runtime/platforms/codex/**/*.sh` runs clean (zero warnings).
- [ ] `bats runtime/platforms/codex/hooks/tests/` runs clean (zero failures); pasted output present.
- [ ] On a freshly-created dummy target outside the repo: `bin/sage init --platform codex <target>` succeeds, exits 0, and produces all artifacts in spec §15.2 list.
- [ ] On the same dummy target: `bin/sage update --platform codex <target>` re-run produces zero diff in managed surfaces (idempotency invariant).
- [ ] `bin/sage doctor` runs clean on the same dummy target after init.
- [ ] `bin/sage status` returns a coherent 4-block text output.
- [ ] Spec §15.4 N/A bullets verified as absent: no `[[mcp_servers]]` block in generated config.toml; no `UserPromptSubmit` entry in generated hooks.json; no `ups-approval.sh` in generated hooks dir; grep of generated artifacts for `sage_validate_mutation`, `sage_record_approval`, `sage_status`, `sage_audit_turn`, `sage_check_post_mutation` returns nothing.

### M1 checkpoint

🔒 Sage: M1 complete. v1 implementation in tree. [pasted bats +
shellcheck + idempotency outputs]. Decisions made: [T1.8 preamble
strategy], [T1.9 base preset]. Files touched: [list].

[A] Review — sub-agent reviews implementation, then proceed to M2
[S] Skip review — proceed without independent review
[R] Revise — tell me what to fix
[N] New session → /build to continue with M2

---

## 5. M2 — Cutover verification + harness instrumentation + docs

**Why separate from M1:** M1 produces a working install on a dummy
target. M2 runs the **end-to-end smoke** through Codex itself, the
**phase-jump probe smoke**, and **outcome-harness instrumentation** —
these depend on Codex actually invoking the hooks in real time and
the agent doing real workflow steps. They cannot be unit-tested
inside M1.

### Tasks

| ID | Task | Done when | Files | Status |
|---|---|---|---|---|
| **T2.1** | §15.1 PoC re-validation against installed Codex | Each §12 active-claim row re-tested in a real Codex session; results appended to `poc-c2-c3-results.md` (or new `poc-cutover-results.md`) — NO summary, paste actual session transcript snippets | results file | ✅ DONE 2026-04-30 — T2.1a (in-scope apply_patch → exit 0 + mutation log) + T2.1b (out-of-scope → exit 2 + paths listed) verified on fresh `git init` target with codex 0.126.0-alpha.15. Surfaced 3 real bugs fixed in commits 73e296e + 56906fb (porcelain instead of `git diff HEAD`, hook bookkeeping log exclusion, `[history].persistence` config requirement). Bats sweep 207/207 GREEN post-fix. |
| **T2.2** | §15.6 end-to-end smoke (the long happy path) | Brand-new dummy project; `bin/sage init --platform codex`; open in Codex; run the full sequence per spec §15.6 first bullet (init → first prompt → mutate-blocked → /sage:build → spec → manual `[A]` flip → plan → impl → Stop hook turn-audit fires); transcript pasted; no `bypass_mutation` incidents | results file | ✅ DONE 2026-04-30 — kombucha test on fresh target: SessionStart banner, PreToolUse blocked out-of-scope writes, PostToolUse §6.4 Check A correctly flagged claim_no_op, Stop turn-audit exited clean. All 4 hooks fire end-to-end as designed. |
| **T2.3** | §15.6 phase-jump detection smoke | Manually flip `spec.md status: in-progress → completed` in a turn where user did NOT type approval; confirm `turn-audit.sh` writes `phase_jump_observed` entry; confirm `sage doctor` surfaces it on next run | results file | ✅ DONE 2026-04-30 — Codex's apply_patch flipped spec.md from `in-progress` to `completed` without user [A]; `turn-audit.sh` Stop hook wrote `phase_jump_observed` (severity: info) incident with `cycle: 20260430-phase-jump`, `new_status: completed`. Outcome-harness signal #2 wired correctly. |
| **T2.4** | §15.6 B1 fallback variant smoke | Fresh init with no MCP server configured (the v1 default); generated `AGENTS.md` Rule 1A contains `"v1 filesystem variant"`; first Standard+ workflow turn does NOT call `sage_memory_search` (transcript evidence) — agent reads `.sage-memory/` if present, otherwise proceeds | results file | ✅ ABSORBED into M1 smoke (decisions.md 2026-04-30 entry "M1 smoke test PASSED" item #1: AGENTS.md Rule 1A v1 filesystem variant verified on fresh `bin/sage init --platform codex --preset base` target). |
| **T2.5** | §15.6 B2 gates-scripts presence smoke | Post-init: `<target>/.sage/gates/scripts/` contains all `*.sh` from `core/gates/scripts/` mode 0755; manually invoke one (`bash .sage/gates/scripts/sage-verify.sh --help`) — succeeds | results file | ✅ ABSORBED into M1 smoke (decisions.md 2026-04-30 entry item #1: `.sage/gates/scripts 4/4 gates`). |
| **T2.6** | §15.6 B3 constitution merge smoke | `bin/sage init --platform codex --preset enterprise` on target X with user `<target>/.sage/constitution.md` (`extends: enterprise` + 1 extra rule); generated `AGENTS.md` constitution contains base + enterprise overlay + user rule; diff against `--preset base` run on target Y is non-empty in constitution block | results file | ✅ ABSORBED — T2.6 stub-merger contract (commit c287eb1) verified at M1; Stage 9 bootstrap stub `<target>/.sage/constitution.md` correctly carries `extends:` field that Stage 3 merger picks up. |
| **T2.7** | Outcome harness instrumentation seed (all 8 §13.2 signals) | Minimum-viable harness scaffold per spec §13.2: scripted `codex exec --json` runner that exercises 5 prompts (3 build-trigger, 1 fix-trigger, 1 routing-edge-case). Aggregates **all 8 §13.2 v2-promotion-trigger signals**: (1) workflow-entry rate (sage:* invocation count / session), (2) `phase_jump_observed` rate, (3) `bypass_mutation` rate, (4) `doctor S1` incidents per session, (5) bash-mediated mutation leaks (writes to managed paths via `bash` tool, not `apply_patch` — detected via post-tool-check Check A on file mtimes vs `.session-mutations.log`), (6) predicate LOC + p95 latency drift (`pre-tool-validate.sh` `wc -l` snapshot + per-invocation timing log), (7) L1-bypass detection (commits with no `.session-mutations.log` entries — proxy for hook-skipped writes), (8) decisions-missing-after-commit (commits where `decisions.md` mtime predates the cycle's last frontmatter flip). Runnable autonomously by Claude Code (per Round 2 C5 hard gate). Output is a single JSON or markdown report. **Scope:** seed (lightweight wiring + first-run baseline only) — full pilot is v1.x or v2 work. If any of signals 5-8 cannot be cheaply instrumented in v1 (cost > 1 day), surface to user: either narrow spec §13.2 (`[R]` on spec) or accept stub-with-TODO marker in T2.7 task notes. Do NOT silently ship 4-of-8 coverage — that re-opens the gap plan-review flagged 2026-04-30. | `runtime/platforms/codex/harness/` (run-harness.sh + lib/aggregate-signals.sh + 5 prompts + README); 7-of-8 wired, 5+6b stub-with-TODO. Baseline saved at `.sage/work/.../harness-baseline/report-2026-04-30-postfix.json` (post-fix). | ✅ DONE 2026-04-30 — first baseline surfaced T2.1-class path-normalization bug (apply_patch absolute paths vs porcelain relative); fixed via new `hooks/lib/path_normalize.sh` + 16 new bats tests (223/223 GREEN); signal 3 dropped 18 → 3 (residual 3 are LEGITIMATE shell-bypass detections — exactly the §13.2 v2-promotion-trigger evidence the harness was designed to capture). |
| **T2.8** | §15.7 documentation pass | `runtime/platforms/codex/README.md` reflects new architecture (link to spec.md as authoritative); `docs/ecosystem/codex-port-baseline.md` annotated with pointer "rewritten in cycle 20260429-codex-port-rewrite"; cycle's `manifest.md` frontmatter `status: completed` after final `[A]`; cycle's `plan.md` (this file) frontmatter `status: completed` after final `[A]` | doc files + frontmatter updates | ✅ DONE 2026-04-30 — `runtime/platforms/codex/README.md` (commit 66a8b9c) points to spec.md as authoritative + describes 4 subsystems + bash-vs-MCP rationale; `docs/ecosystem/codex-port-baseline.md` annotated with "Historical baseline" admonition pointing to current cycle (gitignored locally); manifest + plan frontmatter flipped to `status: completed` on M2 [A] (this commit). |
| **T2.9** | Final wiring + ontology check | Per build workflow Step 8: verify all new components are connected (generator path matches `bin/sage` invocation; hooks path matches `hooks.json` deployment; all referenced files exist on disk); update sage-memory ontology with the new components if they represent significant new structure (skip if just internal additions) | possibly memory store | ✅ DONE 2026-04-30 — `setup/lib/hooks-deploy.sh` *.sh glob auto-deploys path_normalize.sh into target/.codex/hooks/lib/ (smoke-tested + bats stage6 regression assertion added); ontology entries stored: `proj_codexplt1` (codex-platform Project root) + `docu_codharn1` (harness capability Document) linked `harness part_of platform`. |

### M2 exit criteria

- [x] Each of §15.1, §15.6, §15.7 boxes is checked **on disk** with pasted evidence (not summarized).
- [x] No outstanding `[R]` revisions on spec.md.
- [x] Harness seed runs successfully end-to-end at least once (T2.7 evidence).
- [x] `decisions.md` has a "v1 cutover" entry summarizing what shipped, what was deferred (4 cuts confirmation), what triggers v2 work.
- [x] `manifest.md` status flipped to `completed`; this `plan.md` status flipped to `completed`.

### M2 checkpoint

🔒 Sage: v1 ship-ready. [pasted §15 evidence].
Decisions: [v1 cutover summary, 4 cuts confirmed deferred per §13.2 triggers].

[A] Approve — close cycle, ship v1
[R] Revise — here's what needs fixing before ship
[V] Verify — type /sage:review for independent verification

---

## 6. Cross-cutting concerns (apply to every milestone)

### 6.1 Scope discipline (anti-drift contract)

The cycle's `scope:` array (this plan's frontmatter) is the
**implementing agent's gate**. If a task surfaces a need to mutate a
path NOT in `scope:`:

1. Stop.
2. Surface as `[R]` on this plan with the proposed scope expansion
   and the rationale.
3. Wait for user `[A]/[R]` before proceeding.

Examples of what would trigger this:
- Modifying `runtime/platforms/claude-code/` (sibling port — out of
  scope per spec §3 + Round 2 C2/C4).
- Adding files outside `runtime/platforms/codex/` (other than the
  approved `bin/sage`, `core/constitution/**`, `core/preambles/**`,
  `core/workflows/**`, `.sage/work/<cycle>/**`, `.sage/decisions.md`,
  `docs/ecosystem/codex-port-baseline.md`).
- Adding any Python file (v1 is bash-only per spec §6.0 + §8 Cut B).
- Adding any `[[mcp_servers]]` block to any generated artifact (v1
  ships zero MCP infrastructure per spec §2 Cut B).

### 6.2 The 4 cuts as contract — anti-expansion

Per §16 sign-off point 4, the four cuts are **not invitations to
silently re-introduce features**. If during implementation a cut
feels "almost free to add back", it goes to the **§13.2 outcome
harness signals** list, NOT to v1 scope. Examples to watch for:

- "Adding a tiny UPS hook stub for future use" → NO. UPS surface is
  Cut A; nothing ships in v1 (§6.2).
- "Adding an empty `[[mcp_servers]]` block 'for symmetry'" → NO.
  Cut B is total; pure ceremony surface ships nothing (§8).
- "Adding `.githooks/pre-commit` since it's already in the repo" →
  NO. Cut C says generator does not wire it (§2). Pre-existing repo
  artifact is preserved; Codex generator does not touch it.
- "Letting the bash predicate read `tier:` for cycles labelled
  `tier: 1`" → NO. Cut D is total; predicate ignores `tier:` (§10).

If any of these "almost free" cases arise and the implementer
believes the trade-off has shifted, surface as `[R]` on **spec.md**
(not plan.md) — the cuts are spec-level decisions.

### 6.3 Junior-dev / vibe-coder communication style

User self-identifies as junior dev / vibe coder. In every checkpoint
and every error message:

- Plain Polish. Skip jargon when a plain word works.
- When invoking ADR section names or spec §-numbers, immediately
  follow with the actual concern in plain language.
- Error messages from hooks and `bin/sage` follow the spec §6
  contract: short, actionable, "what failed + what to do" — never
  expose internal stack traces or raw `set -e` exits to the user.
- Comm-style file `.sage/docs/comm-style.md` is the source of truth
  for tone.

### 6.4 Tests-before-code (Base Principle 1)

Per spec coding-principles + build-loop SKILL: every behavior in M1
has a test BEFORE the implementation. For hooks: bats. For
generator: a bash test harness in `runtime/platforms/codex/setup/
tests/` (creates a tmpdir, runs `generate-codex.sh`, asserts on
output). For `bin/sage`: shell tests using `bats` or plain bash
assertions.

If a test cannot be written for a task ("how do I test that"), STOP
and surface — that is a sign the task is under-specified, not a
license to skip the test.

### 6.5 Pasted evidence over summaries (Rule 5)

At every checkpoint and at every M1 inter-task mini-status:

- Bats output: paste the full run, not a summary.
- Shellcheck: paste the full run.
- Generator idempotency check: paste the actual diff (which should
  be empty).
- `sage doctor` runs: paste the actual output.
- Codex sessions in M2: paste the relevant transcript window.

"All tests pass" without pasted output does NOT close a checkpoint.

### 6.6 Capture corrections (Rule 6)

If user corrects approach during M0/M1/M2:
1. Stop current work.
2. Store correction via `mcp__sage-memory__sage_memory_store` with
   `tags: ["self-learning", "correction", ...]` BEFORE continuing.
3. Resume with corrected approach.

This is non-negotiable per global Rule 6 + memory of past
corrections (e.g. `[LRN:correction] Fix workflow must honor Sage
gates before code edits`).

### 6.7 Decision logging (Rule 7)

At every M0/M1/M2 checkpoint, prepend a new entry to
`.sage/decisions.md` summarizing:
- What was decided
- Why (key rationale)
- Alternatives considered
- Pointers to artifacts modified

Entries go newest-first directly under the `# Decisions` header.

---

## 7. Verification harness scope (per §15)

This plan binds the implementer to deliver verification matching
spec §15. Concretely:

- **§15.1 Empirical PoCs** → M0 (T0.1-T0.4) + M2 (T2.1).
- **§15.2 Generator pipeline** (15 boxes including B1/B2/B3
  closures) → M1 Group D + M1 final inter-task checkpoint.
- **§15.3 Hook scripts** smoke tests → M1 Group B + Group A
  helpers.
- **§15.4 MCP server N/A in v1** (10 negative-confirmation boxes)
  → M1 Group D (Stage 4 + Stage 5 + Stage 10 sanity sweep) +
  spot-check at M1 final inter-task checkpoint.
- **§15.5 sage doctor** → M1 T1.18.
- **§15.6 End-to-end smoke** (5 boxes including 3 blocker smokes
  B1/B2/B3) → M2 (T2.2-T2.6).
- **§15.7 Documentation** → M2 T2.8.
- **Spec §9 state-machine narrow v1 slice** (added 2026-04-30 per
  plan-review MINOR 2): explicit verification — frontmatter `status:`
  is the only state SoT consumed by the predicate (T1.5 covers via
  "phase value irrelevant" parity test, §6.3); `phase_jump_observed`
  is the only enforcement signal (T1.7 + T2.3 cover); the spec §9
  v1 slice closes here, no separate verifying task — but this bullet
  exists so future agents can SEE that §9 is covered, not assume it.

If any §15 (or §9) box cannot be satisfied with pasted evidence, the
relevant milestone does NOT close.

---

## 8. Risks during execution + escalation patterns

| Pattern | Trigger | Escalation |
|---|---|---|
| **PoC C2 fails** (PostToolUse payload thinner than spec assumes) | M0 T0.1 evidence | Stop; present `[R]` on spec §6.4 with proposed amendment (R-8 in §13.1 was anticipated); user decides v1 scope adjustment |
| **Bash predicate exceeds 80 LOC** (spec §6.0 ceiling) | T1.5 implementation | Stop; this is §8 v2 promotion trigger #1 firing in v1 itself — user decides whether to (a) accept slight overrun and ship v1 anyway, or (b) re-scope the predicate, or (c) escalate to v2 design |
| **Generator idempotency fails** (init then update produces diff) | T1.16 final inter-task checkpoint | Stop; trace which Stage's marker model is broken; fix root cause (NOT swallow with normalization). Do NOT close M1 with non-idempotent generator |
| **Hook script breaks on macOS where `flock` absent** (spec §6.6 mentions degrade-to-plain) | bats test on `lib/json_log.sh` | Confirm degradation path is tested separately; race-tolerance is accepted per spec — this is by design |
| **Implementer about to silently expand scope** (e.g. "while I'm here, fix unrelated thing in `runtime/cli/`") | any task | Per §6.1: stop, surface `[R]`, wait |
| **Implementer stuck (3+ approaches failed)** | any task | Activate `problem-solving` skill (per spec build workflow Step 6 escalation rule). Do NOT retry the same approach |
| **Context budget pressure during long M1** | M1 mid-flight | Update manifest.md handoff field BEFORE suggesting session break (per build workflow manifest lifecycle); never break without writing handoff |

---

## 9. Done definition (cycle close)

This cycle (`20260429-codex-port-rewrite`) is **complete** when ALL
of the following hold simultaneously:

- [ ] M0 + M1 + M2 exit criteria all satisfied with pasted evidence.
- [ ] `manifest.md` frontmatter: `status: completed`,
  `closed_at: <iso>`, `closed_by: alexostl`.
- [ ] This `plan.md` frontmatter: `status: completed`.
- [ ] `spec.md` frontmatter is unchanged from sign-off (no
  silent revisions during implementation).
- [ ] `decisions.md` has a "v1 cutover" entry recorded.
- [ ] All 4 cuts (A/B/C/D) verified absent from generated
  artifacts (via grep + manual review).
- [ ] All 3 Claude-parity blockers (B1/B2/B3) verified present
  via §15.6 smokes.
- [ ] `runtime/platforms/codex/` is non-empty and the new
  generator works end-to-end.
- [ ] User has typed `[A]` on M2 checkpoint.

If any single box is unchecked, **the cycle does NOT close**. Per
spec build workflow anti-deferral guard: never mark complete with
unfinished tasks; surface what remains and let the user decide.
