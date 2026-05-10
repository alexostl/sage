---
title: "Spec — Codex port architecture redesign"
workflow: architect
status: rejected-superseded
superseded_by: .sage/work/20260429-codex-port-rewrite/
superseded_at: 2026-04-29
superseded_reason: |
  User decided the redesign cycle was a dead end and chose to rewrite from
  scratch. This spec, brief, and 8 ADRs are preserved as reference / prior
  thinking. They are NOT inputs to the new cycle; the new cycle restarts
  from `claude-port-logic-map` + `research-codex-port-rewrite-base.md` +
  empirical postmortem of M0–M3.
phase: design
created: 2026-04-29
owner: alexostl
brief: .sage/work/20260429-codex-port-architecture-redesign/brief.md
adrs:
  - .sage/docs/decision-codex-layered-runtime-model.md
  - .sage/docs/decision-codex-workflow-state-machine.md
  - .sage/docs/decision-codex-approval-proof.md
  - .sage/docs/decision-codex-instruction-surface-split.md
  - .sage/docs/decision-codex-public-workflows-internal-library.md
  - .sage/docs/decision-codex-enforcement-profiles.md
  - .sage/docs/decision-codex-mutation-guardrail-stack.md
  - .sage/docs/decision-codex-outcome-driven-verification.md
---

# Spec — Codex Port Architecture Redesign

## Goal

Refactor the Codex adapter as a Codex-native Sage product surface. The target
is not a patch to the current regex hook or a Claude parity exercise. The
target is a coherent architecture where user-facing workflow selection,
internal methodology loading, dynamic project state, and mutation guardrails
each live on the Codex surface that fits them best.

## Non-Goals

- Do not recreate Claude Code command semantics if Codex has a better native
  mechanism.
- Do not expose all internal Sage skills in Codex UI.
- Do not rely on regex intent classification as an enforcement source of
  truth.
- Do not claim hard filesystem enforcement in Skip Permissions /
  `fast-trusted` mode.
- Do not modify shared Sage structures unless the design needs a
  platform-agnostic concept.

## Architecture Overview

The refactored Codex adapter has six layers:

1. **Static contract** — compact generated `AGENTS.md`.
2. **Public workflow surface** — workflow-only `.agents/skills`.
3. **Internal methodology library** — lazy-loaded non-public skills.
4. **Workflow state machine** — explicit phase/gate model and transition
   validation.
5. **Runtime context and guardrails** — SessionStart, UserPromptSubmit,
   PreToolUse, PostToolUse, Stop.
6. **Backstops and observability** — pre-commit, status, verification pilots.

## Runtime Model

The Codex port should treat Sage as a layered runtime, not as one giant prompt
or one hook that tries to decide everything.

### Session Lifecycle

At session start, Codex should receive only durable orientation:

- which Sage project is active;
- whether an initiative is already in progress;
- the current phase and next expected gate if derivable;
- the enforcement profile (`fast-trusted` or `strict`);
- pointers to the public workflow skills and shared `.sage/` state.

This layer should not classify the user's next request because no request
exists yet. Its job is to keep the agent from starting from a blank mental
model.

### Turn Lifecycle

On each user prompt, Codex should receive a compact routing nudge. This nudge
is intentionally not a gate of record. It should tell the model:

- classify the turn semantically, not by keyword;
- if the task is Standard+ or mutation-oriented, enter a Sage workflow
  visibly;
- if the task is chat or read-only, continue normally;
- before any write/edit, expect the mutation guardrail predicate to apply.

The nudge has a hard budget of 200 tokens. If it cannot fit, the design is too
complicated and should be simplified instead of expanding this layer.

### Mutation Lifecycle

The first real enforcement point is the model's attempt to mutate project
state. The adapter should evaluate a shared "valid Sage workflow state"
predicate before common write/edit operations. In `fast-trusted`, that result
is a behavioral block/reminder. In `strict`, it can be paired with sandbox and
approval settings to become closer to an execution boundary.

This means casual conversation remains possible. Sage becomes mandatory when
the work crosses from discussion or inspection into changing the repository.

### Recovery Lifecycle

Because hooks can fail open and Skip Permissions removes hard boundaries, the
runtime needs recovery layers:

- `PostToolUse` notices mutation after the fact and redirects the model;
- `Stop` checks whether the turn ended with pseudo-Sage or missing artifacts;
- pre-commit blocks commits that bypassed the interactive flow;
- `sage status` reports the real guardrail state without overstating it.

