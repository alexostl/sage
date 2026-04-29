# Stream A — Codex Port Initiative Retrospective

**Source:** Explore subagent over `.sage/work/` and `.sage/decisions.md` (main worktree at `/Users/alexostl/Developer/sage-selfhost/`).
**Scope:** chronological retrospective of every Codex-related initiative; what was tried, what reverted, what conclusions were captured.
**Parent:** `research-codex-port-rewrite-base.md`.

---

## Timeline (chronological, oldest first)

### 20260423-codex-enforcement-gap-fix
- **Problem it tried to solve:** Codex adapter did not enforce Sage methodology with the same rigor as Claude Code; agents treated framework as inspiration rather than mandatory process.
- **Hypothesis / approach:** Use Codex-native `UserPromptSubmit` gate hook for runtime pre-turn gating; rewrite `AGENTS.md` for salience under single-load model; inject outcome-focused PREAMBLE into workflow skills to enforce observable compliance signals (spec/plan checks, root-cause presentation, memory search before design).
- **What was implemented:** Five artifacts: `runtime/platforms/codex/hooks/pre-prompt.sh` (UserPromptSubmit gate matching build/fix/architect keywords), rewritten `AGENTS.md` with imperative rules, workflow skill PREAMBLE injection in generator, `hooks.example.json` wiring, `HOOKS.md` documentation of gate behavior. Strategy split into Tier 1 (UserPromptSubmit + AGENTS.md + session-start hook + skill PREAMBLE) and deferred Tier 2 (guardian_approval subagent).
- **Outcome:** Shipped to both `self-host/main` and `codex-port` branches via dual-commit pattern. Verification file added retroactively (verification.md completed 2026-04-24). AGENTS.md under 32 KiB budget (12.4 KB); 16/16 workflow skills received PREAMBLE; regression tests passed. Per decisions.md v2 plan superseded v1 by adopting Codex-native mechanisms instead of Claude parity.
- **Stated reason for outcome:** Plan v2 explicitly rejected line-count calibration as a proxy; shifted to outcome-driven framing of observable compliance signals. v1 approach of copying Claude patterns was discarded after reading Codex docs for native mechanisms.
- **Surfaces touched:** `runtime/platforms/codex/setup/generate-codex.sh` (AGENTS.md heredoc rewrite, workflow skill PREAMBLE loop), `runtime/platforms/codex/hooks/pre-prompt.sh` (new, S1 UserPromptSubmit gate implementation), `runtime/platforms/codex/hooks/session-start.sh` (S3 rich context port from Claude), `runtime/platforms/codex/hooks.example.json` (hook event wiring), `runtime/platforms/codex/HOOKS.md` (documentation).

### 20260424-codex-command-prefix-parity
- **Problem it tried to solve:** Codex generator did not read or apply `command_prefix: true` from `.sage/config.yaml`; Claude surfaces honor the setting but Codex surfaces remained unprefixed, creating port parity mismatch.
- **Hypothesis / approach:** Read `command_prefix` from config in generator; apply token-aware prefix rewrites to generated Codex skill directories, frontmatter `name:` fields, AGENTS.md guidance, and in-skill workflow references; keep `sage` unprefixed as exception, keep native `/review` untouched.
- **What was implemented:** Generator changes to `runtime/platforms/codex/setup/generate-codex.sh` to read config and apply prefix matrix; extended regression test harness to cover default/false, true, and absent scenarios with assertions on unprefixed/prefixed behavior consistency.
- **Outcome:** Shipped. Regression harness passes for default behavior (unprefixed), prefixed behavior, and missing-config regeneration paths. Decisions.md notes Claude as the source of truth for porting conventions.
- **Stated reason for outcome:** Simple artifact parity fix driven by upstream convention. Manifest explicitly states "Claude is the source of truth for Codex port conventions unless the user explicitly decides otherwise."
- **Surfaces touched:** `runtime/platforms/codex/setup/generate-codex.sh` (config read, prefix application), `runtime/platforms/codex/tests/run-regression.sh` (extended coverage).

