---
title: "Spec: Codex operating model v1.1"
workflow: architect
phase: design
status: completed
created: 2026-05-07
updated: 2026-05-07
cycle_id: "20260507-codex-operating-model-v11"
related:
  - ".sage/work/20260507-codex-operating-model-v11/brief.md"
  - ".sage/docs/decision-codex-v11-layered-operating-model.md"
handoff: |
  Key decisions: propose workflow but wait for confirmation on broad-scope
  prompts; show active plus paused/intake work in status; route artifacts
  deterministically without storage questions; prefer recovery-first safe
  auto-fix for reversible state/metadata issues; use a conservative-autonomous
  Capture Router with minimal intake cycles for unsure actionable findings;
  verify agent/runtime behavior with risk-based real Codex harness checks.
  Open questions: exact bootstrap repair surface, status vs doctor split for
  documentation-routing warnings, when review/capture should auto-create intake
  manifests, minimum real Codex harness suite, and whether Bash interception
  expands beyond audit.
  Risks: hook overreach can block legitimate design work; hook underreach can
  overpromise enforcement; Capture Router can create noisy intake if too broad;
  shallow research can harden wrong assumptions.
  Next agent should: run ADR/spec auto-review, address or record findings, then
  create the milestone plan only after the design checkpoint is accepted.
---

# Spec: Codex operating model v1.1

## Purpose

Codex operating model v1.1 defines how Sage should behave inside Codex after
the first fieldwork cycle. It is not an upstream PR readiness pass. It is a
reconciliation of five benchmark sources:

1. Official OpenAI/Codex documentation.
2. Original Sage framework documentation.
3. Current Codex v1 implementation.
4. First-days fieldwork findings.
5. Generated agent instruction surfaces.

The goal is to give the agent a clear next legal move at every workflow and
artifact boundary, while keeping ordinary conversation lightweight.

## Source Basis

Primary sources checked directly during design:

- Official Codex docs for `AGENTS.md`, config, hooks, sandboxing, slash
  commands, cloud task execution, and best practices.