Recovery is not the ideal path, but it makes failures visible instead of
silent.

### Source Of Truth

`.sage/` remains the source of truth for workflow state. Hooks and status
commands may cache or derive summaries, but they must not introduce a competing
Codex-only workflow state unless the design later explicitly adds a phase
tracker.

## Layer 4 — Workflow State Machine

The Codex adapter needs an explicit workflow state machine in addition to
skill invocation. A skill being selected means "the agent received the
procedure"; it does not prove the procedure is being followed.

The state machine should derive state from `.sage/` artifacts and expose:

- active initiative slug and title;
- workflow;
- phase;
- current gate;
- allowed next actions;
- required artifacts;
- required approval evidence;
- checkpoint footer expected in the next user-facing response;
- whether project mutation is currently allowed.

The state machine should validate three kinds of transitions:

1. **Workflow transitions** — for example `architect` design cannot move to
   milestone planning until design is approved.
2. **Conversation transitions** — for example `[R]` means revise the current
   artifact, not unrestricted continuation or implementation.
3. **Mutation transitions** — for example project code edits require the
   workflow to be in an implementation-allowed phase.

It should produce a structured result:

- `state`: current workflow/phase/gate;
- `allowed_actions`: small list of permitted next actions;
- `blocked_actions`: actions that must not happen yet;
- `required_response_shape`: approval checkpoint, choice, open question, or
  no footer;
- `reason`: concise explanation;
- `recovery`: next action if the agent drifted.

This validator is the missing layer that catches pseudo-Sage even when no file
write happens. It should be consumed by:

- `SessionStart`, to summarize current gate;
- `UserPromptSubmit`, to remind the model of the next permitted move;
- `PreToolUse`, to decide whether a mutation fits the current gate;
- `Stop`, to catch invalid endings such as fake checkpoints or missing
  artifacts;
- `sage status`, to show the same next gate to the user.

The first implementation should avoid a separate state file unless artifact
frontmatter and decision log evidence are insufficient. If a phase tracker is
introduced later, it must be derived from or reconciled with `.sage/` instead
of replacing artifact state.

### Approval Proof

The state machine and mutation predicate must not rely on the model's memory
that a user approved a gate. Approval should be provable from disk.

Approval proof should be represented in two places:

1. **Artifact frontmatter** for machine-readable state.
2. **Decision log entry** for human-readable reasoning and audit trail.

When a user approves a checkpoint, the workflow should update the relevant
artifact frontmatter from `status: in-review` to `status: completed` and add
an approval block:

- `approved_at`: date/time;
- `approved_by`: user identifier when known;
- `approval_source`: conversation checkpoint;
- `approval_gate`: brief, design, plan, root-cause, or final;
- `approval_notes`: optional short summary.

The decision log should record what was approved, why, and any risk accepted.

The validator should treat approval as missing when:

- artifact frontmatter does not show completed/approved state;
- the decision log does not contain a matching checkpoint entry;
- the approval applies to a different workflow phase;
- the approval is only present in chat history, not on disk.

For backwards compatibility, existing artifacts without approval metadata may
be treated as "legacy approved" only when their `status: completed` is already
present and a migration/status command reports that assumption explicitly.
New Codex-port artifacts should use explicit approval metadata.

This makes `[A]`, `[R]`, and `[S]` operational:

- `[A]` marks the gate approved and may trigger independent review where the
  workflow requires it.
- `[S]` marks the gate approved without independent review and logs the risk.
- `[R]` keeps the artifact in review and permits only revision of the current
  artifact or associated ADRs.

## Layer 1 — Compact `AGENTS.md`

Generated `AGENTS.md` becomes a short constitution, not the full Sage
rulebook.

It should contain:

- Sage identity on Codex.
- The public workflow list.
- The rule that Standard+ work routes to a workflow.
- The rule that `.sage/` is the shared state source.
- The rule that write/edit requires valid Sage workflow state.
- The distinction between chat/read-only and mutation work.
- Pointers to workflow skills for full procedures.
- Honest statement that hooks strengthen but do not define the rules.

It should not contain:

- full build/fix/architect gate prose;
- long interaction-zone manuals;
- duplicated hook behavior;
- generated active project state;
- internal skill bodies or long dependency tables.

Target size: small enough to remain salient. The exact token/byte budget should
be set during implementation after measuring current Codex behavior, but the
direction is "constitution + pointers", not "manual."

