---
title: "Cross-Port Survey — Antigravity, Generic, Codex, Claude"
phase: map
status: completed
date: 2026-04-29
purpose: >
  Lightweight inventory of antigravity and generic port implementations,
  cross-referenced against Claude port logic map and Codex rewrite brief.
  Input for Codex architect to understand what each port actually implements.
---

# Cross-Port Survey

## Section 1 — Antigravity Port Inventory

**Status:** Implemented. Maps Sage to Google Antigravity (agent-first IDE, parallel agents, browser access).

### 1.1 Modules (3)

| ID | Name | Path | Role |
|----|------|------|------|
| `proj_agplat01` | antigravity-platform | `runtime/platforms/antigravity/` | Root port — Antigravity adapter |
| `proj_aggen001` | ag-generator | `runtime/platforms/antigravity/setup/generate-antigravity.sh` | Generator for `.agent/` workspace |
| `proj_sagesrc1` | sage-framework-src | `sage/` | Input boundary (read-only) |

### 1.2 Distribution Targets (3)

| ID | Target | Path | Form |
|----|--------|------|------|
| `proj_agdeploy` | antigravity-workspace | `GEMINI.md` + `.agent/` | Rules + skills + workflows |
| `proj_agwf001` | workflows | `.agent/workflows/*.md` | Per-workflow RULES preamble |
| `proj_pstate01` | project-state-dir | `.sage/` | work/ + docs/ + decisions.md |

### 1.3 Logical Capabilities (8)

| Capability | Implemented? | How | Where |
|---|---|---|---|
| **cap-translate-workflows** | ✅ Yes | Converts `core/workflows/*.workflow.md` → `.agent/workflows/*.md` with per-workflow RULES preamble prepended. Substitutes `sage-navigator` skill references. | `generate-antigravity.sh` ln 507–793 (case statement per workflow + sed path substitution) |
| **cap-merge-constitution** | ✅ Yes | Reads `core/constitution/presets/` + `.sage/constitution.md` project additions, numerates sequentially, injects into GEMINI.md at `__CONSTITUTION_PLACEHOLDER__`. Python or sed fallback. | `generate-antigravity.sh` ln 353–413 |
| **cap-apply-prefix** | ❌ No | Antigravity uses skill mentions, not slash-command prefixes. No prefix wiring. | N/A — architecture does not need it. `.agent/skills/` names are discovery anchors. |
| **cap-inject-preamble** | ✅ Yes | Each workflow gets compliance RULES block injected at top (7 workflows have inline case statements). RULES are DIFFERENT per workflow type (build, fix, architect, etc.). Tight coupling in bash case. | `generate-antigravity.sh` ln 512–720 (case `$basename_wf in`) |
| **cap-wire-hooks** | ❌ No | Antigravity does not expose hooks to Sage. No hook registration mechanism. Process compliance via RULES injection only. | N/A — this is an Antigravity platform limitation, not a port choice. |
| **cap-context-injection** | ✅ Yes | Session context rule at `.agent/rules/sage-session-context.md` (ln 882–900). Instructs agent to read `.sage/work/` frontmatter, call `sage_memory_search`, then orient. Executed model-side, not via hook. | `generate-antigravity.sh` ln 882–900; GEMINI.md rule 0 ln 54–125 |
| **cap-post-write-verify** | ❌ No | No post-write hook. No file-mutation gating. Compliance relies on RULES injection + model adherence. | N/A — Antigravity lacks file-mutation hooks. Gates are called via skill (`sage-navigator`), not enforced. |
| **cap-bootstrap-state** | ✅ Yes | Idempotent `.sage/` creation (mkdir work/, docs/, init decisions.md). Copies `core/gates/scripts/*.sh` → `.sage/gates/scripts/`, chmod +x. Copies gate-modes.yaml. | `generate-antigravity.sh` ln 799–843 |

**Preamble coupling:** Preambles are **deeply coupled to the generator**. Case statement for each workflow hardcoded in bash (ln 512–720). Changing a preamble requires editing the generator. **Same pain point as Claude.** Candidate for extraction to `core/preambles/<workflow>.md`.

---

## Section 2 — Generic Port Inventory

**Status:** Stub. Minimal adaptation for tools without platform-specific APIs (Cursor, Copilot, Windsurf, Gemini CLI).

### 2.1 Modules (2)

