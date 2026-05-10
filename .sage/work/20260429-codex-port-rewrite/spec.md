---
title: "Spec — Codex port rewrite (greenfield, in-tree, v1)"
status: completed
phase: design
date: 2026-04-30
approved_at: "2026-04-30"
approved_by: "alexostl"
approval_note: "Sign-off na 5 punktów §16: scope (1), nomenclature (2), residual risks R-5/R-6/R-9 z N/A R-1/R-3/R-4 (3), 4 cuts A/B/C/D conscious choice + v2 promotion triggers jako jedyna droga reaktywacji (4), 3 Claude-parity blockers B1/B2/B3 zamknięte w §4 Stage 3 + Stage 9a + Stage 9 v1 addendum (5). ADR amendments minimum zaaplikowane (ADR-1 amended, ADR-2/ADR-3 deferred-to-v2, ADR-9 utworzony)."
cycle_id: "20260429-codex-port-rewrite"
codex_min_version: "0.126.0-alpha.15"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/manifest.md
  - .sage/work/20260429-codex-port-rewrite/review-2026-04-30/synthesis.md
  - .sage/work/20260429-claude-port-logic-map/map.md
  - .sage/docs/decision-codex-validate-mutation-predicate.md          # ADR-1
  - .sage/docs/decision-codex-approval-proof-schema.md                # ADR-2
  - .sage/docs/decision-codex-mcp-stack.md                            # ADR-3
  - .sage/docs/decision-codex-workflow-state-machine.md               # ADR-4
  - .sage/docs/decision-codex-instruction-surfaces.md                 # ADR-5
  - .sage/docs/decision-codex-public-workflows-internal-library.md    # ADR-6
  - .sage/docs/decision-codex-stop-hook-scope.md                      # ADR-7
  - .sage/docs/decision-codex-doctor-and-status.md                    # ADR-8 (sage doctor)
  - .sage/docs/decision-codex-cli-surface.md                          # ADR-9 (bin/sage)
  - .sage/docs/decision-codex-posttool-hallucination-check.md         # ADR-10
greenfield_anchor: "commit 970aa8d (chore: clear pre-rewrite Codex port — greenfield baseline)"
audience: implementing-agent
---

# Spec — Codex port rewrite v1

## 0. Document scope and how to use it

This is the **single specification document** for the Codex port v1.
It is written for an **implementing agent** that will build the port
across one to a few milestones. Sections are ordered as the
implementation will be performed, not as a reading narrative.

The spec is monolithic by user request — v1 will be built "at one
go". A separate `plan.md` (next artifact) breaks the spec into
milestones with exit criteria. This spec answers **what** is built;
plan answers **in what order and how it is verified**.

The spec presupposes:

- **All 10 ADRs are accepted in their current state** (decisions
  baked in). ADR status as of 2026-04-30:
  - **proposed (active in v1, no amendment needed):** ADR-4,
    ADR-5, ADR-6, ADR-8, ADR-9.
  - **proposed-amended (v1 narrowed scope, ADR file has v1
    amendment block):** ADR-1 (P3 tier-1 N/A, P4 N/A, bash impl).
  - **deferred-to-v2 (ADR file has DEFERRED block):** ADR-2
    (approval-proof, Cut A), ADR-3 (MCP stack, Cut B). v1
    implementation does NOT include any mechanism from these
    ADRs — see §16 sign-off Cut A/B.
  - **proposed but spec narrows scope (ADR file NOT amended; read
    spec.md for v1 truth):** ADR-7 (Stop hook scope — §6.5 is v1
    contract; ADR-7 prose still describes v2-target audit scope
    with C1/C2/C5 active, those are NOT in v1), ADR-10 (post-write
    hallucination check — §6.4 is v1 contract; Check A + Check C
    in bash, Check B deferred). These two ADRs will get full v1
    amendment blocks in a follow-up mini-cycle if needed; for v1
    implementation, follow spec.md.

  Where spec.md and ADR text disagree, **spec.md is source of
  truth for v1**. ADRs remain authoritative for v2 reactivation
  redesign once their respective promotion triggers (§13.2) fire.
- **Greenfield baseline** — `runtime/platforms/codex/` is empty
  (commit `970aa8d`). The implementer starts with no legacy code in
  that path. Cross-platform code under `runtime/cli/`,
  `runtime/mcp/`, `runtime/tools/` and sibling platforms
  (`claude-code`, `antigravity`, `generic`) is preserved.
- **Empirical anchor: Codex 0.126.0-alpha.15.** Every PoC referenced
  was run against this version. Versions ≥0.130 may diverge — risk
  register §13 lists what to retest.

Out-of-scope items are listed in §14. If the implementer encounters
something that seems to belong in v1 but is missing here, treat it as
a discovery and surface as `[R]` on the spec — do not silently
expand.

---

## 1. Glossary (D10 closure)

Three term-collisions caused confusion during 3-axis review (ref:
synthesis §DRIFT D10). They are normalized here for the entire
v1 scope; every other section uses these definitions.

### "Approval"

Two unrelated meanings exist; both are kept, **disambiguated by
prefix** in code, comments, and prose:

| Phrase | Meaning |
|---|---|
| **sandbox approval** | Codex's per-tool permission decision — `permissionDecision: "allow" / "deny"` returned by `PermissionRequest` hook. About sandboxing dangerous operations (filesystem writes outside cwd, network, etc.). v1 does NOT wire `PermissionRequest`; this term appears only in cross-references. |
| **workflow approval** | Sage's user-issued `[A]` token at gate checkpoints (brief, spec, plan, verification). v2 carries it via `.sage/.approval-pending` (per ADR-2) and the v2 validator (MCP `sage_validate_mutation`) checks for it. **v1 has no approval-detection layer** (§6.2 deferred); the v1 bash predicate in `pre-tool-validate.sh` only checks "active cycle + path in scope", not approval state. |

In code: variable names use `sandbox_decision` vs `workflow_approval`.
Never just `approval`.

### "Plugin" vs "skill" vs "app"

Codex documentation defines `plugin = a bundle of {skills, apps,
mcp_servers}` (ref: synthesis §A4 + DRIFT D14). Sage skills under
`.agents/skills/` are **skills**, not plugins. The Codex port v1
does not produce plugins. ADR-6 keeps the "internal library" framing.

In code and docs:

| Term | Meaning |
|---|---|
| **skill** | a single `.agents/skills/<name>/SKILL.md` (plus optional support files). Codex-loadable via `[[skills.config]]` block. |
| **app** | a Codex `app` definition (slash-command-like surface). Sage v1 does NOT ship apps. |
| **plugin** | a packaged bundle (skills + apps + mcp_servers) installable via Codex plugin manager. Sage v1 does NOT ship plugins. (v2 candidate; see §14.) |

### "Status"

| Phrase | Meaning |
|---|---|
| **`/status`** (Codex native) | Built-in Codex slash command — shows session info, MCP servers, sandbox profile. Out of Sage's control. |
| **`bin/sage status`** | Sage CLI subcommand — shows project's Sage state from disk (active cycle, pending gates, recent decisions). Defined by ADR-9. |

Cross-reference: when both are relevant, use the full phrase. Never
abbreviate to "status" alone.

---

## 2. Architecture overview

**v1 ships two runtime layers.** L2 (MCP server) and L5 (git-side
backstop) are both **defined but deferred to v2** — see "v1 layer
scope" below for binding triggers.

```
┌─────────────────────────────────────────────────────────────┐
│  L1 — Codex hooks (.codex/hooks.json + scripts on disk)     │
│  Lifecycle gates fired by Codex per session/turn/tool        │
│  Predicates inline in bash (no MCP call-out in v1)           │
└────────────────────────┬────────────────────────────────────┘
                         │ reads/writes
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  L3 — Disk (.sage/, AGENTS.md, .agents/skills/)             │
│  Source of truth for workflow state                          │
└─────────────────────────────────────────────────────────────┘

╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
DEFERRED to v2 (gated on outcome-harness evidence — see §13.2):
┌─────────────────────────────────────────────────────────────┐
│  L2 — Sage MCP server (Python, single process per session)  │
│  Returns when v1 predicate-narrowing or audit-coverage gap   │
│  pressure builds (§8 v2 triggers, §13.2 signals)             │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  L5 — git hooks backstop (.githooks/pre-commit + pre-push)  │
│  Catches mutations that bypassed L1 at git-commit time       │
└─────────────────────────────────────────────────────────────┘
```

### v1 layer scope (decision 2026-04-30)

**v1 ships L1+L2+L3 only.** L5 (client-side git hooks backstop) is
**not deployed by `bin/sage init --platform codex` in v1** — neither
generated nor wired via `core.hooksPath`. The pre-existing
`.githooks/pre-commit` script in this repo is preserved as an artifact
(other ports may use it), but the Codex v1 generator does not touch
it.

