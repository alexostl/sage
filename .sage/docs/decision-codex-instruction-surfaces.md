---
title: "ADR — Codex instruction surfaces"
status: proposed
date: 2026-04-29
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/manifest.md
  - .sage/docs/decision-codex-validate-mutation-predicate.md
  - .sage/docs/decision-codex-approval-proof-schema.md (W2 — UPS-token contract)
  - .sage/docs/decision-codex-mcp-stack.md
  - .sage/docs/decision-codex-shared-skill-manifest.md (ADR-4)
  - .sage/docs/decision-codex-preamble-extraction.md (ADR-6)
  - .sage/docs/research-codex-port-rewrite-base.md (§4.2 AGENTS.md, §4.5 hooks)
  - .sage/work/20260429-claude-port-logic-map/map.md (§3.5, §3.6)
---

# ADR — Codex instruction surfaces

## Context

Codex offers three layered instruction surfaces (research base §4.2)
plus six hook events (§4.5). Four platform facts shape the design:

1. **`AGENTS.md` is loaded ONCE per session** (TUI behavior),
   not per turn. Hard cap: `AGENTS_MD_MAX_BYTES = 32768` (verified
   in Codex source `codex-rs/core/src/config/mod.rs`).
2. **Project `.codex/config.toml` is loaded only when the project
   is trusted** (`[projects."<abs>"].trust_level = "trusted"` in
   user-global config). Same silent-failure mode as
   `[features].codex_hooks` (research base §4.5).
3. **`developer_instructions` is structurally distinct from
   AGENTS.md.** Cross-check against Codex source (2026-04-29,
   sub-agent verification, see §"Empirical findings" below)
   confirmed two **Codex-side facts** plus one **OpenAI Model
   Spec assumption** that this ADR makes explicit:
   - **(Codex-side, VERIFIED)** It is a top-level config string in
     `ConfigToml` schema (`codex-rs/config/src/config_toml.rs:135`),
     valid in BOTH user-global and project `config.toml`. Project
     layer **overrides** user layer when both define it
     (overlay-replaces-scalar merge — `merge.rs:5-30`).
   - **(Codex-side, VERIFIED)** It is injected into the model API
     call as a **`developer` role message** at `input[0]` — distinct
     from AGENTS.md, which lands as a **`user` role context message**
     at `input[1]`. Test evidence:
     `codex-rs/core/tests/suite/client.rs:2140-2230`
     `includes_developer_instructions_message_in_request()`.
   - **(OpenAI Model Spec, ASSUMED — not Codex-side)** OpenAI's
     published role hierarchy ranks `developer` above `user` in
     compliance weight (per OpenAI Model Spec on instruction
     priority: platform > developer > user). Codex source proves
     the *role assignment* + *position*; the *compliance ranking*
     is a model-behavior property documented by OpenAI, not a
     Codex codebase guarantee. ADR-8 outcome harness is the
     mechanism that turns this assumption into measurable evidence.
   - **(Codex-side, VERIFIED)** **No size cap.**
     `developer_instructions` is `Option<String>` with no
     `*_MAX_BYTES` constraint; bounded only by the model's context
     window.
4. **Six hook events, two distinct concerns** — three of them
   (`SessionStart`, `UserPromptSubmit`, `Stop`) are turn-boundary
   surfaces; three (`PreToolUse`, `PermissionRequest`,
   `PostToolUse`) are tool-call surfaces. v1 picks a subset to wire
   and documents why the rest are deferred.

