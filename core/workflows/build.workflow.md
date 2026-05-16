---
name: build
version: "1.0.0"
mode: build
produces: ["Brief (medium+ tasks)", "Spec", "Implementation plan"]
checkpoints: 3
scope: "Single session for medium tasks, multi-session for large"
user-role: "Review and approve at each gate"
---

# Build Workflow

## Artifact Language Contract

When this workflow writes or updates `.sage` artifacts, natural-language prose
follows the target project language contract. Keep artifact filenames,
frontmatter keys and values, workflow/status/phase names, command names, paths,
code identifiers, quoted evidence, and raw tool/test output canonical or
verbatim.

Feature development guided by Sage.

## Alex-native Notes

Sage artifact structure stays canonical: keep `brief.md`, `spec.md`,
`plan.md`, `manifest.md`, frontmatter keys, command names, workflow names, code
identifiers, quoted evidence, and Sage/programming terms in English where they
are canonical. Treść prozatorską nowych sekcji `.sage` pisz po polsku, także
gdy dopisujesz do starszego angielskiego pliku. In conversation, add
junior-friendly context: briefly explain why a gate matters and link to 1-3
important artifact sections instead of assuming the user read the whole file.

**Autonomiczna kontynuacja:** At spec and plan checkpoints, preserve the normal
review paths and add an explicit autonomous path when appropriate:
- po spec: the agent may continue into planning only if planning is mechanical
  and no important architecture decision, scope expansion, or open question
  appears; otherwise zatrzymaj sie przed implementation and ask.
- po plan: always offer `[C] Checkpointed implementation` and `[F] Full
  autonomous implementation`. If the user selects `[F]`, execute the approved
  plan snapshot end-to-end until verification/close without intermediate
  checkpoints. `[F]` is scoped autonomy, not general autonomy: it is bound to
  the plan version, `manifest.scope`, known assumptions, and known stop
  conditions visible at the checkpoint. Scope expansion cancels the grant and
  requires a new user approval.

## Auto-Pickup

BEFORE ANYTHING: Scan `.sage/work/` for existing artifacts.
This scan is MANDATORY — check the DISK.

**Manifest-first path:** If `.sage/work/*/manifest.md` exists, read it.
Resume at the phase indicated. Use context summary and handoff guidance
for judgment context. The manifest is the primary context source.

**Fallback path:** If no manifest.md but artifacts exist, use file-scan
routing (below). Create manifest.md from inferred state before proceeding
(backfill). This preserves backward compatibility with pre-v1.0.9 cycles.

**File-scan routing (when no manifest):**
- No artifacts exist → Step 2 (scope assessment)
- Brief exists, no spec → Step 4 (spec)
- Spec exists, no plan → Step 5 (plan)
- Plan exists, not all completed → Step 6 (build-loop)
- All status: completed → offer next steps

You MUST follow this routing. Do not override it based on:
- Conversation context ("we discussed this before")
- User description ("the design is clear")
- Your own assessment ("this is straightforward")
The disk is the source of truth. Not your memory.

**Multiple in-progress:** Present list:
[1] Continue [initiative A] — [phase]
[2] Continue [initiative B] — [phase]
[3] Start something new

Read `.sage/decisions.md` for recent context. Read the `handoff`
field in the most recent artifact's frontmatter if present.

**Upstream context:** Also scan `.sage/docs/` for research and
analysis artifacts (jtbd-*, ux-audit-*, opportunity-*, ux-evaluate-*).
If found, announce: "Sage: Found research/analysis context — [list].
Using as build input."

### Manifest Lifecycle (build workflow)

**Create** manifest.md when the first artifact is saved (brief or spec).
Use the template from `develop/templates/manifest-template.md`.

**Update** manifest.md at EVERY checkpoint:
- Every [A]/[R]/[N] gate: update phase, status, updated timestamp
- Phase transitions: update context summary if new information emerged
- New decisions: append to the manifest's decisions list

Approval checkpoints keep `status: in-progress` and move `phase` to the
current gate. Do not mark the cycle `paused` unless the user chooses `[N]` New
session, asks to park the work, or the agent is writing a real handoff.

**Context budget pressure:** If the conversation is very long (many
tool calls, approaching context limits), write a manifest update BEFORE
suggesting a session break. This is the critical moment — capture the
judgment that's about to be lost.

**Session end ([N]):** Manifest update is MANDATORY. Write handoff
guidance and context summary before ending.

**Completion:** Set `status: complete` at Step 8.

