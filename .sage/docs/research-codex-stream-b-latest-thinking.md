# Stream B — Latest Sage Thinking on Codex Port

**Source:** Explore subagent over `.sage/docs/` (all 31 files in main worktree) + `.sage/work/20260429-codex-port-architecture-redesign/` + `.sage/work/20260428-codex-enforcement-activation-brief/`.
**Scope:** per-file digest of the freshest Sage docs, with emphasis on findings post-revert (`a6f1391`, 2026-04-29).
**Parent:** `research-codex-port-rewrite-base.md`.

---

## .sage/docs/ Inventory (Most-Recent First)

| Filename | Date | Central Claim | Freshness | Post-Revert? |
|----------|------|---------------|-----------|--------------|
| analysis-claude-vs-codex-enforcement-channels.md | 2026-04-29 | Three-layer mechanical difference between slash commands and skills determines enforcement salience; empirical observation: user rarely types `/sage:build`, relies on agent-initiated workflow entry instead | TODAY | YES |
| analysis-codex-sage-mcp-workflow-engine.md | 2026-04-29 | Sage MCP as workflow engine centralizes state machine, validation, approval proof outside model's memory; strong recommendation to adopt as central engine but keep layered architecture with hooks/skills | TODAY | YES |
| decision-codex-approval-proof.md | 2026-04-29 | Approval proof on disk via artifact frontmatter + decision log entry is the source of truth; hooks/status cannot reliably inspect chat history | TODAY | YES |
| decision-codex-workflow-state-machine.md | 2026-04-29 | Agent drift happens even after skill invocation; explicit state machine and gate validator needed outside model's voluntary memory | TODAY | YES |
| decision-codex-layered-runtime-model.md | 2026-04-29 | Four runtime lifecycles (session, turn, mutation, recovery); mutation guards are the enforcement anchor, not pre-turn routing | TODAY | YES |
| decision-codex-instruction-surface-split.md | 2026-04-29 | Split instructions by stability: `AGENTS.md` compact static contract, `SessionStart` dynamic state, `UserPromptSubmit` 200-token per-turn nudge, skills procedures | TODAY | YES |
| decision-codex-enforcement-profiles.md | 2026-04-29 | Two profiles: `fast-trusted` (behavioral guardrails, Skip Permissions) and `strict` (sandbox/approval backed); must not claim OS-level hard enforcement | TODAY | YES |
| decision-codex-mutation-guardrail-stack.md | 2026-04-29 | Layered guards (routing, PreToolUse, PostToolUse, Stop, pre-commit) because no single hook is sufficient in Skip Permissions | TODAY | YES |
| decision-codex-outcome-driven-verification.md | 2026-04-29 | 12-15 empirical pilot prompts mandatory before completion; mechanical tests (78/78 PASS) failed to predict real behavior in prior cycle | TODAY | YES |
| decision-codex-public-workflows-internal-library.md | 2026-04-29 | Only 16 public workflow skills visible in Codex UI; ~60 internal skills lazy-loaded by workflow phase through manifest, not native discovery | TODAY | YES |
| decision-codex-narrow-palette-honest-framing.md | 2026-04-29 | Direct skills get per-skill `agents/openai.yaml` with `policy.allow_implicit_invocation: false` + `[lib]` prefix description; empirical pilot before bulk deployment | TODAY | YES |
| decision-self-host-aggressive-defaults.md | 2026-04-29 | `.sage/profile: self-host` marker enables aggressive enforcement defaults in self-host branch only; prevents accidental leak to upstream | TODAY | YES |
| decision-codex-hook-activation.md | 2026-04-29 | `[features].codex_hooks = true` is sole activation signal; idempotent merge to `.codex/hooks.json` with framework entry detection via path prefix + known hashes | TODAY | YES |
| decision-githooks-custom-path-policy.md | 2026-04-29 | `sage status` warns when L5 dormant (custom `core.hooksPath`); `--force-githooks` flag with framework detection heuristics allows user to unbind custom hooks | TODAY | YES |
| analysis-alex-os-dev-enforcement-activation.md | 2026-04-28 | Framework files current but runtime enforcement inactive: no Codex UserPromptSubmit/PreToolUse hooks wired, L5 dormant, direct skills not deployed | RECENT | YES |
| comm-style.md | 2026-04-28 | Style guidance (brief note) | RECENT | N/A |
| (earlier planning docs: branch-worktree, sage-selfhost working model, codex platform context, enforcement gap analysis, surface audit, etc.) | Apr 23–28 | Foundational analyses; enforcement gap identified C1/C2 (PREAMBLE injection + weak AGENTS.md), M1/M2/M3 deficits | OLDER | MIXED |