## Layer 2 — Public Workflow Skills

Only workflow skills are deployed into `.agents/skills` by default. This is the
public UI contract.

Expected public workflows:

- sage
- build
- fix
- architect
- continue
- status
- review
- research
- design
- analyze
- qa
- reflect
- learn
- map
- autoresearch
- design-review

Direct/internal skills are not deployed to `.agents/skills` by default. The old
`deploy_direct_skills` behavior should be replaced or redefined as a debug /
legacy option rather than the normal product path.

Workflow skills remain full Codex skills and keep their enforcement preambles.
They are the only user-facing entry points.

## Layer 3 — Internal Sage Library

Internal methodology skills live outside public `.agents/skills`, likely under
the framework tree (`sage/skills` and `sage/core/capabilities`) or a generated
internal manifest path.

The adapter must provide a metadata-first index with at least:

- internal skill id;
- display label;
- description;
- file path;
- owning workflow(s);
- phase(s) where it may be loaded;
- whether it is required or optional.

The agent should see metadata first and load full internal skill files only
when the workflow phase requires them. This preserves Codex-style progressive
disclosure even though these are no longer native UI skills.

Validation must catch:

- workflow references to missing library skills;
- required phase dependency without a path;
- internal skill path drift;
- accidental public deployment of internal skills.

### Internal Library Loading Model

The public workflow skill is responsible for deciding when to load internal
methodology. Codex should not receive all internal skill bodies at startup or
on every prompt.

The loading sequence should be:

1. Workflow skill is selected explicitly by the user or implicitly by Codex.
2. Workflow skill reads a compact internal library manifest.
3. Workflow skill chooses the internal method needed for the current phase.
4. Agent reads only the selected internal skill file or reference.
5. Agent records in the workflow artifact which internal method materially
   shaped the output when that method is required for auditability.

The manifest should contain enough metadata to choose, but not enough prose to
become the skill body. Descriptions should be short and decision-oriented.

The design should distinguish:

- **public workflows**: user-visible Codex skills, invoked from UI or `$`;
- **internal methods**: agent-loadable Sage methodology, hidden from UI;
- **core capabilities**: reusable lower-level methods referenced by workflows;
- **debug/legacy direct skills**: opt-in compatibility surface, not default.

Internal methods should not use Codex native `skills.config enabled=false` as
the main hiding mechanism, because disabled skills are not available as normal
skills. Hiding from UI and remaining agent-accessible should be implemented by
not deploying them to public `.agents/skills`, then exposing them through the
manifest and file reads.

This preserves the desired UX:

- user sees roughly the 16 workflow choices;
- agent can still use the wider Sage method library;
- token cost stays progressive: metadata first, body only on demand;
- guardrails are not weakened because workflow skills remain responsible for
  loading mandatory internal methods before producing artifacts.

## Layer 5 — Runtime Context

### SessionStart

Purpose: dynamic project state, not static rules.

Payload should include:

- active initiative title/slug/status/phase;
- next gate if derivable;
- recent decisions, capped to a small count;
- whether enforcement profile is `fast-trusted` or `strict`;
- pointer to `AGENTS.md` and public workflows.

It should avoid repeating the full constitution.

### UserPromptSubmit

Purpose: per-turn salience nudge.

Hard cap: 200 tokens.

The prompt should not classify via regex. It should ask the model to classify
the current turn into a small set:

- chat;
- read-only;
- build;
- fix;
- architect;
- continue;
- review;
- qa;
- other workflow.

If Standard+ work is likely, the agent should enter the workflow visibly. If
the request is chat/read-only, it should proceed normally. The nudge reminds
that writes are guarded.

This hook should never become a second AGENTS.md.

## Layer 6 — Mutation Guardrails

### Valid Sage Workflow State

The adapter needs one shared predicate for whether mutation is allowed.
Implementation details belong in the build plan, but the predicate should
roughly cover:

- active initiative exists;
- active workflow matches the mutation class when known;
- required artifacts exist and are approved/completed for the phase;
- internal library dependencies required for the phase were loaded or the phase
  does not require them;
- user approval gate has been satisfied where the workflow requires it.

The predicate must be shared by hooks and status reporting.

### Valid State Contract

The mutation predicate should answer one question:

> Is this repository mutation allowed under the active Sage workflow state?

It should return a structured result, not only pass/fail:

- `allowed`: boolean;
- `profile`: `fast-trusted` or `strict`;
- `workflow`: active workflow if known;
- `phase`: active phase if known;
- `reason`: short human-readable explanation;
- `missing`: list of required artifacts or approvals;
- `recovery`: recommended next Sage action.

The first version should support three classes of mutation:

1. **Sage artifact mutation** — writing `.sage/work`, `.sage/docs`, or
   decision logs as part of the active workflow.
2. **Project implementation mutation** — editing product/framework files.
3. **Diagnostic mutation** — temporary files, logs, snapshots, or generated
   inspection output.

Default policy:

- Chat and read-only tool use do not require valid mutation state.
- Sage artifact mutation is allowed when it advances the active workflow phase.
- Project implementation mutation requires the workflow artifacts and approvals
  required by that workflow.
- Diagnostic mutation is allowed only if it is simple to implement safely; if
  not, v1 should treat it like project implementation mutation.
- Unknown mutation class should fail closed behaviorally in `fast-trusted` and
  fail closed operationally in `strict`.

Workflow-specific minimums:

- `build`: completed/approved `spec.md` and `plan.md` before implementation
  files are changed.
- `fix`: approved root cause before any fix edit; moderate/systemic fixes also
  require a completed/approved `plan.md`.
- `architect`: brief exists before design artifacts; approved design before
  milestone plan; implementation still routes through build gates.
- `continue`: must resolve to a concrete active initiative and inherit that
  initiative's workflow minimums.
- `review`, `analyze`, `research`, `qa`, `status`, `reflect`, `learn`, `map`:
  may write Sage artifacts when the workflow calls for them, but project
  implementation mutation requires escalation into `build` or `fix`.

Approval proof is defined by the workflow state machine: artifact frontmatter
plus matching decision log evidence. If approval cannot be proven from disk,
the predicate should treat it as missing.

The predicate should be implemented once and consumed by:

- `PreToolUse` before common writes;
- `PostToolUse` after observed mutation;
- `Stop` for end-of-turn validation;
- `sage status` for user-visible diagnosis;
- verification tests and pilot prompt evaluation.

### PreToolUse

Use `PreToolUse` for common mutation paths:

- `apply_patch`;
- aliases `Edit|Write`;
- selected MCP write tools;
- narrow Bash commands where command shape is clearly mutating.

In `fast-trusted`, this is behavioral. In `strict`, pair it with sandbox and
permission settings.

`PreToolUse` should call the shared valid-state predicate and render the same
core explanation regardless of which tool triggered it. Tool-specific hook code
should only normalize the attempted mutation into a common input shape:

- mutation class;
- target path(s) when available;
- tool name;
- command summary if the tool is shell-like;
- whether the mutation target is inside `.sage/` or project code.

The hook should not attempt full semantic routing. Its job is to stop or
redirect an attempted mutation when the Sage state is missing.

### PostToolUse

Use `PostToolUse` to detect completed mutations and redirect the model if
something changed without valid Sage state. It cannot undo side effects, so it
must be worded as a recovery guardrail.

`PostToolUse` should be explicit when it is recovering after the fact:

- state that mutation already happened;
- identify the affected path(s) if available;
- ask the model to stop further mutation;
- route to the missing Sage workflow step;
- suggest cleanup only if safe and clearly attributable.

### Stop

Use `Stop` to catch end-of-turn failures:

- assistant claimed Sage workflow without files;
- assistant produced pseudo-Sage without `.sage/work` artifacts;
- assistant failed to update documentation or decisions after a checkpoint;
- assistant ended after mutation without verification or next gate.

`Stop` should not create an infinite nag loop. In v1 it should prefer a clear
end-of-turn warning plus next required Sage action. Continuation can be added
later only if pilot testing shows it improves outcomes without making the
agent noisy.

### Hook Boundary Contract

Every hook and generated doc must use the same boundary language:

- In `fast-trusted`, hooks are behavioral guardrails and recovery signals.
- In `strict`, hooks plus sandbox/approval settings may provide stronger
  operational enforcement.
- Hooks may fail open when Codex event coverage changes or a tool path is not
  observable.
- Pre-commit is the last repository-level backstop, not a substitute for
  interactive Sage workflow gates.

This language should appear in `HOOKS.md`, `README.md`, generated
`AGENTS.md`, and `sage status` output so users do not over-trust the guardrail
stack.

### Pre-Commit