**L1 scope amendment — UPS hook deferred (decision 2026-04-30,
paired with §6.2 deferral).** v1 does NOT ship `UserPromptSubmit`
hook for approval detection. No `ups-approval.sh`. No `.sage/
.approval-pending` token. The approval gate (Codex agent must have
fresh user-issued token to flip `spec.md status: completed`) is
**deferred entirely from v1** because every candidate detection
mechanic either violated brief Hard Anti-Pattern ("no keyword
classification, in any language") or required user discipline we
couldn't justify mandating in v1. Phase enforcement is **soft policy
in v1** (AGENTS.md + skill prose). Outcome harness measures
phase-jump rate; v2 promotion triggers in §13.2 / §6.2.

**L2 scope = NONE — MCP server deferred entirely from v1 (decision
2026-04-30, third cut compounding earlier same-day cuts).** The
sequence of cuts that landed on this:
1. "MCP lite" — 5 tools → 2 (`sage_validate_mutation` +
   `sage_record_approval`); the other 3 went to bash with documented
   coverage gaps and v2 promotion triggers.
2. Approval-gate deferral (§6.2) — UPS hook + token + dependents
   scrapped; `sage_record_approval` had no caller left → also
   deferred. "MCP lite" became "MCP ultra-lite" (1 tool).
3. **MCP server itself deferred (this cut).** With only
   `sage_validate_mutation` left at narrowed predicate ("active
   cycle + path scope only" per §6.3), the predicate is ~30 lines
   of bash equivalent. Python advantage (typed state machine,
   atomic writes, complex predicates) does not apply at v1 scope.
   Path (b) chosen — drop MCP from v1 entirely; predicate inline in
   `pre-tool-validate.sh` bash.

**v1 ships zero MCP infrastructure.** No Python server, no
`pyproject.toml`, no `[[mcp_servers]]` block in generated
`.codex/config.toml`, no `runtime/platforms/codex/mcp/` directory
shipped, no `sage-mcp` install dependency. `pre-tool-validate.sh`
implements the cycle-scope predicate inline (~40 lines bash + jq +
yq). Hooks remaining (`session-init`, `pre-tool-validate`,
`post-tool-check`, `turn-audit`) are all bash, all stateless, all
read disk directly.

**v2 promotion trigger for MCP (binding):** outcome-harness data
shows that v1 needs richer predicate (phase check, approval token,
cross-cycle correlation) AND that bash equivalent has hit complexity
ceiling (predicate file > 200 LOC, or shellcheck warnings exceed
threshold, or measured race conditions on shared log writes). At
that point: ship MCP server alongside bash hooks; hook scripts gain
sentinel `SAGE_USE_MCP=1` env-var to switch evaluator. No big-bang
cutover.

**v2 promotion trigger for L5:** unchanged from prior cut —
outcome-harness shows L1 effectively bypassed (agents disabling
`.codex/hooks.json`, commits landing without incident-log entry,
`--no-verify` evasion observed).

**v2 trigger condition (binding):** L5 is added to v1.x or v2 only
when **outcome-harness data** shows that L1+L2 are being effectively
bypassed in real sessions — for example: agents disabling
`.codex/hooks.json`, MCP `required = true` becoming non-binding after
a Codex bump, or commits landing without any incident-log entry from
L1/L2. Until that data exists, L5 is overhead without measured value.

**Accepted risk for v1:** if a session bypasses L1+L2 (intentionally
or via bug), there is no client-side gate before `git commit`. The
mitigation is **detection, not prevention**: `sage doctor`
post-session and ADR-7 Stop hook log analysis surface bypass patterns,
which feed the v2 trigger above.

External to these three layers but consumed by them:

- **`bin/sage` CLI** — surface for the user (`init`, `update`,
  `doctor`, `status`). Lives outside the Codex session lifecycle;
  invoked by user from terminal.
- **Sage skills** under `.agents/skills/` — instruction surface
  layer. Loaded by Codex natively (no Sage runtime involvement at
  load time).
- **AGENTS.md** at repo root — primary instruction file for Codex,
  per `/codex/AGENTS.md` doc. Generated by Sage; loaded by Codex.

ADR-to-layer mapping:

| ADR | Layer | Component |
|---|---|---|
| ADR-1 | L1 (v1) → L1+L2 (v2) | `PreToolUse(apply_patch)` hook — **v1 predicate inline in bash**, narrowed to "active cycle + path scope only" per §6.3 (no phase, no approval). MCP `sage_validate_mutation` returns in v2 alongside richer predicate. |
| ADR-2 | **DEFERRED to v2** | `UserPromptSubmit` hook + `.sage/.approval-pending` token — entire approval-detection layer deferred per §6.2 decision (2026-04-30). v2 ADR replaces ADR-2 with deterministic-surface design (numeric / markup / slash-command channel only). |
| ADR-3 | **DEFERRED to v2** | MCP server stack (Python, transport, lifecycle). v1 ships zero MCP infrastructure per §2 / §8 decisions (2026-04-30). MCP returns when v2 trigger fires per §2 v2 promotion trigger. |
| ADR-4 | **DEFERRED to v2** | Full workflow state machine. v1 implements only the cycle-existence + path-scope predicate inline in bash (§6.3); state machine transitions (envision → deliver, etc.) are soft policy in AGENTS.md + skill prose (§9). Returns in v2 with ADR-2 replacement and ADR-3 reactivation. |
| ADR-5 | L1 + L3 | Hook contracts + AGENTS.md + developer_instructions |
| ADR-6 | L3 | Public workflows + internal library (skills layout) |
| ADR-7 | L1 (v1) → L1+L2 (v2) | `Stop` hook in bash for v1 — orphan-approval / approval-coupling checks **skipped in v1** (no token to evaluate per §6.2); session-mutations + new phase-jump probe remain. Promote to MCP `sage_audit_turn` in v2 (§8 promotion trigger). |
| ADR-8 | external | `sage doctor` (CLI subcommand, reads disk + probes session) |
| ADR-9 | external (v1) | `bin/sage` overall surface; `bin/sage status` reads disk directly in v1 (no MCP tool needed; `sage_status` was already on the deferred-to-bash list per "MCP lite" cut) |
| ADR-10 | L1 (v1) → L1+L2 (v2 if Check B added) | `PostToolUse(apply_patch)` hook in bash for v1 (Check A diff-claim + Check C frontmatter); promote to MCP `sage_check_post_mutation` only when Check B (symbol existence) is added (needs language parsers, must be Python). |

Dependencies (build order considerations):

- L1 depends on L3 (hooks read disk directly in v1).
- `bin/sage init` writes L1 + L3 setup; `bin/sage update` regenerates
  L1 surface (idempotent).
- L3 has no Sage runtime code (it is just files on disk in defined
  shapes).
- L2 (when reactivated in v2) sits between L1 and L3.

---

## 3. Starting point + delete plan (closure)

**Pre-existing in repo (preserved):**

- `runtime/cli/` — universal CLI dispatcher (`cli.mjs`).
- `runtime/mcp/` — shared MCP runtime (`mcp-client.ts`,
  `discover.sh`, `load_config.py`, `json_to_toml.py`,
  `sage-mcp-config.example.json`).
- `runtime/tools/` — shared tooling (`skill_manager.py`,
  `sage-check.sh`, `sage-scaffold.sh`, etc.).
- `runtime/platforms/{claude-code,antigravity,generic}/` — siblings.
- `bin/sage` — CLI entrypoint (codex platform option preserved;
  generator path will be updated by M1).
- `AGENTS.md` (root) — placeholder; M1 regenerates.
- `.agents/skills/` — installed skills (intact).
- `.githooks/pre-commit` — git layer L5 backstop (intact as artifact;
  **NOT wired by Codex v1 generator** per §2 "v1 layer scope"; other
  ports may continue to use it).
- `docs/ecosystem/codex-port-baseline.md` — historical record (read-
  only).

**Removed in commit `970aa8d`:**
- All of `runtime/platforms/codex/` (27 tracked files + ~50 generated
  fixtures cleaned from disk).

**To be created by this rewrite (the v1 surface):**
- `runtime/platforms/codex/` (rebuilt from scratch per §4-§7 below).
- ~~`runtime/platforms/codex/mcp/`~~ — **NOT created in v1** per §2 / §8
  decision (2026-04-30). v1 ships zero MCP infrastructure. When v2
  triggers fire, the v2 plan creates the MCP server (Codex-specific
  source location is the deferred design choice; preserved here for
  v2 reference: Codex-specific now, shared `runtime/mcp/server/` when
  a second port adopts MCP).
- Possible additions to `runtime/cli/src/cli.mjs` (codex platform
  setup flow, see §7).
- ~~Additions to `runtime/mcp/discover.sh` and `mcp-client.ts`~~ —
  **NOT needed in v1** (no MCP server to discover). Returns in v2.

**Future extraction (v2 candidate, not v1 work):** when a second port
needs an MCP server (e.g. Claude Code adds MCP), the codex-specific
implementation in `runtime/platforms/codex/mcp/` is extracted to a
shared `runtime/mcp/server/` directory. v1 explicitly does NOT
pre-build this shared abstraction — premature abstraction with no
second consumer is rejected per "no abstractions before second
consumer" rule.

The pre-rewrite codex code under `runtime/mcp/json_to_toml.py` is
read-only-preserved; the rewrite **may** call it but **must not**
modify its semantics (it serves the existing platforms too).

---

## 4. Codex generator pipeline (CRIT-1 closure)

This is the largest single deliverable. The generator is what
`bin/sage init --platform codex` invokes to produce the L1 + L3
surface in a target project.

The Claude port has a working generator (`runtime/platforms/claude-
code/setup/generate-claude-code.sh`) that is the parity reference.
Below is the 10-stage pipeline, each stage with: input, output,
mapping to Claude port equivalent, and Codex-specific deviations.

### Stage 1 — Discover target project shape

**Input:** `<target>` directory (passed as arg from `bin/sage init`).
**Output:** in-memory record `{is_git_repo, has_codex_config_dir,
has_existing_agents_md, has_sage_dir, project_root}`.
**Claude parity:** identical first stage.
**Codex deviations:** check for `<target>/.codex/` not `<target>/.claude/`.

Implementation:
- `[ -d "$target/.git" ]` → `is_git_repo`.
- `[ -d "$target/.codex" ]` → `has_codex_config_dir`.
- `[ -f "$target/AGENTS.md" ]` → `has_existing_agents_md`.
- `[ -d "$target/.sage" ]` → `has_sage_dir`.
- `project_root := $target` (assumed; fail if not absolute path).

Failure: target not a directory → exit 2 with clear message; do not
auto-create.

### Stage 2 — Read Sage core (workflows, skills, decisions)

**Input:** `<sage_repo>/core/` (the framework's own skills + workflow
definitions).
**Output:** in-memory list of `{skills_to_deploy, workflows_to_load}`.
**Claude parity:** identical — same `core/` source of truth.
**Codex deviations:** none at this stage. Source files are platform-
agnostic.

Implementation:
- Read `core/capabilities/orchestration/sage-navigator/SKILL.md` and
  every other `SKILL.md` under `core/capabilities/`.
- Read `core/workflows/*.workflow.md`.
- Read `core/presets/<preset>.yaml` (preset is `base`, `startup`,
  `enterprise`, `opensource` — chosen at `bin/sage init` time).
- Filter the skill list per preset's `skills_enabled` field.

### Stage 3 — Compose AGENTS.md

**Input:** Sage core + project shape + preset.
**Output:** `<target>/AGENTS.md` (**prefix-managed** — see "Managed-
content model" below).
**Claude parity:** Claude generates `<target>/CLAUDE.md`. Identical
composition logic; the only difference is destination filename and a
small set of platform-specific phrasings.
**Codex deviations:** Codex reads `AGENTS.md` natively (per
`/codex/AGENTS.md` doc). Optional override file is `AGENTS.override.md`
in same directory; v1 generator does NOT touch override.

**Managed-content model (decision 2026-04-30):** AGENTS.md uses a
**prefix-managed pattern with a single end marker**. Everything
**above** the marker is Sage-regenerated on every `bin/sage update`.
Everything **below** the marker is **user-owned territory** —
generator never touches it.

End marker (HTML comment so it renders as zero-width whitespace in
markdown viewers but is semantically detectable by tooling):

```markdown
<!-- SAGE-MANAGED-END — do not modify or move this line. Content above is regenerated. Content below is yours. -->
```

Generator behavior on update:
1. Read existing `AGENTS.md` if present.
2. Locate the marker line (exact substring match `<!-- SAGE-MANAGED-END`).
3. **If marker found:** preserve everything from the marker line onward verbatim (the user's territory). Replace everything above the marker with newly composed Sage content + the marker line.
4. **If marker not found** (file present but pre-marker world OR user accidentally deleted it):
   - First-time migration: emit warning "no SAGE-MANAGED-END marker found, regenerating full file with marker; if you had user content below the previous Sage block, it has been preserved as `AGENTS.md.user-backup-<ts>`".
   - Save user's pre-update content to `AGENTS.md.user-backup-<iso-ts>` before overwrite.
   - Generate fresh file with marker at end of Sage section + empty user territory below.
5. **If file absent:** generate fresh file with marker at end of Sage section.

This pattern is asymmetric on purpose: Sage owns the prefix (where the
constitution and rules live, which agents need consistent across
sessions), user owns the suffix (project-specific notes, custom
instructions). Paired START/END blocks (the alternative considered)
were rejected for AGENTS.md because they clutter a markdown file the
user reads daily; a single end marker is visually quieter.

Composition above the marker (in order, each section separated by `---`):

1. **Frontmatter** — `# Sage — Project Instructions` header + a
   one-line "auto-generated" comment + the pointer "Content below
   `<!-- SAGE-MANAGED-END -->` is yours, edit freely."
2. **Constitution merge + injection** — three-layer merge, parity
   with Claude port (ref: claude-port-logic-map §3.4 +
   `runtime/platforms/claude-code/setup/generate-claude-code.sh:419-
   473`):
   1. **Base layer** — `$SAGE_FRAMEWORK/core/constitution.md` (the
      common rules-of-engagement that define `[A]/[R]/[N]`, gate
      semantics, etc.).
   2. **Preset overlay** — read
      `$SAGE_FRAMEWORK/core/constitution/presets/${PRESET}.constitution.md`
      where `${PRESET}` defaults to the preset passed by Stage 2
      (`base`, `startup`, `enterprise`, `opensource`). Preset overlay
      wins on conflicting rules.

      **Sentinel-bypass behavior (T1.9 LOCKED 2026-04-30, claude/
      antigravity convention; ref:
      `runtime/platforms/claude-code/setup/generate-claude-code.sh:421-422`):**
      - `PRESET ∈ {base, none, "", unset}` → **skip preset overlay
        merge entirely**: no file lookup, no warning. Base layer
        alone is the constitution. (No `base.constitution.md` file
        exists or is authored — `base` is the sentinel that means
        "the base layer is sufficient".)
      - `PRESET=<other>` AND
        `core/constitution/presets/<other>.constitution.md` missing
        → emit warning to stderr (`Preset overlay missing: <other> —
        falling back to base layer`), fall back to base alone.
      - `PRESET=<other>` AND file present → load + merge as overlay.
   3. **User overlay** — read `<target>/.sage/constitution.md` if
      present; extract `extends:` field (override `${PRESET}` if
      different) and append/override remaining content. User overlay
      wins over preset overlay. If `<target>/.sage/constitution.md`
      is absent, Stage 9 will create a stub with `extends: <preset>`
      header.
   4. **Inject** — replace `__CONSTITUTION_PLACEHOLDER__` token in
      the source template with the merged result.

   **Why this matters:** without preset merge, the four presets
   (`base`/`startup`/`enterprise`/`opensource`) lose their
   differentiated constitutions — every Codex project would get the
   same baseline regardless of preset choice (closes GAP-2 + GAP-4
   from the 2026-04-30 confrontation review).
3. **Engineering principles** — fixed text from preset.
4. **Available skills section** — list with name + one-line summary
   per skill.
5. **Communication style include** — embed (or reference) the
   project's `.sage/docs/comm-style.md` if it exists.
6. **Project state pointer** — paragraph telling the agent that
   `.sage/decisions.md` and `.sage/work/` are the working state.
7. **`<!-- SAGE-MANAGED-END -->` line.**

Below the marker: **user territory** (initially empty for
first-time generation; preserved verbatim on update).

The composition output replicates Claude's logic step-for-step **for
the Sage-managed prefix**.
**Why we duplicate rather than share:** because the Claude generator
is `bash`, the Codex generator is also `bash` (per ADR-5 stack
choice — see §5), and ADR-5 explicitly trades a small duplication
cost for surface independence (so a Claude-side change does not
silently break Codex). Note: Claude port may or may not adopt the
same prefix-marker pattern; cross-port marker syntax alignment is
NOT a v1 deliverable.

**v1 Constitution variant rendering — Rule 1A MCP-fallback (decision 2026-04-30, closes GAP-3 / B1 from confrontation review):**

Constitution Rule 1A ("Memory Before Work") originally instructs
agents to call `sage_memory_search` MCP tool twice before any
Standard+ task. **In v1, the Sage Memory MCP server is deferred
entirely (§8 Cut B)** — a Codex agent following the literal
constitution would either call a non-existent tool (hard error) or
skip the rule (silent constitution violation). The generator MUST
detect MCP availability and render a v1-variant Rule 1A.

Generator detection rule (executed during Stage 3, before injection):

```bash
# Pseudocode — actual implementation in core/setup/install.sh
if grep -q "^\[\[mcp_servers\]\]" "<target>/.codex/config.toml" 2>/dev/null; then
  RULE_1A_VARIANT="mcp"   # Standard rule with sage_memory_search
else
  RULE_1A_VARIANT="filesystem"   # v1 fallback rendering
fi
```

When `RULE_1A_VARIANT=filesystem`, the merged constitution text for
Rule 1A is replaced with this v1-specific rendering before injection:

> **Rule 1A — Memory Before Work (MANDATORY for Standard+) — v1
> filesystem variant.** Before writing specs, plans, ADRs, or
> starting an investigation, check `<target>/.sage-memory/` for
> past learnings on the current task domain. Skim filenames and
> read any file whose name matches the task keywords (or
> `self-learning.md` if it exists). Use findings to inform your
> approach. **Note:** v1 ships without the Sage Memory MCP server;
> filesystem fallback is the only v1 path. v2 will reintroduce
> `sage_memory_search` per §8 promotion trigger — at which point
> this rule reverts to the MCP-tool form. Skip only for Tier 1 tasks.

**Why fallback over strip:** stripping Rule 1A entirely would lose
the "memory-before-work" discipline; the filesystem fallback is
explicitly mentioned in the existing constitution as a degraded
mode and matches what the upstream Claude port already does when
its MCP server is unreachable. Sets v1 agent expectation correctly
without inventing a new constitutional rule.

**Generator implementation note:** the variant rendering is a
single-pass substitution on the merged constitution text BEFORE
the placeholder injection in step 2. If the constitution source
file does not contain a parseable Rule 1A block (e.g. user heavily
customized it via `<target>/.sage/constitution.md`), generator
emits a warning and proceeds with no substitution — user is on
the hook for keeping their custom Rule 1A internally consistent
with their MCP configuration.

### Stage 4 — Compose `.codex/config.toml`

**Input:** project shape + preset. (v1 has no MCP server install
path to inject — §8 deferred. Placeholder comment only.)
**Output:** `<target>/.codex/config.toml` (**block-managed** — Sage
regenerates only the content between paired markers; user's
configuration outside the markers is preserved verbatim).
**Claude parity:** Claude writes `<target>/.claude/settings.json`
(JSON, not TOML). Same semantic content, different format.
**Codex deviations:** TOML format, Codex-specific keys per
`/codex/config-reference`.

**Managed-content model (decision 2026-04-30):** `.codex/config.toml`
uses **paired-marker block management**. Sage owns the content
between `# >>> SAGE MANAGED BLOCK START` and `# <<< SAGE MANAGED
BLOCK END`. Everything **outside** these markers is user-owned —
generator preserves it on every `bin/sage update`. The user can:
- Add their own `[blocks]` above or below the managed block (e.g.
  custom `[review]`, `[ui]`, project-specific TOML keys).
- Add comments outside the managed block — preserved.
- NEVER edit content inside the managed block — `sage update` will
  overwrite it; if user edits inside, a warning is emitted on next
  update and the user-edit version is saved to
  `.codex/config.toml.user-edit-backup-<iso-ts>` before overwrite.

Generator behavior on update:
1. Read existing `.codex/config.toml` if present.
2. Locate marker pair (`# >>> SAGE MANAGED BLOCK START` …
   `# <<< SAGE MANAGED BLOCK END`).
3. **If pair found:** replace content between markers with freshly
   composed Sage block; everything outside markers preserved verbatim.
4. **If only one marker found** (file corrupted): treat as "no marker
   pair", trigger backup-and-regenerate path (5).
5. **If markers absent** (file present, pre-marker world OR user
   removed them): backup user file to
   `.codex/config.toml.user-edit-backup-<iso-ts>`, regenerate full
   file with marker pair, emit warning. User reconciles manually.
6. **If file absent:** generate fresh file with marker pair + empty
   user territory before/after.

Why paired markers (not prefix-only like AGENTS.md): TOML has no
notion of "user appends free text below" — every line must be valid
TOML. User additions can come above or below or interleaved with
sections; only paired markers fence Sage's territory cleanly.

Mandatory blocks (in order, **inside the managed block**):

```toml
# >>> SAGE MANAGED BLOCK START
# Auto-generated by Sage. Regenerate with `sage update`.
# Sage only refreshes this managed block.

[features]
codex_hooks = true            # required for L1 — confirms hooks loaded

# Optional review / model tuning (commented out by default; user-owned)
# review_model = "..."
# model_reasoning_effort = "medium"
# project_doc_max_bytes = 65536    # public name; Rust-source AGENTS_MD_MAX_BYTES same field (D6 closure)

# v1 ships NO [[mcp_servers]] block — MCP server deferred entirely
# (decision 2026-04-30, §2 / §8). Predicates run inline in bash hooks.
# When v2 triggers fire (§2 v2 promotion trigger), the regenerator
# adds a [[mcp_servers]] block here.

# <<< SAGE MANAGED BLOCK END
```

The block delimiters are crucial — they let `sage update` regenerate
this block without touching user-owned config below.

`developer_instructions` block (per ADR-5 §"Discovery + composition
order"):

```toml
[history]
developer_instructions = """
# Sage rules (loaded as developer instructions on every turn)
... (see §5 of this spec for full content)
"""
```

`developer_instructions` is a **single string field** (per Codex docs
verification, A2 sub-agent finding 2026-04-30). v1 puts the
constitution-equivalent rules here as the second instruction surface
(see §5).

### Stage 5 — Compose `.codex/hooks.json`

**Input:** Sage hook templates from `runtime/platforms/codex/hooks/
*.template.json` (created by this rewrite).
**Output:** `<target>/.codex/hooks.json` (**fully Sage-owned, full
regenerate** — JSON has no comment syntax for in-file markers; the
file is treated as a Sage artifact).
**Claude parity:** Claude writes `<target>/.claude/settings.json` (no
separate hooks file). Codex separates them.
**Codex deviations:** 2-level schema (`hooks.<EventName>[].matcher` +
`hooks.<EventName>[].hooks[]`).

**Managed-content model (decision 2026-04-30):** **full regenerate**.
This file is registry-only (no business logic, just hook→script
mappings). User customization is unsupported in v1; if a user wants
to add their own hook, they fork the project's Sage installation or
file an issue for v2 (Sage may add a "user_hooks" extension point).
On update, file is overwritten unconditionally; if a backup is needed
(user manually edited), it is saved to
`.codex/hooks.json.user-edit-backup-<iso-ts>` before overwrite — same
backup convention as Stage 3/4.

Concrete file written:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".codex/hooks/session-init.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": ".codex/hooks/pre-tool-validate.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": ".codex/hooks/post-tool-check.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".codex/hooks/turn-audit.sh" }
        ]
      }
    ]
  }
}
```

Key design points:

- **Matchers are explicit per ADR-1 amendment** — `PreToolUse` and
  `PostToolUse` use `matcher: "apply_patch"` (regex on tool name).
  v1 only intercepts `apply_patch`; Bash mutations are **uncovered in
  v1** (L5 backstop deferred per §2 — see §6 PreToolUse "v1 matcher
  list" for accepted-risk details).
- **Multi-hook ordering is order-independent** (PoC A1 U3 closure) —
  if a project later adds its own hook for `PreToolUse`, both fire,
  ordering is non-deterministic. Sage hook scripts make no
  assumption about firing order.
- **No `PermissionRequest` hook in v1** (per ADR-5).

### Stage 6 — Deploy hook scripts

**Input:** `runtime/platforms/codex/hooks/*.sh` (templates from
this rewrite).
**Output:** `<target>/.codex/hooks/*.sh` (executable, mode 0755) —
**fully Sage-owned, full regenerate** (Sage runtime code; user-
modification is not supported).
**Claude parity:** Claude deploys to `<target>/.claude/hooks/`.
**Codex deviations:** path is `.codex/hooks/`, semantics differ per
event (see §5).

**Managed-content model (decision 2026-04-30):** **full regenerate**.
These are Sage runtime scripts; modifying them in `<target>/.codex/
hooks/` is equivalent to forking Sage. On update, files are
overwritten unconditionally with no backup (user-edit detection via
content hash is out of scope for v1; if user customization is
detected as a real need in outcome harness, v2 may add a "skip if
hash differs from last-deployed" guard).

Files deployed (paths relative to `<target>/`):

- `.codex/hooks/session-init.sh`
- `.codex/hooks/ups-approval.sh`
- `.codex/hooks/pre-tool-validate.sh`
- `.codex/hooks/post-tool-check.sh`
- `.codex/hooks/turn-audit.sh`

All scripts are bash (per ADR-5 stack choice). Each has its full
contract documented in §5.

### Stage 7 — Deploy skills to `.agents/skills/`

**Input:** preset + filtered skill list from Stage 2.
**Output:** `<target>/.agents/skills/<skill_name>/SKILL.md` (plus
support files).
**Claude parity:** Claude deploys to `<target>/.claude/skills/`.
**Codex deviations:** path is `.agents/skills/` per Codex
`[[skills.config]]` schema.

Use existing `runtime/tools/skill_manager.py` (preserved). Pass
`--target-dir .agents/skills` for Codex. Do not duplicate the deploy
logic — `skill_manager.py` already supports `.agents/` target per
preserved code.

### Stage 8 — Wire `.githooks/pre-commit` (L5 backstop) — DEFERRED to v2

**v1 status:** **SKIPPED**. Per §2 "v1 layer scope" decision
(2026-04-30), L5 is not deployed by Codex v1 generator. This stage is
documented for v2 reference and parity with Claude port, but the
Codex v1 init flow has only 9 active stages (1-7, 9-10).

**v2 trigger:** outcome harness data showing L1+L2 bypass patterns.

**v2 contract (when activated):**
- **Input:** Sage's L5 pre-commit script template.
- **Output:** `<target>/.githooks/pre-commit` (executable) + git
  config update `core.hooksPath = .githooks`.
- **Reuse:** existing logic from `runtime/platforms/claude-code/
  setup/` (or factor out to `runtime/platforms/generic/setup/install-
  githooks.sh`).
- **Writer contract (per ADR-7 amendment):** pre-commit appends a JSON
  line per commit to `<target>/.sage/.precommit.log`:
  `{"commit_hash_pending": "<sha>", "ts": "<iso>", "files": [...], "session_id": null}`
- **ADR-7 C5 consumer:** the `.precommit.log` writer is referenced by
  ADR-7 audit logic. In v1, ADR-7 C5 degrades to "no precommit log
  available" — audit operates on session-mutations.log + decisions.md
  diff alone.

**v1 implication for ADR-7:** the audit pathway that compares
`.precommit.log` to `.sage/.session-mutations.log` is **partially
muted** in v1 — Stop hook can still verify "agent claimed approval ↔
decisions.md entry" coupling, but cannot cross-check "commit hash ↔
session mutations" without the precommit writer. This is an
accepted v1 limitation (see Risk register R-6 update).

### Stage 9 — Bootstrap `.sage/` skeleton (if missing)

**Input:** project shape (does `.sage/` exist?).
**Output:** if not exists, create:
- `<target>/.sage/decisions.md` (empty file with `# Decisions` header)
- `<target>/.sage/docs/.gitkeep`
- `<target>/.sage/work/.gitkeep`
- `<target>/.sage/gates/.gitkeep`

If `.sage/` exists, leave it alone (project-owned state).

**Claude parity:** identical — Sage state layout is platform-
agnostic.

**v1 addendum (decision 2026-04-30, closes B3 from confrontation review):**
during first-time bootstrap (no `<target>/.sage/constitution.md`
present), Stage 9 also creates a stub:

```markdown
---
extends: <preset>
---

# Project constitution overlay

Add project-specific overrides here. Rules in this file override
the preset rules (§4 Stage 3 merge order: base → preset → this file).
Leave empty to inherit preset defaults verbatim.
```

`<preset>` is the value passed by Stage 2. The stub gives users a
discoverable surface for constitution customization without forcing
them to know about preset internals. If the file already exists,
Stage 9 leaves it alone.

### Stage 9a — Deploy gates scripts (decision 2026-04-30, closes B2 from confrontation review)

**Input:** `$SAGE_FRAMEWORK/core/gates/scripts/*.sh` (preset-filtered
by Stage 2).
**Output:** copies to `<target>/.sage/gates/scripts/`, mode `0755`.

**What this is:** gate scripts are how the Sage framework backstops
engineering principles (test-before-code, no-silent-failures,
secrets-never-in-code, etc.) at runtime. Skills and L5 hooks invoke
them; without them, any skill that depends on a gate silently
degrades to "no-op gate".

**Claude parity:** identical — Claude `bin/sage init` performs
the same copy step from `runtime/platforms/claude-code/setup/`.
Gate scripts are platform-agnostic (pure bash, no Codex- or
Claude-specific syscalls).

**Codex deviations:** none.

**Empty-preset behavior:** if
`$SAGE_FRAMEWORK/core/gates/scripts/` is empty (preset has no
gates wired), skip with info message `[sage] no gate scripts
configured for preset <name>` — not an error.

**Update flow:** on `bin/sage update`, gates scripts are
**re-copied** (overwrite). Sage owns this directory entirely;
user-edited gate scripts are an anti-pattern (custom gates
belong in skills, not scripts/). Pre-update: backup any modified
script as `<name>.user-edit-backup-<iso-ts>` and warn.

### Stage 10 — Verify wiring + emit summary

**Input:** the just-created files from Stages 3-9a.
**Output:** stdout summary of what was created/updated; exit 0 if
all OK, exit non-zero on any sanity failure.

Sanity checks:
- `<target>/AGENTS.md` exists, non-empty, contains a non-empty
  constitution block (substring presence check, not full parse).
- **(v1 only)** if `<target>/.codex/config.toml` contains no
  `[[mcp_servers]]` block, AGENTS.md Rule 1A renders the v1
  filesystem-fallback variant (substring `"v1 filesystem variant"`
  present) — closes B1 sanity guarantee.
- `<target>/.codex/config.toml` parses as TOML.
- `<target>/.codex/hooks.json` parses as JSON.
- All **4 hook scripts in v1** in `<target>/.codex/hooks/` are
  executable: `session-init.sh`, `pre-tool-validate.sh`,
  `post-tool-check.sh`, `turn-audit.sh`. (v2 adds 5th
  `ups-approval.sh` when §6.2 reactivates.)
- **(closes B2)** All `*.sh` files in
  `<target>/.sage/gates/scripts/` are executable (mode 0755) and
  match the count in `$SAGE_FRAMEWORK/core/gates/scripts/` for the
  active preset. Empty preset: skip check, info message only.
- **(closes B3)** `<target>/.sage/constitution.md` exists with a
  parseable `extends:` field in frontmatter (created by Stage 9 if
  missing).
- (v1 only) **No L5 sanity check** — Stage 8 deferred per §2. v2
  reactivation: `<target>/.githooks/pre-commit` executable + `git
  config core.hooksPath` = `.githooks`.

On failure, emit a clear "what failed, what to do" message and
exit 2. Do not auto-fix — this is an init/update flow, the user is
present.

### Per-file managed-content strategy (decision 2026-04-30)

Single-source summary of how each file generated by `bin/sage init` /
`bin/sage update` treats user content. Authority for individual
stages is in their respective stage subsections above.

| File | Strategy | User territory | On user-edit conflict |
|---|---|---|---|
| `AGENTS.md` | **Prefix-managed** (single end marker `<!-- SAGE-MANAGED-END -->`) | Everything below the marker | If marker missing → backup `AGENTS.md.user-backup-<ts>`, regenerate full file with marker |
| `.codex/config.toml` | **Block-managed** (paired markers `# >>> SAGE MANAGED BLOCK START` / `# <<< SAGE MANAGED BLOCK END`) | Everything outside markers; user can add own `[blocks]` above/below | If markers absent or content modified inside → backup `.codex/config.toml.user-edit-backup-<ts>`, regenerate, warn |
| `.codex/hooks.json` | **Full regenerate** (Sage-owned, JSON has no comment markers) | None — file is registry-only | Backup `.codex/hooks.json.user-edit-backup-<ts>`, overwrite |
| `.codex/hooks/*.sh` | **Full regenerate** (Sage-owned scripts) | None — runtime code | Overwrite without backup (out of scope v1) |
| `.agents/skills/<skill>/` | **Managed by `skill_manager.py`** (existing tool, not Stage-4 territory) | Per `skill_manager.py` rules (preserved code) | Per existing tool behavior |
| `AGENTS.override.md` | **Never touched by generator** | Entire file | N/A — user-only file |
| `.sage/decisions.md` | **Bootstrap-only** (Stage 9 creates if missing) | Entire file after creation | N/A — generator does not update on subsequent runs |
| `.sage/work/`, `.sage/docs/`, `.sage/gates/` | **Bootstrap-only** (Stage 9 creates `.gitkeep` if missing) | Entire content | N/A — project state |
| `.sage/constitution.md` | **Bootstrap-only stub** (Stage 9 creates with `extends: <preset>` header if missing; closes B3) | Entire file after creation | N/A — user-overlay file; generator never touches once created |
| `.sage/gates/scripts/*.sh` | **Sage-owned, full re-copy on update** (Stage 9a; closes B2) | None — runtime gate logic | Backup modified files as `<name>.user-edit-backup-<iso-ts>` then overwrite |

**Backup convention:** all `*-backup-<iso-ts>` files use ISO-8601
basic format `YYYYMMDDTHHMMSS` for the timestamp segment (e.g.
`AGENTS.md.user-backup-20260430T143022`). Backups are written to the
same directory as the original file. They are NOT git-ignored by
default — user is expected to inspect, reconcile, then delete (v2
candidate: auto-cleanup of backups older than N days).

**Idempotency invariant:** running `bin/sage update` twice with no
intervening user edit produces no diff in any managed surface (Stage
3 above marker, Stage 4 inside markers, Stage 5/6 entirely). This is
testable in §15.2 pre-cutover checklist.

### Generator stack choice (D7 closure)

The generator is **bash + small Python helpers** (mirrors Claude
port). Rationale:

- Bash is sufficient for file generation, templating (heredoc), and
  simple JSON/TOML writing.
- v1 has no Python runtime requirement at all (§8 deferred — no MCP
  server). Generator and hooks are bash-only. v2 reintroduces Python
  for the MCP server when promotion triggers fire.
- This avoids a "Python everywhere" vs "bash everywhere" inconsistency
  with Claude port that would slow down cross-port maintenance.

---

## 5. Instruction layers (defense-in-depth)

This section formalizes the three-tier defense described in
synthesis §A2. Each tier has its own **placement on disk**, **load
mechanism in Codex**, and **content responsibility**. They are
explicitly different surfaces; v1 uses all three concurrently.

### Tier A — `AGENTS.md` (project-level, primary)

**Placement:** `<project>/AGENTS.md` (root).
**Load mechanism:** Codex reads natively per `/codex/AGENTS.md` doc.
Loaded once at session start; stays in context for the whole session.
Subject to `project_doc_max_bytes` cap (default 32768 bytes; public
docs name; Rust-source name `AGENTS_MD_MAX_BYTES` is the same field
per A2 verification).
**Content responsibility:** primary instructions visible to the agent
across **all** turns. The constitution (rules of engagement) is
embedded here. Engineering principles, project goals, communication
style, available skills directory.
**Generator stage:** §4 Stage 3.

### Tier B — `developer_instructions` (config-level, additional)

**Placement:** `.codex/config.toml`, key
`[history].developer_instructions = """..."""`.
**Load mechanism:** loaded by Codex when the project is **trusted**
(per Codex trust-flow). Verified to exist as a separate field from
`model_instructions_file` (A2 sub-agent finding 2026-04-30 — both
are documented, distinct fields). Sage v1 uses ONLY
`developer_instructions`, not `model_instructions_file` (see
"Why not model_instructions_file" below).
**Content responsibility:** **redundant restatement** of
non-negotiable rules in compact form, expressed as **sane defaults**
that AGENTS.md may override. Specifically:
1. The 5 Sage gate rules (Rule 0 routing, Rule 1A memory recall,
   Rule 4 checkpoints, Rule 5 verify-before-done, Rule 7 record-
   decisions).
2. The `[A]/[R]/[N]` vocabulary (English-only, whole-word; references
   ADR-2 W2).
3. A "if `AGENTS.md` disagrees with these defaults, AGENTS.md wins;
   hard policies are enforced by hooks, not by this text" clause
   (precedence note — see "Tier coordination" below).
**Why redundant:** if a clever attacker / lossy compaction / context
window pressure removes `AGENTS.md` from active context,
`developer_instructions` is loaded fresh from config every time
trust is verified. Defense-in-depth = same rule in two places.
**Hard vs soft separation:** content of B is **soft policy** (defaults,
style, vocabulary) — overridable by A. **Hard policy** (mutation
blocking, gate enforcement, security blocks) lives in hooks (ADR-1,
ADR-7, ADR-10) and is independent of A/B/C text precedence.

### Tier C — Per-workflow preamble (skill-level, contextual)

**Placement:** the first paragraph of each
`core/workflows/*.workflow.md` (or its compiled form in
`.agents/skills/<name>/SKILL.md`).
**Load mechanism:** loaded by Codex when a skill is invoked
(`/sage:build`, `/sage:fix`, etc.). Stays in context for the duration
of the workflow.
**Content responsibility:** **workflow-specific** non-negotiables:
- Build workflow preamble: "spec.md AND plan.md must exist with
  status:completed before implementing".
- Fix workflow preamble: "investigate root cause before scoping the
  fix".
- Architect workflow preamble: "elicit (3 rounds) before designing".
- These lines are the workflow-specific gates; they would not fit in
  `AGENTS.md` (too narrow) or `developer_instructions` (too verbose).

### Why not `model_instructions_file`?

`model_instructions_file` (per A2 verification 2026-04-30) is a
**replacement** mechanism — it overrides Codex's built-in model
instructions. Sage v1 does NOT use it because:

1. Replacement risk: if Sage's file goes out of date relative to
   Codex's built-in baseline, every base behavior agent depends on
   may regress silently.
2. Defense-in-depth: replacement is a single point of failure;
   `developer_instructions` (additional) is layered on top of
   built-ins, no regression risk.
3. Cross-port consistency: Claude port uses additional-instruction
   mechanism (CLAUDE.md is appended, not replacing). Codex port
   uses the same shape.

`model_instructions_file` is a v2 candidate **only if** outcome
harness shows that built-in Codex behavior conflicts with Sage gates
in a measurable way.

### Tier coordination — when they disagree

Explicit precedence (locked by this spec, restated in Tier B):

```
Tier A (AGENTS.md) > Tier B (developer_instructions) > Tier C (workflow preamble)
```

**Rationale — closest-to-user wins:**
- A is **user-authored, project-specific**, edited directly by the
  developer. Highest authority because it represents explicit user
  intent for this project.
- B is **Sage-generated from a preset** (base/startup/enterprise/
  opensource). Represents "sane defaults" — overridable when the user
  has a project-specific reason.
- C is **dynamically injected** at workflow invocation; narrow scope
  (one workflow); easiest to suppress in long sessions. Lowest by
  construction.

This mirrors standard config precedence (git: project > user > system;
shell: local > user > system) — the surface closest to the user wins
on conflict.

**Conflict resolution example 1 (soft policy):** AGENTS.md says
"communicate in Polish" + preset enterprise developer_instructions
says "respond in English" → **A wins, agent communicates in Polish**.
The preset's English default is overridden by user's project-specific
Polish requirement.

**Conflict resolution example 2 (soft policy, hierarchy lower):**
AGENTS.md says nothing about language + developer_instructions says
"respond in English" + workflow preamble for `/sage:build` says
"checkpoints in Polish" → **B wins over C**, agent uses English for
checkpoints. Preamble loses to config-level default.

### Hard policy — independent of text precedence

The A>B>C precedence above governs **textual conflicts** — style,
vocabulary, communication, soft defaults. The LLM resolves these by
reading the prompt; precedence is **expressed in text** ("AGENTS.md
takes precedence on conflict") and **respected best-effort** by the
model. It is not a CLI-level enforcement mechanism.

**Hard policy** — mutation blocking, gate enforcement, security
blocks, frontmatter validation — is enforced by **hooks** (ADR-1
PreToolUse, ADR-7 Stop, ADR-10 PostToolUse) via **deny-fail-closed
exit codes** (`exit 2` blocks, `exit 0` allows). v1 has no MCP
server (§8 deferred); the predicate is inline in `pre-tool-validate.sh`.
v2 reintroduces an MCP server and its `required = true` deny-fail-
closed contract (ADR-3 D6) when promotion triggers fire — the hard-
policy contract becomes "hook exit code OR MCP tool denial". These
mechanisms operate independently of A/B/C text precedence: even if
the user's AGENTS.md says "allow `--no-verify`", a hook checking for
`--no-verify` in the apply_patch payload will still block the action.

This separation is intentional:
- **Soft policy** (style, language, vocabulary) → A>B>C, user-
  overridable, soft enforcement via prompt text.
- **Hard policy** (correctness, security, gate compliance) → hooks
  (v1) / hooks + MCP (v2), NOT user-overridable from AGENTS.md, hard
  enforcement via exit codes (and v2 MCP tool denial).

If the user truly needs to override a hard policy (e.g. emergency
hotfix bypassing review), that is a config-level operation (disabling
a hook in `.codex/hooks.json`, documented and audited) — not a text
override in AGENTS.md.

---

## 6. Hooks runtime (L1 detail per script)

This section is the **per-script implementation contract** for the
5 hook scripts deployed by §4 Stage 6. Each script's:

- Trigger event + payload shape (per Codex `/codex/hooks` doc + PoC
  C1 / A1 anchors)
- Action sequence
- Exit codes and their semantics (per ADR-7 amended D4-bis)
- File writers (tracked in ADR-7 C7 audit list)

### 6.0 — Hook script language: bash (decision 2026-04-30, locked)

**All 5 hook scripts are bash** (`#!/usr/bin/env bash`), with `jq` for
JSON parsing of Codex hook payloads. Locked decision; alternatives
considered and rejected.

**Primary rationale — cold-start latency:**
- Codex fires hooks **multiple times per turn**: SessionStart (1x),
  UserPromptSubmit (1x), PreToolUse + PostToolUse (1-N pairs per
  apply_patch), Stop (1x). A typical turn with 3 mutations triggers
  ~9 hook invocations.
- Bash startup: ~5-15ms per invocation (negligible).
- Python startup: ~100-200ms per invocation, even for trivial scripts
  (interpreter warmup + import overhead). 9 × 150ms = ~1.35s of
  added latency per turn.
- This latency is **user-perceivable** and compounds across longer
  sessions. The cold-start delta is the deciding factor.

**Secondary rationale:**
- **Zero-dependency surface:** bash + jq are present on macOS and
  Linux out-of-the-box (jq via Homebrew default / standard apt
  package). No Python install required just for hooks.
- **Cross-port consistency:** Claude port hooks are bash. Identical
  language across ports lowers cross-port debugging cost.
- **v1 has no MCP server** (§8 deferred). All v1 logic — including
  the validator predicate — lives in bash (~40 lines for
  pre-tool-validate; see §6.3). Bash is sufficient at the v1
  predicate scope (cycle exists + path-in-scope).

**Alternatives rejected:**
- **Python hooks (full Python):** rejected on cold-start grounds
  above. Considered briefly because Python would let hooks share
  modules with a future MCP server (DRY); decided against since v1
  has no MCP server, and v2 plans to keep hooks thin even when MCP
  returns (hooks dispatch via `sage-mcp` shim, not import shared
  modules).
- **Hybrid (bash shim → Python module):** rejected — same cold-start
  cost as full Python (interpreter still launches per hook), without
  the cross-port consistency benefit. The bash shim adds an extra
  process layer to debug.

**Implication for hook complexity:** hooks MUST stay thin. v1 ceiling
is ~40 lines per hook (pre-tool-validate is the heaviest). When a
predicate grows beyond ~80 lines of bash, or requires non-trivial JSON
manipulation, or needs language parsers (e.g. ADR-10 Check B), the
v2 trigger fires per §8: ship MCP server, move logic to MCP tool,
hook becomes thin dispatcher.

**Toolchain conventions:**
- `set -euo pipefail` at top of every hook (fail-fast on errors).
- `jq` for all JSON parsing. No `grep` / `sed` on JSON.
- `command -v jq >/dev/null || { echo "jq required" >&2; exit 0; }` —
  if `jq` missing, hook degrades to no-op (exit 0) rather than
  blocking work; `sage doctor` surfaces the missing-dependency
  warning.
- Shellcheck-clean (CI gate: `shellcheck runtime/platforms/codex/
  hooks/*.sh` must pass).
- Tests via `bats-core` (`runtime/platforms/codex/hooks/tests/
  *.bats`).

### 6.1 — `session-init.sh` (event: `SessionStart`)

**Trigger:** Codex session opens (project loaded). v1 has no MCP
servers to start (§8 deferred); SessionStart fires immediately after
project load.

**Payload (stdin JSON):**
```json
{
  "session_id": "<uuid>",
  "project_dir": "<absolute path>",
  "ts": "<iso>"
}
```
(Schema confirmed by recon-claude-bootstrap report — the SessionStart
event semantics are documented; this script mirrors Claude port's
`sage-session-init.sh`, claude-port-logic-map §3.6.)

**Action sequence:**
1. Print Sage banner to stdout — Codex injects this as a
   system-reminder-equivalent context block.
2. Check Codex trust state: if untrusted, emit *"project not trusted
   — run `sage doctor` for the trust line"* to stderr and exit 0.
3. Read `<project>/.sage/work/*/manifest.md` frontmatter; for any
   cycle with `status: in-progress` or `status: paused`, emit a one-
   line summary (cycle title, workflow, phase, next-step).
4. Read latest 3 entries from `<project>/.sage/decisions.md` (`### `
   headers); emit compact list.