- `README.md` project-state sections.
- `docs/philosophy/project-state-convention.md`.
- `docs/philosophy/design-philosophy.md`.
- `core/workflows/architect.workflow.md`.
- `core/workflows/status.workflow.md`.
- `core/workflows/continue.workflow.md`.
- `core/workflows/review.workflow.md`.
- `runtime/platforms/codex/setup/lib/agents-md.sh`.
- `runtime/platforms/codex/setup/lib/hooks-deploy.sh`.
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`.
- `runtime/platforms/codex/hooks/turn-audit.sh`.
- `runtime/platforms/codex/hooks/lib/active_init.sh`.
- `runtime/platforms/codex/hooks/lib/bootstrap_check.sh`.

Subagent research remains reconnaissance only. Design decisions below depend on
the primary checks above, not on subagent summaries alone.

## Architecture Summary

Codex v1.1 is a layered operating model:

1. Instruction layer: generated `AGENTS.md` and compact project instructions.
2. Workflow layer: Sage skills and full workflow definitions.
3. State layer: `.sage/work`, frontmatter, manifests, core artifacts, and
   `.sage/decisions.md`.
4. Documentation governance layer: routing rules for `.sage/docs`,
   `.sage/work/<cycle>`, `.sage/work/<cycle>/research`, manifests, and
   decisions.
5. Recovery UX layer: `status`, `doctor`, SessionStart context, and hook
   messages.
6. Guardrail layer: blocking hooks only where Codex can intercept reliably.
7. Audit layer: Stop/PostTool checks for bypasses and suspicious ordering.
8. Verification layer: deterministic tests plus real Codex harness evidence.
9. Deferred integration layer: MCP/workflow-engine work only if a layer gap
   proves current surfaces insufficient.

The governing ADR is
`.sage/docs/decision-codex-v11-layered-operating-model.md`.

## State Model

### Desired Outcome

When the user returns to a project, Sage should show a complete but calm view of
work: active work first, then parked or intake work, each with a clear next
action. The user should not have to reconstruct state from conversation history.

### Cycle States

Codex v1.1 should treat cycle frontmatter as the source of truth.

- `in-progress`: active for mutation, hooks, `status`, and `/continue`.
- `paused`: resumable and visible; not active for mutation until resumed.
- `intake`: valid manifest-only holding state for future work; visible and
  resumable, but not implementation-active.
- `completed` or `complete`: closed; visible in history, not resumable by
  default.
- missing or malformed frontmatter: invalid state; recovery UX must explain
  how to repair or create a manifest-backed cycle.

Current implementation finding: `active_init.sh` only treats
`status: in-progress` as active. That is acceptable for mutation, but
`status` and `/continue` must separately surface paused and intake cycles so
they do not disappear from the user's mental model.

UX decision: `status` and `/continue` should show `in-progress` plus
`paused`/`intake` in separate sections. `in-progress` remains the only
implementation-active state; `paused` and `intake` are visible and resumable,
not mutation-active.

### Manifest Lifecycle

Architect cycles create a manifest when `brief.md` is saved. The manifest is
updated at every checkpoint, session handoff, and completion. For Codex v1.1,
the same lifecycle language must be shared by:

- generated `AGENTS.md`;
- workflow definitions;
- `sage status`;
- `sage doctor`;
- SessionStart context;
- hook recovery messages;
- deterministic tests.

Bootstrap must be robust. Current fieldwork found that creating an empty cycle
directory before writing `manifest.md` can block bootstrap because
`bootstrap_check.sh` only permits first manifest creation when the directory
does not already exist. v1.1 should either permit an empty target cycle
directory or produce a recovery message that teaches the exact fix.

## Documentation Artifact Governance

### Desired Outcome

The user should decide scope and outcomes, not storage mechanics. Agents should
route findings, TODOs, ADRs, research, and checkpoint decisions
deterministically from purpose, without asking where to write the file.

Before writing a documentation artifact, the agent must classify it by purpose.

| Purpose | Location | Notes |
| --- | --- | --- |
| Durable project knowledge | `.sage/docs/*.md` | Analyses, ADRs, durable learnings, runbooks. |
| Initiative deliverable | `.sage/work/<cycle>/*.md` | Brief, spec, plan, QA, review, reflection. |
| Initiative-specific research | `.sage/work/<cycle>/research/*.md` | Discovery that supports one cycle and should not become project-wide truth by default. |
| Actionable TODO or backlog | `.sage/work/<cycle>/manifest.md` or plan artifact | Action belongs to a manifest-backed cycle, not `.sage/docs`. |
| Significant checkpoint decision | `.sage/decisions.md` | Newest-first reasoning log; not a substitute for a manifest. |
| Self-learning/correction | `.sage-memory/*` | Persistent correction or convention used before future work. |

Governance consequences:

- Generated `AGENTS.md` must state the routing rule more sharply than the
  current broad "`work/` or `docs/`" wording.
- `review.workflow.md` currently instructs direct writes of review findings to
  `.sage/decisions.md`. v1.1 should give review/capture a manifest-backed
  route when findings are actionable or process-changing.
- Status and recovery UX should identify misplaced actionable docs when
  practical, but this should begin as audit or warning, not broad blocking.
- Tests should cover at least the most common wrong route: actionable TODOs in
  `.sage/docs` instead of a paused/intake work manifest.

Trade-off: strict blocking for every documentation mistake would create false
positives and slow legitimate knowledge capture. v1.1 should block only when
the wrong route would enable unsafe mutation; otherwise warn, audit, and teach.

Storage questions are not user decisions. If the classification is uncertain
but the item is actionable, the safe fallback is a minimal `intake` cycle with
`needs-triage`, not a question to the user and not a loose `.sage/docs` note.
Sage should ask only when the finding changes scope, priority, product
behavior, risk posture, or which active cycle to continue.

## Surface Map

| Problem | Primary Surface | Supporting Surfaces |
| --- | --- | --- |
| Conversation vs workflow entry | `AGENTS.md`, workflow text | SessionStart, status |
| Active cycle detection | manifest frontmatter | hooks, status, continue |
| Paused/intake visibility | `status`, `continue` | manifest lifecycle docs |
| Missing artifacts before mutation | blocking hook | workflow text, tests |
| Hook bootstrap trap | blocking hook recovery UX | tests, doctor |
| Documentation routing | workflow docs, `AGENTS.md` | status/doctor warnings, tests |
| Review capture | review workflow | manifest, decisions log |
| Cross-repo ownership | `AGENTS.md`, hooks | status, doctor, tests |
| Bash/config bypass limits | audit hook, docs | optional future hook expansion |
| Agent/runtime behavior | real Codex harness | Bats fixture tests |

## Blast Radius

The v1.1 operating model affects these implementation areas:

| Area | Primary paths | Expected impact | Downstream dependency |
| --- | --- | --- | --- |
| Generated Codex instructions | `runtime/platforms/codex/setup/lib/agents-md.sh`, setup tests | Sharpen workflow entry, artifact routing, recovery, and cross-repo wording. | Every regenerated project `AGENTS.md`. |
| Hook deployment/config | `runtime/platforms/codex/setup/lib/hooks-deploy.sh`, `.codex/hooks.json` fixtures | Ensure recovery and audit hooks are installed with the right events. | Project trust and Codex hook feature flag behavior. |
| Blocking hook predicates | `runtime/platforms/codex/hooks/pre-tool-validate.sh`, `runtime/platforms/codex/hooks/lib/*` | Separate fix implementation enforcement from architect/design/doc artifacts; repair bootstrap handling. | `apply_patch` flow, manifest scope checks, artifact-order tests. |
| Audit hooks | `runtime/platforms/codex/hooks/turn-audit.sh` and hook libs | Record bypasses and misplaced/captured findings without overblocking. | Stop hook reports, session mutation logs. |
| Status/continue/doctor workflows | `core/workflows/status.workflow.md`, `core/workflows/continue.workflow.md`, doctor/status implementation if present | Show active plus paused/intake sections and next legal moves. | SessionStart context, user recovery, unattended task resumption. |
| Review/capture guidance | `core/workflows/review.workflow.md`, `core/capabilities/review/*`, navigator/capture text | Route findings through Capture Router rather than dumping actionable work into decisions/docs. | Auto-review, reflect, future intake cycles. |
| Documentation conventions | `docs/philosophy/project-state-convention.md`, generated instruction snippets | Clarify deterministic routing without changing the two-folder Sage convention. | Human docs, future platform adapters. |
| Verification | Codex setup/hook Bats, harness scripts/fixtures under `runtime/platforms/codex/**` | Add fixture coverage and minimal real Codex harness cases for behavior claims. | CI/runtime confidence and release criteria. |

Breaking-change risk should be low for existing completed artifacts because
v1.1 primarily changes future routing and recovery behavior. Existing
misrouted documents or paused/intake manifests should be surfaced as advisory
state first, not rewritten silently.

## Workflow Entry

### Desired Outcome

Users should be able to think out loud without side effects. When a broad scope
is emerging, Sage should recommend a workflow and wait for confirmation. Once
the user confirms work, state moves to disk and workflow gates apply.

Codex v1.1 should preserve the current conversation-first routing:

1. Conversational or read-only question: answer directly unless the user asks
   for a workflow.
2. Explicit workflow command: enter the named workflow and follow its gates.
3. Action mandate: route to the appropriate workflow or ask for confirmation if
   the scope is ambiguous.
4. Borderline prompt: use soft confirmation before creating workflow state.

UX decision: for prompts like "what do we do with this broad scope?", the
default is to propose the likely workflow and ask for confirmation. For direct
mandates like "write the brief", "fix this", or "prepare the plan", the agent
enters the workflow.

After workflow entry, artifact and approval gates are mandatory. The operating
model should keep this distinction visible so Codex does not turn every
conversation into ceremony, but also does not treat conversation as durable
workflow state.

## Review And Capture Flow

### Desired Outcome

Long-running work should leave a complete trail of discoveries without
interrupting the user for administrative placement decisions. Findings should
not vanish into chat, pollute `.sage/docs`, or silently expand the current
scope.

Review/capture must become a first-class flow:

1. Classify the finding: bug, process gap, documentation-routing issue,
   self-learning correction, or future backlog.
2. Route it with the Capture Router:
   - correction -> `.sage-memory`;
   - checkpoint decision -> `.sage/decisions.md`;
   - current-cycle follow-up -> current `manifest.md` or `plan.md`;
   - separate actionable -> new minimal `intake` cycle;
   - durable knowledge, ADR, or analysis -> `.sage/docs`;
   - unsure actionable -> new minimal `intake` cycle with `needs-triage`.
3. Prepend `.sage/decisions.md` only for significant checkpoint reasoning,
   review verdicts, or accepted process decisions.
4. Store corrections in `.sage-memory` when the user corrects the agent or a
   non-obvious recurring pattern appears.

Trade-off: automatic intake reduces lost findings but can create state noise.
v1.1 should keep the first implementation conservative: minimal intake
manifests, clear source links, `needs-triage` when uncertain, and no automatic
scope expansion of the current plan.

UX decision: Capture Router is `conservative-autonomous`. It writes the safest
durable state without asking about storage. It asks the user only when
continuing would require a product, priority, scope, or risk decision.

## Recovery-First Sage Behavior

### Desired Outcome

Sage should keep long unattended tasks moving. If the agent hits a repairable
state or process problem, Sage should perform a safe, reversible fix and
continue. Human interruption is reserved for scope, product, risk, destructive
actions, or genuinely ambiguous ownership.

Every recovery surface should answer:

- what state was detected;
- why it matters;
- what Sage did or what the next legal move is;
- whether the issue is blocking, advisory, or informational.

Recovery surfaces include `status`, `continue`, `doctor`, SessionStart context,
workflow text, generated `AGENTS.md`, blocking hooks, and audit hooks.

### Safe Auto-Fix Policy

Sage may auto-fix without asking when the change is reversible metadata or
state hygiene and does not alter scope, priority, product behavior, or risk.

Examples:

- create or repair a minimal manifest for a clear intake/capture item;
- add missing handoff/frontmatter fields when inferable from the artifact;
- route a deterministic finding/TODO to current cycle or intake;
- show paused/intake cycles in status and pick the only clear `/continue`
  candidate;
- update manifest scope for an obvious same-cycle documentation artifact.

Sage must stop when continuing would alter approved scope, choose among
multiple equivalent active cycles, perform destructive changes, resolve
conflicting instructions, or mutate implementation without approved artifacts.

## Hook Model

Hooks should be honest guardrails:

- Blocking hooks enforce only clear, low-false-positive invariants.
- Hook messages must say what state was found, what safe auto-fix was applied
  if any, and what the next legal move is.
- Hooks must not claim to be a complete security boundary.
- Audit hooks record bypasses and post-hoc ordering issues that blocking hooks
  cannot reliably prevent.
- Hook predicates should be scoped by workflow and phase, not just by count of
  mutated files.

Current live finding: while this architect spec was being prepared,
`PreToolUse[apply_patch]` allowed the first `.sage/docs/decision-codex-v11-*`
ADR, then blocked subsequent design ADR writes with a Moderate+ fix
plan/manifest error. This appears to be over-application of fix artifact-order
logic to architect design documentation. v1.1 should separate "fix
implementation file count" from "architect design artifacts" and include a
regression test for this exact path.

## Migration Path

v1.1 should roll out in compatibility-preserving order:

1. **Contract and wording baseline.** Update workflow docs and generated
   `AGENTS.md` wording for workflow entry, deterministic artifact routing,
   recovery-first behavior, and cross-repo ownership. Add deterministic tests
   before changing hook behavior.
2. **Status/continue visibility.** Teach status/continue to display
   `in-progress`, `paused`, and `intake` separately with next actions. This is
   read-only and can ship before any blocking behavior changes.
3. **Capture Router convention.** Update review/navigator guidance so findings
   route to memory, current cycle, intake, docs, or decisions. The first
   implementation creates minimal intake only for actionable findings outside
   current scope; it does not rewrite existing docs.
4. **Hook predicate repair.** Narrow Moderate+ fix artifact-order enforcement
   so architect design artifacts and same-cycle documentation writes are not
   misclassified as implementation. Fix empty-cycle bootstrap recovery. Add
   regression tests for both before changing deployed hooks.
5. **Recovery-first safe auto-fix.** Add safe auto-fix only for reversible
   metadata/state hygiene after status/capture tests exist. Each auto-fix must
   log what it changed and why.
6. **Risk-based real harness.** Add minimal real Codex scenarios for workflow
   entry, blocked mutation recovery, Capture Router intake, safe auto-fix, and
   cross-repo ownership. Treat harness failures as release blockers for
   behavior claims, not for unrelated text-only changes.

Compatibility rules:

- Existing active cycles remain valid; no migration may mark user work
  completed, delete artifacts, or silently expand scope.
- Existing `.sage/docs` files are not moved automatically. Misplaced
  actionable docs become advisory findings or intake candidates.
- New blocking behavior must be preceded by fixture tests and recovery text.
- If hook behavior is uncertain, ship audit/warning first and promote to block
  only after a real failure mode is understood.

Known breaking-change candidates:

- A previously hidden `paused` or `intake` cycle will become visible in status.
  This is intentional and informational.
- Hooks that previously overblocked architect/doc writes will become less
  strict for those paths.
- Capture Router may create new minimal intake manifests for unrelated
  actionable findings; those manifests must be low-noise and easy to close.

## Cross-Repo Ownership

The edited repository owns workflow state, scope, and gates. If a task begins
in `sage-selfhost` but implementation belongs in another Sage-managed repo, the
agent must switch to that repo's project instructions, `.sage/work`,
`.sage-memory`, hooks, and status. `sage-selfhost` may contain durable
framework-level analysis, but it must not impersonate the target repo's active
cycle.

Trade-off: this is more explicit than sharing a single central manifest, but it
keeps verification, scope, and recovery tied to the files actually being
changed.

## Verification Strategy

### Desired Outcome

The project should not confuse text coverage with behavior coverage. Most
changes should stay fast through deterministic tests, but agent/runtime UX must
earn confidence through real Codex harness checks.

Deterministic tests should cover:

- generated `AGENTS.md` wording for routing, artifact governance, and
  manifest lifecycle;
- hook predicates for active, paused, intake, missing, and malformed cycle
  states;
- bootstrap behavior for empty cycle directories;
- architect ADR/spec writes without Moderate+ fix false positives;
- status visibility for active, paused, and intake cycles;
- review/capture routing guidance;
- cross-repo scope ownership wording and hook behavior.

Real Codex harness checks should cover:

- a conversational read-only prompt does not create workflow state;
- an explicit architect/fix/build prompt creates or resumes the correct
  manifest;
- a blocked mutation receives a recovery message with the next legal move;
- safe auto-fix keeps a long-running task moving when the repair is reversible
  metadata/state hygiene;
- Capture Router creates minimal intake for an unrelated actionable finding
  instead of asking the user or writing a loose `.sage/docs` note;
- a documentation-routing correction is captured in `.sage-memory` and used on
  the next relevant task;
- a cross-repo task uses the target repository's state.

Trade-off: fixture tests are faster and should carry most regression coverage.
The real harness should stay small but mandatory for behavior that depends on
Codex actually following instructions.

UX decision: verification is risk-based. Bats and fixtures are the default;
real Codex harness is required when the claim is about agent behavior rather
than deterministic framework output.

## Reversibility

The layered model is reversible by layer, not as a single big switch.

| Layer | Reversal path | Cost |
| --- | --- | --- |
| Instruction wording | Revert generated `AGENTS.md` templates and rerun `sage update`. | Low; affects future sessions after regeneration/restart. |
| Status/continue visibility | Revert display logic or hide intake/paused behind an option. | Low to medium; state remains on disk. |
| Capture Router | Disable intake auto-capture; keep existing intake manifests as normal paused/intake work or close them manually. | Medium; cleanup may require triage of created intake cycles. |
| Safe auto-fix | Gate auto-fix behind config or downgrade to advisory-only recovery. | Medium; any already-applied metadata fixes remain as normal artifact edits. |
| Hook predicate changes | Revert hook scripts/config and rerun setup/update. | Medium; must preserve tests for the regression that motivated the revert. |
| Real harness requirements | Mark harness cases advisory while keeping deterministic tests. | Low; reduces confidence but does not alter project state. |

Rollback rule: never delete user artifacts as part of rollback. If Capture
Router created intake cycles that later prove noisy, mark them `closed` or
`superseded` with a decision entry instead of removing history.

## Implementation Milestones Preview

The detailed milestone plan should be written only after this spec is approved.
Expected milestone shape:

1. State and manifest lifecycle alignment.
2. Documentation artifact governance and review/capture guidance.
3. Recovery-first safe auto-fix and hook predicate corrections.
4. Status/doctor/continue visibility.
5. Verification expansion, including a minimal real Codex harness suite.

## Risks

| Risk | Mitigation | Owner surface | Verification signal |
| --- | --- | --- | --- |
| Hook overreach blocks legitimate Sage design work. | Scope hook predicates by workflow, phase, and artifact type; add architect ADR/spec regression tests. | Blocking hooks | Bats case for architect design docs after multiple mutations. |
| Hook underreach creates false security for Bash/config mutations. | Keep unsupported paths audit-first and document Codex hook limits. | Audit hooks, docs | Stop/audit test plus explicit limitation in generated guidance. |
| `AGENTS.md` becomes overloaded. | Keep `AGENTS.md` to routing and invariants; push detail into workflow docs and skills. | Generated instructions | Snapshot/grep tests plus size/readability review. |
| Capture Router creates noisy intake cycles. | Minimal manifests, `needs-triage`, source links, no current-scope expansion, easy close/supersede path. | Review/capture workflows | Fixture tests and one real harness capture case. |
| Safe auto-fix changes too much while unattended. | Limit auto-fix to reversible metadata/state hygiene; log every auto-fix; stop for scope/product/risk. | Recovery UX, hooks, status/doctor | Bats for allowed/denied auto-fix classes plus harness smoke. |
| Shallow research fossilizes wrong assumptions. | Treat subagent research as reconnaissance and require primary-source checks for design decisions. | Architect workflow/spec discipline | Source list in spec and review checklist coverage. |
| Cross-repo ownership remains ambiguous. | Edited repo owns state, memory, scope, gates, and recovery; source repo only stores framework-level analysis. | Instructions, hooks, status | Real harness cross-repo scenario. |

## Open Questions For Plan

- Should empty-cycle bootstrap be fixed in `bootstrap_check.sh`, `bin/sage`, or
  both?
- Which documentation-routing warnings belong in `status` versus `doctor`?
- What exact threshold separates same-cycle follow-up from new minimal intake
  in Capture Router?
- What is the smallest real Codex harness set that catches the operating-model
  failures without making every change slow?
- Should Bash mutation interception expand now, or remain audit-only with
  explicit documentation?