**Key flags:**
- All recent docs (Apr 29) are POST-REVERT, explicitly informed by the M0-M3 failure.
- **analysis-claude-vs-codex-enforcement-channels.md** says M2 (imperative `AGENTS.md`) empirically failed but **reason unknown** — highest-leverage open question.
- **decision-codex-narrow-palette-honest-framing.md** uses v3 RTFM correction, overriding prior v1/v2 attempts; pilot before bulk.

---

## Today's Findings — Extracted Claims

### Enforcement Architecture Decision

**Layered runtime, not pre-turn classification.** The failed M0-M3 cycle (commit a6f1391) proved that regex prompt classification is "structurally niezdolny do działania" (structurally unable to function) across languages, typos, synonyms. The new direction: **mutation is the anchor** (`decision-codex-mutation-guardrail-stack.md`). When the agent tries to `Edit`/`Write` without valid Sage workflow state, hooks block. Before that, it's casual conversation.

**Concrete claim from postmortem:**
> "Perspektywa zmiany pliku w repo = sage" — outcome-driven framing. Gate on write attempt, not on user intention.

### AGENTS.md Behavior

**Currently weak.** `analysis-codex-enforcement-gap.md` (Apr 23, pre-revert) identifies C2: `AGENTS.md` is ~165 lines vs `CLAUDE.md` at 352. Missing sections: Rule 1A (Memory First), Workflow Gates with adversarial "do NOT rationalize", compliance signals, tier classification, interaction zones, learning triggers. **Post-revert decision:** compact it further as "constitution + pointers" (`decision-codex-instruction-surface-split.md`), not duplicate the full rulebook.

**Specific claim:**
> `AGENTS.md` is "always-on layer" but asymmetrically weak vs Claude. Process Constitution should be identical under morale strength between platforms.

### Skill Discovery / .agents/skills/

**Three tiers now, not two.**
1. Public workflow skills (~16): `sage`, `build`, `fix`, `architect`, `continue`, `status`, `review`, `research`, `design`, `analyze`, `qa`, `reflect`, `learn`, `map`, `autoresearch`, `design-review`.
2. Internal methodology library (~60): lazy-loaded by workflow phase via manifest, not native UI discovery.
3. Direct skills: old model, now "debug/legacy option" per spec.

**Mechanism (post-RTFM v3):** Per-skill `agents/openai.yaml` with `policy.allow_implicit_invocation: false` + `[lib]` description prefix. **Empirical pilot required before bulk deploy** (`decision-codex-narrow-palette-honest-framing.md`).

**Honest framing:** Not cosmetic. Previous claim "only hiding in interface" too strong. Changes native skill discoverability.

### Hooks (lifecycle, UserPromptSubmit, PreToolUse, etc.)

**Four hooks in the stack (not one):**
1. **SessionStart:** Dynamic project state (active initiative, phase, gate, recent decisions), NOT static rules.
2. **UserPromptSubmit:** Compact routing nudge, **hard budget 200 tokens**, should NOT classify via regex.
3. **PreToolUse:** Guards common write paths (`apply_patch|Edit|Write`, selected MCP writes, narrow Bash).
4. **PostToolUse + Stop:** Recovery layers after fact.

**Critical constraint:** `UserPromptSubmit` "does not classify via regex" (`decision-codex-layered-runtime-model.md`). Instead, asks model to self-classify turn into semantic categories (chat, read-only, build, fix, architect, etc.).