5. Exit 0.

**Exit codes:**
- 0 always (session start should never block).

**File writers:** none. This script is read-only against `.sage/`.

**Failure mode:** script crashes → Codex logs to its hook log;
session proceeds without context injection. Acceptable degradation.

### 6.2 — `ups-approval.sh` (event: `UserPromptSubmit`) — DEFERRED to v2

**Status (decision 2026-04-30):** the UserPromptSubmit hook for
approval detection is **deferred from v1 entirely**. No
`ups-approval.sh` script ships in v1. No `.sage/.approval-pending`
token exists. No UPS-event registration in `.codex/hooks.json`.

**Why deferred — short version:**

After working through four candidate mechanics (literal English
vocabulary; LLM classification; deferred-to-validator semantic
check; agent confirmation echo) plus two industry-pattern
alternatives (explicit slash command; numeric-channel match), every
design either **violated the brief's "no keyword classification"
anti-pattern** (any free-text intent detection across Polish surface
forms) or **required user discipline we couldn't justify mandating
in v1** (slash command memorization; agent footer emission
discipline that M0-M3 showed Codex regularly drops).

The deeper insight: the M0-M3 failure mode that motivated this whole
rewrite was **"Codex ignored AGENTS.md routing on the first Polish
build prompt"** — i.e. the agent failed to *enter* the workflow at
all. It was **not** "agent fabricated approval mid-workflow to skip
a review gate". The approval gate was protecting against a threat
the empirical record did not show. That is the textbook shape of
over-engineering against a hypothetical threat.