After every `status` or `phase` change, tell the user what changed after the
frontmatter has been updated. If the platform exposes a session id, record it
as `active_session_id` when moving a cycle to `status: in-progress`.

**Anti-lazy-manifest contract:**
Context summary MUST NOT be:
- A copy of the spec's title or description
- "See spec.md for details"
- Generic guidance ("Continue with implementation")
The summary must contain judgment the spec doesn't contain.

## Phase Announcements

At each major phase transition, announce before doing any phase work:

```
Sage: Entering UNDERSTAND phase [cycle-id] — gathering requirements via quick-elicit.
Sage: Entering PLAN phase [cycle-id] — creating implementation plan from spec.
Sage: Entering DELIVER phase [cycle-id] — implementing with TDD and quality gates.
Sage: Entering REVIEW phase [cycle-id] — running quality verification.
```

The cycle ID is the directory name under `.sage/work/` (e.g., `20260324-auth-flow`).

## Step 2: Assess Scope

Classify by structural complexity — not time, not gut feeling.

**Lightweight:** One component, no design decisions, no behavior changes
visible to other team members. The change is obvious from the request.
→ Skip to Step 6, implement directly.

**Standard:** Multiple components, OR any design decision, OR
coordination between modules. Spec file REQUIRED.
→ spec.md MUST exist at .sage/work/ before implementation.
→ plan.md MUST exist at .sage/work/ before implementation.
→ If the task also needs scope definition, write brief first (Step 3).

**Comprehensive:** New subsystem, cross-cutting changes, or multiple
stakeholder impact.
→ MUST write brief (Step 3) → spec (Step 4) → plan (Step 5) → implement.

**Complexity signals** (any ONE makes it Standard or above):
- Touches more than 3 files
- Involves a new API endpoint or data model change
- Requires coordination between multiple modules or services
- Has user-facing behavior changes (new UI, changed flow)
- Involves a decision a team member would need to know about
- Multiple layers affected (database + backend + frontend)

**Anti-downgrade:** When in doubt, classify as Standard, not Lightweight.
Do NOT downgrade to Lightweight to avoid writing a spec. If you find
yourself thinking "this is simple enough to skip the spec," that
thought is the signal to NOT skip the spec.

Present your assessment:

**Sage → build workflow.** [Scope] — [what makes it this scope].
Starting with [first required step].

If the user explicitly asks to skip a required step, write a minimal
5-line spec anyway (WHAT, WHY, HOW, DONE-WHEN), present [A]/[R], and
record the skip rationale only if it is decision-worthy under Rule 7.

## Step 3: Brief (Standard with unclear scope, or Comprehensive)

If scope is unclear or the task is Comprehensive, elicit requirements
before defining the brief.

For structured elicitation process, read
`sage/core/capabilities/elicitation/quick-elicit/SKILL.md`.
It provides 3 focused rounds (~2 minutes):
1. Intent — what should this do when working perfectly?
2. Boundaries — what should this NOT do?
3. Verification — how will we know it works?

If quick-elicit cannot be loaded, ask these three questions directly
and draft a brief from the answers.

Define: what to build, why, acceptance scenarios, and constraints.

Save to `.sage/work/YYYYMMDD-slug/brief.md` with frontmatter:

```yaml
---
title: "Brief description of the initiative"
status: in-progress
phase: brief
priority: high  # high | medium | low
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

🔒 **CHECKPOINT:**

Sage: Brief saved to .sage/work/YYYYMMDD-slug/brief.md
Decision: [decision-worthy scope choices, if any]. (prepend to .sage/decisions.md)

[A] Approve — continue to spec in this session
[R] Revise — tell me what to change
[N] New session — type sage:build or natural-language resume to continue with spec

Pick A/R/N, or tell me what to change.

On approval: update brief frontmatter to `status: completed`.
Prepend only decision-worthy choices to decisions.md (Rule 7).

## Step 4: Spec

Define: components, data model, APIs, key decisions, edge cases.
Resolve open questions from the brief.

For detailed spec writing process, read
`sage/core/capabilities/planning/specify/SKILL.md`.

Save to `.sage/work/YYYYMMDD-slug/spec.md` with frontmatter:

```yaml
---
title: "Spec for [initiative]"
status: in-progress
phase: spec
priority: high
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

🔒 **CHECKPOINT:**
Sage: Spec saved to .sage/work/YYYYMMDD-slug/spec.md
Decision: [decision-worthy technical choices, if any]. (prepend to .sage/decisions.md)