### 20260424-codex-enforcement-gate-revision
- **Problem it tried to solve:** Review of 20260423 delivery found five bugs in the UserPromptSubmit gate: (C1) global `any_initiative_has()` scope caused gate to passthrough after first initiative matched; (M2) fix-keyword regex over-blocked Tier 1 operations like "fix typo"; (M3) verification.md missing from 20260423 (Rule 5 violation); (M4) regression harness depended on ripgrep (`rg`), not available on clean macOS; (M5) `$skill` passthrough whitelist incomplete, missing `$status`, `$learn`, `$map`, etc.
- **Hypothesis / approach:** (C1) per-initiative status-aware gate checking each active initiative for spec+plan, not global passthrough; (M2) Tier 1 fix passthrough with `TIER1_FIX_RE` pattern for surgical operations; (M5) pattern-based `$skill` whitelist `^\s*[$/][a-z][a-z0-9-]*`; swap `rg -Fq` → `grep -Fq` for POSIX portability.
- **What was implemented:** Rewrote `runtime/platforms/codex/hooks/pre-prompt.sh` gate logic (per-initiative checks, Tier 1 passthrough, pattern-based skill whitelist), swapped regex dependency in `tests/run-regression.sh`, created retroactive `verification.md` for 20260423, updated `HOOKS.md` with new gate semantics and skill passthrough list. Defined "Tier 1 fix" as typo/indent/whitespace/formatting/rename/comment/logging operations.
- **Outcome:** Shipped. 13 smoke scenarios verified (S1–S13 covering build blocks, Tier 1 passthrough, skill prefix routing). Regression harness passes on clean macOS without ripgrep. AGENTS.md still under 32 KiB. All 5 findings from review closed with evidence.
- **Stated reason for outcome:** Verification plan notes gate logic "overfitted to happy path of first initiative and shut down realistic usage patterns." Reopening the fix was necessary to close Rule 5 compliance on 20260423 itself.
- **Surfaces touched:** `runtime/platforms/codex/hooks/pre-prompt.sh` (gate rewrite), `runtime/platforms/codex/tests/run-regression.sh` (ripgrep swap), `runtime/platforms/codex/HOOKS.md` (updated gate docs), `.sage/work/20260423-codex-enforcement-gap-fix/verification.md` (retroactive creation).

### 20260424-codex-enforcement-hybrid-levers
- **Problem it tried to solve:** Codex enforcement visibility was fragmented across four independent mechanisms (pre-prompt gate, verification shape, close-out script, pre-commit hook). No shared validator existed, causing divergent rules and manual testing burden. Need a unified enforcement architecture with single source of truth for verification shape.
- **Hypothesis / approach:** Four-lever bundle: L1 sticky context (inject active initiative state every turn), L2 verification.md template + validator (canonical shape rules), L4 sage-close script (atomic close-out with dual-branch commit), L5 pre-commit hook (shape validation at commit time). Shared validator `verification_check.py` as single source of truth for L2/L4/L5.
- **What was implemented:** Plan drafted (not full implementation in this window) defining 9 tasks: test fixtures builder, validator (`verification_check.py`), verification template, L1 sticky context integration, L4 sage-close script, L5 pre-commit hook, install ergonomics, path convention documentation, end-to-end self-close test. Identified path layout convention: `runtime/platforms/codex/hooks/lib/` for platform-specific, `bin/sage-close` for generic, `.githooks/` for hook scripts.
- **Outcome:** Spec and plan documents completed to `APPROVE-WITH-NOTES` status. Full implementation not completed in this cycle; marked as foundation for later milestones. Reviewer noted risks around sticky-context dilution, sage-close partial failure, and PreToolUse regression.
- **Stated reason for outcome:** High-effort initiative requiring rigorous test-first discipline per Base Principle 1. Planned in dependency order so validator lands first and all four levers use it from day one. Deferred full implementation but established architecture and risk mitigation strategy.
- **Surfaces touched:** Documentation/planning only: `spec.md`, `plan.md`, manifest; no shipping code in 20260424 (setup for later milestones M1/M2/M3).