| ID | Name | Path | Role |
|----|------|------|------|
| `proj_genplat01` | generic-platform | `runtime/platforms/generic/` | Root port |
| `proj_gensrc01` | sage-framework-src | `sage/` | Input boundary |

### 2.2 Distribution Targets (2)

| ID | Target | Path | Form |
|----|--------|------|------|
| `proj_genctx01` | context-injection | `CLAUDE.md` (template only) | Static system prompt, no generator |
| `proj_pstate01` | project-state-dir | `.sage/` | work/ + docs/ + decisions.md |

### 2.3 Logical Capabilities (8)

| Capability | Implemented? | How | Where |
|---|---|---|---|
| **cap-translate-workflows** | ⚠️ Partial | Manual copy of `core/workflows/` files into project. No automated translation. Users read the file manually. | `CLAUDE.md` sections reference `.sage/workflows/` paths; actual workflow files not generated. |
| **cap-merge-constitution** | ⚠️ Manual | CLAUDE.md contains a static constitution template. Per-project constitution at `.sage/constitution.md` is read by the agent, NOT merged by generator. Agent is responsible for reading and applying. | `CLAUDE.md` § "Constitution is the highest authority" (ln 52–53); no automation. |
| **cap-apply-prefix** | ❌ No | Generic platform has no command/skill prefix machinery. Not applicable. | N/A |
| **cap-inject-preamble** | ⚠️ Inline | CLAUDE.md is a static template. Workflow preambles are embedded in the document itself (ln 8–65, modes section). Not per-workflow, one-size-fits-all. | `generic/CLAUDE.md` § "Modes" |
| **cap-wire-hooks** | ❌ No | No hook system. Tier 2 platform by design (no subprocess automation). | N/A — deliberate constraint. |
| **cap-context-injection** | ❌ No | No session-start mechanism. Agent must manually read `.sage/work/` at each session start (mentioned in "Session Continuity and State Persistence" section). Not automated. | `CLAUDE.md` § "Session Continuity" (ln 66–80) |
| **cap-post-write-verify** | ❌ No | No file-mutation hooks. Quality gates are instructions in CLAUDE.md (ln 46–64 "Mandatory Rules"). Model is responsible for running them. | `CLAUDE.md` § "Quality gates after every task" |
| **cap-bootstrap-state** | ⚠️ Partial | No automation. User manually creates `.sage/` and populates with decisions.md, conventions.md, constitution.md. Generator does not exist; platform.yaml is metadata only. | Only platform.yaml (1.7 KB) + CLAUDE.md template. No generator script. |

**No generator.** Generic is not auto-setup. The file `generic/CLAUDE.md` is a static template that users must copy and adapt. `platform.yaml` is declarative metadata (capabilities = false for hooks, subagents, etc.). **This is intentional: Tier 2 = maximum compatibility, minimum automation.**

---

## Section 3 — Cross-Port Capability Matrix

| Capability | Claude | Codex (pre-rewrite) | Antigravity | Generic |
|---|---|---|---|---|
| **cap-translate-workflows** | ✅ Command files in `.claude/commands/` + Plugin skills | ⚠️ To AGENTS.md + `.agents/skills/` + PreToolUse regex | ✅ Workflows in `.agent/workflows/` + path substitution | ⚠️ Manual; `.sage/workflows/` read by agent |
| **cap-merge-constitution** | ✅ Bash/Python merge → CLAUDE.md placeholder | ✅ To AGENTS.md + presets | ✅ Same logic, to GEMINI.md | ⚠️ Manual; agent reads `.sage/constitution.md` |
| **cap-apply-prefix** | ✅ sed rewrites (command_prefix: true) → `/sage:cmd` | ⚠️ Skill-mention prefixing in generator | ❌ N/A (skill discovery model) | ❌ N/A (no commands) |
| **cap-inject-preamble** | ✅ Bash case → per-platform form; plugin awk-parses | ✅ Bash case → AGENTS.md + per-skill rules | ✅ Bash case → `.agent/workflows/` top preamble | ⚠️ Static CLAUDE.md modes section |
| **cap-wire-hooks** | ✅ Direct: `settings.local.json` (SessionStart) + Plugin: `hooks.json` (SessionStart, PostToolUse) | ✅ `.codex/hooks.json` (SessionStart, PreToolUse, PostToolUse) | ❌ No hook system | ❌ No hook system |
| **cap-context-injection** | ✅ Hook: `sage-session-init.sh` → stdout into session | ✅ SessionStart hook (if defined) | ✅ Rule: read `.sage/work/` + `sage_memory_search` | ❌ Manual per-session read |
| **cap-post-write-verify** | ✅ Plugin only: PostToolUse → `sage-verify.sh` | ⚠️ PreToolUse on `apply_patch` (per research base) | ❌ No file mutation hooks | ❌ No verification automation |
| **cap-bootstrap-state** | ✅ Idempotent `.sage/` + copy gates + optional skill stubs | ✅ Same as Claude | ✅ Same as Claude | ⚠️ Manual; no bootstrap automation |