[A] Subagent review — explicitly authorize Codex to spawn a read-only subagent
    to review the spec; findings are shown and the user decides
[S] Skip review — approve without independent review
[C] Continue autonomously — explicitly authorize subagent review if available,
    then plan and stop before implementation if needed
[R] Revise — tell me what to change
[N] New session — type sage:build or natural-language resume to continue with planning

Pick A/S/C/R/N, or tell me what to change.

**On [A] Subagent review:**
1. Update spec frontmatter to `status: completed`.
2. Write `handoff` field in frontmatter:
```yaml
handoff: |
  Key decisions: [summary of choices made]
  Open questions: [what's unresolved]
  Risks: [what to watch for during implementation]
  Next agent should: [specific guidance for planning phase]
```
3. Prepend decision-worthy spec choices to decisions.md (Rule 7).
4. **Run auto-review and return to the checkpoint decision:**
   Read `sage/core/capabilities/review/auto-review/SKILL.md`.
   If conditions met (Task tool available + Standard+ scope +
   auto_review ≠ false in config + user chose an option that explicitly
   authorized subagent review):
     Announce: "⚡ Running spec review (sub-agent)..."
     Spawn sub-agent with the **Spec Review** prompt.
     Pass the spec path and decisions.md path.
     Present findings inline (see capability for format).
     Treat the review verdict as process evidence; record only the user's
     subsequent decision-worthy choice, if any.
   If Task tool NOT available:
     Announce: "Task tool not available — skipping independent review."
5. Do not proceed to Step 5 until the user chooses an approval or
   autonomous-continuation path after seeing findings.

**On [S] Skip review:**
1. Update spec frontmatter, write handoff, append decision (same as above).
2. Announce: "Skipping independent review."
3. Record the skip only if it is decision-worthy under Rule 7.
4. Proceed to Step 5.

**On [C] Continue autonomously:**
1. Run the [A] review path.
2. Continue to Step 5 and draft the plan.
3. If planning reveals a material architecture choice, scope expansion, or
   important unanswered question, stop before implementation and ask one
   question. Otherwise present the plan context and continue only if the
   autonomous instruction still clearly applies.

## Step 5: Plan

Break into small, independently testable tasks. Each task: what to do,
done criteria, files involved. Use checkboxes as a guide.

For detailed planning process, read
`sage/core/capabilities/planning/plan/SKILL.md`.

Save to `.sage/work/YYYYMMDD-slug/plan.md` with frontmatter:

```yaml
---
title: "Plan for [initiative]"
status: in-progress
phase: plan
priority: high
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

🔒 **CHECKPOINT:**

Sage: Plan saved to .sage/work/YYYYMMDD-slug/plan.md

[A] Subagent review — explicitly authorize Codex to spawn a read-only subagent
    to review the plan; findings are shown and the user decides
[S] Skip review — approve without independent review
[C] Checkpointed implementation — approve plan, explicitly authorize required
    subagent gates if available, and execute with normal checkpoints
[F] Full autonomous implementation — approve plan, explicitly authorize
    required subagent gates if available, and execute through final verification
[I] Revise and Implement in the same turn — give specific bounded revision
    instructions and approve implementation after those changes
[R] Revise — tell me what to change
[N] New session — type sage:build or natural-language resume to start implementation

Pick A/S/C/F/I/R/N, or tell me what to change.

**On [A] Subagent review:**
1. Prepend the plan approach only if it is decision-worthy under Rule 7.
2. **Run auto-review and return to the checkpoint decision:**
   Read `sage/core/capabilities/review/auto-review/SKILL.md`.
   If conditions met (Task tool available + Standard+ scope +
   auto_review ≠ false in config + user chose an option that explicitly
   authorized subagent review):
     Announce: "⚡ Running plan review (sub-agent)..."
     Spawn sub-agent with the **Plan Review** prompt.
     Pass the plan path and spec path.
     Present findings inline.
     Treat the review verdict as process evidence; record only the user's
     subsequent decision-worthy choice, if any.
   If Task tool NOT available:
     Announce: "Task tool not available — skipping independent review."
3. Update `manifest.md` BEFORE Step 6:
   - Set phase to `implement`.
   - Add a `scope:` list containing every file or glob the approved plan
     will mutate, including tests and implementation files.
   - Keep `.sage/work/<cycle-id>/*` and `.sage/decisions.md` in scope.
   - If scope is uncertain, stop and ask before implementation.
4. Do not proceed to Step 6 until the user chooses an approval or
   autonomous-implementation path after seeing findings.

**On [S] Skip review:**
1. Prepend the plan approach only if it is decision-worthy under Rule 7.
2. Announce: "Skipping independent review."
3. Record the skip only if it is decision-worthy under Rule 7.
4. Update `manifest.md` BEFORE Step 6:
   - Set phase to `implement`.
   - Add a `scope:` list containing every file or glob the approved plan
     will mutate, including tests and implementation files.
   - Keep `.sage/work/<cycle-id>/*` and `.sage/decisions.md` in scope.
   - If scope is uncertain, stop and ask before implementation.
5. Proceed to Step 6.

**On [I] Revise and Implement in the same turn:**
1. Apply only the specific user-requested plan revisions.
2. Update `manifest.md` before implementation as above.
3. Record `implementation_approval` in manifest frontmatter with
   `mode: conditional_revision`, a non-empty `revision` summary, and
   `artifact` pointing at the canonical `.sage/work/<cycle-id>/plan.md`.
4. Proceed to Step 6 only if the revision stays inside the existing approved
   scope and introduces no new decision, risk, ownership conflict, or ambiguous
   assumption. Otherwise return to the checkpoint.

**On [F] Full autonomous implementation:**
1. Run the [A] review path unless the user explicitly asked to skip review.
   Selecting [F] explicitly authorizes read-only subagent review and required
   subagent quality gates during this approved implementation run when the
   platform tool is available.
2. Update `manifest.md` before implementation as above and record an
   `autonomy_grant` note that names the approved plan snapshot and
   `manifest.scope`.
3. Execute Step 6 through Step 8 without intermediate checkpoints.
4. Stop and ask one question if a key assumption, product/architecture
   decision, accepted risk, ownership, conflict, new file outside scope, or
   scope expansion changes the approved plan. Present:
   `[A] Approve scope expansion`, `[R] Revise`, `[S] Split into intake`.

## Step 6: Implement

Execute the plan task by task using the build loop.

Before the first implementation edit, run this preflight:
- Re-read `manifest.md` and confirm `scope:` covers the next task's files.
- If the next file is outside `manifest.scope`, stop for a scope expansion
  checkpoint. Do not update `manifest.md` and continue under the old grant.
- Do not attempt the implementation patch and let PreToolUse reject it; the
  manifest scope is part of the approved plan handoff.

Read and follow `sage/core/capabilities/orchestration/build-loop/SKILL.md`.
It provides:
- Task-by-task execution with status reporting
- TDD discipline for each task (loads `sage/core/capabilities/execution/tdd/SKILL.md`)
- Scope guard to prevent drift (loads `sage/core/capabilities/context/scope-guard/SKILL.md`)
- Quality gates between tasks (loads `sage/core/workflows/sub-workflows/quality-gates.workflow.md`)
- Inter-task checkpoints every 1-3 tasks
- Escalation on repeated failure (3x → ask human)
- Context budget awareness (suggest new session if full)

If the build-loop cannot be loaded, follow these minimum rules:
implement one task at a time, write tests before code, run full
suite after each task, stay in scope, commit after each task.

If relevant Sage skills exist in `sage/skills/`, read and follow them.

**If stuck during implementation:** Activate the `problem-solving` skill.
Match the stuck pattern to a technique — complexity spiral → Simplification,
forced solution → Inversion, works-locally-but-fails → Scale Testing,
can't isolate → Minimal Reproduction.

## Step 7: Quality Gates

Run quality gates on the completed implementation.

Read and follow `sage/core/workflows/sub-workflows/quality-gates.workflow.md`.
It sequences 5 verification stages:
1. Spec compliance — does implementation match the plan? (adversarial)
2. Constitution compliance — does it respect project principles?
3. Code quality — clean, secure, maintainable?
4. Hallucination check — are all imports, APIs, versions real?
5. Verification — tests pass with pasted evidence?

Each gate that fails triggers fix-and-retry (max 3 attempts) or
escalation to the user.

If quality-gates cannot be loaded, follow these minimum rules:
run full test suite, paste output, verify implementation matches spec,
check for hallucinated imports or APIs.

Quality gates now include Gate 8 (Auto-QA) which runs automatically
as part of the gate sequence when Task tool is available. See
`quality-gates.workflow.md` for the full sequence including Gate 8.

## Step 8: Review and Close

Review against spec. Check for missed edge cases.

**Closeout order:** The completion checkpoint is not approval. Before presenting
it, do a final self-review and finish required verification evidence, plan
bookkeeping, decisions, and handoff context while keeping the manifest active,
for example `status: in-progress`, `phase: completion-checkpoint`. Only after
explicit user closeout approval may the agent mark lifecycle artifacts complete.
Treat `manifest.status: completed` as the last Sage artifact mutation for the
cycle. After closeout, report stage/commit status and ask whether to perform
local handoff for this cycle's changes; do not ask for `push` by default and do
not add a post-closeout `.sage` epilogue.

Standalone `closeout.md` is not the default for ordinary non-milestone builds.
Keep closeout evidence in existing lifecycle artifacts such as `manifest.md`,
`plan.md`, verification notes, and decision-worthy `.sage/decisions.md`
entries. Use standalone closeout artifacts only for umbrella, milestone-based,
multi-phase, or architecture-style build cycles where evidence spans multiple
stages or absorbed cycles.

After closeout, use completed manifest-only reconciliation only for obvious
bookkeeping in that cycle's `manifest.md` while preserving
`manifest.status: completed`. A substantive issue found later needs a follow-up
cycle. Reopen is only for an immediate correction in the same active conversation before handoff.

**Anti-deferral guard:** Before presenting the completion checkpoint,
verify ALL plan tasks are addressed. If any tasks remain incomplete,
do NOT present "Build complete." Instead:
1. List what's done and what remains
2. Explain why remaining tasks couldn't be completed
3. Ask the user: continue, pause, or adjust scope?
Never mark an initiative as complete with unfinished tasks, and never
defer planned work without the user's explicit decision.

🔒 **CHECKPOINT:**

Sage: Build ready for completion approval. [summary of what was built]
Decision: [decision-worthy implementation choices, if any]. (prepend to .sage/decisions.md)

[A] Approve closeout — close the Sage cycle locally
[R] Revise — here's what needs fixing
[V] Verify — type /review for independent verification

Pick A/R/V, or tell me what to change.

**On approval — checkpoint state (Rule 7):**
1. Walk through plan.md and check completed tasks in bulk
2. Update plan.md frontmatter: `status: completed`
3. Prepend completion summary to `.sage/decisions.md` only when the closeout
   contains a decision-worthy outcome
4. Write `handoff` field in plan.md frontmatter with key decisions,
   open questions, and risks for the next agent
5. Store key findings in memory if sage-memory available
6. **Wiring check:** Verify all new components are connected — imports
   wired, routes registered, handlers hooked up, config entries added.
7. **Ontology update (if sage-memory available):** For significant new
   structure (new module, service, API endpoint, major component), create
   ontology entities and link them to existing graph. Skip for small
   changes within existing modules — only update when the codebase's
   *navigable structure* changed. Search ontology first to avoid dupes.
8. Set `manifest.status: completed` as the last Sage artifact mutation.
9. Report stage/commit status and ask about local git handoff. Do not push
   unless the user explicitly asks for push.

**Next steps (Zone 3):**

Next steps:
  /qa             — browser-based functional testing
  /design-review  — design quality audit
  /reflect        — review the cycle, extract learnings
  /review         — independent code evaluation

Type a command, or describe what you want to do next.

## Quality Criteria

**Communication style:** Engineering precision. Emphasize trade-offs,
edge cases, and implementation specifics. Reference file paths, function
names, and test results concretely.

Good build output:
- Implementation matches the spec — no undocumented deviations
- Tests exist for new functionality and pass — output pasted as evidence
- Edge cases from the spec are handled, not just happy paths
- Code follows project conventions (naming, structure, patterns)
- No unrelated changes mixed in — scope discipline maintained
- Verification output is from the actual test run, not a summary

## Self-Review

Before presenting completed work, check each criterion above. Also:
- Did I paste actual test output, or just claim tests pass?
- Did I run the FULL suite, or just the new tests?
- Are there spec requirements I didn't implement or test?

## Rules

- Spec before implementing (Rule 0 gate). DO NOT implement without
  an approved spec in .sage/work/.
- Tests before code (Base Principle 1). Write failing test first.
- Checkpoints mandatory (Rule 4). Present [A]/[R] and wait.
- Verify with evidence (Rule 5). Paste actual test output.
- Capture corrections (Rule 6). Store as self-learning.
- Record decision-worthy decisions at checkpoints (Rule 7). Prepend to decisions.md.
- Stay in scope — note improvements, don't add them.
- If stuck, use problem-solving skill. Don't retry the same approach.
