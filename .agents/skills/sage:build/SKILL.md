---
name: sage:build
description: >-
  Feature implementation workflow. Use for new behavior, refactors, and planned delivery work.
---

RULES (apply to every step — non-negotiable):
- Announce: "Sage → build workflow." before starting work.
- MEMORY FIRST: Before writing spec or plan, call sage_memory_search twice —
  once with feature-domain keywords (limit 5), once with the same query and
  filter_tags ["self-learning"] (limit 5). Parameter types: limit is an
  integer, filter_tags is an array. Use findings to avoid past mistakes.
- FILE CHECKS: spec.md and plan.md MUST exist on disk at .sage/work/<init>/
  before ANY implementation. "Design is clear" is NOT a spec. "We discussed
  this" is NOT a spec. A spec is a file.
- [A] = APPROVE + REVIEW: at spec and plan checkpoints, present
  [A] Approve  [R] Revise  [S] Skip review. When the user picks [A] and a
  fresh subagent is available, run independent review before proceeding.
- Save all artifacts to .sage/work/ or .sage/docs/ — never inline-only.
- Choices: present with [1] [2] [3] bracket notation.
- Verify: PASTE actual test output before claiming done — no summaries.
- Never use code blocks for interaction (checkpoints, options, status).
- If user corrects your approach, call sage_memory_store with tag
  "self-learning" BEFORE continuing.

# Sage build workflow

Codex-native workflow skill for Sage.

Use shared project state in `.sage/` and avoid creating platform-specific
state duplicates.


# Build Workflow

Feature development guided by Sage.

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

**Context budget pressure:** If the conversation is very long (many
tool calls, approaching context limits), write a manifest update BEFORE
suggesting a session break. This is the critical moment — capture the
judgment that's about to be lost.

**Session end ([N]):** Manifest update is MANDATORY. Write handoff
guidance and context summary before ending.