Brief V3 explicitly framed `fast-trusted` profile as
*"a guardrail, not a hard boundary"*. A hard `PreToolUse` block on
missing approval token contradicts that framing. With the gate
removed, the framing matches the implementation.

**What this means for v1 — concretely:**

- **No real-time block** on agent flipping `spec.md status:
  in-progress → completed` without user signoff. The agent *could*
  do this; the rest of the system (Stop hook audit, `sage doctor`,
  outcome harness) detects it post-hoc.
- **No `.sage/.approval-pending` file**. References to it removed
  from §6.5 (turn-audit.sh), §6.7 (writers manifest). MCP tool
  `sage_record_approval` was originally to consume this token —
  deferred along with the rest of MCP per §8 (third cut, same day).
- **Phase enforcement** (e.g. "agent cannot start implementation
  before plan.md is `status: completed`") is now **soft policy
  only** — lives in AGENTS.md prose + workflow skill prose, same
  pattern as the Claude port. If Codex ignores the soft policy, the
  outcome harness measures it; v2 redesigns the gate with real data.

**What still gates mutations in v1:**

- `pre-tool-validate.sh` (§6.3) implements the predicate inline in
  bash (no MCP call in v1). Predicate v1 = **"active cycle exists +
  patch path is in scope of that cycle"**. NOT predicate v2 (which
  would have included "approval token exists for current phase").
  This blocks mutations to project files when no cycle is open at all
  (e.g. agent tries `apply_patch` on `src/foo.py` when nobody ran
  `/sage:build`). It does NOT block phase-jumping inside a cycle.

**v2 promotion triggers (binding — must be added to outcome harness
before v2 design):**

1. **Phase-jump rate.** If outcome harness logs N sessions where
   agent flipped frontmatter `status: completed` without an
   identifiable user approval-like message in the same turn window
   above threshold X% — gate becomes a v2 candidate.