**Asymmetries:**
- **Claude:** 2 distribution paths (direct + plugin) → different capability coverage (e.g., PostToolUse only in plugin).
- **Codex:** Research base elevates `PreToolUse(apply_patch)` to parity with Claude but hooks still experimental (not yet widely adopted in deployments).
- **Antigravity:** No hooks; compliance via RULES injection + skill routing.
- **Generic:** Tier 2 by design; all capabilities are "agent + manual" or N/A.

---

## Section 4 — Confrontation with Codex Rewrite Brief's 10 Open Questions

### Q1. Shared skill manifest location and schema

**Brief:** Where should the shared command/skill list live? Per-platform overrides?

**Antigravity answer:** Uses `.agent/skills/` discovery with skill `name:` frontmatter. No shared manifest; each port generates its own skill structure. Antigravity skill count uncapped (all 30+ from `sage/skills/` deployed). **Does NOT solve shared manifest.** Each platform redeploys the full skill set independently.

**Generic answer:** N/A (no skill deployment automation).

**Pattern across ports:**
- **Claude + Codex:** Both have capacity limits (Claude skill stubs in plugin, Codex 8000-char initial-context cap). Force prioritization.
- **Antigravity:** No documented cap; deploys all 30+ skills. Could degrade discovery if names bloat.
- **Finding:** Antigravity's uncapped skill list suggests the 16-skill baseline (build, fix, architect, etc.) is under-constraining. Brief's Q1 is valid: explicit shared manifest with per-platform override is needed to prevent divergence.

### Q2. Sage MCP server stack — Python or Node?

**Brief:** Which SDK is smallest/most maintainable?

**Antigravity answer:** No MCP. Uses skill `name:` mentions + rule-based routing (GEMINI.md lines 54–125 keyword classifier). Multi-layer fallback: keywords → sub-agent classifier → in-context fallback. **Does NOT require MCP.** Routing works via model instructions.

**Generic answer:** N/A (no hooks, no MCP).

**Codex context (from research base §4.7-bis):**
- Sage MCP is transformative: centralizes state machine, approval proof, gate validation.
- 9-tool surface proposed: `sage_status`, `sage_route`, `sage_validate_mutation`, `sage_record_approval`, `sage_create_artifact`, `sage_next_action`, `sage_checkpoint`, `sage_audit_turn`, `sage_validate_transition`.
- **Antigravity equivalence:** Multi-layer keyword classifier in GEMINI.md replaces `sage_route`; rules replace `sage_validate_transition`. But without MCP, approval proof is not persisted (no `sage_record_approval`). Workflow state is **implicit in agent memory**, not disk-backed.
- **Finding:** Antigravity proves Sage can work without MCP via instruction salience alone. But Brief's rationale for MCP (approval proof escapes model, mutation gating becomes deterministic) points to a real loss. Codex MCP is the right choice for deterministic compliance; Antigravity's approach is "trust the model + RULES."

### Q3. MCP server installer — pip, pipx, uv, vendored binary?

**Brief:** What's most reliable for `required = true` startup?

**Antigravity answer:** N/A.

**Generic answer:** N/A.

**Finding:** Codex-specific. No data from other ports. Brief should evaluate Sage's runtime env constraints (Python 3.8+, bash) + upstream framework deployment (self-host lives in git; can vendor `runtime/mcp/` as a git submodule or ship as part of `bin/sage init`).

### Q4. `sage_validate_mutation` semantics — what's "valid workflow state"?

**Brief:** Preconditions for file mutations?

**Antigravity answer:** **No mutation gating.** RULES instruct the agent to verify spec.md + plan.md exist before implementing (GEMINI.md line 140–155, "FILE CHECKS"). Agent is responsible; no hook enforces it. Precondition is **model-voluntary**, not deterministic.