**Prior empirical finding** (closed cycle
`20260428-codex-enforcement-activation-brief`, commit `a6f1391`):
the previous Codex port shipped AGENTS.md content with **declarative,
soft-toned language** (e.g. "agents should…", "consider…", "this
project uses Sage"). Compliance was measurably weaker than parity
`CLAUDE.md` in the same repo, which uses **imperative, file-check
language** ("MUST EXIST", "NEVER skip", "Before any substantial
response, scan…"). Tone mismatch — not architecture — was the
proximate cause of the activation gap. **This ADR locks imperative
tone as a hard requirement.**

ADR-2 W2 left an explicit contract gap: the `UserPromptSubmit` hook
that issues the one-shot approval token is referenced as
`runtime/platforms/codex/hooks/ups-approval.sh` but its full surface
schema (input payload, output side-effects, vocabulary list) is
not yet specified. ADR-7 (Stop hook scope) and ADR-1 (PreToolUse
mutation gate) similarly reference hook scripts whose surface
contracts must be locked in one place. **This ADR is that one
place.**

ADR-4 (shared skill manifest) and ADR-6 (preamble extraction) both
have consequences here:

- ADR-4 declares which skills are public on Codex. AGENTS.md
  references that list via a generated marker block.
- ADR-6 places per-workflow rules in `core/preambles/<wf>.md` —
  bodies of those preambles do NOT belong in AGENTS.md or
  `developer_instructions`. The cross-skill rules that stay at
  session level follow the boundary test from ADR-6 §Boundary.

Today's repo state (verified 2026-04-29):

- `runtime/platforms/codex/setup/generate-codex.sh` — exists, emits
  AGENTS.md and `.codex/config.toml`. The current AGENTS.md content
  is shaped by the rejected redesign cycle and is **expendable per
  brief §Refactor Intent**. The current generator does NOT emit
  `developer_instructions`.
- `runtime/platforms/codex/hooks/` — directory exists with starter
  pack from rejected redesign; **content is expendable**.
- `runtime/platforms/codex/hooks.example.json` — exists, will be
  rewritten to match this ADR's schema.

## Empirical findings (Codex source verification, 2026-04-29)

A sub-agent ran a code-level verification pass against the official
Codex repo (`openai/codex`, Rust) for three claims that anchor this
ADR's architecture. All three VERIFIED:

| Claim | Source | Result | Evidence |
|-------|--------|--------|----------|
| `developer_instructions` valid in project `config.toml` (not just user-global) | Codex codebase | **VERIFIED** | `config_toml.rs:135` + `loader/mod.rs:67-75` (loader applies same schema to all 6 layers) |
| Project layer **overrides** user layer for `developer_instructions` | Codex codebase | **VERIFIED** | `state.rs:274` + `merge.rs:5-30` (overlay-replaces-scalar) |
| `developer_instructions` lands in `developer` role API message at `input[0]`; AGENTS.md lands in `user` role context message at `input[1]` | Codex codebase | **VERIFIED** | Source comment `config_toml.rs:133` + behavioral test `client.rs:2140-2230` (asserts `role == "developer"` for `input[0]`) |
| No size cap on `developer_instructions` | Codex codebase | **VERIFIED** | No `*_MAX_BYTES` constant exists for it; `AGENTS_MD_MAX_BYTES = 32768` is for AGENTS.md only |
| `developer` role outranks `user` role in model compliance weight | OpenAI Model Spec | **ASSUMED** (not Codex-side) | OpenAI Model Spec on instruction priority: platform > developer > user. ADR-8 outcome harness measures whether the assumption holds in practice for our prompts. |

**Why this matters architecturally.** Codex source proves
`developer_instructions` rides a structurally distinct API role
(`developer`) at a distinct input position (`input[0]`), separate
from AGENTS.md (`user` role at `input[1]`). OpenAI's documented
model behavior treats `developer` role as higher-trust than `user`
role. **If the OpenAI assumption holds, `developer_instructions`
is a stronger compliance channel than AGENTS.md.** Defense in depth
combines both channels; ADR-8 outcome harness is the mechanism by
which we measure (rather than assume) that the dual-channel design
produces stronger compliance than AGENTS.md alone.

The trust gate caveat: project `config.toml` is "loaded-but-disabled"
until the user adds the project as trusted in `~/.codex/config.toml`.
Same gate that already protects hooks; no new infrastructure needed.

## Out of scope (explicitly)

Two Codex-native instruction surfaces remain **not managed by Sage v1**:

- **`~/.codex/AGENTS.override.md`** (and per-directory walk
  variants) — Codex-native escape hatch. Sage does not write or
  read it. Users who need a personal override hand-write it
  themselves; Codex loads it natively.

- **User-global `~/.codex/config.toml` `developer_instructions`** —
  cross-project user preference channel. Sage v1 does not write
  to user-global config from a project init flow (research base
  §6.1.8). Project layer overrides user layer anyway, so anything
  Sage cares about goes via project `<repo>/.codex/config.toml`.

The narrowed surface Sage manages is **two files in the project**:
- `<repo>/AGENTS.md` (full contract, user-role channel)
- `<repo>/.codex/config.toml` `developer_instructions` (high-weight
  primer, developer-role channel)

Both project-scoped. Zero user-global writes.

## Decision

**Three-part decision:**

1. **Two complementary project-scoped instruction surfaces** —
   Sage owns project `<repo>/AGENTS.md` (regenerated by
   `sage update`) AND project `<repo>/.codex/config.toml`
   `developer_instructions` field (regenerated by the same flow).
   - **`developer_instructions`** = high-weight primer in
     `developer` role API message. Holds the 3-5 strongest
     non-negotiables (MEMORY FIRST, mutation gate, approval
     vocabulary). Compact (~600-1000 chars). This is the
     channel the model treats as highest-trust instruction.
   - **AGENTS.md** = full contract in `user` role context message.
     Holds the complete cross-skill rule set with compliance
     lines, public skills marker block, framing, pointers.
     ~8 KiB target / 32 KiB cap.
   - Both written in **imperative, file-check language** matching
     this repo's `CLAUDE.md` strength. Defense in depth across two
     API roles.

2. **v1 hook surface = four scripts wired** —
   `SessionStart` (context injection), `UserPromptSubmit` (UPS-token
   per ADR-2 W2), `PreToolUse(apply_patch)` (mutation gate per
   ADR-1), `Stop` (turn audit per ADR-7). `PermissionRequest` and
   `PostToolUse` are explicitly deferred to v2 with documented
   rationale (see Options).

3. **All hook scripts are thin bash shims** that delegate to the
   Sage MCP server (per ADR-3). Hook scripts read/write small disk
   markers (e.g. `.sage/.approval-pending` from ADR-2) but do not
   carry workflow logic. The MCP server is the single source of
   truth for state and validation.

### Why two surfaces, not one

Empirical evidence (§"Empirical findings") shows
`developer_instructions` is structurally stronger than AGENTS.md
in OpenAI role hierarchy. A single AGENTS.md surface uses only the
weaker channel. The 2026-04-28 cycle proved that **enforcement
strength is the bottleneck, not surface count**.

By splitting:
- The **non-negotiables** (5 pre-action gates: MEMORY FIRST,
  mutation gate, approval vocabulary, verify before done, capture
  corrections) ride the structurally distinct developer-role
  channel where OpenAI's documented role hierarchy says the model
  is most likely to comply.
- The **full contract** (all 7 cross-skill rules with compliance
  lines, public skills, framing) rides AGENTS.md where size budget
  and rich structure work better.
- The model receives the 5 pre-action rules **twice via two
  different roles** — defense in depth without duplication waste
  (under 1 KiB extra in `developer_instructions`).

In plain terms for the junior-dev reader: Codex sends both files
to the model in the same API call but tags them differently. The
`developer` tag is the one OpenAI documents as "higher-trust
instruction." So the 5 most important pre-action rules ride that
tag; the full contract (including 2 protocol rules and compliance
verification lines) rides AGENTS.md.

### Why thin bash shims, not inline hook logic

Three reasons:

1. **Auditability.** A 10-line bash script is `bash -x`-debuggable.
   A 200-line shell parser of a Codex JSON payload is not.
2. **One source of validation logic.** ADR-3 places state machine
   validation, approval recording, and turn audit in the Sage MCP
   server. Hook scripts that re-implement that logic in shell drift
   from the MCP — exactly the multi-source-of-truth problem the
   rewrite is removing (ADR-4, ADR-6).
3. **Cross-platform.** If we ever port the MCP-backed validators
   to Antigravity or generic ports (per brief C4), bash shims for
   those platforms would mirror Codex's shape, while the
   validators stay one Python service.

## `developer_instructions` content (project layer)

Path: `<repo>/.codex/config.toml`, top-level key
`developer_instructions = """..."""`. Generated by
`generate-codex.sh` from a template; user-global Codex config is
never touched.

**Purpose:** the primer the model sees BEFORE AGENTS.md, in a
role the model treats as authoritative. Holds only the rules
where compliance failure is unacceptable.

**Target size:** 600-1000 chars (well under any practical limit).
Compactness matters because this channel is per-API-call, not
per-session.

### 2026-05-08 implementation note — downstream refresh must not hide framework fixes

During an `alex-os-dev` refresh, the operator asked to update that downstream
repo to the latest Sage SelfHost and verify that Developer Instructions carried
the important Sage rules. The refresh exposed a real Stage 3 `AGENTS.md`
idempotency bug: marker preservation matched the explanatory header mention of
`<!-- SAGE-MANAGED-END -->` instead of only the real marker comment line, so
rerunning the generator duplicated the managed block.

The code patch was small and correct in shape — anchor marker detection to
`^<!-- SAGE-MANAGED-END` and add a Stage 3 regression — but the process was
wrong: a downstream operational refresh turned into a framework runtime fix
without first routing through `sage:fix`, updating the relevant manifest/plan,
or presenting the workflow boundary to the user. This is an instruction-surface
failure mode as much as a generator bug: Developer Instructions and generated
guidance must make it explicit that edits under `runtime/`, `bin/`, `core/`,
or setup tests are Sage framework implementation work even when discovered
while refreshing another repo.

Follow-up: strengthen the Developer Instructions digest and/or hook recovery
UX so a model must stop and reclassify when a downstream maintenance task
reveals a framework code change. The target-repo ownership rule should cover
not only cross-repo file paths, but also semantic ownership: the repo whose
runtime behavior is being changed owns the workflow gate.

### Canonical content (generator template)

```toml
developer_instructions = """
This project uses the Sage methodology framework. The following
non-negotiables MUST be followed on every response. They override
any default behavior.

1. MEMORY FIRST. Before starting any Standard+ work (anything
   beyond a one-line answer), you MUST call sage_memory_search
   with task domain keywords (limit 5), then again with
   filter_tags=["self-learning"] (limit 5). Use findings.

2. SPEC AND PLAN BEFORE MUTATION. You MUST NOT mutate files
   without matching artifacts on disk:
   .sage/work/<initiative>/spec.md (status: completed) AND
   .sage/work/<initiative>/plan.md (status: completed).
   The PreToolUse hook enforces this; do not surprise yourself.

3. APPROVAL VOCABULARY IS LITERAL ENGLISH. Checkpoints are
   approved by the user typing exactly [A] or approve or continue
   (case-insensitive, whole-word). No other phrasing counts. Use
   [A] Approve / [R] Revise footers verbatim.

4. VERIFY BEFORE DONE. You MUST paste real test output before
   claiming a task complete. Summaries do NOT count.

5. CAPTURE CORRECTIONS. When the user corrects your approach,
   you MUST call sage_memory_store with self-learning tag BEFORE
   the next substantive action.

For the full cross-skill rule set, see AGENTS.md. For active
cycles run sage status; for setup verification run sage doctor.
"""
```

**Content rules** (LR-1..LR-5 from §"AGENTS.md language
requirements" apply here too):

- Imperative mood only (MUST/NEVER/MUST NOT). No "should",
  "consider", "it is recommended".
- Numbered rules, one paragraph each.
- One short framing line + one short pointer line. No marketing
  prose.
- ~600-800 chars effective. Headroom for project-specific addenda
  via `.sage/config.yaml` profile (see §"Profile-aware
  generation").

### What does NOT go in `developer_instructions`

- The full 7-rule cross-skill list with compliance lines (lives
  in AGENTS.md — too verbose for a high-weight primer).
- Public skills marker block (project AGENTS.md surface; not
  every developer-role injection should carry it).
- Per-workflow gates (lives in `core/preambles/<wf>.md` per
  ADR-6).
- Honest framing / profile description (AGENTS.md handles).

### Rule mapping between the two surfaces

`developer_instructions` carries 5 compact rules. AGENTS.md carries
all 7 cross-skill rules with full compliance lines. The mapping:

| `developer_instructions` rule (compact) | Maps to AGENTS.md rule | Topic |
|------------------------------------------|-------------------------|-------|
| 1. MEMORY FIRST | rule 4 | Pre-action memory search |
| 2. SPEC AND PLAN BEFORE MUTATION | rule 5 | Mutation precondition |
| 3. APPROVAL VOCABULARY IS LITERAL ENGLISH | rule 3 | Approval surface |
| 4. VERIFY BEFORE DONE | rule 6 | Test output requirement |
| 5. CAPTURE CORRECTIONS | rule 7 | Self-learning trigger |

AGENTS.md rules **1 (save artifacts to disk)** and **2 (NEVER use
code blocks for interaction)** are AGENTS.md-only. They describe
**output shape and protocol**, not pre-action gates — they are
how the agent FORMATS work, not what the agent must DO before
starting. Compact developer_instructions is reserved for the
strongest pre-action gates; protocol/format rules ride only the
elaborated AGENTS.md channel.

### Why the overlap is intentional

Cross-check evidence shows `developer` and `user` role messages
arrive in the same API call, in different roles, at adjacent
positions (`input[0]` vs `input[1]`). The model parses both. The
overlap is intentional:

- **Developer role:** "these rules are authoritative and high-trust"
- **User role (AGENTS.md):** "here is the full elaborated contract
  with compliance verification lines"

The model gets 5 pre-action rules in two registers (developer +
user), plus 2 protocol rules and the elaborated compliance lines
only in AGENTS.md. Net duplication cost is ~700 chars; net
compliance gain (assuming the OpenAI role hierarchy holds)
is significant because the strongest pre-action rules ride the
strongest channel.

## AGENTS.md language requirements (the strong-tone contract)

Applies to BOTH `developer_instructions` and AGENTS.md.

### Rule LR-1 — Imperative mood, not declarative

| Wrong (rejected pattern) | Right (this ADR mandates) |
|--------------------------|---------------------------|
| "This project uses Sage." | "Sage methodology is mandatory for every response." |
| "Agents should search memory before starting." | "BEFORE any Standard+ task, you MUST search `sage_memory` (limit 5)." |
| "Consider running tests after changes." | "You MUST paste real test output before claiming a task complete. Summaries do NOT count." |
| "It is recommended to save artifacts to `.sage/`." | "All specs, plans, briefs MUST land in `.sage/work/`. Inline-only is FORBIDDEN." |

Generator templates use second-person imperative throughout. No
"agents should". No "it is recommended". No "consider".

### Rule LR-2 — File-check language for gates

Where a rule has a verifiable file precondition, the rule MUST state
the file check explicitly:

> "BEFORE implementing, verify BOTH files exist on disk:
> `.sage/work/[initiative]/spec.md` (status: completed) AND
> `.sage/work/[initiative]/plan.md` (status: completed). If EITHER
> file is missing → create it first. No exceptions."

This pattern matches `CLAUDE.md` at line 109-122 of this repo and
is the empirically-strong shape.

### Rule LR-3 — Explicit prohibitions ("NEVER" / "DO NOT")

Soft phrasing is a known weak signal. Each non-negotiable behaves
the same way:

> "NEVER use code blocks for interaction (checkpoints, options,
> transitions). Code blocks are for code. Plain text with **bold**
> emphasis for everything else."

> "DO NOT skip the spec gate because 'the design is clear'. A spec
> file is a file on disk, not a feeling."

### Rule LR-4 — Compliance check after each rule (AGENTS.md only)

Each numbered AGENTS.md rule ends with one line stating the
observable signal that the rule was followed:

> **Compliance:** Every Standard+ workflow start includes at least
> one `sage_memory_search` call before producing artifacts.

Compliance lines are AGENTS.md-only. `developer_instructions` is
compact primer mode; compliance verification belongs in the
elaborated channel.

### Rule LR-5 — No marketing prose

Neither file is a README. Sage philosophy, framework history, and
architecture explanations belong in `runtime/platforms/codex/INSTALL.md`
or `.sage/docs/`. Both surfaces contain rules, not pitches.

### Rule LR-6 — Generator template review gate

Templates live at:
- `runtime/platforms/codex/templates/agents.md.tmpl` (new)
- `runtime/platforms/codex/templates/developer-instructions.toml.tmpl` (new)

Every edit to either template requires:

- Side-by-side diff with this repo's `CLAUDE.md` constitution.
- Manual check: imperative mood + file-check language + (for
  AGENTS.md) explicit compliance line.
- `sage doctor --strict` (ADR-9) re-runs lint programmatically on
  generated artifacts.

## AGENTS.md content (project layer)

What goes in `<repo>/AGENTS.md` (auto-generated by
`generate-codex.sh`):

| Block | Purpose | Source |
|-------|---------|--------|
| Header | "Sage methodology is mandatory. Cross-skill rules below MUST be followed on every response. Per-workflow gates load when you invoke `$skillname`." | static |
| Cross-skill rules (7) | Full canonical rule set with compliance lines (LR-1..LR-4) | static |
| Worktree scope | "Operations MUST be limited to the current worktree. NEVER touch parent project state from a worktree session." — from ADR-1 W1 | static |
| Public skills marker block | Generated list of `$skill` invocations Codex shows by default | from `skills.compiled.json` (ADR-4) |
| Honest framing | "Active enforcement profile: <strict\|fast-trusted>. <single sentence on what that profile guarantees AND what it does not>." — from V3 | from `.sage/config.yaml` profile setting |
| `sage status` / `sage doctor` pointer | "For active cycles, run `sage status`. For setup verification, run `sage doctor`." | static |

What does NOT go in AGENTS.md:

- Per-workflow gates ("3 elicitation rounds")
  — those live in `core/preambles/<wf>.md` (ADR-6).
- Verbose Sage manifesto / philosophy. INSTALL.md teaches.
- Tool tables. Codex shows tools via its native discovery surface.

### Cross-skill rules (the canonical list, imperative form)

These are the rules that pass the ADR-6 boundary test ("if removing
the rule from one preamble would clone it into 3+ others, it belongs
at session level"). They appear in AGENTS.md with full compliance
lines. **Rules 1-5 also appear in compact form in
`developer_instructions`** (high-weight primer):

1. **Save artifacts to disk.** All specs, plans, briefs, ADRs MUST
   land in `.sage/work/` or `.sage/docs/`. Inline-only output is
   FORBIDDEN for Standard+ work.
   *Compliance:* Every Standard+ checkpoint references a file path
   under `.sage/`.
2. **NEVER use code blocks for interaction.** Checkpoints, options,
   and transitions are plain text with **bold** emphasis. Code
   blocks are for code only.
   *Compliance:* No backtick-fenced block contains
   `[A]`/`[1]`/checkpoint footers.
3. **Approval vocabulary is literal English.** Use `[1]`/`[2]`/`[3]`
   for choices and `[A]` Approve / `[R]` Revise for checkpoints.
   These exact tokens drive the ADR-2 W2 approval surface — they
   are NOT stylistic.
   *Compliance:* Every choice block uses `[1]/[2]/[3]`; every
   checkpoint footer uses `[A] Approve / [R] Revise`.
   *(Mirrored in `developer_instructions` rule 3)*
4. **MEMORY FIRST.** BEFORE starting Standard+ work, you MUST call
   `sage_memory_search` with the task domain (limit 5), THEN call
   it again with `filter_tags: ["self-learning"]` (limit 5). Skip
   ONLY for Tier 1 tasks.
   *Compliance:* At least one `sage_memory_search` call appears
   before the first artifact write on every Standard+ workflow.
   *(Mirrored in `developer_instructions` rule 1)*
5. **Spec or plan exists before mutation.** The `apply_patch` hook
   (ADR-1) enforces this at the kernel surface. Patches without
   matching `.sage/work/<initiative>/spec.md` AND `plan.md` are
   denied at the hook layer.
   *Compliance:* Every commit-touching edit is preceded by a
   matching artifact under `.sage/work/`.
   *(Mirrored in `developer_instructions` rule 2)*
6. **Verify before claiming done.** You MUST paste real test output
   before saying "done". Summaries do NOT count. If tests don't
   exist or don't pass, the task is NOT done.
   *Compliance:* Every "done" message contains a fenced code block
   with literal command output, not a paraphrase.
   *(Mirrored in `developer_instructions` rule 4)*
7. **Capture corrections.** When the user corrects your approach,
   you MUST call `sage_memory_store` with `filter_tags:
   ["self-learning", "<type>"]` BEFORE proceeding. This is
   automatic, not optional.
   *Compliance:* Every correction-pattern user message is followed
   by a `sage_memory_store` call before the next substantive work.
   *(Mirrored in `developer_instructions` rule 5)*

### Public skills marker block

Generator emits, between fixed markers:

```markdown
<!-- >>> SAGE PUBLIC SKILLS START -->
Available Sage workflows. Invoke with `$skillname`:

- `$build` — feature: spec → plan → build-loop → quality gates
- `$fix` — diagnose → scope → fix → verify
- `$architect` — elicit → design → milestone plan → phased build
- `$research` — interview → JTBD → opportunity map
- `$design` — brief → spec → copy
- `$analyze` — UX audit → evaluation → findings
- `$reflect` — review cycle → extract learnings → seed next cycle
- `$continue` — resume any active cycle with full context
- `$qa` — browser-based functional testing
- `$map` — ontology / dependency mapping
- `$autoresearch` — optimize / iterate-until pattern
- `$design-review` — design quality + system compliance audit
- `$status` — project state summary
- `$review` — independent evaluation via sub-agent
- `$learn` — codebase scan → memory storage
- `$sage` — route → confirm → enter

To add or remove public skills: edit
`core/workflows/<name>.workflow.md` `manifest.public` and rerun
`sage update`.
<!-- <<< SAGE PUBLIC SKILLS END -->
```

The block is regenerated on every `sage update` from
`core/_compile/skills.compiled.json` filtered on
`public: true AND "codex" in platforms`.

### AGENTS.md char budget

Target: **≤16 KiB** for the Sage-generated content. Hard cap (Codex):
32 KiB. Headroom 16 KiB for project-specific additions the user
might paste below the Sage block.

| Block | Estimated bytes |
|-------|-----------------|
| Header + framing (imperative form) | ~700 |
| Cross-skill rules (7 rules with compliance lines) | ~3500 |
| Worktree scope rule | ~300 |
| Public skills marker block (16 entries) | ~1500 |
| Honest framing block | ~600 |
| `sage status` / `sage doctor` pointer | ~200 |
| Margin / blank lines | ~600 |
| **Subtotal (Sage-managed)** | **~7400** |

UPS approval vocabulary text moves to AGENTS.md cross-skill rule 3
(was a separate row in the previous draft); it is also in
`developer_instructions` rule 3.

`developer_instructions` adds **~700-1000 chars** in a separate
config string (no AGENTS.md cap impact).

`sage doctor` measures the actual generated AGENTS.md and warns at
24 KiB (75% of cap), fails at 32 KiB.

### User additions to AGENTS.md (append-below model)

The generated AGENTS.md ends with a hard separator line and a
user-additions zone:

```markdown
<-- everything above is Sage-managed and regenerated by `sage update` -->

---
## --- USER ADDITIONS BELOW ---

<!-- Anything below this line is preserved across `sage update`.
     Add project-specific instructions for Codex here. -->

```

**Preservation rule:** `generate-codex.sh` regenerates everything
**above** the literal line `## --- USER ADDITIONS BELOW ---` and
preserves everything **below** it byte-for-byte.

**Failure handling:**
- Separator missing (legacy AGENTS.md without it) → generator
  appends the separator + empty user zone at the end. No content
  is lost (Sage-managed content lands above; legacy content lands
  below the new separator as user additions).
- User accidentally puts content ABOVE the separator → that
  content is overwritten on next `sage update`. `sage doctor`
  warns: "AGENTS.md has content between Sage block and separator;
  move it below `## --- USER ADDITIONS BELOW ---` to preserve."
- Separator duplicated → generator uses the FIRST occurrence as
  the boundary; warns about the duplicate.

This separator-based append-below model is preferred over a
START/END marker pair because:
- One line to remember, not two
- User cannot accidentally drop the END marker and lose all
  customisation
- Visually obvious in the file (literal line "USER ADDITIONS
  BELOW" appears in the middle)

## Profile-aware generation

`.sage/config.yaml` has a `profile` setting (`strict` |
`fast-trusted`, per V3). Both surfaces are profile-aware:

- **`developer_instructions`** — same 5 rules in both profiles
  (non-negotiables don't flex). Profile name appears in the
  framing line.
- **AGENTS.md honest framing block** — sentence varies by profile:
  - `strict`: "PreToolUse fail-closed; MCP required; mutations
    without spec.md/plan.md are denied at the hook surface."
  - `fast-trusted`: "PreToolUse fail-closed (apply_patch);
    Bash write paths trusted (caught by L5 pre-commit). MCP
    required. False-positive UPS-tokens are accepted as the
    cost of determinism."

## Hook contracts

### `SessionStart` — `runtime/platforms/codex/hooks/session-init.sh`

| Field | Value |
|-------|-------|
| Matcher | `startup\|resume\|clear\|compact` |
| Block via | `"continue": false` (not used in v1) |
| Cache | Once per session; output is part of session prelude |

Action sequence:

1. Verify `[features].codex_hooks = true` is set in the loaded
   config. If absent → emit warning to stderr ("hooks present but
   not enabled — run `sage doctor`"), exit 0 (do NOT block session).
2. Verify project trust state. If untrusted → emit warning to
   stderr ("project not trusted — `.codex/config.toml` not loaded
   (this also disables `developer_instructions`); run `sage doctor`
   for the trust line to add"), exit 0.
3. Read `.sage/work/*/manifest.md` frontmatter for any cycle with
   `status: in-progress` or `status: paused`. Emit a short summary
   block (cycle title, workflow, phase, next-step from handoff).
4. Read latest 3 `### ` entries from `.sage/decisions.md`. Emit
   compact list.
5. Output everything to stdout as structured markdown. Codex wraps
   it in a system-reminder equivalent and injects into context.

This script replaces the Claude port's `sage-session-init.sh`
(claude-port-logic-map §3.6 — same logical capability,
platform-different surface).

Failure mode: script crashes → Codex logs to its hook log; session
proceeds without context injection. Acceptable degradation.

### `UserPromptSubmit` — `runtime/platforms/codex/hooks/ups-approval.sh`

| Field | Value |
|-------|-------|
| Matcher | none (UserPromptSubmit has no matcher field — research base §4.5) |
| Fires | every user message |
| Cache cost | stable script text → KV-cache hit |

Action sequence (per ADR-2 W2):

1. Read `prompt` field from Codex hook payload (PoC C1 ext.
   confirmed this is the literal user text, Codex 0.126).
2. Detect English Sage gate vocabulary by **whole-word
   case-insensitive match**:
   - `[A]`, `[a]`
   - `approve`
   - `continue`
3. On match:
   - Read latest active manifest to infer `cycle` and pending `gate`
     (best-effort; both fields nullable).
   - Compose JSON token:
     ```json
     {
       "cycle": "...",
       "gate": "...",
       "issued_at": "<now ISO 8601 UTC>",
       "expires_at": "<now+5min ISO 8601 UTC>"
     }
     ```
   - Atomic write to `.sage/.approval-pending` (mktemp + mv).
4. On no match: exit 0, do nothing.

**Hard constraints** (non-negotiable, locked here):

- Vocabulary is **English-only** and **literal**. No Polish
  detection. No "yes go ahead" semantic match. No regex on
  conjugations.
- Whole-word match — `approval` does NOT match `approve`;
  `continued` does NOT match `continue`. Use word boundaries
  (`\b...\b`) in grep.
- Case-insensitive — `[A]`, `[a]`, `Approve`, `APPROVE` all match.
- The hook is the **only writer** of `.sage/.approval-pending`.
  ADR-2 W2 single-writer assumption depends on this.

The teaching surface (where users learn the vocabulary) is
**both** `developer_instructions` rule 3 AND the AGENTS.md
cross-skill rule 3 AND the `[A] Approve / [R] Revise` checkpoint
footer. `sage status` will surface a *"approval pending — type
[A] to confirm"* hint when a checkpoint is open.

### `PreToolUse` — `runtime/platforms/codex/hooks/pre-tool-validate.sh`

| Field | Value |
|-------|-------|
| Matcher | regex on tool name |
| Registered names (v1) | `apply_patch` |
| Block via | `"permissionDecision": "deny"` or **exit code 2** |

Action sequence (per ADR-1):

1. Read tool name + args from payload.
2. If MCP server is reachable: call `sage_validate_mutation` MCP
   tool with the active initiative path; the tool returns
   allow/deny.
3. If MCP server is NOT reachable: ADR-3 D6 mid-session recovery
   path applies — log to `.sage/.mcp-incidents.log` and **deny**
   (fail-closed, per V3 honest framing for strict profile;
   fast-trusted profile uses `required = true` so this branch
   should not fire — if it does, MCP startup already failed and
   session is in error state). **`pre-tool-validate.sh` is
   listed as an authorised writer of `.mcp-incidents.log` in
   ADR-3 §"Files written outside MCP" (added in this ADR's
   review pass).**
4. Translate MCP result to hook exit code: allow → 0, deny → 2.

v1 matcher list is **`apply_patch` only** (per Round 3 G2). Bash
write paths are accepted as a known leak, caught by L5 pre-commit.

Future expansion: when v1 outcome harness shows the leak is too
large, add Bash matcher with command-content regex (option (c)
from G2). Schema lives in `.codex/hooks.json` so adding a matcher
is a generator-only change.

### `Stop` — `runtime/platforms/codex/hooks/turn-audit.sh`

| Field | Value |
|-------|-------|
| Matcher | none (Stop has no matcher — research base §4.5) |
| Fires | end of every turn |
| Block via | `"continue": false` (not used in v1) |

Action sequence (full audit logic in ADR-7; this ADR locks the
surface contract only):

1. Shim → `sage_audit_turn` MCP tool call.
2. Audit checks (ADR-7 will detail):
   - Stale `.sage/.approval-pending` token (issued but never
     consumed — possible "user typed approve, agent never followed
     through" pattern; log incident).
   - Forge attempts on `.sage/.approval-pending` written by
     non-hook process — detected via Stop hook examining file
     mtime + comparing to UPS hook log (ADR-2 honest framing:
     detectable, not preventable).
   - Active gate state: was a checkpoint pending at turn end and
     not addressed?
3. Audit writes findings to `.sage/.mcp-incidents.log`.
4. v1: audit does NOT block continuation (`"continue": true` always).
   v2 candidate: hard-block on critical incidents.

### `PermissionRequest` — DEFERRED to v2

**Not wired in v1.** Reasoning:

- `PreToolUse(apply_patch)` already covers the dominant mutation
  vector. PermissionRequest fires when the model *requests*
  approval before tool dispatch — useful for granular approval
  policy fine-tuning, but adds another script and another point
  of failure.
- v1 outcome harness (brief C5) will surface gaps if PreToolUse
  alone is insufficient. Then we add PermissionRequest with data,
  not speculation.

### `PostToolUse` — DEFERRED to v2

**Not wired in v1.** Reasoning:

- Pre-mutation gating (PreToolUse) prevents the bad write before
  it lands. Post-mutation hooks add audit value but can't undo.
- Stop hook covers turn-end audit (ADR-7). PostToolUse would add
  per-tool audit chatter; not useful in v1 fast-trusted profile.

## hooks.json schema (v1)

Generated by `generate-codex.sh` at `<repo>/.codex/hooks.json`.
Source of truth template: `runtime/platforms/codex/hooks.example.json`.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash runtime/platforms/codex/hooks/session-init.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash runtime/platforms/codex/hooks/ups-approval.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          {
            "type": "command",
            "command": "bash runtime/platforms/codex/hooks/pre-tool-validate.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash runtime/platforms/codex/hooks/turn-audit.sh"
          }
        ]
      }
    ]
  }
}
```

`PermissionRequest` and `PostToolUse` keys are absent. Adding them
in v2 = an additive PR; no schema migration.

## Discovery + composition order (Codex native)

Verified against Codex source (`config_toml.rs`, `loader/mod.rs`,
`client.rs`):

1. **`developer_instructions`** — composed from config layers in
   precedence order (admin → system → user → project → CLI runtime).
   Project layer overrides user layer when both define it. Lands
   in API call as `developer` role message at `input[0]`. **Sage
   writes this in project `<repo>/.codex/config.toml`.**
2. AGENTS chain:
   - `~/.codex/AGENTS.override.md` *(out of Sage scope)*
   - `~/.codex/AGENTS.md` *(out of Sage scope)*
   - `<project-root>/AGENTS.override.md` *(out of Sage scope)*
   - **`<project-root>/AGENTS.md`** *(Sage owns this)*
   - (each subdir from project-root to cwd: `AGENTS.override.md`
     then `AGENTS.md`)
   Concatenated, "later overrides earlier", lands in API call
   as `user` role context message at `input[1]`.
3. Built-in Codex base instructions.
4. First user turn.

**Role hierarchy:** developer > user. So `developer_instructions`
(step 1) outranks AGENTS.md (step 2) in conflict resolution
*at the model compliance level*, even though both arrive in the
same API call. This is the empirical anchor for the dual-surface
decision.

## Cross-check status

- Empirical findings table in §"Empirical findings" — VERIFIED
  against Codex source 2026-04-29.
- **v1 (this ADR):** spec.md (post-Batch-3) MUST re-run a manual
  cross-check pass when `codex_min_version` is bumped (today's pin:
  0.126). Owner: whoever bumps the version. Cadence: at every
  `codex_min_version` change, before the bump merges.
  Specifically verify:
  - `config_toml.rs` `developer_instructions` field still present
  - `client.rs` test still asserts `role == "developer"` for
    `input[0]`
  - No new `*_MAX_BYTES` cap added on `developer_instructions`
  - Hook event names + matcher syntax unchanged
  - `[features].codex_hooks` flag still gates hook loading
  - `[projects."<abs>"].trust_level` still gates project config

- **v2 (deferred):** automate the above as a **verification
  snapshot artifact**. New file
  `runtime/platforms/codex/templates/codex-source-verification.json`
  records:
  - Verified Codex source file paths
  - Source SHAs at last verification time
  - Assertion strings (e.g. `"role == \"developer\""`)
  - Date of last verification + verifying agent ID

  `sage doctor --codex-version-changed` (new flag) re-runs a
  sub-agent cross-check pass against the current Codex source
  and fails closed if any assertion no longer holds. Until v2
  lands, the manual cross-check is the only mechanism — accept
  this as a known v1 gap, with explicit owner (version bumper)
  + cadence (per bump).

## Options considered

### Option A (chosen) — two project-scoped surfaces (AGENTS.md + developer_instructions) + four-script v1 hooks + imperative tone contract

Plus:
- Dual-channel: strongest 5 rules ride **developer role** API
  message (verified higher-trust than user role); full contract
  rides AGENTS.md with rich structure.
- Both surfaces project-scoped → Sage writes to project files
  only. Zero user-global writes.
- Imperative tone addresses the empirical compliance gap observed
  in cycle 2026-04-28 commit `a6f1391`. ADR-8 outcome harness
  measures whether the gap is closed in practice.
- Hook surface matches the operations we know we need (audit per
  ADR-7, mutation gate per ADR-1, UPS-token per ADR-2, context
  injection per claude-port-logic-map analog).
- Defers PermissionRequest + PostToolUse with documented rationale
  (data-driven additions in v2).

Minus:
- Two surfaces to keep in sync (≈700-char overlap on rules 1-5).
  Mitigated: both generated from one template source, drift caught
  by `sage doctor --strict` lint.
- Project trust gate disables BOTH `developer_instructions`
  and project AGENTS.md until trusted. Mitigated: same gate
  already required for hooks; `sage init` G5 prompt handles in
  one step.
- Four hook scripts to maintain. Mitigated: each is a thin shim
  delegating to MCP (per ADR-3); the actual logic lives in one
  Python service.

### Option B — single AGENTS.md surface only

Plus:
- Simplest model. One file Sage writes.

Minus:
- Uses ONLY the user-role channel. Empirical evidence
  (§"Empirical findings") shows `developer_instructions` is a
  structurally stronger channel that cycle 2026-04-28 left
  unused. Adopting B means we knowingly leave the strongest
  compliance lever inactive.
- The 2026-04-28 enforcement gap had two contributors: weak tone
  AND single-channel. Fixing only tone leaves channel strength
  on the table.
- **Rejected** — empirical data points to Option A.

### Option C — wire all six hook events in v1

Plus:
- Maximum hook coverage from day one.

Minus:
- PermissionRequest and PostToolUse add 2 more scripts + 2 more
  failure modes for marginal v1 value (PreToolUse already gates).
- Outcome harness (brief C5) hasn't told us we need them. Building
  on speculation contradicts brief V3 ("honest framing").
- **Rejected.**

### Option D — inline hook logic, no MCP shim

Plus:
- Hooks self-contained; no MCP startup dependency for hooks to work.

Minus:
- Re-implements ADR-3's MCP service surface in shell. Two sources
  of truth for state machine and approval logic. ADR-3 D6 mid-
  session recovery already accepts MCP-backed validators; this
  ADR aligns hooks with that model.
- Bash hooks parsing JSON payloads + writing approval frontmatter
  + recording decisions.md entries = a 500-line shell script per
  hook. Auditability suffers.
- **Rejected.**

### Option E — Sage writes to user-global `~/.codex/config.toml` `developer_instructions`

Plus:
- Cross-project Sage primer — works even in repos without Sage
  init.

Minus:
- Sage writes to user-global file. Sharp footgun per research
  base §6.1.8 (idempotency bug = corrupted user config).
- Project layer overrides user layer anyway, so for any Sage
  project the user-global value is masked. The cross-project
  benefit only applies to non-Sage projects, which is out of
  scope for v1 (brief: framework should be portable, not user-
  resident).
- **Rejected.**

### Option F — keep declarative AGENTS.md tone (status quo from rejected redesign)

Plus:
- Minimum delta from current generator templates.

Minus:
- Empirical evidence from cycle 2026-04-28 closed `a6f1391` showed
  declarative tone yields measurably weaker compliance than the
  imperative `CLAUDE.md` parity in the same repo.
- **Rejected.**

## Trade-offs

- **Two surfaces** doubles the template surface (AGENTS.md +
  developer_instructions) but each template is small and both
  share the LR-1..LR-6 rule set. Drift caught by lint.
- **Imperative tone (LR-1..LR-6)** adds ~25% to AGENTS.md char
  count vs declarative form. Still well under the 16 KiB target
  / 32 KiB cap. `developer_instructions` has no documented cap.
- **`developer_instructions` per-project means project must be
  trusted** for it to land in the model. Same gate as hooks; no
  new infra. `sage doctor` reports trust state.
- **Hook scripts as thin bash shims** keep the shell layer
  auditable but require the MCP server to be up. ADR-3
  `required = true` makes the dependency loud (session fails to
  start if MCP fails); ADR-3 D6 documents the mid-session
  recovery path.
- **PermissionRequest and PostToolUse deferred** means v1 might
  miss approval-time gating gaps. The outcome harness will catch
  this if it matters; v2 is one PR away.
- **`UserPromptSubmit` cache cost** — the hook script text is
  stable (no per-turn dynamic content), so KV-cache stays warm
  across turns (research base §4.5).
- **`sage update` prompt-cache invalidation** — each `sage update`
  regenerates `<repo>/.codex/config.toml` (with new
  `developer_instructions`) and `<repo>/AGENTS.md`. Sessions
  started AFTER `sage update` pay one prompt-cache miss because
  the cached prefix changed. In-flight sessions are unaffected
  (config loaded once at session start). Acceptable cost; users
  who run `sage update` frequently see this as one extra startup
  delay per update, not a per-turn cost.
- **No silent-failure hiding** — both `[features].codex_hooks` and
  project trust are checked at SessionStart with clear stderr
  warnings, AND by `sage doctor`. Two surfaces; neither alone is
  the only line of defense.

## Failure modes

**FM-1 — `[features].codex_hooks = true` missing in loaded config.**
- Detection: SessionStart hook prints stderr warning; `sage doctor`
  reads loaded config and reports.
- Impact: all Sage hooks silently no-op. `apply_patch` mutation
  gate inactive; UPS-token issuance inactive; turn audit inactive.
- Mitigation: `sage init` includes the flag in generated
  `.codex/config.toml`; `sage doctor --fix` can re-add it; status
  is visible in `sage status`.

**FM-2 — Project untrusted (no `[projects."<abs>"].trust_level =
"trusted"` in user-global config).**
- Detection: SessionStart hook prints stderr warning + suggests the
  exact line to add; `sage doctor` reports.
- Impact: project `.codex/config.toml` is loaded-but-disabled. This
  disables BOTH project hooks AND project `developer_instructions`.
  Same effective outcome as FM-1 plus loss of the developer-role
  primer.
- Mitigation: `sage init` interactive prompt offers to add the
  trust line (per ADR-3 G5).

**FM-3 — AGENTS.md exceeds 32 KiB.**
- Detection: generator measures `wc -c` after generation; warns
  at 24 KiB, fails at 32 KiB.
- Impact: Codex stops adding files past the threshold; project
  additions silently dropped.
- Mitigation: cross-skill rule list is finite by ADR-6 boundary
  test; public skills marker block is bounded by 16-skill cap;
  drift comes from project additions, which `sage doctor`
  surfaces.

**FM-4 — Hook script not executable or missing shebang.**
- Detection: Codex logs hook failure to its hook log; SessionStart
  is the loudest because user sees it first.
- Impact: that specific hook silently no-ops.
- Mitigation: `sage init` chmods scripts; `sage doctor` checks
  +x and shebang lines.

**FM-5 — `ups-approval.sh` matches a phrase that user did not
intend as approval.**
- Example: user types "the approve button is gray" — `approve`
  matches, token issued.
- Impact: a token sits in `.sage/.approval-pending` for 5 minutes
  with no associated checkpoint. ADR-2 W2 5-minute expiry handles
  most cases; Stop hook (ADR-7) detects and logs stale tokens.
- Honest framing: false positives are accepted as the cost of
  determinism.

**FM-6 — MCP server unreachable mid-session (ADR-3 D6 path).**
- Detection: `pre-tool-validate.sh` cannot call `sage_validate_mutation`.
- Impact: in `required = true` config (v1 default), MCP failure
  fails session startup, so this is the mid-session-crash branch
  only.
- Mitigation: hook denies the mutation, logs incident to
  `.sage/.mcp-incidents.log` (ADR-3 D6). User restarts session.

**FM-7 — Forge attempt on `.sage/.approval-pending`.**
- Detection: Stop hook compares file mtime against UPS hook log;
  any non-hook write is flagged.
- Impact: agent could write a fake token via `apply_patch`, which
  itself goes through PreToolUse — so the mutation must be
  approved by another already-valid token. Catch-22 by design
  (ADR-2 §Why this works).
- Honest framing: detectable in `git diff`, not preventable in
  fast-trusted profile.

**FM-8 — Tone drift in either surface (developer_instructions or
AGENTS.md).**
- Detection: `sage doctor --strict` runs LR-1..LR-3 lint on both
  generated artifacts (forbidden phrase list: "agents should",
  "consider", "it is recommended").
- Impact: re-emergence of the 2026-04-28 enforcement gap.
- Mitigation: lint runs in CI; LR-6 generator template review
  gate; templates live in code-reviewed files.

**FM-9 — `developer_instructions` and AGENTS.md drift out of sync
on rules 1-5.**
- Detection: `sage doctor --strict` lint compares the canonical
  rule list (defined in this ADR) against both generated artifacts.
- Impact: model gets contradictory or misaligned rules across the
  two API roles; compliance becomes unpredictable.
- Mitigation: both templates pull from one shared rule source
  (`runtime/platforms/codex/templates/canonical-rules.yaml`, new
  file in Step 3 of migration). Templates render different views
  of the same rules.

## Migration plan

Migration is mechanical. Generator output is testable.

### Step 1 — Land hook scripts

Create four bash scripts under `runtime/platforms/codex/hooks/`:

- `session-init.sh` (replaces existing legacy script — the
  rejected-cycle starter pack is expendable per brief)
- `ups-approval.sh` (new)
- `pre-tool-validate.sh` (new — shim to `sage_validate_mutation`)
- `turn-audit.sh` (new — shim to `sage_audit_turn`; full logic in
  ADR-7)

Each is ≤80 lines. Each starts with `#!/usr/bin/env bash` and
`set -euo pipefail`. Each handles JSON payload via `jq` (already a
generator dep).

### Step 2 — Land `hooks.example.json`

Replace `runtime/platforms/codex/hooks.example.json` with the v1
schema above (4 events). The generator path-substitutes
`${CODEX_PROJECT_DIR}` into the `command` strings during emission
to the per-project `.codex/hooks.json`.

### Step 3 — Land canonical rule source + two templates

New files:

- `runtime/platforms/codex/templates/canonical-rules.yaml` —
  source of truth for the 7 cross-skill rules; both templates
  render from this.
- `runtime/platforms/codex/templates/agents.md.tmpl` — full
  AGENTS.md including 7 rules with compliance lines, public
  skills marker block, framing.
- `runtime/platforms/codex/templates/developer-instructions.toml.tmpl` —
  compact `developer_instructions` string with rules 1-5 in
  imperative form, no compliance lines.

### Step 4 — Update `generate-codex.sh`

- Read canonical rules YAML.
- Render AGENTS.md from agents.md.tmpl (fill marker blocks
  from `core/_compile/skills.compiled.json` and `.sage/config.yaml`
  profile).
- **AGENTS.md preservation flow** (append-below model):
  1. If `<repo>/AGENTS.md` exists, read it. Find first occurrence
     of literal line `## --- USER ADDITIONS BELOW ---`.
  2. If found: capture everything from that line onward as
     `user_zone`.
  3. If not found (legacy file or first-run): set `user_zone` to
     a default empty zone (separator + comment block).
  4. Generate Sage-managed content above; append separator;
     append `user_zone` below.
  5. Atomic write (mktemp + mv) to `<repo>/AGENTS.md`.
- Render `developer_instructions` value from
  developer-instructions.toml.tmpl.
- Emit `<repo>/.codex/config.toml` containing top-level
  `developer_instructions = """..."""` PLUS `[features]
  codex_hooks = true` PLUS `[mcp_servers.sage]` block (per
  ADR-3) PLUS any other Sage-managed config. Same atomic-write
  + Sage-block preservation pattern as AGENTS.md if user added
  custom keys.
- After emission: measure `wc -c AGENTS.md`; warn ≥24 KiB, fail
  ≥32 KiB.
- Generate `.codex/hooks.json` from the example template with
  path substitution.

### Step 5 — `sage init` flow

Per ADR-3 G5:

- After project files land, prompt: "Add this project to trusted
  projects in your global Codex config? [y/N]".
- Yes → atomic edit of `~/.codex/config.toml` adding
  `[projects."<abs>"] trust_level = "trusted"` between Sage-managed
  markers. **This step gates BOTH project hooks AND project
  `developer_instructions` activation.**
- No → print copy-paste line: "To activate Sage hooks AND the
  developer-role primer, add this to `~/.codex/config.toml`:\n\n
  [projects.\"<abs>\"]\ntrust_level = \"trusted\"\n".

`sage init` does NOT touch user-global `~/.codex/config.toml`
`developer_instructions` (per Out-of-scope: user-global writes
are forbidden).

### Step 6 — `sage doctor` checks

- `[features].codex_hooks = true` set in loaded config.
- Project trust state.
- All four hook scripts exist, executable, valid shebang.
- AGENTS.md size <24 KiB (warn) / <32 KiB (fail).
- Public skills marker block matches `skills.compiled.json` (no
  drift between marker and source of truth).
- `developer_instructions` field present in
  `<repo>/.codex/config.toml`, non-empty.
- `--strict` mode:
  - AGENTS.md tone lint (forbidden phrases per LR-1..LR-3).
  - `developer_instructions` tone lint (same forbidden phrases).
  - Rules 1-5 alignment check between AGENTS.md and
    `developer_instructions` (FM-9).

### Step 7 — Verification

Outcome harness (brief C5) prompts that exercise each surface:

- SessionStart: prompt that depends on injected cycle context
  (e.g., "what's my current task?") — expect agent to reference
  the active manifest summary.
- UserPromptSubmit: prompt with `[A]` literal — expect token to
  appear in `.sage/.approval-pending` with 5-minute expiry.
- PreToolUse: prompt that triggers a mutation without prior spec
  — expect deny + clear error.
- Stop: prompt that types `[A]` but the agent doesn't follow
  through — expect Stop hook to log a stale-token incident.
- `developer_instructions` channel: prompt that tests rule 1
  compliance (e.g. "build me X" without prior memory search) —
  expect agent to call `sage_memory_search` first. Compare
  against same prompt run with `developer_instructions` removed
  (control — verifies the developer-role channel is doing work).
  **ADR-8 (outcome harness) MUST wire a harness toggle that
  regenerates `<repo>/.codex/config.toml` with and without the
  `developer_instructions` field between control and treatment
  runs.** This ADR commits the verification scope; ADR-8
  commits the harness mechanism (template variant emission +
  session restart between runs).
- Tone lint: run `sage doctor --strict` against generated
  AGENTS.md AND `<repo>/.codex/config.toml`; expect no
  forbidden phrases in either.

## Consequences

- **ADR-1 (PreToolUse mutation predicate)** keeps its integration
  point: `pre-tool-validate.sh` shim is the surface defined here.
- **ADR-2 (approval proof schema)** has its W2 contract gap closed
  here: `ups-approval.sh` script schema is locked. The approval
  vocabulary is taught in BOTH `developer_instructions` rule 3
  AND AGENTS.md rule 3 — defense in depth.
- **ADR-3 (MCP stack)** keeps `required = true` as the entry
  contract — hook scripts depend on MCP being up. ADR-3 D6
  mid-session recovery path remains the documented incident
  procedure.
- **ADR-4 (shared skill manifest)** feeds the public skills marker
  block in AGENTS.md. Generator reads `skills.compiled.json`.
- **ADR-6 (preamble extraction)** boundary test determines what
  cross-skill rules live at session level (this ADR's two
  surfaces) vs per-workflow preambles.
- **ADR-7 (Stop hook scope)** consumes the `turn-audit.sh` shim
  contract defined here. ADR-7 details the audit logic.
- **ADR-9 (sage doctor + status)** consumes the doctor checks
  listed in Failure modes (FM-1 through FM-5, FM-8, FM-9).
- **`bin/sage init`** gains the interactive trust-level prompt
  (per Out-of-scope: no user-global writes).
- **`runtime/platforms/codex/INSTALL.md`** documents the
  two-surface architecture for downstream users (and notes that
  user-global `developer_instructions` is out of Sage's scope).
- **`runtime/platforms/codex/HOOKS.md`** is rewritten to match
  this ADR's schema. The current HOOKS.md document is expendable
  per brief.
- **Spec.md** MUST re-run the empirical findings cross-check
  whenever `codex_min_version` is bumped.

## Open questions for review

All five Batch 2 open questions were closed in Batch 3 (Stop hook
scope ADR-7; remaining four in ADR-9). Resolutions recorded below
for traceability.

1. **Stop hook v1 scope** — **CLOSED 2026-04-29 by ADR-7.**
   Surface locked here (`turn-audit.sh` shim → `sage_audit_turn`
   MCP); audit semantics locked in ADR-7 with seven warn-only
   checks (C1–C7), v1 invariant: NEVER hard-block. User approved
   full 7-check version over the minimalist 2-check fallback.
2. **PermissionRequest / PostToolUse stub scripts in v1?** —
   **CLOSED 2026-04-29 by ADR-9 D2 (H2).** NO stubs. `sage
   doctor`'s H2 check verifies absence as v1-correct state.
   Wiring them in v2 is an additive PR (no schema migration).
3. **Developer-instructions content size budget** — **CLOSED
   2026-04-29 by ADR-9 D2 L3 (`--strict` lint).** Locked
   range: 700–1000 chars. Below 500 → warn ("compression too
   aggressive"); above 1000 → error ("rule scope drift").
   Rule split (1–5 in dev-instructions, 6–7 only in AGENTS.md)
   stands; ADR-8 outcome harness measures whether the assumption
   holds.
4. **Tone lint forbidden-phrase list** — **CLOSED 2026-04-29 by
   ADR-9 D2 L1.** v1 seed locked at 9 phrases (case-insensitive
   substring): `"agents should"`, `"agents may"`, `"consider "`,
   `"it is recommended"`, `"please "`, `"if you'd like"`,
   `"feel free to"`, `"try to"`, `"agent will typically"`. One
   match → warn; ≥2 matches → error. Spec.md is the canonical
   place for future expansion (e.g., specific phrases observed
   in the 2026-04-28 cycle); this ADR locks the v1 seed.
5. **`runtime/platforms/codex/INSTALL.md` framing of native
   escape hatches** — **CLOSED 2026-04-30 by ADR-9 D7 (Native
   escape-hatch posture).** Honest stance: Sage manages what
   Sage owns. INSTALL.md documents that `AGENTS.override.md`,
   `.codex/AGENTS.local.md`, and user additions to
   `<repo>/.codex/config.toml` outside the `# --- SAGE BEGIN/END ---`
   markers are native Codex features preserved by Sage but not
   written or linted by Sage. `sage doctor` surfaces their
   existence as INFO (not warn) via N1–N3 checks so the user
   remembers they may affect agent behavior.

## Status: proposed

Awaiting user approval at design checkpoint after Batch 3 + spec.md.