2. **User-pain rate.** If user reports phase-jump ("agent just
   started implementing before I approved the plan") in `sage
   doctor` review or self-learning storage above threshold Y per
   week — gate becomes v2 candidate.
3. **Forge attempt observed.** If audit detects agent fabricating
   "user approved" claims in transcript without corresponding user
   message — gate becomes v2 candidate (this is the original
   threat model; v2 gets *real data* to design against).

Until any trigger fires, v1 ships without the gate and harness
collects the baseline.

**v2 design constraint (locked even though v2 is far away):** any
future approval mechanism must use a **deterministic surface only**
(per brief Hard Anti-Pattern). Acceptable surfaces: numeric channel
(`1`/`2`), markup channel (`[A]`/`[R]`), slash command
(`/sage:approve`). Unacceptable: any keyword/regex/semantic match
on Polish or English free text. Unacceptable: any LLM classification
on every user message (latency cost). The v2 ADR will pick from
the deterministic-surface set with empirical data informing which.

**Files NOT shipped in v1 (recap):**
- `runtime/platforms/codex/hooks/ups-approval.sh` — does not exist.
- `.sage/.approval-pending` — never written.
- `.sage/.ups-hook.log` — never written.
- UserPromptSubmit hook entry in generated `.codex/hooks.json` —
  not present (Stage 5 generator reflects this).

### 6.3 — `pre-tool-validate.sh` (event: `PreToolUse`, matcher: `apply_patch`)

**Trigger:** Codex about to invoke `apply_patch`.

**Payload (stdin JSON, empirically verified 2026-04-30 on
codex-cli 0.126.0-alpha.15 via M0 PoC T0.1):**
```json
{
  "session_id": "<uuid>",
  "turn_id": "<uuid>",
  "transcript_path": "<path>",
  "cwd": "<abs-path>",
  "hook_event_name": "PreToolUse",
  "model": "<model-id>",
  "permission_mode": "<mode>",
  "tool_name": "apply_patch",
  "tool_input": { "command": "*** Begin Patch\n*** Add File: <path>\n+<line>\n*** End Patch\n" },
  "tool_use_id": "<id>"
}
```
(Codex 0.126 verified: PoC C1 + M0 T0.1 confirmed `tool_name` and
`tool_input` in payload; PreToolUse fires before mutation. Note:
`tool_input.command` is the apply_patch DSL — hook must parse
`*** Add/Update/Delete File: <path>` lines to extract `claimed_paths`,
~10 lines of bash.)

**Implementation: pure bash + jq + yq (decision 2026-04-30 — MCP
deferred entirely from v1 per §2 / §8). No MCP call-out in v1.**

**Action sequence (per ADR-1, with v1 predicate amendment + bash
inlining 2026-04-30):**
1. Read `tool_input.command` from payload via `jq`. Parse apply_patch
   DSL — extract `*** (Add|Update|Delete) File: <path>` lines (~10
   lines bash) → `claimed_paths` list.
2. **Find active cycle** — scan `.sage/work/*/manifest.md`; first
   one with `yq eval '.status'` returning `in-progress` is the
   active cycle. (At most one expected; if more than one, take
   newest mtime + log a warning to `.sage/.skipped-checks.log`.)
3. **No active cycle** → exit 2 with stderr message:
   *"Sage: no active cycle. Run `/sage:build` (or `/sage:fix`,
   `/sage:architect`) to start a workflow before mutating files."*
4. **Active cycle found** → read `scope:` array from manifest
   frontmatter (list of glob patterns the cycle is allowed to
   mutate, e.g. `src/**`, `tests/**`, `.sage/work/<cycle>/**`).
5. **Scope match** — for each `claimed_path`, test against each
   `scope_glob` using bash case-pattern matching (`case $path in
   $glob) ... esac`). If any path matches no glob → out-of-scope.
6. **Out-of-scope paths exist** → exit 2 with stderr message listing
   the paths: *"Sage: paths outside cycle scope: <list>. Active
   cycle: <cycle-id>. Allowed scope: <globs>."*
7. **All paths in scope** → exit 0 (allow); append session-mutations
   log line to `.sage/.session-mutations.log` for ADR-7 audit:
   `{"session_id":"...","files":[...],"ts":"..."}`.

**Total length:** ~40 lines bash. Reference implementation lives in
`runtime/platforms/codex/hooks/pre-tool-validate.sh` (M2 milestone).

**v1 validator predicate scope (decision 2026-04-30 — paired with
§6.2 deferral):** the predicate v1 evaluates **only** the cycle-scope
test (steps 2-6 above). It does **NOT** evaluate phase consistency
(whether spec/plan are at `status: completed` for the requested
mutation class) and does **NOT** consult any approval token (none
exists in v1 — see §6.2). Phase enforcement is soft policy in
AGENTS.md + skill prose.

This is the explicit narrowing of ADR-1's predicate from "active
cycle + correct phase + approval token" to just "active cycle +
scope". v2 promotion to the full predicate is gated on the same
triggers as §6.2 (phase-jump rate, user-pain rate, observed forge
attempts). When any trigger fires, the v2 predicate adds the
phase + approval checks back, AND the predicate gets reimplemented
in MCP `sage_validate_mutation` (Python) because complexity exceeds
bash maintainability ceiling at that point.

**v1 failure modes (silent-failure mitigation):**
- Missing `jq` or `yq` on system → hook can't parse payload or
  manifest. Mitigation: `bin/sage init --platform codex` runs
  pre-flight check (per §7 `bin/sage` updates), refuses to install
  if either binary missing, prints exact `brew install jq yq` /
  `apt-get install jq yq` command. Without this pre-flight check,
  the silent-failure mode is real.
- Permission error on `.sage/.session-mutations.log` → step 7 fails;
  hook exits with non-zero from `set -euo pipefail`. Codex treats
  this as deny (exit code != 0). Same outcome as MCP unreachable in
  prior design — fail-closed.
- Race on log write → multiple Codex sessions writing concurrently.
  Mitigation: `lib/json_log.sh` (per §6.6) uses `flock` when
  available, atomic mktemp+rename otherwise. Same pattern as ADR-7
  audit writes.

**v1 matcher list:** `apply_patch` only. Bash mutations are
**uncovered in v1** — they would have been caught at L5 (ADR-1
amendment 2026-04-30), but L5 is deferred to v2 (§2). Accepted risk:
a session using `sed -i` / `python -c "open(...).write(...)"` to
mutate files outside `apply_patch` will not be gated by L1.
Detection-only: ADR-7 Stop hook compares session-touched paths to
`apply_patch`-claimed paths; mismatches surface in `sage doctor`.
v2 trigger (Bash matcher activation): outcome harness sees
Bash-mediated mutations leaking past audit.

**Exit codes:**
- 0 = allow
- 2 = deny (stderr carries reason → agent context)

**File writers:**
- `.sage/.mcp-incidents.log` — **NOT written by this hook in v1**
  (no MCP unreachable branch since no MCP). Returns as writer in v2
  if/when MCP comes back.
- `.sage/.session-mutations.log` (append-only; sole writer).
- `.sage/.skipped-checks.log` (informational; e.g. multiple active
  cycles detected).

### 6.4 — `post-tool-check.sh` (event: `PostToolUse`, matcher: `apply_patch`)

**Trigger:** Codex completed `apply_patch`.

**Implementation: pure bash + git + yq** (decision 2026-04-30, "MCP
lite" v1 — `sage_check_post_mutation` MCP tool deferred per §8.2).
Both Check A and Check C are equivalent in bash to MCP variant; no
compliance loss.

**Payload (stdin JSON, empirically verified 2026-04-30 on
codex-cli 0.126.0-alpha.15 via M0 PoC T0.1):** PreToolUse shape
plus two extra fields:
- `tool_input` — same as PreToolUse (apply_patch DSL string).
- `tool_response` — STRINGIFIED JSON
  `"{\"output\":\"...\",\"metadata\":{\"exit_code\":0,\"duration_seconds\":N.N}}"`.
  Extract via `jq -r '.tool_response | fromjson | .metadata.exit_code'`
  (one extra `fromjson` step). M0 T0.1 confirmed both fields present
  in single hook firing — PoC C2 closed.

**Action sequence (bash-native per §8.2 v1 lite):**
1. Read `tool_input.command` from payload via `jq` — parse apply_patch
   DSL (`*** (Add|Update|Delete) File: <path>` lines) into
   `claimed_paths`. Optimization (M0 T0.1 finding): if
   `tool_response | fromjson | .metadata.exit_code` ≠ 0, exit 0
   early — apply_patch already failed, no diff needed.
2. **Check A — Diff-claim mismatch (file-level):**
   - `actual_paths=$(git diff --name-only HEAD -- $claimed_paths)`
   - Compare sets:
     - `claimed_paths` minus `actual_paths` → `claim_no_op` incidents
       (file claimed but unchanged).
     - `actual_paths` minus `claimed_paths` → `unclaimed_change`
       incidents (file changed but not claimed; rare).
   - For each, append JSON line to `.sage/.mcp-incidents.log` with
     `severity: warn`.
3. **Check C — `.sage/` frontmatter health:**
   - Filter `actual_paths` to entries matching `.sage/**/*.md`.
   - For each: extract frontmatter (between leading `---` and next
     `---`), pipe to `yq eval '.' > /dev/null`. On non-zero exit →
     `broken_frontmatter` incident.
   - If `yq` missing: skip Check C, append one-time
     `frontmatter_check_skipped` info line; emit doctor hint.
4. **Check B — DEFERRED:** symbol-existence check per ADR-10 stays
   deferred (would need language parsers; v2 promotion target — at
   that point `post-tool-check.sh` calls MCP `sage_check_post_mutation`
   per §8.2 v2 expansion path).
5. **No MCP unreachable branch needed** — bash does the checks
   directly. (When v2 promotes back to MCP, the `MCP unreachable
   → dead_validator_post incident` branch returns per ADR-3 D6.)
6. Exit 0 always.

**v1 invariant:** never blocks. ADR-10 fixed warn-only.

**Exit codes:** 0 always.

**File writers:**
- `.sage/.mcp-incidents.log` (append-only).
- `.sage/.skipped-checks.log` (informational, append-only) — when
  `yq` missing or claimed paths outside cwd.

**Dependency note:** `yq` (Go-based YAML processor by mikefarah) is
the runtime dependency for Check C. Acceptable — distributed via
homebrew/apt by default in most dev environments. If absent, Check C
degrades gracefully (Check A still runs).

**Pre-cutover gate:** PoC C2 (PostToolUse fires + payload shape) must
pass. See §13.

### 6.5 — `turn-audit.sh` (event: `Stop`)

**Trigger:** end of every turn (Codex finishes responding).

**Payload (stdin JSON):**
```json
{
  "session_id": "<uuid>",
  "turn_id": "<int>",
  "ts": "<iso>"
}
```
(Verified PoC A1 U1: Stop fires once per turn end.)

**Implementation: pure bash + jq + git** (decision 2026-04-30, "MCP
lite" v1 — `sage_audit_turn` MCP tool deferred per §8.2). Bash
coverage ~70% of ADR-7 audit surface; misses deep manifest cross-
reference and full ADR-7 C7 writers-manifest validation. Accepted
v1 limitation; v2 promotion trigger documented in §8.2.

**Action sequence (bash-native v1 lite — partial ADR-7 surface,
amended 2026-04-30 for approval-gate deferral per §6.2):**
1. **Orphan approval check (ADR-7 C1):** SKIPPED in v1 — no
   `.sage/.approval-pending` writer exists (§6.2 deferred). Returns
   if v2 promotion brings approval gate back.
2. **Approval-coupling check (ADR-7 C2):** SKIPPED in v1 — no
   approval token to couple. Returns with v2.
3. **Session-mutations vs claimed paths (ADR-7 C3, partial):** read
   `.sage/.session-mutations.log` lines for this `session_id`+`turn_id`,
   compare to `git diff --name-only HEAD` since session start. If a
   git-tracked path was mutated but not in session-mutations log →
   append `bypass_mutation` incident.
4. **Phase-jump probe (NEW v1 — informational, feeds outcome
   harness per §6.2 v2 promotion trigger #1):** scan
   `.sage/.session-mutations.log` for this turn's mutations targeting
   `.sage/work/*/manifest.md` or `.sage/work/*/spec.md` or
   `.sage/work/*/plan.md`. For each, parse the patch (best-effort)
   to detect frontmatter `status:` field flipping to `completed`.
   If detected → append `phase_jump_observed` incident with
   `{cycle, file, prior_status, new_status, ts, severity: info}`.
   This is a **measurement**, not a block — feeds harness data so
   v2 trigger threshold can be evaluated against real numbers.
5. **Skipped (v1 limitation, v2 promotion target):**
   - **ADR-7 C5** precommit-log cross-check: skipped because L5 is
     deferred per §2 (no `.precommit.log` writer exists in v1).
   - **ADR-7 C7** writers-manifest deep validation: bash version does
     point-in-time check against last commit only; full multi-commit
     audit via `sage doctor S4` (which can run retroactively, batch
     mode).
6. **Dead-MCP detection (ADR-7 C6):** SKIPPED in v1 — no MCP server
   shipped (§2 / §8 deferred). Returns when MCP comes back in v2.
7. Exit 0.

**v1 invariant:** never blocks. ADR-7 D5 locked.

**Exit codes:** 0 always (no exit 2, no `continue: false`, no
`decision: "block"` per ADR-7 D4-bis).

**File writers:**
- `.sage/.mcp-incidents.log` (append-only; bash-native writer — uses
  `lib/json_log.sh` for atomic append).

### 6.6 — Cross-script common helpers

All v1 hook scripts (4 — session-init, pre-tool-validate, post-tool-
check, turn-audit) share two needs that justify a small library
under `runtime/platforms/codex/hooks/lib/`:

- **`json_log.sh`** — atomic JSON-line append to `.sage/.*.log`
  files (mktemp + cat >> + flock if available; degrade to plain >>
  on systems without flock).
- **`active_init.sh`** — read `.sage/work/*/manifest.md` and return
  the most recent `status: in-progress` cycle path (or empty).

~~`mcp_call.sh`~~ — **NOT created in v1** (no MCP server to call).
Returns in v2 alongside ADR-3 reactivation.

These helpers are kept minimal — avoid building a hook framework.

### 6.7 — Hook script audit (writers manifest)

For ADR-7 C7 (bypass-write detection on `.sage/`), the authoritative
writers manifest is:

```yaml
# runtime/platforms/codex/audit/sage-writers.yaml
.sage/.approval-pending:
  # v2 only — UPS approval hook deferred per §6.2; in v1 this file
  # is never written. ADR-7 C1/C2 audit checks degrade to "skipped".
  writers: []
.sage/.ups-hook.log:
  # v2 only — see above. v1 has no UPS hook script.
  writers: []
.sage/.mcp-incidents.log:
  # v1 writer set — all bash hooks (no MCP server in v1 per §2 / §8
  # decision 2026-04-30; sage_validate_mutation reimplemented inline
  # in pre-tool-validate.sh bash). pre-tool-validate.sh is NOT
  # currently a writer in v1 (no MCP unreachable branch); it joins
  # writers list in v2 when MCP returns.
  writers: [post-tool-check.sh, turn-audit.sh]
.sage/.session-mutations.log:
  writers: [pre-tool-validate.sh]
.sage/.precommit.log:
  writers: [.githooks/pre-commit]  # v2 only — L5 deferred per §2; in v1 this file is absent and ADR-7 C5 cross-check degrades to "no precommit log" mode.
.sage/decisions.md:
  # v1: only the agent (via apply_patch when path scope allows it)
  # writes here. sage_record_approval MCP tool deferred per §8.2 +
  # §6.2 (no approval token → no atomic record-approval call).
  writers: [agent_via_apply_patch_when_P2_2]
.sage/work/**:
  # v1: only agent writes (no sage_record_approval in v1 per §8.2).
  writers: [agent_via_apply_patch_when_P2_2]
.sage/docs/**:
  writers: [agent_via_apply_patch_when_P2_2]
```

This file is generated by §4 Stage 6 (or Stage 4) and consumed by
ADR-7 C7 audit + `sage doctor`. Single source of truth.

---

## 7. CLI surface

### 7.1 — `bin/sage` updates

The existing `bin/sage` script (preserved per §3) needs minimal
updates for the new Codex port:

**Line ~752:** the `if platform_has "codex"` block currently calls
`runtime/platforms/codex/setup/generate-codex.sh`. After this
rewrite, that path will be a different generator — the call signature
stays the same, no `bin/sage` change beyond ensuring the path
matches what M1 produces.

**Line ~1271:** the "Codex MCP" hint block in `sage doctor` is
**removed in v1** (no MCP server shipped per §2 / §8 decision
2026-04-30). When v2 reactivates MCP, the hint block returns to
surface install instructions (`pipx install sage-mcp` or local
`pip install -e ...`).

**New pre-flight check in `bin/sage init --platform codex`:** verify
`jq` and `yq` are on PATH before installing hooks (per §6.3 silent-
failure mitigation). If either missing → fail with platform-specific
install hint (`brew install jq yq` on macOS, `apt-get install jq
yq` on Debian/Ubuntu). Without this pre-flight, missing tooling
causes silent hook failures.

No new top-level subcommands required by Codex port. ADR-9 already
reserves `init`, `update`, `doctor`, `status` — all generic.

**Naming collision (D12 closure):** `bin/sage status` vs Codex native
`/status`. Decision: keep both names; documentation always uses the
full phrase ("`bin/sage status`" or "Codex `/status`"). No rename.

### 7.2 — `sage doctor` (D2 checks per ADR-8)

The `sage doctor` subcommand is the user-facing diagnostic. Inputs
are the disk state + a Codex session probe. Outputs are a structured
list of pass/warn/fail results.

**Posture: read-only diagnostic only (decision 2026-04-30, locked
for v1).** `sage doctor` **never modifies project state**. It
reads, probes, reports. Every fail/warn message includes a "Fix:
`<command>`" hint pointing the user at the explicit command that
addresses the issue. The user runs the fix; doctor verifies on
re-run.

**Why no auto-fix in v1:**
1. **Predictable side-effect surface.** Diagnostic that never writes
   has zero risk of corrupting project state. The user can run
   `sage doctor` 100x and the project state is invariant.
2. **User learns the system.** Reading the fix command is the
   shortest path to understanding what Sage actually does. Auto-fix
   skips this loop and produces users who can't unstick themselves
   when auto-fix fails.
3. **Test surface stays small.** Read-only doctor needs ~2 tests per
   check (pass case + fail case). Auto-fix would multiply this by
   "fix path × destructive variant × backup verification".

**v2 trigger (binding):** outcome harness shows users running the
same `sage doctor`-suggested fix command repeatedly across sessions
(signal: "manual fix is friction"). Then v2 adds **`sage doctor
--fix`** as opt-in flag with per-check "safe vs destructive"
classification (per Option 3 from design discussion 2026-04-30 —
preserved here for future reference, not implemented in v1).

**Cursor convention (already documented in S1):** `sage doctor`
maintains `<project>/.sage/.doctor-cursor` to track which incidents
have been surfaced. **This is the only file `sage doctor` writes in
v1** — it's a read-position marker, not a state mutation. The
read-only posture above means "no change to managed Sage surface or
user files"; the cursor file is doctor's own bookkeeping.

D2 checks for v1 (per synthesis punch list 13-15):

#### E1 — Codex CLI present + version check
- Probe: `which codex` + `codex --version`.
- Pass if version ≥ 0.126.0-alpha.15.
- Fail message: *"Codex CLI not found / version too old. v1 needs
  ≥0.126; install via `npm i -g @openai/codex` or upgrade."*

#### E2 — `.codex/config.toml` valid + Sage block present
- Probe: parse TOML, find `# >>> SAGE MANAGED BLOCK START`.
- Pass if both true.
- Fail: *"Run `bin/sage update --platform codex` to regenerate Sage
  managed block."*

#### E3 — MCP server reachable — **N/A in v1** (deferred per §2 / §8)
- Skipped check in v1 — no MCP server shipped.
- Returns when v2 reactivates MCP server.

#### E4 — Trust state
- Probe: detect Codex trust marker for project (mechanism per Codex
  trust doc; if not API-introspectable, fall back to "is
  `developer_instructions` being applied" heuristic).
- Pass if trusted.
- Fail: *"Project not trusted in Codex — `developer_instructions`
  not loaded. Trust via Codex UI / CLI flow."*

#### M1 — `AGENTS.md` matches generated baseline
- Probe: regenerate AGENTS.md to a temp file, diff against on-disk.
- Pass if identical or "user changes outside Sage block" only.
- Warn: *"AGENTS.md drifted from Sage baseline. Run `bin/sage
  update`."*

#### M2 — Hook scripts present + executable
- Probe: stat 4 v1 hook scripts under `.codex/hooks/` (`session-
  init.sh`, `pre-tool-validate.sh`, `post-tool-check.sh`,
  `turn-audit.sh`), check mode 0755. UPS hook is **NOT** expected
  in v1 per §6.2 deferral.
- Probe: verify `jq` and `yq` are on PATH (hooks depend on these).
- Fail: *"Missing/non-executable hook: <path>. Run `bin/sage
  update`."* / *"Missing tool: jq/yq. Run `brew install jq yq`."*

#### M3 — Sandbox-write self-test (closes A3 #UV2)
- Probe: write a tiny file under `<project>/.sage/.doctor-probe-<pid>`
  via Codex (cannot be done from `sage doctor` directly; instead,
  surface "Codex sandbox config to allow `.sage/` writes" as a hint).
- Mode: hint-only in v1; v2 candidate to actually run the probe via
  a test harness.

#### M4 — Mid-session MCP liveness — **N/A in v1** (deferred per §2 / §8)
- Skipped in v1 — no MCP server shipped.
- Returns when v2 reactivates MCP.

#### S1 — `.sage/.mcp-incidents.log` unread incidents
- Probe: count lines newer than `.sage/.doctor-cursor` (cursor
  updated each doctor run).
- Warn if > 0; print each as a one-liner (severity, type, ts).

#### S2 — Stale `.sage/.approval-pending` — **N/A in v1** (deferred per §6.2)
- Skipped in v1 — no UPS hook, no token writer.
- Returns when v2 brings approval gate back.

#### S3 — Active cycle without recent activity
- Probe: for any cycle with `status: in-progress`, check
  `<cycle>/manifest.md` mtime > 7 days.
- Info: list as "stale cycles, consider closing or resuming".

#### S4 — Writers manifest validation (closes ADR-7 C7)
- Probe: read `runtime/platforms/codex/audit/sage-writers.yaml`,
  cross-reference against last N commits of `git log --diff-
  filter=AM .sage/`. For each `.sage/` file mutation, verify the
  writer is on the manifest list.
- Warn: *"Bypass-write detected: <file> mutated by non-listed
  writer."*

#### CV1 — Codex version watch (residual D-class risks)
- Probe: compare current Codex version against last-validated
  version (`<project>/.sage/.codex-validated-version`).
- Warn if current > last-validated by major bump:
  *"Codex bumped to <new>. Retest PoC A1 (forge resistance) and PoC
  C1 (no-respawn) before trusting v1 invariants."*

### 7.3 — `bin/sage status`

The status subcommand (per ADR-9) shows:

1. Active cycles — title, workflow, phase, status, last update.
2. Pending gates — *"approval pending — type [A] to confirm"* lines
   for any cycle with a gate awaiting `[A]`.
3. Recent decisions — last 3 entries from `decisions.md`.
4. Health summary — short version of `sage doctor` (just count of
   warns/fails; full doctor for details).

Output is plain text; `--json` flag for scriptable form.

---

## 8. MCP server — DEFERRED to v2 (decision 2026-04-30, third cut)

**v1 has no MCP server.** The validator predicate (`sage_validate_mutation`
in ADR-1) is implemented inline in `pre-tool-validate.sh` as ~40 lines
of bash (jq + yq + glob match — see §6.3). All other planned tools
(`sage_record_approval`, `sage_status`, `sage_audit_turn`,
`sage_check_post_mutation`) are also deferred or implemented in bash —
see §6.7 writers manifest for the full v1 mapping.

**Cut history (compounded same day):**
- Cut 1 ("MCP lite"): planned 5 tools → 2 (validator + record_approval).
- Cut 2 ("MCP ultra-lite"): approval gate deferred → 1 tool (validator only).
- Cut 3 ("no MCP"): single-tool predicate is bash-equivalent → 0 tools, no server.

**v2 promotion trigger (binding):** MCP server returns when **any** of:
1. v1 predicate exceeds bash complexity ceiling (~80 lines, or > 1 second
   cold-start latency, or needs language parsers for symbol-existence
   checks à la ADR-10 Check B).
2. §6.2 v2 promotion fires (approval gate returns) — `sage_record_approval`
   needs Python's atomic file ops, brings the server back with it.
3. A second port (Claude Code, antigravity, generic) declares intent to
   share validator logic — at that point shared `runtime/mcp/server/`
   becomes warranted (no premature abstraction).

**v2 design constraint (locked):** when MCP returns, location is
`runtime/platforms/codex/mcp/` first; only extracted to `runtime/mcp/
server/` when a second consumer materializes (§3 "no abstractions before
second consumer"). Distribution name `sage-mcp` is reserved.

**ADR-3 status:** `enabled_tools` is empty in v1. ADR-3 is amended in
v2 when the promotion trigger fires.

### 8.x — v1 bash dependencies (replaces former §8.6)

Hook scripts depend on:
- `git` (diff calls).
- `jq` (JSON-line construction + payload parse — see §6.3).
- `yq` (YAML frontmatter parse — see §6.3, §6.4).
- `flock` (Linux); on macOS, degrade to plain append (acceptable race
  tolerance per ADR-3 prior decision; carried forward).

`bin/sage init --platform codex` performs a pre-flight check that
`jq` and `yq` are on PATH and fails fast with install instructions
if either is missing (see §7.1). No Python install needed in v1.

---

## 9. Workflow state machine (ADR-4 surface)

The full state machine is specified in ADR-4. **v1 implements only a
narrow slice** (decision 2026-04-30, paired with §6.2 / §6.3 / §8.2
cuts):

**States (full ADR-4 set, mostly soft-only in v1):**
- `inactive` — no cycle in progress.
- `understand` (research) — interview/JTBD/discovery phase.
- `envision` (design) — brief/spec/plan in flight.
- `deliver` (build/fix) — implementing.
- `review` — verification + approval gate.
- `paused` — explicit user action.
- `completed` — terminal.

**v1 hard enforcement = state membership only (cycle exists or
not).** The bash predicate in `pre-tool-validate.sh` (§6.3) checks:
- Is there an active cycle (any `manifest.md` with `status:
  in-progress`)?
- Are mutation paths in scope of that cycle?

That is **all** the validator enforces in v1. Phase transitions
(envision → deliver, etc.) and their approval-coupling are **soft
policy** in v1 — described in AGENTS.md + skill prose; agent is
expected to honor them but no validator blocks phase-jumps.

**Transitions in v1 (soft):** the same as ADR-4 describes — `spec.md
status: in-progress → completed` triggered by user typing approval —
but the "user typed approval" detection layer is **deferred to v2**
per §6.2. In v1, the agent reads user response and updates
frontmatter; nothing real-time blocks the agent from doing this
unilaterally. Detection (post-hoc) via `turn-audit.sh`
`phase_jump_observed` informational incidents.

**Why this v1 narrowing:** see §6.2 deferral rationale — every
candidate approval-detection mechanic either violated brief
anti-pattern or required user discipline we couldn't justify
mandating. Hard phase enforcement only makes sense when paired with
a working approval-detection layer; without that, the phase block
fires on legitimate user-approved transitions because the validator
can't tell. Soft policy + harness measurement is the v1 strategy;
v2 reintroduces hard phase enforcement once §6.2 v2 design is
shipped.

**Source-of-truth precedence (D11 closure — unchanged in v1):**

```
file system (manifest.md frontmatter status + phase)
     >
.sage/decisions.md (newest entry mentioning this cycle)
     >
agent's in-context memory
```

Rationale:
- Manifest frontmatter is authoritative because it is the input to
  the predicate in `pre-tool-validate.sh` (v1) / `sage_validate_mutation`
  MCP tool (v2). Validator reads files; if frontmatter says `status:
  completed` but decisions.md says "WIP", validator goes by frontmatter.
- decisions.md is for **human reasoning trace**; it does not
  override file state.
- Agent memory is least authoritative; agents are subject to
  compaction.

In practice this means: when updating cycle state, **frontmatter
update is mandatory**. Adding to decisions.md is good practice but
not the gate.

---

## 10. Sage labels ↔ native Codex profile mapping (D13 closure)

Sage skills declare a "tier" or "preset" affinity in their
frontmatter. Codex has its own profile concept (sandbox profiles,
review profiles). This section gives the deterministic mapping.

| Sage label | Native Codex profile | Rationale |
|---|---|---|
| `tier: 1` | (no native equivalent) | Tier-1 bypass is a Sage-only manifest field; Codex sandbox profile is orthogonal. **v1: soft policy only** — AGENTS.md + skill prose tell the agent that `tier: 1` cycles bypass review gates; the bash predicate (`pre-tool-validate.sh`) does NOT read `tier:` and applies cycle-scope check uniformly. ADR-1 P3 second row marked N/A in v1; hard tier-1 bypass returns in v2 alongside richer MCP predicate. |
| `preset: base` | `sandbox_profile: workspace-write` (default) | Standard development; full workspace writes, no network. |
| `preset: startup` | `sandbox_profile: workspace-write` + `network_access = true` | Fast iteration, includes network for npm/pypi. |
| `preset: enterprise` | `sandbox_profile: read-only-trusted` | Strict: agent reads project, mutations only via L1 (L5 deferred to v2 per §2). |
| `preset: opensource` | `sandbox_profile: workspace-write` (v1) | Public contributions. **v1:** L5 is NOT mandatory (deferred per §2); rely on L1 only (no L2 — MCP also deferred per §8). **v2:** when L5 is reactivated, this preset's mapping gains "+ L5 enforced" and L5 becomes mandatory for opensource. |

These mappings are written into `.codex/config.toml` (Stage 4) when
the project is initialized with the corresponding preset.

The mapping is **one-way (Sage → Codex)**. Sage does not consume
Codex profile information; only the other direction.

---

## 11. DRIFT resolutions (D6-D14 mechanical adoption)

Per synthesis §DRIFT, items D6-D14 are mechanical normalizations
that this spec adopts. Each is closed below.

- **D6 (`AGENTS_MD_MAX_BYTES` vs `project_doc_max_bytes`).** Spec
  uses `project_doc_max_bytes` (public name) wherever the field is
  referenced. Rust-source name `AGENTS_MD_MAX_BYTES` is the same
  field; mentioned only in this DRIFT closure for traceability.

- **D7 (8000-char discovery cap).** Conservative fallback;
  realistic cap is 2% of context window (per Codex doc). Spec uses
  the public name `project_doc_max_bytes` and notes the 2% guideline
  in §5 Tier A description.

- **D8 ("Codex deprecated slash commands 2026-01-22").**
  Unverified date in original ADR-4 prose. Removed; spec text in §1
  "Status" glossary refers to `/status` as a current native command
  (without deprecation claim).

- **D9 (`startup_timeout_sec=5` override).** **N/A in v1** — DRIFT
  D9 concerns `[[mcp_servers]]` configuration; v1 ships no MCP server
  (§8 deferred), so there is no `[[mcp_servers]]` block to override
  or accept-default in. Decision deferred to v2 alongside MCP
  reactivation; v2 will revisit whether to keep Codex default (10s)
  or override to 5s based on observed `sage-mcp` startup latency.

- **D10 (approval/plugin/status terminology).** Closed by §1
  Glossary.

- **D11 (frontmatter vs decisions.md precedence).** Closed by §9
  source-of-truth precedence statement.

- **D12 (`bin/sage status` vs Codex `/status`).** Closed by §7.1
  naming policy.

- **D13 (Sage labels ↔ native profile mapping).** Closed by §10
  table.

- **D14 (skill vs plugin nomenclature).** Closed by §1 Glossary.
  Sage v1 ships skills, not plugins.

---

## 12. PoC-anchored claims (CC-4 closure, surfaced for risk register)

The following v1 invariants are **empirically anchored on Codex
0.126.0-alpha.15**, not docs-anchored. Risk register §13 watches
each.

| Claim | Anchor | What breaks if Codex changes |
|---|---|---|
| ~~`required = true` hard-fails session at startup~~ | ~~PoC C1 T2~~ | **N/A in v1** — no MCP server (§8 deferred). Anchor returns when v2 brings MCP back. |
| ~~`Transport closed` returned cleanly to agent on MCP crash~~ | ~~PoC C1 T3~~ | **N/A in v1** — no MCP server. Anchor returns in v2. |
| Hook `exit 2` is treated as deny + stderr surfaced to agent | PoC C1 ADR-1 (validator path) | If Codex changes hook exit-code semantics, deny-fail-closed via bash hook breaks; would need different signal channel. |
| ~~UPS does not re-fire on Stop hook stderr injection~~ | ~~PoC A1 U1~~ | **N/A in v1** — UPS hook deferred per §6.2 (2026-04-30). Anchor returns to active list when v2 brings approval gate back. |
| Multi-hook entries fire all sequentially in registration order (PASS_ALL_FIRE_ORDERED) | PoC A1 U3 + M0 T0.3 (re-verified) | If only first fires, framework + user override coexistence breaks. (M0 finding: ordering is registration-sequential, not unordered as initial spec text said — corrected 2026-04-30.) |
| `apply_patch` PreToolUse payload includes `tool_name` and `tool_input` | PoC C1 ADR-1 + M0 T0.1 | Validator can't reach predicate logic; v1 dead. (M0 correction: field name is `tool_input`, not `tool_args`. Value is apply_patch DSL string requiring small bash parser.) |

**Pre-cutover gates (PoCs needed before v1):**

| PoC | Tests |
|---|---|
| PoC C2 | PostToolUse fires after `apply_patch`; payload shape includes patch args (or at minimum file list). |
| PoC C3 | Hook timing: `apply_patch` return → PostToolUse fire latency. Ensure no race with agent reading patched file. |

These are spec.md gates, not ADR-10 gates — the ADR is "proposed";
the PoC closure is part of M1 verification.

---

## 13. Risk register (living section)

This section is **the only living section** of v1 — it gets updated
at every Codex bump, every empirical retest, every observed leak.

### 13.1 — Active risks (v1 cutover)

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R-1 | Codex bump removes `required = true` semantics | N/A in v1 (no MCP server — §8 deferred) | N/A in v1 | Risk returns with v2 MCP reactivation; retest PoC C1 T2 then. | none in v1 |
| R-2 | Codex bump changes hook payload schema | medium | high (hooks blind — bash predicate + audit fail) | retest PoC C1 + A1 + C2; CV1 doctor check; payload-shape parity tests in `pre-tool-validate.sh`, `post-tool-check.sh`, `turn-audit.sh` | implementer |
| R-3 | Subagent UPS firing forges approval token | N/A in v1 (D-R1) | N/A in v1 (UPS hook deferred per §6.2; no token to forge) | Risk returns when v2 brings approval gate back; v2 ADR must address this on the v2 deterministic-surface design. | none in v1 |
| R-4 | Hook `additionalContext` injection bypasses UPS | N/A in v1 (D-R2) | N/A in v1 (no UPS hook to bypass) | Returns with v2 approval gate. | none in v1 |
| R-5 | Agent self-promotes `tier: 1` to bypass validator | low in v1 (no hard bypass exists — `tier: 1` is soft policy only per §10; predicate ignores `tier:`); risk materializes in v2 when hard tier-1 bypass returns alongside MCP predicate | medium (in v2) | turn-audit.sh logs every `tier:` frontmatter flip in v1 as informational baseline measurement, so v2 starts with empirical data on flip rate; v2 CLI flow gates promotion behind explicit `bin/sage tier --promote <cycle>` command (not direct frontmatter edit) | implementer (v1 instrumentation), v2 design (gating mechanic) |
| R-6 | L5 deferred to v2 — no client-side git-layer gate in v1 | medium (accepted per §2) | medium | Detection-only via ADR-7 audit + sage doctor; v2 trigger when L1+L2 bypass observed in outcome harness; `--no-verify` is then the secondary v2 risk | none in v1 |
| R-7 | `apply_patch` to `.sage/decisions.md` is unconstrained | low in v1 (no MCP server, no record-approval writer — agent IS the only writer per §6.7) | medium | ADR-7 C7 bypass-write detection still applies (writers manifest lists agent_via_apply_patch as sole writer); sage doctor S4; predicate validates path is in cycle scope (`.sage/decisions.md` always in scope by convention — see §6.3) | implementer |
| R-8 | PostToolUse PoC C2 fails — payload thinner than expected | medium | medium | fallback: post-tool-check.sh uses git diff against last commit (more complex) | implementer |
| R-9 | **Approval gate deferred to v2 — agent can flip frontmatter `status: completed` without user signoff in v1** | medium (accepted per §6.2 deferral 2026-04-30) | medium (phase-jump = workflow integrity loss; not data-destructive but undermines review-gate UX) | Detection-only: turn-audit.sh phase-jump probe (§6.5 step 4) writes `phase_jump_observed` incidents; sage doctor surfaces them; outcome harness measures rate. v2 trigger: phase-jump rate > X%, user-pain rate > Y/week, or any forge attempt observed (§6.2 v2 promotion triggers). | implementer (harness instrumentation), user (review of doctor output) |

### 13.2 — Outcome harness signals (v2 candidates)

These trigger v2 work if outcome harness data shows them present:

- **Symbol hallucinations leak.** Add ADR-10 Check B (per-language
  parser).
- **Bash-mediated mutation leaks** (agent uses `sed -i` to mutate
  files outside `apply_patch`). Add Bash matcher to PreToolUse with
  command-content regex.
- **`developer_instructions` ignored** (rule 3 violations frequent).
  Move rule 3 stricter into AGENTS.md or consider
  `model_instructions_file`.
- **Multi-hook ordering bites** (race in shared log writes despite
  flock). Investigate; potentially serialize via a lock file in
  `.sage/.lock`.
- **Bash audit coverage gap surfaces (ADR-7).** Outcome harness
  signal: agents committing without `decisions.md` entry > 5% of
  turns, OR `sage doctor S4` bypass-write detection rate exceeds
  threshold. Trigger: introduce MCP server in v2 (per §8 v2 promotion
  trigger #1 — bash complexity ceiling); promote `turn-audit.sh` to
  call `sage_audit_turn` MCP tool. Bash fallback stays as
  compatibility path during transition (env-var sentinel
  `SAGE_AUDIT_VIA_MCP=1`).
- **Bash post-tool-check Check B needed (ADR-10).** Outcome harness
  signal: imagined-symbol hallucinations leak into commits at
  measurable rate. Trigger: add Check B (per-language parser, e.g.
  `ast.parse` for Python) — this fires §8 v2 promotion trigger #1
  (language parsers can't run in bash). Promote `post-tool-check.sh`
  to `sage_check_post_mutation` MCP tool alongside MCP server reintro.
- **Bash predicate complexity ceiling (§6.3).** Outcome harness
  signal: `pre-tool-validate.sh` exceeds ~80 lines, or cold-start
  latency > 1 second, or v2 design needs phase-aware/approval-aware
  predicate per §6.2 v2 promotion. Trigger: §8 v2 promotion fires;
  predicate moves to `sage_validate_mutation` MCP tool (Python ~50
  lines + tested) and bash hook becomes thin dispatcher to MCP.
- **`sage doctor` fix friction observed.** Outcome harness signal:
  users running the same doctor-suggested fix command repeatedly
  across sessions (e.g. `bin/sage update --platform codex` after
  every Codex bump). Trigger: ship `sage doctor --fix` as opt-in
  flag with per-check "safe vs destructive" classification (Option 3
  from design discussion 2026-04-30). Safe fixes auto-apply on
  `--fix`; destructive require `--fix --aggressive` or per-fix
  `[A]/[R]` confirmation.
- **L1 bypass observed (v1).** Sessions where commits land without
  any entry in `.sage/.session-mutations.log` (predicate hook never
  ran), or where `.codex/hooks.json` is intentionally disabled, or
  where bash hook crashes (jq/yq missing or broken) are not surfaced
  to user. Trigger: ship **L5 client-side git hooks backstop** per §2
  deferred entry — reactivate Stage 8 of generator, wire
  `.githooks/pre-commit` + `pre-push`, restore ADR-7 C5 precommit-log
  audit pathway. Rollout note: when L5 ships, it must be deployed for
  ALL existing Codex projects on `bin/sage update`, not just new
  `init`s. **v2 expansion:** once MCP server returns (per §8 v2
  promotion), this trigger expands to "L1+L2 bypass" — adds the
  fourth condition "MCP `required = true` becomes non-binding after a
  Codex bump" — and the L5 backstop covers both layers.
- **Phase-jump rate signal (paired with §6.2 approval-gate deferral).**
  Outcome harness signal: turn-audit.sh `phase_jump_observed` incidents
  fire above threshold X% of cycle turns (e.g. >5% of cycles see
  agent flip `spec.md status: completed` without user-issued
  approval-like message in same turn window). Trigger: design and
  ship v2 approval gate per §6.2 v2 design constraint (deterministic-
  surface only — numeric / markup / slash-command channel; never
  keyword classification). New v2 ADR replaces deferred ADR-2.
- **User-pain phase-jump signal.** User self-reports phase-jump in
  `sage doctor` review (e.g. "agent started implementing before plan
  was approved") above Y reports/week or stored as self-learning
  with `phase-jump` tag at measurable rate. Trigger: same as above —
  ship v2 approval gate.
- **Forge attempt observed.** Audit detects agent fabricating
  "user approved" claims in transcript without corresponding user
  message (turn-audit pairing transcript scan with `.sage/.ups-hook
  .log` — n.b. v1 has no UPS log; v2 introduces the log alongside
  the approval gate). Trigger: same as above — ship v2 approval gate
  with the threat now empirically anchored.

### 13.3 — Codex version watch

| Version | Validated? | Date | Key tests |
|---|---|---|---|
| 0.126.0-alpha.15 | yes | 2026-04-30 (M0 close) | PoC A1 U3 + M0 T0.3 (multi-hook PASS_ALL_FIRE_ORDERED — sequential by registration), PoC C1 ADR-1 + M0 T0.1 (PreToolUse `apply_patch` payload includes `tool_name` + `tool_input` — note: field is `tool_input`, not `tool_args`), exit-2 deny semantics + stderr surface format `Command blocked by PreToolUse hook: <stderr>` (M0 T0.3); PoC C2 CLOSED (M0 T0.1 — PostToolUse payload includes `tool_input` AND `tool_response` stringified-JSON with `metadata.exit_code` — see §6.4); PoC C3 CLOSED (M0 T0.2 — hooks blocking, no race, apply_patch writes to disk before PostToolUse fires). MCP-related anchors (C1 T1-T3, A1 U1) N/A in v1 — return with v2 MCP reactivation. Full M0 results: `.sage/work/20260429-codex-port-rewrite/poc-c2-c3-results.md`. |
| 0.130 (next major) | no | TBD | retest A1 U3, exit-2 deny semantics, payload shapes for PreToolUse / PostToolUse / Stop hooks. MCP retests (C1 T2-T3, A1 U1) N/A in v1; activate when v2 reintroduces MCP. |
| 0.200 (LTS) | no | TBD | full re-validate suite — v1 anchors above plus v2 MCP anchors if MCP has been reactivated by then. |

`sage doctor` CV1 check (per §7.2) compares current Codex version
to entries in this table; warns if current > last-validated major.

---

## 14. Out of scope (v2 candidates explicitly listed)

The following are NOT in v1:

- **`PermissionRequest` hook wiring.** ADR-5 deferred. v2 candidate
  if outcome harness shows sandbox bypass attempts.
- **ADR-10 Check B (symbol existence).** Deferred per §6.4 / ADR-
  10 §"Check B (DEFERRED)".
- **`model_instructions_file` mechanism.** Deferred per §5 "Why not".
- **Visual gate** (browser screenshot diff). Excluded per CRIT-2
  Option C; Codex CLI has no UI affordance.
- **Bash matcher on PreToolUse.** Deferred to v2 with empirical
  trigger.
- **Codex `app` definitions** (slash-command-like surfaces). Sage
  v1 ships skills, not apps.
- **Codex `plugin` packaging** (skills + apps + mcp_servers
  bundle). v2 candidate; would let `bin/sage init` install as a
  single Codex plugin.
- **L5 client-side backstop** (`.githooks/pre-commit` +
  `pre-push` deployed and wired by Codex generator). **Deferred to v2
  per §2 decision (2026-04-30)**, gated on outcome-harness evidence
  of **L1 bypass in v1** (later "L1+L2 bypass" once v2 reactivates
  MCP). See §13.2 trigger.
- **`sage doctor --fix` auto-fix mode.** **Deferred to v2 per §7.2
  decision (2026-04-30)**, gated on outcome-harness evidence that
  manual fixes are repetitive friction. v1 is read-only diagnostic
  only.
- **MCP server entirely** (Python package, `sage-mcp` shim, transport,
  `[[mcp_servers]]` block, all 5 originally-planned tools —
  `sage_validate_mutation`, `sage_record_approval`, `sage_status`,
  `sage_audit_turn`, `sage_check_post_mutation`). **Deferred to v2 per
  §8 decision (2026-04-30, third cut — "no MCP")**. v1 implements all
  load-bearing logic in bash hooks: predicate inline in
  `pre-tool-validate.sh` (§6.3), audit in `turn-audit.sh` (§6.5),
  diff/frontmatter check in `post-tool-check.sh` (§6.4), read-only
  state in `bin/sage status`. Promotion triggers per §8 v2 promotion:
  bash predicate complexity ceiling, approval-gate reactivation
  (§6.2), or any second port adopting MCP-mediated gating. `sage_status`
  likely never promotes (read-only state is bash-equivalent forever).
- **Server-side L5 backstop** (GitHub branch protection, pre-
  receive hook). Deferred per ADR-1 trade-offs; orthogonal to
  client-side L5 above.
- **Tier-1 trust marker** (`tier_set_by: cli` field in manifest).
  N/A in v1 — `tier:` is soft policy only per §10 (predicate ignores
  it); field design returns when v2 reintroduces hard tier-1 bypass
  alongside MCP predicate. Current accepted risk per §13.1 R-5
  (informational baseline measurement only in v1).
- **Auto-respawn for MCP** on crash. N/A in v1 (no MCP server); when
  MCP returns in v2, Codex still doesn't expose this — not Sage's to
  fix.
- **Cross-worktree coordination** (one MCP shared across multiple
  Codex sessions). N/A in v1 (no MCP); out of scope for v2 too per
  ADR-1 P1.
- **Multi-language UPS vocabulary** (Polish, etc.). Hard locked
  English-only per ADR-2 W2 — superseded by full UPS hook deferral
  per §6.2 (2026-04-30); whole approval-detection layer is v2.
- **`UserPromptSubmit` hook + `ups-approval.sh` script + `.sage/
  .approval-pending` token + `sage_record_approval` MCP tool.**
  **Deferred entirely from v1 per §6.2 decision (2026-04-30)**, gated
  on outcome-harness evidence (phase-jump rate, user-pain rate, or
  forge-attempt observation — see §13.2). v2 design constraint locked:
  any future approval mechanism uses **deterministic surface only**
  (numeric/markup/slash-command channel — never keyword classification
  per brief Hard Anti-Pattern).
- **Phase enforcement at validator level** (e.g. blocking
  implementation `apply_patch` before `plan.md` reaches `status:
  completed`). Validator predicate v1 narrowed per §6.3 to
  cycle-scope-only. Phase enforcement is **soft policy in v1**
  (AGENTS.md + skill prose, same pattern as Claude port). Returns to
  hard policy in v2 alongside the approval-gate redesign.
- **Hard-block on critical incidents.** v2 candidate per ADR-7 D5;
  v1 is warn-only.
- **PoC-driven outcome harness as a runtime feature.** Outcome
  harness is a measurement scaffold (separate from Sage runtime); it
  produces the data that triggers the above v2 candidates.

---

## 15. Pre-cutover verification checklist

Before declaring v1 complete (the final milestone exit criterion),
all the following must pass. Pasted output / file pointers required —
no self-reports.

### 15.1 — Empirical PoCs

- [ ] PoC C2 — PostToolUse fires after `apply_patch`, payload
  contains required fields.
- [ ] PoC C3 — Hook timing: no race with agent reading patched file.
- [ ] All §12 anchored claims re-verified against installed Codex
  version (manual smoke test).

### 15.2 — Generator pipeline

- [ ] `bin/sage init --platform codex <empty-target>` produces all
  artifacts per §4 stages 3-9.
- [ ] `bin/sage update --platform codex <existing-target>`
  regenerates managed blocks idempotently (run twice, second time
  produces no diff).
- [ ] Generated `AGENTS.md` is non-empty, includes constitution.
- [ ] Generated `.codex/config.toml` parses, contains all required
  blocks.
- [ ] Generated `.codex/hooks.json` parses, **4 events** registered
  in v1: `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`. **No
  `UserPromptSubmit` entry** (§6.2 deferred). v2 adds the 5th event
  back when approval gate returns.
- [ ] All **4 hook scripts** in `.codex/hooks/` are executable and
  non-empty: `session-init.sh`, `pre-tool-validate.sh`,
  `post-tool-check.sh`, `turn-audit.sh`. **No `ups-approval.sh`** in
  v1.
- [ ] **No `.githooks/pre-commit` wiring assertion in v1** — Stage 8
  deferred per §2 "v1 layer scope". v2 reactivation: re-add the
  `git config core.hooksPath = .githooks` check.
- [ ] **(closes B3)** Generated `AGENTS.md` constitution section
  reflects active preset — diff between `--preset base` and
  `--preset enterprise` runs of the generator on the same target
  must be non-empty in the constitution block (preset overlay
  effective).
- [ ] **(closes B3)** With `<target>/.sage/constitution.md`
  containing custom rules + `extends: enterprise`, the generated
  `AGENTS.md` constitution merge contains both the enterprise
  preset rules AND the user-overlay rules (user wins on conflict).
- [ ] **(closes B2)** All `core/gates/scripts/*.sh` files for the
  active preset are copied to `<target>/.sage/gates/scripts/`
  with mode 0755 after `bin/sage init --platform codex`. Empty
  preset emits info message and skips copy without error.
- [ ] **(closes B2)** `bin/sage update --platform codex` re-copies
  modified `<target>/.sage/gates/scripts/<name>.sh` files,
  backing up user edits as `<name>.user-edit-backup-<iso-ts>` first.
- [ ] **(closes B1)** When `<target>/.codex/config.toml` has no
  `[[mcp_servers]]` block, generated `AGENTS.md` Rule 1A renders
  the v1 filesystem-fallback variant (substring `"v1 filesystem
  variant"` present); when an MCP block is present (e.g. user
  hand-added one in v1), the standard `sage_memory_search` Rule 1A
  is rendered.

### 15.3 — Hook scripts (per §6)

- [ ] `session-init.sh` smoke test: print banner, no crash.
- [ ] No `ups-approval.sh` shipped (§6.2 deferred). Generator must
  NOT emit a `UserPromptSubmit` block in `.codex/hooks.json`.
- [ ] `pre-tool-validate.sh` smoke tests (bash-native predicate, §6.3):
  - No active cycle → exit 2, stderr message present.
  - Active cycle, path in scope → exit 0, append to
    `.sage/.session-mutations.log`.
  - Active cycle, path out of scope → exit 2, stderr lists
    out-of-scope paths.
  - `jq` or `yq` missing on PATH → exit 2 with install hint
    (defense-in-depth — pre-flight in `bin/sage init` should have
    caught this; hook still fails closed if user dropped a binary).
- [ ] `post-tool-check.sh` smoke tests:
  - Diff matches → no incident.
  - Diff mismatch → `claim_no_op` incident logged.
  - Broken frontmatter file → `broken_frontmatter` incident logged.
- [ ] `turn-audit.sh` smoke tests:
  - Normal turn → audit runs (session-mutations vs claimed paths +
    `phase_jump_observed` probe).
  - Skipped checks (orphan-approval, approval-coupling, dead-MCP)
    verifiably do NOT fire (no `.approval-pending` file → no input;
    no MCP → no validator process to detect).

### 15.4 — MCP server — N/A in v1 (§8 deferred entirely)

**No MCP server ships in v1** (decision 2026-04-30, third cut). All
checklist items below replace prior MCP-assuming criteria:

- [ ] `.codex/config.toml` contains NO `[[mcp_servers]]` block (only a
  comment placeholder for v2 reactivation, per §4 Stage 4).
- [ ] `.codex/hooks.json` contains NO `UserPromptSubmit` entry (§6.2
  deferred) and NO MCP-tool dispatch in any hook (predicate is inline
  bash in `pre-tool-validate.sh`).
- [ ] `pre-tool-validate.sh` parity tests (replaces `sage_validate_mutation`
  MCP tool tests):
  - No active cycle → deny.
  - Active cycle exists, patch path within `scope:` glob → allow.
  - Active cycle exists, patch path outside `scope:` glob → deny
    with explicit list of out-of-scope paths.
  - Phase value in manifest is irrelevant (predicate is cycle-scope-only
    per §6.3 v1 narrowing).
- [ ] `post-tool-check.sh` parity tests (replaces `sage_check_post_mutation`):
  - Check A (diff-claim via `git diff --name-only HEAD`) on synthetic
    cases — claim-no-op + unclaimed-change incidents fire correctly.
  - Check C (frontmatter via `yq eval`) on synthetic broken YAML —
    `broken_frontmatter` incident logged.
  - Check B (symbol existence) absent — confirmed not implemented in v1.
- [ ] `bin/sage status` (bash, no MCP) reads `.sage/work/*/spec.md|
  plan.md|manifest.md` frontmatter and emits the JSON shape that ADR-9
  originally required from `sage_status`.
- [ ] `bin/sage init --platform codex` pre-flight check fails fast on
  missing `jq` or `yq` with install hints (§7.1).
- [ ] No `sage-mcp` package install attempted; no Python runtime
  required for v1 hooks.
- [ ] No stale references to deferred MCP tools (`sage_validate_mutation`,
  `sage_record_approval`, `sage_status`, `sage_audit_turn`,
  `sage_check_post_mutation`) anywhere in generated artifacts. (grep
  the generated `.codex/` and `AGENTS.md` for these strings — should
  return nothing.)

### 15.5 — `sage doctor`

- [ ] All E1-E4, M1-M4, S1-S4, CV1 checks pass on a freshly-init'd
  project.
- [ ] Each check, when intentionally broken, produces the documented
  failure message.

### 15.6 — End-to-end smoke

- [ ] Brand-new project: `bin/sage init --platform codex` → open in
  Codex → first user prompt → agent responds → `apply_patch` to a
  project file is **blocked** by `pre-tool-validate.sh` (no active
  cycle, exit 2 with stderr message) → user runs `/sage:build` →
  agent writes `spec.md` (now allowed: cycle exists + path in scope)
  → agent presents `[A]/[R]` → user types `[A]` → **agent reads user
  reply and manually flips `spec.md` frontmatter to `status:
  completed`** (no UPS hook in v1; agent is on honor system per §6.2)
  → agent writes `plan.md` → same manual `[A]` flow → implementation
  → Stop hook `turn-audit.sh` fires each turn → `phase_jump_observed`
  probe writes informational entries if frontmatter flips happen
  without paired `[A]` in transcript window → no `bypass_mutation`
  incidents → final commit.
- [ ] Phase-jump detection smoke (replaces multi-language smoke):
  manually flip `spec.md` `status: in-progress → completed` in same
  turn where user did NOT type approval → confirm `turn-audit.sh`
  writes `phase_jump_observed` entry to `.sage/.mcp-incidents.log` →
  confirm `sage doctor` surfaces it on next run. This validates the
  v1 measurement layer that v2 promotion triggers depend on.
- **Multi-language UPS smoke removed:** UPS hook deferred per §6.2;
  no token-issuance mechanism to test. Multi-language routing (Sage
  Rule 0) is tested in Sage core skill prose, not Codex port.
- [ ] **Constitution merge smoke (closes B3):**
  `bin/sage init --platform codex --preset enterprise` on target X +
  user-authored `<target>/.sage/constitution.md` with `extends: enterprise`
  and one extra rule → generated `AGENTS.md` includes: (a) base
  constitution, (b) enterprise preset overlay, (c) user-authored
  extra rule. Diff against `--preset base` run on target Y confirms
  preset overlay is effective (non-empty diff in constitution block).
- [ ] **MCP-fallback variant smoke (closes B1):** fresh
  `bin/sage init --platform codex` with no MCP server configured →
  generated `AGENTS.md` Rule 1A renders the `"v1 filesystem
  variant"` text; first Standard+ workflow turn does NOT attempt
  to call `sage_memory_search` (agent reads `.sage-memory/` instead
  if present, otherwise proceeds with no memory recall — no hard
  error, no constitution violation logged).
- [ ] **Gates scripts presence smoke (closes B2):** post-init,
  `<target>/.sage/gates/scripts/` contains all `*.sh` files from
  `$SAGE_FRAMEWORK/core/gates/scripts/` with mode 0755; manually
  invoking one of the gate scripts (e.g. `bash
  .sage/gates/scripts/test-before-code.sh --help`) succeeds.

### 15.7 — Documentation

- [ ] `runtime/platforms/codex/README.md` reflects new architecture.
- [ ] `docs/ecosystem/codex-port-baseline.md` is annotated with a
  pointer to this spec ("rewritten in cycle 20260429-codex-port-
  rewrite").
- [ ] `manifest.md` of this cycle has `status: completed`.

---

## 16. Sign-off requirements

This spec is approved when:

1. User has read sections 1-3 (overview, glossary, starting point)
   and §14 (out of scope) and confirms scope.
2. User accepts §1 glossary and §10 mapping table as final
   nomenclature.
3. User accepts §13.1 risk register as understood, with explicit
   acknowledgment of v1 accepted residual risks: **R-5** (`tier:`
   self-promotion is soft-only in v1; baseline measurement only),
   **R-6** (L5 git-layer backstop deferred; bypass via direct git
   commit possible), **R-9** (approval gate deferred; agent can flip
   `status: completed` frontmatter without user signoff;
   detection-only via `phase_jump_observed` probe). R-1, R-3, R-4 are
   **N/A in v1** (their MCP / UPS preconditions don't exist) and
   return to active list when v2 reactivates the corresponding layers.
4. User accepts the **four compounded v1 cuts made on 2026-04-30** as
   a conscious scope choice, NOT as oversights:
   - **Cut A — UPS approval gate deferred** (§6.2): no
     `UserPromptSubmit` hook, no `.approval-pending` token, no
     keyword/markup/numeric token detection. Phase enforcement is
     soft policy in AGENTS.md + skill prose only.
   - **Cut B — MCP server deferred entirely** (§8): no Python server,
     no `[[mcp_servers]]` block, no `sage-mcp` install. All v1 logic
     lives in bash hooks (~40-line predicate inline in
     `pre-tool-validate.sh`).
   - **Cut C — L5 client-side git hooks deferred** (§2): no
     `.githooks/pre-commit` wiring by Codex generator. Server-side L5
     also out of scope (separate decision).
   - **Cut D — Hard tier-1 bypass deferred** (§10): `tier:` is soft
     policy in v1; predicate ignores it.

   User understands that **v2 promotion triggers in §13.2 are the
   only sanctioned path** to reactivate any of these. Reactivation
   requires outcome-harness data (not vibes), a new ADR per
   reactivation, and explicit user `[A]` on the v2 plan.
5. User accepts the **three Claude-parity blockers closed on
   2026-04-30** (per confrontation review of prior 6-axis cycle)
   as part of v1 scope, NOT deferred:
   - **B1 — sage-memory MCP contradiction** (§4 Stage 3 v1
     Constitution variant): generator detects absence of
     `[[mcp_servers]]` in `config.toml` and renders Rule 1A as a
     filesystem-fallback variant pointing at `.sage-memory/`.
     First Standard+ workflow turn no longer hard-errors.
   - **B2 — `core/gates/scripts/` copy** (§4 Stage 9a): generator
     copies preset gates scripts to `<target>/.sage/gates/scripts/`
     mode 0755 — Codex projects no longer silently lose engineering-
     principle backstops.
   - **B3 — Constitution preset merge** (§4 Stage 3 item 2 + Stage 9
     v1 addendum): three-layer merge (base → preset overlay →
     `<target>/.sage/constitution.md` user overlay); each preset
     now produces a differentiated constitution.

After approval (`[A]` on this spec), `plan.md` is the next artifact:
breakdown into milestones with exit criteria. The user has stated
preference for "v1 in one go" — plan.md will reflect this with a
small number of milestones (likely 1-2, plus a final cutover
milestone) rather than 6 fine-grained ones.

## Status: completed
Approved by user `alexostl` on 2026-04-30 at design checkpoint.
Sign-off covered all 5 points from §16: scope, nomenclature,
residual risks, 4 cuts (A/B/C/D), and 3 Claude-parity blockers
(B1/B2/B3). ADR amendments minimum applied (ADR-1 amended,
ADR-2 + ADR-3 deferred-to-v2, ADR-9 created).

Next artifact: `plan.md` — milestone breakdown with exit
criteria. Per user preference ("v1 in one go"), expect 1-2
implementation milestones plus a final cutover milestone, not
6 fine-grained ones. plan.md to be authored by Sage Build
in a separate session/thread.