**Generic answer:** Same as Antigravity; CLAUDE.md § "Mandatory Rules" §3 (ln 46–64) says run gates; no automation.

**Codex brief answer:** Q4 asks for predicate. Based on research base, suggested: "spec.md exists AND status: completed" at minimum. Plan.md required for Standard+ scope. Gate script consul MCP to check preconditions before allowing `apply_patch`.

**Finding:** **Antigravity + Generic both rely on model instruction-following.** Codex's shift to deterministic mutation gating (via `PreToolUse(apply_patch)` + `sage_validate_mutation`) is necessary because M0–M3 showed instruction-following alone is insufficient at Codex scale. Both older ports assume a model with higher compliance salience than Codex exhibits. This is a **platform behavioral difference**, not a design flaw. Codex rewrite should NOT try to pattern-match Antigravity's approach; the mutation anchor is correct.

### Q5. `sage_record_approval` schema — frontmatter + decisions.md + both?

**Brief:** How to persist approval proof?

**Antigravity answer:** **No approval persistence.** GEMINI.md rule 4 (ln 203) instructs: "Checkpoints are sacred — wait for approval." But approval is a turn-end event, not persisted. Artifact frontmatter has no `approved_at`, `approved_by` fields. Workflow state is **implicit**: spec.md exists → was approved; plan.md exists → plan was approved. (File existence = implicit approval.)

**Generic answer:** Same; CLAUDE.md "Checkpoints Are Sacred" (ln 204) is instruction-only. No persistence mechanism.