### 20260428-codex-enforcement-activation-brief
- **Problem it tried to solve:** Three misalignments in Codex port enforcement: (1) framework files on disk vs runtime activation were treated as equivalent but are not; (2) `deploy_direct_skills: false` was described as GUI-only hiding but in Codex it also affects native skill availability; (3) `sage update` did not explicitly activate hooks despite `codex_hooks = true` existing in config.
- **Hypothesis / approach:** Activate three layers: L4 UserPromptSubmit gate (build/fix/architect intent classification via regex keywords), L5 pre-commit hook (commit-time verification gate), M3 behavioral isolation of direct skills via per-skill `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. Pre-flight M0 included SHA256 versioning, atomic JSON merge with backup, fixture construction.
- **What was implemented:** Milestones M0, M1 (hook activation pipeline), M2 (githooks policy + `--force-githooks` flag), M3 (behavioral isolation per direct skill with YAML). 78/78 unit tests PASS across all milestones. Generator deploying all artifact types idempotently; `sage status` reporting enforcement state in 5 levels (DISABLED/DORMANT/ACTIVE/MISCONFIGURED). Bulk deploy demo: 34/34 direct skills with yaml isolation, 17 workflow skills reactive. Full manifest/spec/plan/verification cycle completed with signed-off decisions (ADR-1 through ADR-4 v3).
- **Outcome:** Reverted (commit a6f1391). Empirical dead end — first real-world test failed catastrophically.
- **Stated reason for outcome:** Postmortem 2026-04-29 provides definitive analysis: regex keyword classifier fundamentally broken. Polish user prompt "chce zbudowac prosty to do app" (want to build a simple todo app) did not match English BUILD_RE pattern (`build|implement|create|...`), so hook silently emitted passthrough. Codex built feature without Sage routing, spec, plan, or checkpoints — exact failure mode L4 was designed to prevent. Root cause is not a missing word in list but structural: every regex keyword classifier has silent bypass modes (typos: `buidl`, `creat`; synonyms: `knock together`, `spin up`; other languages: anything outside English; slang/abbreviations). Patch-then-test is reactive; failure is silent (indistinguishable from "no gate"). Decision.md documents: "regex-classifier as dead end" + "outcome vs proxy calibration error." Process lesson: pilot empirical test cannot be deferred to user after close-out — must be gate #N+1 before tombstone commit.
- **Surfaces touched:** `runtime/platforms/codex/hooks/pre-prompt.sh` (regex intent classifier — reverted), `.githooks/pre-commit` (L5 wiring — reverted), `runtime/platforms/codex/setup/generate-codex.sh` (yaml isolation emit — reverted), various `.sage/work/20260428-*` planning artifacts (retained as historical trace).

### 20260428-sage-init-hooks-ergonomics
- **Problem it tried to solve:** L5 pre-commit hook was broken for cross-project use: (A) `.githooks/` lived only in framework repo, not copied to downstream projects by `copy_framework`; (B) hook hardcoded path `REPO_ROOT/runtime/platforms/codex/hooks`, which broke after `sage init` when validator moved to `<project>/sage/runtime/platforms/codex/hooks/`; (C) no `install-hooks` subcommand, no auto-wiring in `sage init`, no nudge for users.
- **Hypothesis / approach:** Path-flexible hook resolution (search list: downstream layout first, fallback to framework layout); auto-wire on `sage init`/`sage update` (copy hook if missing, set `core.hooksPath` if unset); first-run nudge (one-line stderr message once per minute via `/tmp/sage-hooks-nudge.<repo-hash>` marker); new `sage install-hooks` dispatcher command.
- **What was implemented:** Five files: `.githooks/pre-commit` (path-flexible search logic), `bin/sage` (new `ensure_hooks_wired()` function, auto-call in `sage_init`/`sage_update`, dispatcher nudge prelude, new `install-hooks` case), `bin/sage-install-hooks` (thin wrapper delegating to `bin/sage install-hooks`), extended `test_pre_commit_hook.sh` (+2 cases for downstream/neither layout), new `test_sage_init_hooks.sh` (end-to-end init wiring test).
- **Outcome:** Shipped and completed (closed via commit 2f90d2d per git log). Status marked as completed with plan fully executed. Regression on `pre-commit` test suite: +2 new cases added, all 10 passing. End-to-end smoke on the self-host repo itself verified hook wiring works.
- **Stated reason for outcome:** Successfully addressed all three root causes. Auto-wiring is non-breaking (skips silently when not git repo or when `core.hooksPath` already custom). First-run nudge is optional (opt-out via `SAGE_HOOKS_QUIET=1`). Backward-compatible with framework layout (existing tests still pass).
- **Surfaces touched:** `.githooks/pre-commit` (path resolution), `bin/sage` (auto-wire + nudge), `bin/sage-install-hooks` (delegation), `runtime/platforms/codex/hooks/tests/test_pre_commit_hook.sh` (new cases), `runtime/platforms/codex/hooks/tests/test_sage_init_hooks.sh` (new file).

### 20260429-codex-port-architecture-redesign
- **Problem it tried to solve:** Codex port carries too many Claude-shaped workarounds; regex-based activation failed empirically (dead end postmortem 20260428). Need complete refactor around Codex-native surfaces: compact `AGENTS.md`, public-only workflow skill UI, internal lazy-loaded library, explicit workflow state machine, mutation guardrails on best-effort PreToolUse + backstops (pre-commit, Stop), two enforcement profiles (fast-trusted for Skip Permissions, strict for sandbox/permissions).
- **Hypothesis / approach:** Six-layer architecture: static contract (AGENTS.md), public workflow surface only, internal Sage library (lazy-loaded), workflow state machine (phase/gate validator), runtime context/guardrails (SessionStart, UserPromptSubmit micro-router ≤200 tokens, PreToolUse write/edit blocks, PostToolUse/Stop), backstops (pre-commit, status, outcome-driven pilots). Explicit requirement: no regex intent classifier as source of truth. No semantic subagent gate. No full internal skill exposure.
- **What was implemented:** Brief.md (problem statement, design questions, candidate solution directions), spec.md (architecture overview, six layers, session/turn/mutation/recovery lifecycle, constraints), manifest.md (status: in-review). Eight decision docs drafted (ADRs on layered runtime, workflow state machine, approval proof, instruction surface split, public/internal skill model, enforcement profiles, mutation guardrail stack, outcome-driven verification). No shipping code yet.
- **Outcome:** In-review phase (checkpoint awaiting [A]/[R]/[S]). Marked as deliberate complete architectural refactor, not incremental patch. Rewrite allowed to reorganize AGENTS.md, .agents/skills, .codex/config.toml, hooks, generated docs, status checks as needed. Status: pending user design approval before plan phase.
- **Stated reason for outcome:** Decision.md notes (2026-04-29) framing shift: "Codex port musi być projektowany pod natywne Codex surfaces, nie jako kopia Claude workaroundów" (must be designed for native Codex surfaces, not as copy of Claude workarounds). Key architectural constraint: cannot rely on approval prompts in Skip Permissions; enforcement must be behavioral guardrail + backstops, not hard filesystem boundary. User-formulated outcome rule: "perspektywa zmiany pliku w repo = sage" (perspective of file change in repo = Sage).
- **Surfaces touched:** Planning only: `.sage/work/20260429-codex-port-architecture-redesign/{brief,spec,manifest}.md` + eight ADR docs in `.sage/docs/decision-codex-*.md`.

### 20260423-branch-worktree-operating-model
- **Problem it tried to solve:** Repository had conflicting branch/worktree use: `upstream/main` 5 commits ahead of fork's main; `codex-port` for shared integration; `cap/self-host-framework` for local changes; daily work and upstream PRs bleeding into each other.
- **Hypothesis / approach:** Establish predictable model: one local worktree for active self-host work, separate worktree for `codex-port` integration, separate for clean upstream mirror, temporary worktrees for upstream fixes. Define update chain: upstream → fork mirror → integration → self-host.
- **What was implemented:** Brief.md and manifest.md documenting the operating model and constraints. No code changes; this is a coordination/workflow planning initiative.
- **Outcome:** Completed (planning artifact). Identifies gaps around remote self-host branch publication decision and long-term rebase vs merge strategy. Recommends promoting branch/worktree rules into `.sage/docs/` after model proves stable.
- **Stated reason for outcome:** Planning-phase deliverable to establish organizational structure for the other Codex initiatives. Provides foundation for understanding why `20260423-codex-enforcement-gap-fix` uses dual-branch (self-host/main + codex-port) commit pattern.
- **Surfaces touched:** Documentation/planning only (no code): brief.md, manifest.md, plan.md, spec.md.

### 20260428-sage-codex-to-selfhost-rename
- **Problem it tried to solve:** Semantic clarity: repository renamed from sage-codex to sage-selfhost in git log and documentation, reflecting that this is the user's self-hosted Sage instance, not merely a Codex port artifact.
- **Hypothesis / approach:** Update references in git history notes, CLAUDE.md, README, and framework knowledge to use sage-selfhost terminology consistently.
- **What was implemented:** Documentation updates and git log entry (commit 41dbe5d per log). Renaming is primarily a naming/clarity change, not a feature change.
- **Outcome:** Shipped. Per decisions.md (2026-04-29): "docs: rename sage-codex → sage-selfhost in active project knowledge."
- **Stated reason for outcome:** Semantic accuracy for an operator repo. Downstream projects like alex-os-dev reference this repo; clarity in naming prevents confusion.
- **Surfaces touched:** Documentation/git history (no code logic changes).

## Cross-cutting failure patterns

1. **Regex-based intent classification is structurally blind** — Affects: 20260428-codex-enforcement-activation-brief (empirical dead end). English-only keyword lists cannot catch Polish prompts, typos (`buidl`), synonyms outside the list (`knock together`), slang, passive voice, or other languages. Every bypass is silent (hook emits passthrough, no signal). Declared dead end in postmortem; all future L4 gates must use non-keyword mechanisms.

2. **Unit test green does not imply outcome success** — Affects: 20260428-codex-enforcement-activation-brief (78/78 PASS but real test failed). Testing hook mechanics (does regex block when matched?) is not the same as testing real-world compliance (does user stay in Sage on first Polish prompt with typo?). Postmortem explicitly states: "Kalibracja sukcesu była proxy-driven, nie outcome-driven." Process rule captured: behavioral outcome tests must gate before close-out, not deferred to user.

3. **One-time session-load constraints force salience vs duplication tradeoff** — Affects: 20260423-codex-enforcement-gap-fix (AGENTS.md strategy shift). Codex injects AGENTS.md once per session, not per turn, unlike Claude. Means rules must be tight and scannable to stay salient. Plan v2 rejected v1's "port all Antigravity PREAMBLE 1:1" and instead wrote outcome-driven, imperative-voice rules for each observable behavior needed.

4. **Codex hook feature availability and stability are undocumented** — Affects: 20260423-codex-enforcement-gap-fix, 20260428-codex-enforcement-activation-brief, 20260429-codex-port-architecture-redesign. `codex_hooks` flag described as experimental; `UserPromptSubmit` works but details on how long input is matched are sparse; `PreToolUse` documented as guardrail, not hard boundary; no standard for hook merge logic when user has custom hooks. Decisions.md note (2026-04-24): "Codex docs flaga eksperymentalna, user musi opt-in." Assumption that hooks are stable enough to be the main enforcement layer proved risky.

5. **Dual-branch merge complexity under-tested until late** — Affects: 20260424-codex-enforcement-hybrid-levers, 20260428-codex-enforcement-activation-brief. Design assumes sage-close can atomically commit and merge between `self-host/main` and `codex-port` with deterministic result, but merged-during-divergence scenarios, revert-commit semantics, and dual-push-failure handling are complex. Postmortem 20260428 notes this as a risk but implementation never reached the point of discovering concrete failure modes.

6. **Generator must handle both framework repo and downstream layouts** — Affects: 20260428-sage-init-hooks-ergonomics (cross-project hook wiring). Framework layout (`runtime/platforms/codex/hooks/`) is where generator runs; downstream layout (`.sage/runtime/platforms/codex/hooks/` after copy_framework) is where deployed projects find validators. All three: hooks, validators, docs, and tests must account for both. Early 20260428 iterations hardcoded one path and failed on the other.

## Verdicts already on record

### From plan.md and spec.md documents

**20260423-codex-enforcement-gap-fix v2 plan (line 59-65):**
> "v1 myślał: 'skopiuj Claude pattern, adaptuj do Codex surface'. v2 myśli: 'Codex ma inne levery niż Claude. Użyj tych których Claude nie ma (UserPromptSubmit gate), i dostosuj tekst do faktu że AGENTS.md jest loaded **once per session, not per turn**.'"

**20260428-codex-enforcement-activation-brief postmortem (verdicts, 2026-04-29):**
> "**Mechanizm enforcementu oparty na klasyfikacji prompta przez regex słów-kluczowych jest strukturalnie niezdolny do działania.** Nie ma takiej listy słów, która pokryje wszystkie języki, wszystkie literówki, wszystkie synonimy i wszystkie sposoby wyrażania intencji."

> "Regułę do zapamiętania: Klasyfikator regex w `runtime/platforms/codex/hooks/pre-prompt.sh` (BUILD_RE/FIX_RE/ARCHITECT_RE) jest anglojęzyczny i zamknięty."

**20260428-sage-init-hooks-ergonomics plan (line 22-39, root causes):**
> "L5 from functioning cross-project: (A) `.githooks/` lives at framework repo root. `copy_framework` only copies `sage/`. Downstream projects after `sage init` never receive the hook."

**20260429-codex-port-architecture-redesign brief (success criteria, line 162-177):**
> "A successful follow-up cycle should produce: (1) A spec that clearly defines what 'enforcement active' means for Codex... (2) A decision on hook activation policy for `sage-selfhost` vs `codex-port` / upstream. (3) A decision on narrow palette semantics: cosmetic, behavioral, or accepted hybrid... (4) Implementation that can be verified by a fresh consumer fixture, not only by reading generated files."

**Decision.md entry 2026-04-29 (Codex enforcement activation revert, verdict line 65-97):**
> "**Werdykt:** cykl ... **(M0+M1+M2+M3, 78/78 testów PASS, commits 28b0782 + 03dfee3) revertowany do baseline 443a7c8 po empirical outcome failure** na pierwszym realnym teście... Codex zbudował feature (index.html/styles.css/app.js) bez `/sage` routingu, bez spec/plan, bez checkpointów — **dokładnie failure mode który L4 miał blokować**."

## Open questions left dangling

1. **Regex intent classification replacement mechanism** — Postmortem identifies four candidate directions (A: default-block inversion, B: Codex self-classification, C: PreToolUse gate on file mutation instead of intent, D: park L4 entirely, rely on L5 pre-commit only). User-formulated outcome rule: "perspektywa zmiany pliku w repo = sage." None explicitly decided. 20260429 brief notes this is the key open question for architect phase.

2. **Hook activation policy for sage-selfhost vs upstream** — Brief 20260428 poses: "Should `sage init` copy Codex hook starter pack automatically or require explicit project-level opt-in?" Current state: `codex_hooks = false` in upstream generator, self-host manually wires. No explicit decision on whether self-host should auto-activate or require user action.

3. **Narrow skill palette semantics** — Brief 20260428 questions: "Is `deploy_direct_skills: false` purely cosmetic (GUI hiding) or does it change native skill availability?" In Codex, `.agents/skills/` is both the UI list and native availability surface, so hiding is not purely cosmetic. M3 attempted to solve via yaml isolation, but postmortem notes "fallback plan = re-open ADR-4" if yaml is ignored by Codex. ADR-4 v3 in spec 20260428 deferred visual palette ordering (zz-sage- prefix) to separate cycle. Current status: behavioral isolation deployed (reverted with M3), visual paltte ordering not attempted.

4. **sage-close atomic merge safety** — Spec 20260424-codex-enforcement-hybrid-levers (spec.md line 84-87) describes L4 sage-close performing "commit on self-host/main, merge into codex-port, push both" but never tested the failure modes (what if codex-port has diverged? what if merge conflicts? what if push #2 fails after push #1 succeeds?). Marked as high-risk in spec but full implementation never reached to discover concrete issues.

5. **Dual-branch operating model durability** — Brief 20260423-branch-worktree-operating-model (gaps, line 36-44) asks: "Whether the user eventually wants to publish a remote self-host branch or keep it local-only for now. Whether the longer-term relationship between codex-port and self-host work should remain merge-based or later be cleaned up via rebase once the model is stable."

6. **Verification pilot corpus for behavioral outcome tests** — Spec 20260429 (open questions, line 162-177) asks for "likely 12-15 prompts covering casual chat, read-only analysis, Polish build requests with typos, fix, architect, explicit workflow invocation, invalid writes, valid writes, and optional temp writes." None yet drafted or run; postmortem 20260428 emphasizes this must be gate #N+1 before close-out, not deferred.

7. **What is the exact public workflow skill list and naming contract?** — Brief 20260429 (line 164-165) lists as open design question. Current practice: ~16 workflow skills (build, fix, architect, research, design, analyze, reflect, continue, qa, map, autoresearch, design-review, status, review, learn, sage-navigator wrapper). No explicit documented contract on whether this is stable or extensible.

8. **Where should the internal skill manifest live if shared across platforms?** — Brief 20260429 (line 166) notes this is open. Currently Codex has its own `.agents/skills/` deployment; Claude has its own. No shared manifest exists yet, and the cost of cross-platform coordination is unknown.

---

**Total initiatives analyzed: 9**
- Shipped/completed: 6 (20260423 gap fix, 20260424 command-prefix, 20260424 gate revision, 20260428 init hooks, 20260423 branch model, 20260428 rename)
- Reverted/dead-end: 1 (20260428 enforcement activation — empirical failure)
- In-progress/in-review: 2 (20260424 hybrid levers — spec/plan complete, not implemented; 20260429 architecture redesign — brief/spec drafted, awaiting design approval)

**Total git commits touching Codex enforcement:** ~20 related commits in the log shown, with the most significant being the revert (a6f1391) and the pre-revert milestones (28b0782, 03dfee3, 9017249).