Keep `.githooks/pre-commit` as the final repository backstop. It should not be
the primary user experience, but it is valuable in Skip Permissions mode.

## Enforcement Profiles

### fast-trusted

Designed for the user's normal Skip Permissions workflow.

Guarantee:

- best-effort behavioral guardrails;
- hook redirects for common mutation paths;
- status warnings when sandbox/approval boundary is disabled;
- git backstop before commit.

Non-guarantee:

- no claim that file writes are impossible.

### strict

Designed for teams or less trusted environments.

Guarantee target:

- same Sage hooks;
- sandbox/permissions configured to constrain writes where possible;
- approval/rules policy can remain interactive or fail-closed;
- clearer hard-boundary language only when sandbox is actually active.

## Status And Observability

`sage status` for Codex should report:

- public workflow skill deployment state;
- internal library manifest state;
- hook activation state;
- active enforcement profile;
- whether sandbox/permissions provide a hard boundary;
- whether mutation guardrails are active;
- whether pre-commit is active;
- current active initiative and next gate.

Status language must avoid false certainty. Example:

- `Sage write guard: behavioral (fast-trusted, Skip Permissions)`
- `Sage write guard: sandbox-backed (strict)`
- `PreToolUse: active for apply_patch/Edit/Write, MCP write allowlist`
- `Pre-commit: active / dormant / custom hooks path`

## Generator Changes

`runtime/platforms/codex/setup/generate-codex.sh` should be refactored into
clear emission phases:

1. Emit compact `AGENTS.md`.
2. Emit workflow-only `.agents/skills`.
3. Emit internal library manifest or references.
4. Emit `.codex/config.toml` managed block.
5. Emit optional hooks starter / activation config.
6. Emit status metadata for `bin/sage status`.

The generator should stop describing direct skill deployment as normal product
behavior. If kept, it should be an explicit debug/legacy mode.

## Documentation Changes

Update Codex docs to remove obsolete claims:

- `pre-prompt.sh` is no longer a regex pre-turn gate.
- `PreToolUse` is not a complete enforcement boundary.
- Hooks are part of a layered guardrail stack.
- `AGENTS.md` is compact static contract, not a full methodology dump.
- Skip Permissions maps to `fast-trusted` behavioral enforcement.

## Verification

Mechanical tests:

- generated `AGENTS.md` contains compact contract and omits old long gate
  sections;
- exactly public workflow skills are deployed by default;
- internal manifest resolves every required internal skill path;
- UserPromptSubmit payload is under 200 tokens;
- hook config matches supported Codex events and matchers;
- status renderer distinguishes `fast-trusted` and `strict`;
- pre-commit backstop still works.

Outcome pilot:

- 12-15 prompt corpus across chat, read-only, build, fix, architect, explicit
  workflow, invalid write, valid write, pseudo-Sage, and optional temp writes.
- Include Polish prompts, typos, and non-keyword phrasings.
- Mark milestone incomplete until pilot passes or failure is documented and
  architecture revised.

## Risks

- Hooks may fail open or not cover a new mutation path.
- Compact `AGENTS.md` may become too thin if workflow skills are not invoked.
- Internal library manifest can drift from real files.
- UserPromptSubmit can become noisy if allowed to grow.
- `fast-trusted` can be misunderstood as hard enforcement.
- Shared Sage changes may leak Codex-specific assumptions into other platforms.

## Open Design Questions

Proposed defaults awaiting user confirmation:

- Internal library manifest starts Codex-first; generalize only after the
  model proves useful and avoids Codex-specific assumptions.
- Approval proof uses artifact frontmatter plus matching decision log entry.
- `Stop` warns and routes in v1; continuation is deferred until pilot testing.
- Diagnostic temp writes are allowed only if safe allowlisting is simple;
  otherwise they follow the same gate as project implementation mutation.

Decisions requiring user confirmation before design approval:

- Should internal library manifest start Codex-first or become shared Sage
  architecture immediately?
- Is frontmatter plus matching decision log sufficient approval proof, or do we
  need a separate event log from the start?
- Should `Stop` only warn/route in v1, or should it attempt automatic
  continuation/recovery?
- Should diagnostic temp writes get a v1 allowlist, or should every write use
  the same Sage gate?

Implementation detail to decide during milestone planning after the design
direction is approved:

- exact MCP write-tool allowlist;
- exact approval metadata schema names and migration behavior for legacy
  artifacts;
- exact pilot corpus and pass/fail rubric.