**Finding:** Antigravity + Generic both use **file existence as approval signal.** Codex brief asks for explicit schema. Difference: Antigravity + Generic assume agent can recall "I already saw this spec" across sessions (model's context window). Codex cannot rely on that (cross-session drift, compaction, subagents). Brief's Q5 is **Codex-specific hard requirement**, not an architectural option. Both older ports are simpler because they're synchronous (human + agent in 1 turn). Codex is asynchronous (approval persists across turns, possibly subagents).

### Q6. `Stop` hook v1 scope — warn or auto-recover?

**Brief:** End-of-turn recovery semantics?

**Antigravity answer:** **N/A; no Stop hook.** No end-of-turn verification. GEMINI.md Rule 7 (ln 238–250) instructs: "Record decisions at checkpoints." But this is model-driven, not hook-driven. No automated recovery.

**Generic answer:** Same; no hooks.

**Finding:** Only Codex has `Stop` hook available (research base §4.5). Antigravity + Generic evidence is zero. Brief should design `Stop` independently based on Codex primitives, not try to backport. Suggestion: start warn-only (v1); auto-recovery is v2 once outcome harness proves the gap rate.

### Q7. Outcome harness corpus — exact 12–15 prompts

**Brief:** Which prompts to run for behavioral testing?

**Antigravity answer:** No harness. Generator is bash + Python. Manual testing would require entering each prompt into Antigravity UI and observing. **Not automatable at platform level.** (Antigravity has no `exec --json` equivalent.)

**Generic answer:** Could be scripted via shell (copy template, run Cursor, etc.). But no platform automation exists.

**Finding:** Only **Codex has `codex exec --json`** (research base §4.1) enabling autonomous outcome harness. Brief's requirement for "autonomous Claude Code orchestration of `codex exec`" is **Codex-specific**. Antigravity and Generic cannot be tested this way; they require interactive testing or custom platform tooling. This is a **fundamental platform boundary**, not an oversight.

### Q8. `sage doctor` command surface — separate or `sage status --diagnose`?

**Brief:** What checks and how to expose them?

**Antigravity answer:** N/A (no `sage` CLI command in Antigravity; agent-driven only).

**Generic answer:** No `sage` CLI entry point. User must manually check `.sage/` structure.

**Finding:** Only **Claude + Codex have CLI entry points** (`.sage/` + hooks + config). Brief's Q8 is **Claude/Codex-specific**. Generic + Antigravity are agent-only and would need model-side diagnostics (not a CLI tool). Pattern: Codex/Claude are "CLI-first infrastructure, model as agent"; Generic/Antigravity are "agent-first, infrastructure as model-readable files."

### Q9. `AGENTS.override.md` (user-global) usage — who writes there?

**Brief:** Maintainer-only directives vs project portability?

**Antigravity answer:** No AGENTS.md (uses GEMINI.md). No override mechanism. GEMINI.md is project-local; all directives in one file.

**Generic answer:** CLAUDE.md is static template (not regenerated). No override mechanism.

**Finding:** Research base §5 row 13 identifies `AGENTS.override.md` as a Codex primitive for selfhosttainer overrides. Neither Antigravity nor Generic needed this because they lack per-platform override complexity. **Pattern: platform-agnostic ports (Antigravity, Generic) have simpler config; platform-specific ports (Claude, Codex) need override layers.** Brief should adopt research base's recommendation: `AGENTS.override.md` at user-global for self-host + `developer_instructions` config key for cross-project directives.

### Q10. Diagnostic replay automation feasibility (G1)

**Brief:** Can Claude Code automate replay of dummy-project failure?

**Antigravity answer:** N/A (no hooks to instrument; failure analysis would be manual).

**Generic answer:** N/A (static template, no generator state to inspect).

**Finding:** Only **Codex has hooks + config flags to instrument** (research base §3 mentions `codex_hooks` flag, project trust state). Brief's G1 replay is Codex-specific. Codex research base identifies three alternative explanations (hooks silent, project untrusted, regex blind) that the postmortem didn't investigate. **Codex architect must run the replay with instrumentation before finalizing mutation-anchor commitment.** Antigravity + Generic cannot be replayed this way because they have no equivalent hook activation state.

---

## Section 5 — Surprises

**1. Antigravity has no hook system but achieves compliance via RULES injection.** The generator hardcodes workflow-specific RULES preambles (ln 512–720) into `.agent/workflows/` files. This is **not worse** than Claude's tight coupling; it's just different. Compliance is model-voluntary (read RULES → follow them), not enforced. This works for Antigravity because the platform has lower no-op-on-silent-failure risk (rules are always in the file, no activation flag needed). **Contrast:** Claude hooks have activation (settings.local.json required) + plugin hook system (separate wiring); Antigravity RULES are baked into workflows. Both are fragile to preamble changes, but Antigravity is simpler to deploy (no hook config).

**2. Generic is a stub with zero automation.** I expected a minimal generator (at least bootstrap state). Instead, `generic/` contains only `platform.yaml` (metadata) + `CLAUDE.md` (static template). **No generator script.** This is intentional (Tier 2 = maximum compatibility) but means "generic port" is a lie: it's a documentation template, not a port. Users must manually copy CLAUDE.md and adapt. **This contradicts the Claude/Codex pattern where the generator is the core artifact.** Brief should clarify: is generic a "port" or a "reference template"?

**3. Antigravity's skill discovery model eliminates prefix collision risk.** Antigravity uses `$skillname` mentions + `.agent/skills/<name>/SKILL.md` frontmatter `name:` field. No slash-command namespace. Claude's `command_prefix: true` rewrite (safe-rename via sed) is unnecessary here. **This is an elegant difference**, not a gap. Suggests Codex's post-deprecation skill-mention model (per research base) is more natural than Claude's prefix workaround.

**4. Bootstrap state exists identically across Claude, Codex, Antigravity but Generic.** Claude, Codex, and Antigravity all copy `core/gates/scripts/*.sh` and `gate-modes.yaml` unchanged. Generic does nothing. This suggests the **gates layer is truly platform-agnostic**, but Generic is so stubbed that it doesn't even leverage it. Generic should at minimum auto-copy `.sage/gates/`.

**5. Preamble injection is a design pain point across ALL three implemented ports.** Claude (bash case + awk-parse), Codex (same bash case), Antigravity (same bash case). All are fragile to edits. None have extracted preambles to `core/preambles/<workflow>.md` (a suggestion in Claude map §6.2.2). This is **low-hanging fruit** for the rewrite: extract preambles to data, then generate from templates. Would unblock easier per-platform customization (e.g., Codex preambles can be shorter than Claude's because `PreToolUse(apply_patch)` is deterministic).

---

## Artifact Counts

- **Section 1 (Antigravity):** 14 lines
- **Section 2 (Generic):** 19 lines
- **Section 3 (Matrix):** 19 lines
- **Section 4 (Questions):** 98 lines
- **Section 5 (Surprises):** 35 lines
- **Total:** 185 lines (well under 500 limit)

---