**Completion:** Set `status: complete` at Step 8.

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
record the skip rationale in decisions.md.

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
```

🔒 **CHECKPOINT:**

Sage: Brief saved to .sage/work/YYYYMMDD-slug/brief.md
Decision: [key scope decisions]. (prepend to .sage/decisions.md)

[A] Approve — continue to spec in this session
[R] Revise — tell me what to change
[N] New session — type /sage:build to continue with spec

Pick A/R/N, or tell me what to change.

On approval: update brief frontmatter to `status: completed`.
Prepend decision to decisions.md (Rule 7).

## Step 4: Spec

Define: components, data model, APIs, key decisions, edge cases.
Resolve open questions from the brief.

For detailed spec writing process, read
`sage/core/capabilities/planning/specify/SKILL.md`.

Save to `.sage/work/YYYYMMDD-slug/spec.md` with frontmatter:

```yaml
```

🔒 **CHECKPOINT:**
Sage: Spec saved to .sage/work/YYYYMMDD-slug/spec.md
Decision: [key technical decisions]. (prepend to .sage/decisions.md)

[A] Review — sub-agent reviews spec, then continue to plan
[S] Skip review — approve without independent review
[R] Revise — tell me what to change
[N] New session — type /sage:build to continue with planning

Pick A/S/R/N, or tell me what to change.

**On [A] Review:**
1. Update spec frontmatter to `status: completed`.
2. Write `handoff` field in frontmatter:
```yaml
handoff: |
  Key decisions: [summary of choices made]
  Open questions: [what's unresolved]
  Risks: [what to watch for during implementation]
  Next agent should: [specific guidance for planning phase]
```
3. Prepend decision to decisions.md (Rule 7).
4. **Run auto-review BEFORE proceeding to Step 5:**
   Read `sage/core/capabilities/review/auto-review/SKILL.md`.
   If conditions met (Task tool available + Standard+ scope +
   auto_review ≠ false in config):
     Announce: "⚡ Running spec review (sub-agent)..."
     Spawn sub-agent with the **Spec Review** prompt.
     Pass the spec path and decisions.md path.
     Present findings inline (see capability for format).
     Prepend review verdict to decisions.md.
   If Task tool NOT available:
     Announce: "Task tool not available — skipping independent review."
5. THEN proceed to Step 5.

**On [S] Skip review:**
1. Update spec frontmatter, write handoff, append decision (same as above).
2. Announce: "Skipping independent review."
3. Log to decisions.md: "Spec approved without auto-review (user chose [S])."
4. Proceed to Step 5.

## Step 5: Plan

Break into small, independently testable tasks. Each task: what to do,
done criteria, files involved. Use checkboxes as a guide.

For detailed planning process, read
`sage/core/capabilities/planning/plan/SKILL.md`.

Save to `.sage/work/YYYYMMDD-slug/plan.md` with frontmatter:

```yaml
```

🔒 **CHECKPOINT:**

Sage: Plan saved to .sage/work/YYYYMMDD-slug/plan.md

[A] Review — sub-agent reviews plan, then start building
[S] Skip review — approve without independent review
[R] Revise — tell me what to change
[N] New session — type /sage:build to start implementation

Pick A/S/R/N, or tell me what to change.

**On [A] Review:**
1. Prepend plan approach to decisions.md (Rule 7).
2. **Run auto-review BEFORE proceeding to Step 6:**
   Read `sage/core/capabilities/review/auto-review/SKILL.md`.
   If conditions met (Task tool available + Standard+ scope +
   auto_review ≠ false in config):
     Announce: "⚡ Running plan review (sub-agent)..."
     Spawn sub-agent with the **Plan Review** prompt.
     Pass the plan path and spec path.
     Present findings inline.
     Prepend review verdict to decisions.md.
   If Task tool NOT available:
     Announce: "Task tool not available — skipping independent review."
3. THEN proceed to Step 6.

**On [S] Skip review:**
1. Prepend plan approach to decisions.md.
2. Announce: "Skipping independent review."
3. Log to decisions.md: "Plan approved without auto-review (user chose [S])."
4. Proceed to Step 6.

## Step 6: Implement

Execute the plan task by task using the build loop.

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

**Verification artifact (Standard+ scope):** Write
`.sage/work/<slug>/verification.md` from the canonical template at
`.agents/skills/sage:build/templates/verification-template.md`. Path is
pinned: slug root, never under a phase subdirectory. Shape is enforced
by `runtime/platforms/codex/hooks/lib/verification_check.py`,
`bin/sage-close`, and the `.githooks/pre-commit` hook — all three reject
out-of-shape verification files. Required sections in order:
`## Pre-fix reproducer`, `## Implementation summary`,
`## Test command + pasted output` (must contain a fenced block with
real output, not a prose summary), `## Close-out checklist`.

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

**Anti-deferral guard:** Before presenting the completion checkpoint,
verify ALL plan tasks are addressed. If any tasks remain incomplete,
do NOT present "Build complete." Instead:
1. List what's done and what remains
2. Explain why remaining tasks couldn't be completed
3. Ask the user: continue, pause, or adjust scope?
Never mark an initiative as complete with unfinished tasks, and never
defer planned work without the user's explicit decision.

🔒 **CHECKPOINT:**

Sage: Build complete. [summary of what was built]
Decision: [key implementation decisions]. (prepend to .sage/decisions.md)

[A] Approve — merge/ship
[R] Revise — here's what needs fixing
[V] Verify — type /review for independent verification

Pick A/R/V, or tell me what to change.

**On approval — checkpoint state (Rule 7):**
1. Walk through plan.md and check completed tasks in bulk
2. Update plan.md frontmatter: `status: completed`
3. Prepend completion summary to `.sage/decisions.md`
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

**Next steps (Zone 3):**

Next steps:
  /sage:qa             — browser-based functional testing
  /sage:design-review  — design quality audit
  /sage:reflect        — review the cycle, extract learnings
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
- Record decisions at checkpoints (Rule 7). Prepend to decisions.md.
- Stay in scope — note improvements, don't add them.
- If stuck, use problem-solving skill. Don't retry the same approach.