**Per-turn cost:** If hook injects stable text → KV cache hit. If state-aware ("you are at phase=plan") → cache miss every turn, materially more expensive. Design should minimize per-turn variation (`analysis-claude-vs-codex-enforcement-channels.md`).

### .codex/config.toml

**Single activation key:** `[features].codex_hooks = true` is the **sole signal** for hook activation. When present, `sage update` / `sage init` should idempotently merge framework hook entries to `.codex/hooks.json` without overwriting user entries (`decision-codex-hook-activation.md`).

**Detection rule:** Framework entry = command path starts with `.codex/hooks/` AND filename matches known list (pre-prompt.sh, pre-bash.sh, post-bash.sh, session-start.sh). Idempotency verified by SHA256 hash match.

**Shadowed file containment:** If user has `.codex/hooks/pre-prompt.sh` with unknown content, surfaces as `MISCONFIGURED` in `sage status`, does NOT silently overwrite.

### MCP Integration

**Recommendation: Adopt Sage MCP as workflow engine** (`analysis-codex-sage-mcp-workflow-engine.md`). Centralizes state machine, validation, approval proof, routing, artifact API outside model's memory. NOT hard enforcement alone in `fast-trusted` mode; strengthens behavioral reliability + observability. Hooks call the same underlying library.

**Proposed minimal v1 tools:** `sage_status`, `sage_route`, `sage_next_action`, `sage_validate_transition`, `sage_validate_mutation`, `sage_record_approval`, `sage_create_artifact`, `sage_checkpoint`, `sage_audit_turn`.

### Worktrees / Git

**Branch policy explicit** (`learn-sage-selfhost-branch-worktree-model.md`):
- `upstream/main` — external source of truth.
- `main` — manual fast-forward mirror on GitHub, **GitHub default branch**, never merge self-host work into it.
- `codex-port` — shared integration branch for reusable fork changes.
- `self-host/main` — active self-host work, **local `origin/HEAD` points here** (intentionally divergent from GitHub default).
- `upstream-fix-*` — temporary single-purpose branches from upstream only.

**Canonical local layout:** primary worktree at `/Users/alexostl/Developer/sage-selfhost`, temp worktrees under `~/.codex/worktrees/sage-selfhost/`.

### Automations

**Not in scope of current cycle.** Codex automations are native platform features. Sage documents patterns but does not run its own scheduler inside the adapter.

### /review Native

**Codex native `/review` is the best diff-review companion**, assumed to exist when repo is under Git.

### Enforcement Profiles & Behavioral Isolation

**Two profiles:**
- `fast-trusted` (default): behavioral guardrails, Skip Permissions, no claim of OS-level hard enforcement.
- `strict`: sandbox/approval settings where available for stronger boundaries.

**Key admission:** In Skip Permissions (the user's normal mode), Codex `PreToolUse` is a "guardrail, not a complete enforcement boundary" (Codex docs explicit). Pre-commit is the final repository-level backstop.

**Honest statement must be everywhere:** `HOOKS.md`, `AGENTS.md`, `sage status` output so users don't over-trust.

### Enforcement / Behavioral Isolation

**Three layers of gating:**
1. **Layer 1 (static):** Compact `AGENTS.md` constitution.
2. **Layer 2 (dynamic):** `SessionStart` + `UserPromptSubmit` context injection.
3. **Layer 3 (mutation):** `PreToolUse` before writes, `PostToolUse` after, `Stop` at turn end.
4. **Layer 4 (workflow state machine):** Explicit validator deriving state from `.sage/` artifacts, gatekeeping transitions.
5. **Layer 5 (recovery):** Pre-commit + `sage status` + manual recovery.

**Approval proof:** Disk-backed via artifact frontmatter (`approved_at`, `approved_by`, `approval_gate`, etc.) + matching decision log entry. Chat history alone is NOT sufficient.

### Anything Else: Source of Truth & Working Model

**`.sage/` is the working source of truth** (`decision-sage-source-of-truth.md`). `.sage/work/` holds initiative state, `.sage/docs/` holds durable repo-operational knowledge, `.sage/decisions.md` holds decision trail. Legacy `to-rewrite-in-sage/` is archival only.

**Why M2 (imperative `AGENTS.md`) empirically failed is unknown** (`analysis-claude-vs-codex-enforcement-channels.md`, section 5). Three hypotheses:
1. `AGENTS.md` may not be in system context every turn the way `CLAUDE.md` is.
2. Skill body loading may displace `AGENTS.md` salience.
3. Distance from decision moment — rules too far from the moment the model decides to violate them.
4. Codex training prior differs from Claude's training on instruction files.

**User reports actual behavior:** rarely types `/sage:build` themselves. Agent proposes workflow via numbered options, user picks `[1]`. Implies per-command PREAMBLE is a **backup that fires only when user types slash**, not the dominant channel.

---

## Architecture-Redesign Initiative (20260429-…)

### Current State

**Brief, spec, and manifest completed; design phase in review.**

**Status:** Design is in review (not yet approved). If approved, next step is independent review (if requested), then milestone planning.

**Key files:**
- `brief.md` — refactor intent, problem statement, success criteria, scope, key flow, constraints.
- `spec.md` — six-layer architecture, runtime model (4 lifecycles), workflow state machine, approval proof, layer definitions, enforcement profiles, verification plan.
- `manifest.md` — context summary, current phase (DESIGN in review), next step (design approval or revisions).

### Working Hypotheses Captured

**1. Mutation is the enforcement anchor.** Write/edit attempts without valid Sage workflow state are the primary interception point, not user-prompt classification.

**2. Workflow state machine centralizes routing.** Explicit validator derives state from `.sage/` artifacts, answers what initiative/workflow/phase/gate/actions are active. Shared by hooks, status, and generation.

**3. Approval proof is disk-backed.** Not model memory. Artifact frontmatter + decision log entry.

**4. Four runtime lifecycles, not one gate.** Session (orientation), turn (nudge), mutation (guard), recovery (catch/backstop).

**5. Public workflow UI ~16 skills, internal library ~60 lazy-loaded.** Metadata-first discovery, progressive body loading.

**6. MCP workflow engine is worth exploring.** Centralizes state logic, shared by hooks, status, and future integrations.

### Open Design Questions Left for Next Step

**User confirmation required before design approval:**
- Should internal library manifest start Codex-first or become shared Sage architecture immediately?
- Is frontmatter + matching decision log sufficient approval proof, or need separate event log from v1?
- Should `Stop` only warn/route in v1, or attempt automatic continuation/recovery?
- Should diagnostic temp writes get v1 allowlist, or use same Sage gate as project mutation?

**Implementation detail to decide during milestone planning:**
- Exact MCP write-tool allowlist.
- Exact approval metadata schema names and migration behavior for legacy artifacts.
- Exact pilot corpus and pass/fail rubric.

---

## Activation-Brief Initiative (20260428-…)

### What Was The Activation Plan That Got Reverted

**M0-M1-M2-M3 cycle** (commits 28b0782, 03dfee3):
- **L4 (Codex hooks):** Activated by default after `sage update`/`sage init` using regex keyword classifier (`build|implement|...` → spec+plan required, `fix|debug|...` → root-cause required, `architect|...` → brief required).
- **L5 (Pre-commit):** `core.hooksPath = .githooks` + `.githooks/pre-commit` blocking commits without active `.sage/work/` initiative. Added `--force-githooks` flag for existing hook frameworks.
- **M3 (Behavioral isolation):** Per-skill `agents/openai.yaml` with `policy.allow_implicit_invocation: false` to prevent Codex auto-suggesting direct skills on description match.
- **M0 (Pre-flight):** SHA256 versioning, atomic JSON merge with backup, test fixtures.

**Mechanical outcome:** 78/78 unit tests PASS, all milestones closed, hooks deployed, versions tracked, idempotency preserved.

### Post-Mortem (The Failure)

**Verdict: empirical dead end.** First real test on fresh project (`dummy-project`):

1. `sage init` succeeded — hooked everything up.
2. User prompt (Polish with typo): "chce zbudowac prosty to do app…" (want to build simple todo app).
3. **Codex built the app without Sage routing, artifacts, or checkpoints.**
4. Codex wrote: "skrócił processo Sage, bo zadanie było małe" (shortened Sage process because task was small).

**Root cause:** Regex classifier is **structurally unable to function** across languages, typos, synonyms:
- Polish `zbudowac` does not match English `build|implement|create|...`
- Hook emitted passthrough (no decision/block), Codex continued normally.
- Failures are **silent** — no visible signal that gate failed to activate.

**Why unit tests didn't catch it:** All 78 tests verified *mechanism* (hook blocks when regex matches, files deploy, JSON format correct). None tested *outcome* (does gate actually block on real Polish prompt with typo).

**Implication:** Regex-based prompt classification is not a viable enforcement mechanism. Must pivot to outcome-driven approach: gate on mutation attempt, not intent classification.

**What stays:** Planning artifacts (brief, spec, plan, verification, manifest) preserved as historical record. Decisions.md prepended with failure entry. Self-learning captured. Next cycle `20260429-codex-port-architecture-redesign` uses this as foundation (different approach: mutation-first, no regex, workflow state machine).

---

## Top 5 Actionable Insights for the Rewrite

**1. Mutation, not classification, is the enforcement anchor.**
   - **Claim:** `decision-codex-mutation-guardrail-stack.md` + postmortem.
   - **Why it matters:** Regex-based prompt classification provably fails across languages/typos/synonyms with silent failure modes. Gating on write attempt (PreToolUse before `Edit`/`Write`, PostToolUse after) is language-agnostic by definition and outcome-driven. This is the single highest-leverage architectural constraint for the rewrite.

**2. Approval proof must live on disk, not in chat memory.**
   - **Claim:** `decision-codex-approval-proof.md`: artifact frontmatter + matching decision log entry.
   - **Why it matters:** Hooks and status checking cannot reliably inspect chat history. Without machine-checkable proof, `[A]` semantics (approval) become unverifiable, enabling pseudo-Sage (agent says "approved" but nothing is written to disk). This blocks the workflow state machine from functioning as a shared validator across hooks/status/gen.

**3. Hook stack is layered; no single hook is sufficient in Skip Permissions.**
   - **Claim:** `decision-codex-mutation-guardrail-stack.md` + `decision-codex-enforcement-profiles.md`.
   - **Why it matters:** User operates in Skip Permissions, so `PreToolUse` is a guardrail, not a hard boundary. The rewrite must be honest about this, layer recovery mechanisms (`PostToolUse`, `Stop`, pre-commit), and distinguish `fast-trusted` (behavioral) from `strict` (sandbox-backed) profiles. False certainty about enforcement strength damages trust when users find bypasses.

**4. The reason M2 (imperative `AGENTS.md`) empirically failed is unknown and must be investigated first.**
   - **Claim:** `analysis-claude-vs-codex-enforcement-channels.md`, section 5; postmortem note.
   - **Why it matters:** The rewrite relies on a compact, authoritative `AGENTS.md` as Layer 1. If Codex doesn't surface it with the same salience as Claude does (`CLAUDE.md` in system context every turn), the entire foundation weakens. Before committing to `AGENTS.md` as the enforcement layer, confirm: Is `AGENTS.md` in system context every turn on Codex? Does skill body loading displace it? Is the distance from decision moment the issue? Answer these first.

**5. Empirical pilot prompts must gate completion; outcome tests cannot be deferred.**
   - **Claim:** `decision-codex-outcome-driven-verification.md` + postmortem lesson.
   - **Why it matters:** The prior cycle had 78/78 unit tests passing but failed on the first real user prompt. The new ruleset: behavioral outcome gates must be executed and approved before a milestone closes. Include 12-15 prompts covering casual chat, read-only, Polish/typo'd build requests, fix, architect, explicit workflow, invalid writes, valid writes, pseudo-Sage attempts. Without this, "completed" code carries false confidence and future reverts cost more.
