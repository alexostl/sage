# Research Base — Codex Port Rewrite

**Status:** input artifact for `/sage:architect` cycle that follows the M0–M3 revert (commit `a6f1391`, 2026-04-29).
**Method:** 4-stream parallel research (initiative history, freshest `.sage/docs/` thinking, current adapter map, official Codex platform docs) → confrontation synthesis. Every architectural claim below is cross-checked against `https://developers.openai.com/codex/`.

---

## 1. Executive verdict

The Codex port did not fail because Codex is incapable. It failed because **Sage's mental model of Codex was Claude-shaped**, and several Codex primitives that would have made the enforcement layer trivial were either misunderstood, unused, or assumed-absent.

Three concrete examples that the rewrite must absorb before designing anything:

1. **`PreToolUse` hooks DO match file-mutation tools** (specifically `apply_patch`, plus MCP tool names). The current adapter doc and `HOOKS.md` say otherwise. This is the language-agnostic enforcement anchor that the M0–M3 cycle was reaching for via regex prompt classification — it was already available, just on a different surface.
2. **Codex deprecated custom user-defined slash commands** on 2026-01-22, directing users to skills instead. The `$build` / `$sage:build` machinery in the generator is therefore not "slash commands with a prefix" — it is skill-name invocation via the `$skillname` mention syntax. The conceptual framing has been wrong for months; the file-system output happens to still be correct.
3. **Project-local `.codex/config.toml` is only loaded when `[projects."<abs>"] trust_level = "trusted"`** is set in user-global config. Sage's generator does not set this. If the dummy-project test that triggered the M0–M3 revert was untrusted, *no project hook would have fired regardless of what regex was inside it*. The "regex blind to Polish" diagnosis in the postmortem is at best partial until this is verified.

The rest of this document expands these and 12 more confrontations, then enumerates the constraints and open questions the architect must resolve before the rewrite begins.

---

## 2. What was tried, what reverted, what is on the table

Compressed timeline (full retrospective in Stream A appendix below; per-initiative source in `.sage/work/`):

| Date | Initiative | Approach | Outcome |
|---|---|---|---|
| 04-23 | `codex-enforcement-gap-fix` | Strict `AGENTS.md` + workflow PREAMBLE + `UserPromptSubmit` regex gate | **Shipped.** v2 plan rejected v1 ("copy Claude pattern") in favor of "use Codex-native levers". |
| 04-24 | `codex-command-prefix-parity` | Read `command_prefix` from `.sage/config.yaml`, rewrite skill dirs + `name:` + AGENTS refs | **Shipped.** Cosmetic parity, not behavior. |
| 04-24 | `codex-enforcement-gate-revision` | Per-initiative gate logic, Tier 1 fix passthrough, ripgrep→grep | **Shipped.** Closed 5 review findings on the 04-23 gate. |
| 04-24 | `codex-enforcement-hybrid-levers` | Spec for L1+L2+L4+L5 with shared `verification_check.py` validator | **Spec/plan only.** Implementation deferred to 04-28. |
| 04-28 | `sage-init-hooks-ergonomics` | Path-flexible `pre-commit`, auto-wire `core.hooksPath`, first-run nudge, `sage install-hooks` | **Shipped.** L5 cross-project ergonomics. |
| 04-28 | `codex-enforcement-activation-brief` | M0+M1+M2+M3: regex intent classifier (`UserPromptSubmit`) + L5 pre-commit + per-skill `agents/openai.yaml` isolation. 78/78 unit tests PASS | **REVERTED 04-29 (`a6f1391`).** Empirical dead end on first real prompt. |
| 04-29 | `codex-port-architecture-redesign` | 6-layer architecture: AGENTS.md / public-skills / internal lib / state machine / runtime guardrails / backstops. Plus 8 new ADRs. | **In-review.** Brief + spec drafted, awaiting design approval — this research is the input. |

The thing the rewrite is replacing is therefore not "the adapter that exists today" — most of the adapter (generator, prefix machinery, AGENTS.md scaffold, regression tests, optional hook starter pack) is intact. The thing being replaced is **the enforcement-activation theory**: that strict instructions + a regex-gated `UserPromptSubmit` would carry process compliance.

---

## 3. Postmortem reframe — was it really "regex blind to Polish"?

The 04-29 postmortem in `decisions.md` declares:

> "Mechanizm enforcementu oparty na klasyfikacji prompta przez regex słów-kluczowych jest strukturalnie niezdolny do działania. Nie ma takiej listy słów, która pokryje wszystkie języki, wszystkie literówki, wszystkie synonimy i wszystkie sposoby wyrażania intencji."

That conclusion is *correct as a general principle* — regex intent classification is a dead end for any multilingual user base. But the postmortem also asserts the regex was the proximate cause of the dummy-project failure. Stream D surfaces three alternative or co-causal explanations the postmortem does not investigate:

**(a)** `[features].codex_hooks = true` must be present in the loaded config or hooks silently no-op. The Codex docs are explicit. The generator emits this key, but the postmortem does not show whether the dummy-project test had it active.

**(b)** Project-local `.codex/config.toml` is only loaded when the user's global config contains `[projects."<abs>"] trust_level = "trusted"` (config-reference). Sage's generator does not write to user-global config. If the dummy project was not trusted at test time, *no project hook fires*, and the resulting outcome (Codex builds without Sage routing) looks identical to "regex didn't match Polish".

**(c)** `UserPromptSubmit` does not support a `matcher` field (Stream D, hooks page) — so the script ran on every prompt. But the regex was inside the script. If the script was invoked, it would have seen `chce zbudowac…` and emitted passthrough → the failure is consistent with "regex blind". If the script was *not* invoked (cases a or b), the failure is consistent with "hooks silently inactive".

**Implication for the architect:** before committing to any new enforcement layer, replay the dummy-project test with deterministic logging on three things: was `codex_hooks` set in the loaded config; was the project trusted; did the hook script's stderr appear at all. If the hook never ran, the entire "structural" framing of the postmortem needs a footnote — the regex is still a dead end as a *strategy*, but it may not be the proximate cause of the *empirical* failure that triggered the revert.

This matters because the rewrite's foundational decision — pivot from intent classification to mutation guardrails — is the right call regardless. But how confident the architect can be about why the previous cycle failed determines how much budget to spend hardening peripheral assumptions vs. redesigning the core.

---

## 4. Codex platform truth (compressed from official docs)

Sources: `developers.openai.com/codex/{guides/agents-md, skills, hooks, config-reference, config-sample, mcp, cli/slash-commands, concepts/sandboxing, subagents, memories, app/worktrees, app/automations, app/review, plugins, rules, changelog}`.

### 4.1 Surface inventory (CLI vs App vs Cloud vs IDE)

- **CLI** (`codex` binary, Rust, OSS) — local, reads `~/.codex/config.toml` + per-project `.codex/config.toml` *if trusted*. Headless mode `codex exec` with `--ephemeral`, `--full-auto`, `--json`, `--output-schema`, `--output-last-message`, `resume --last`.
- **App** (desktop) — additional surfaces: Plugins UI, Automations pane, Worktrees composer, Review pane, in-app browser. Some features are app-only.
- **Cloud** (`chatgpt.com/codex`) — async tasks, GitHub integration via `@codex` mention, parallel background runs, distinct configuration schema (not in `config.toml`).
- **IDE extension** — narrow surface: 8 slash commands (`/auto-context`, `/cloud`, `/cloud-environment`, `/feedback`, `/local`, `/review`, `/status`, plus one).

Sage so far has implicitly targeted CLI. The architect must decide explicitly which surfaces are in/out of scope for the rewrite.

### 4.2 Instructions: AGENTS.md + AGENTS.override.md

- Discovery: walks **root → cwd**, concatenated, blank line between, **later overrides earlier**. Global at `~/.codex/AGENTS.override.md` then `~/.codex/AGENTS.md`. Project layer at every dir from project-root marker (`.git` by default, configurable via `project_root_markers`) down to cwd: `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`.
- Hard size cap: `project_doc_max_bytes` defaults **32768 bytes**. Codex stops adding files past the threshold.
- Format: plain markdown. No required frontmatter. No special directives documented.
- Loaded **once per session** (TUI), not per turn. This is the operating constraint Sage has been designing around since 04-23 — confirmed in canonical docs.
- Order: `developer_instructions` (config string) → AGENTS.md → first turn. `model_instructions_file` overrides built-in base instructions entirely.

### 4.3 Skills

- Discovery paths: `$CWD/.agents/skills/` and every parent → repo root → `$HOME/.agents/skills` → `/etc/codex/skills` → bundled OpenAI skills.
- Layout: directory containing required `SKILL.md` (frontmatter `name`+`description`) plus optional `scripts/`, `references/`, `assets/`, `agents/openai.yaml`.
- `agents/openai.yaml` keys: `display_name`, `short_description`, icons, brand color, `default_prompt`, **invocation policy** (this is what M3 was using as `policy.allow_implicit_invocation: false`). The mechanism is documented.
- Auto-discovery: yes, with hot reload ("restart Codex if changes don't appear"). Activation: explicit `$skillname` mention, `@`-menu (added 03-19), or implicit description-match.
- **Initial skill list context cap: ~8000 characters.** With ~60 internal skills exposed, Codex will truncate the discovery context. This is the empirical justification for the public-16 / internal-lazy-load architecture in `decision-codex-public-workflows-internal-library.md` — not aesthetic, structural.
- Per-skill toggle: `[[skills.config]] path = "..."  enabled = false`.
- **No `$ARGUMENTS` placeholder is documented.** Skills are instruction-only or scripts; arg-passing is not part of the format.

### 4.4 Slash commands — the real story

- **CLI built-ins (~25):** `/model`, `/fast`, `/personality`, `/permissions`, `/status`, `/clear`, `/new`, `/plan`, `/diff`, `/review`, `/mention`, `/fork`, `/resume`, `/agent`, `/mcp`, `/apps`, `/plugins`, `/experimental`, `/copy`, `/compact`, `/feedback`, `/logout`, `/quit`, `/exit`, `/memories`, `/theme`.
- **Custom slash commands: deprecated 2026-01-22.** Changelog entry directs users to skills for reusable instructions. There is no documented file format for user slash commands, and no `command_prefix` config key in the docs.
- **Translation for Sage:** when AGENTS.md says "use `$build`", that is a **skill mention**, not a slash command. The `command_prefix: true` rewrite (`$build` → `$sage:build`) is renaming the skill directory and frontmatter `name` field — which IS valid because Codex matches `$skillname` against skill names. So the wire format is correct. But the conceptual framing in `HOOKS.md`, `AGENTS.md`, and several `.sage/docs/` files calls these "slash commands", which they are not.

### 4.5 Hooks — six events, gated by feature flag

```toml
[features]
codex_hooks = true
```

Without this flag, every hook silently does nothing. **This is the single most important precondition the rewrite must verify on every test, because failure mode is invisible.**

Six events:

| Event | Matcher? | Block via | Notes |
|---|---|---|---|
| `SessionStart` | regex (`startup\|resume\|clear\|compact`) | `"continue": false` | Once per session; payload omits `turn_id`. |
| `UserPromptSubmit` | **no matcher** | `"continue": false` | Fires on every user message. KV-cache cost: stable text → hit; per-turn dynamic → miss. |
| `PreToolUse` | regex on tool name | `"permissionDecision": "deny"` or **exit code 2** | Tool names include `Bash`, **`apply_patch`**, MCP tool names (`<server>__<tool>`). |
| `PermissionRequest` | regex | `"behavior": "allow" \| "deny"` | Fires when model requests approval — decision-time gate, not intent-time. |
| `PostToolUse` | regex on tool name | `"decision": "block"` | After-the-fact; useful for recovery / audit, not prevention. |
| `Stop` | **no matcher** | `"continue": false` | Fires at end of turn. Natural home for "did this turn satisfy gate state?" recovery check. |

Configuration: `~/.codex/hooks.json`, `~/.codex/config.toml` `[hooks]`, `<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml`. Enterprise: `requirements.toml` with `managed_dir`. **All matching hooks run concurrently.**

Stream C noted "no file-edit PreToolUse gating (only Bash); enforcement relies on pre-prompt + constitution." **This is incorrect against the official docs.** `apply_patch` is the matcher for file mutations and the tool name is documented. The rewrite must correct this in `HOOKS.md` and `runtime/platforms/codex/README.md`.

### 4.6 Configuration shape

- User: `~/.codex/config.toml` (or `$CODEX_HOME/...`).
- Project: `<repo>/.codex/config.toml` — **only loaded when project trusted** via user-global `[projects."<abs>"] trust_level = "trusted"`.
- Profiles: `[profiles.<name>]` overrides any top-level key, activated via root `profile = "..."` or `--profile`.
- Permissions profiles: `[permissions.<name>.filesystem]` glob rules + `[permissions.<name>.network]`. Activate via `default_permissions = "<name>"`.
- `[features]` flag list (full): `apps`, `codex_hooks`, `enable_request_compression`, `fast_mode`, `memories`, `multi_agent`, `personality`, `prevent_idle_sleep`, `shell_snapshot`, `shell_tool`, `skill_mcp_dependency_install`, `undo`, `unified_exec`. Deprecated: `web_search`, `web_search_cached`, `web_search_request`.
- `approval_policy`: string (`untrusted | on-request | never`) or **granular**: `{ granular = { sandbox_approval, rules, mcp_elicitations, request_permissions, skill_approval } }`.
- `sandbox_mode`: `read-only | workspace-write | danger-full-access`. OS-level enforcement: Seatbelt (macOS), Windows Sandbox/WSL2, bubblewrap (Linux).

### 4.7 MCP

- `[mcp_servers.<id>]` in `config.toml`. Two transports: STDIO, Streamable HTTP. Plain SSE not documented.
- Native keys Sage's MCP infrastructure does not currently use: `enabled`, `required` (fail startup if init fails), `enabled_tools`, `disabled_tools`, `startup_timeout_sec`, `tool_timeout_sec`, `oauth_resource`, `scopes`, `cwd`, `env_vars`.
- Sage's `runtime/mcp/json_to_toml.py` translates `.claude/mcp.json` → TOML inside `# >>> SAGE MANAGED BLOCK START` markers — preserving user-owned config outside the block. Mechanically correct.

### 4.7-bis MCP as workflow engine — what it unblocks

This is a finding from `analysis-codex-sage-mcp-workflow-engine.md` (2026-04-29 ADR, status: proposed) that did not survive into the M0–M3 implementation cycle and should be re-elevated for the rewrite. **It is the highest-leverage architectural change available.**

**Core proposition:** Sage's workflow logic — state machine, gate validation, approval proof, routing, artifact creation, audit — should live behind an MCP server (`[mcp_servers.sage]`) plus a shared local library that hooks and `sage status` also call. Today this logic lives in three duplicated places: prompt text inside `AGENTS.md` and skills (model's voluntary memory), shell scripts under `runtime/platforms/codex/hooks/`, and Python validators. The MCP-engine model centralizes it in one testable surface that Codex treats as a first-class tool.

**Proposed v1 tool surface (9 tools):**

| Tool | Purpose | Replaces today's |
|---|---|---|
| `sage_status` | active initiative / phase / next-action | shell + AGENTS.md prose claims |
| `sage_route` | "given user prompt, which workflow + skill?" | regex prompt classifier (M0) |
| `sage_next_action` | "what is the next legal phase transition?" | model-voluntary state recall |
| `sage_validate_transition` | gate check for `[A]/[R]/[S]` checkpoints | inline AGENTS.md instructions |
| `sage_validate_mutation` | called from `PreToolUse(apply_patch)` to confirm spec+plan exist | nothing (M0–M3 had no mutation gate) |
| `sage_record_approval` | persist approval to disk (frontmatter + `decisions.md`) | model "remembering" approval |
| `sage_create_artifact` | scaffold brief.md / spec.md / plan.md / verification.md | shell template + manual edits |
| `sage_checkpoint` | "is this turn ready to close?" snapshot | model self-assessment |
| `sage_audit_turn` | end-of-turn integrity check (called from `Stop` hook) | nothing (no `Stop` integration today) |

**What centralized MCP unblocks (problems Sage cannot solve cleanly without it):**

1. **Approval proof escapes the model.** Today, "user approved this spec" exists only as a prior turn's text. After compaction, drift, or a fresh subagent, the proof is gone. `sage_record_approval` writes it to disk frontmatter + `decisions.md`; `sage_validate_transition` reads it back. The model can no longer "forget" approval.
2. **Mutation gating becomes deterministic.** `PreToolUse` matching `apply_patch` calls `sage_validate_mutation`; the validator returns deny if no spec+plan exist on disk for the active initiative. Language-agnostic, regex-free, observable. This is what the M0–M3 cycle was reaching for via `UserPromptSubmit + regex` and never achieved.
3. **State machine derivation moves out of prompt text.** Today, `AGENTS.md` and skills carry instructions like "if in spec phase, next is plan". With ~16 public skills competing for the 8000-char discovery cap, this prose is a cost. `sage_next_action` is one tool call.
4. **Turn audit becomes possible at all.** `Stop` hook invokes `sage_audit_turn`; missing artifacts, broken approval chain, or unmet gate state get logged + recovered. Today: nothing fires at end of turn.
5. **Hooks and `sage status` stop drifting from the workflow definition.** Both call the same shared library that backs MCP. Update once, three surfaces reflect.
6. **Token cost drops.** Process logic that today bloats `AGENTS.md` (constrained to 32 KiB and loaded once per session, fully cached) moves to lazy on-demand MCP calls.

**Hard limits — what MCP-engine does NOT solve (preserve in user-facing docs):**

- Does not enforce against an agent that simply does not call the MCP tool. Hooks (`PreToolUse`) plus instruction salience cover that gap.
- Does not enforce in `danger-full-access` + `approval_policy = "never"`. Skip Permissions still removes hard boundaries; this is a behavioral guardrail, not a security boundary.
- Does not survive an MCP server outage unless paired with `required = true` (which fails session start on init failure) and surfaced via `sage status`.

**Native Codex MCP keys to lean on (Sage uses none today):**

- `required = true` — fail Codex session startup if Sage MCP fails to initialize. Converts "MCP silently absent" (current invisible failure mode) into a loud, observable startup error. **This is the single most important MCP key the rewrite should adopt.**
- `enabled_tools` / `disabled_tools` — narrow surface per profile (e.g., strict profile exposes all 9 tools; fast-trusted exposes only the read-only subset).
- `startup_timeout_sec` / `tool_timeout_sec` — bound the latency hit on each turn.
- MCP elicitation (per spec) — could later support interactive approval UX inside tool calls. Not required for v1; disk-backed proof is sufficient.

**Composition with the rest of the stack:**

```
PreToolUse(apply_patch) ──calls──▶ sage_validate_mutation ──reads──▶ .sage/work/<active>/{spec,plan}.md
                                                                                │
UserPromptSubmit ───────calls──▶ sage_route ──returns──▶ skill suggestion       │
                                                                                ▼
Stop ───────────────────calls──▶ sage_audit_turn ◀──same library──▶ sage status (CLI)
```

The shared library is the source of truth; MCP exposes it to the agent; hooks call the library directly (no MCP self-call); `sage status` and `decisions.md` read the same state. **One workflow definition, four observation surfaces.**

**Implementation notes from the ADR:**

- Existing assets reduce cost: `runtime/mcp/` already has MCP discovery/proxy utilities; Codex config generator already emits `[mcp_servers.*]` blocks.
- Refactor cost: existing shell hooks become thin adapters over the shared library.
- Outcome pilot harness (the 12–15 prompts from `decision-codex-outcome-driven-verification.md`) becomes the regression suite for the MCP engine, not just the hooks.

### 4.8 Subagents (`multi_agent` feature)

- Gated by `[features] multi_agent = true`.
- TOML definition files at `~/.codex/agents/<name>.toml` and `<repo>/.codex/agents/<name>.toml`.
- Required fields: `name`, `description`, `developer_instructions`. Optional: `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`, `nickname_candidates`.
- Global limits: `[agents]` with `max_threads = 6`, `max_depth = 1`, `job_max_runtime_seconds = 1800`.
- Per-role: `[agents.<role>] description, config_file`.
- Built-in agents: `default`, `worker`, `explorer`. Invocation: prompt-driven natural language + `/agent` slash for inspection. **No exposed callable tool name** like Claude's `Task` — this is a real semantic gap.

### 4.9 Native features Sage should integrate with rather than reimplement

- **`/review`** (CLI + IDE + app): scope options (uncommitted, all-branch, last turn, staged vs unstaged), inline diff comments, `review_model` config override. Sage's `review.workflow.md` should explicitly delegate diff inspection to native `/review` and own only the workflow-level "review checkpoint" semantics.
- **`/plan`** + `plan_mode_reasoning_effort` (incl. `none`): Codex has plan mode. Sage's spec phase output should be designed to live inside it where useful.
- **`/agent`**: subagent management.
- **`/compact`** + `model_auto_compact_token_limit` + `compact_prompt`: built-in compaction. Sage need not engineer its own context management.
- **`/memories`** + `[memories]` table — but: off by default + **geo-restricted (no EEA / UK / Switzerland at launch)**. Sage's user is in Poland → memories likely unavailable. The architecture must not depend on Codex memories. `.sage/decisions.md` remains the disk-of-record memory layer.
- **`.rules` Starlark policy files** (`developers.openai.com/codex/rules`): policy-as-code for command gating. Currently unused by Sage. Candidate replacement / complement for the L5 pre-commit hook — needs evaluation.
- **Worktrees**: native — but **app-only as a UI surface**. No `codex worktree` CLI command. The branch-worktree-model document's `~/.codex/worktrees/sage-selfhost/` paths are app-managed. CLI users must use plain `git worktree`. Sage should not assume Codex creates them.
- **Automations**: app-only. Cron syntax, daily/weekly/minute intervals, thread + standalone types. Run against Git worktrees when project is a repo. **CLI has no automation surface.** Sage is already correct on this point.

---

## 5. Sage assumption audit

Each row is a claim Sage's docs / code currently make, vs. Codex official truth, vs. action for the rewrite.

| # | Sage assumption | Codex truth | Action |
|---|---|---|---|
| 1 | `$build`/`$sage:build` are slash commands with prefix override | They are skill mentions; custom slash commands are deprecated. The renaming is the right wire format but the framing is wrong | Rewrite framing in `HOOKS.md`, `AGENTS.md`, generator comments. Drop "slash command" language; call them **skill invocations**. |
| 2 | `PreToolUse` only matches Bash — no file-edit gating | `PreToolUse` matches `Bash`, `apply_patch`, MCP tool names | **Foundational unblock.** Mutation guardrail stack (the 04-29 ADR) is implementable. Update Stream C's claim and `runtime/platforms/codex/README.md`. |
| 3 | Hooks are 4 events (SessionStart / UserPromptSubmit / PreToolUse / PostToolUse) | Six events — adds **`PermissionRequest`** and **`Stop`** | Add `Stop` for end-of-turn recovery. Evaluate `PermissionRequest` for decision-time gating instead of intent-time. |
| 4 | `[features].codex_hooks = true` is the activation toggle | Correct AND silent failure mode if absent | `sage status` must verify the flag in the *loaded* config (not just in template). Postmortem must verify it for the dummy-project replay. |
| 5 | `.codex/config.toml` is loaded automatically when project has one | Only when user-global `[projects."<abs>"] trust_level = "trusted"` is set | Generator must surface this requirement. `sage init` should print the exact line to add to `~/.codex/config.toml`. `sage status` must verify trust state. |
| 6 | Approval enforcement requires custom hook logic | Native `approval_policy = { granular = { ... } }` and `[permissions.<name>]` profiles exist | Evaluate native granular policy as primary, hooks as secondary. Reduce custom code surface area. |
| 7 | `agents/openai.yaml policy.allow_implicit_invocation: false` is undocumented territory | Documented; standard mechanism | M3 isolation was on solid footing. The revert should not have rolled this back. Re-evaluate independently of M0+M1+M2. |
| 8 | Initial-context cap on skills is unknown / aesthetic | ~8000 chars hard cap on skill discovery context | Public-16 / internal-lazy-load is structurally required, not optional. Confirms `decision-codex-public-workflows-internal-library.md`. |
| 9 | `regex prompt classification` was the only way to do `UserPromptSubmit` | `UserPromptSubmit` has no matcher; the script can do anything (including no classification at all) | The dead end is the *strategy* (intent-time prompt classification), not the *event*. `UserPromptSubmit` remains useful for compact non-classifying nudges (e.g., inject current `.sage/work/` state). |
| 10 | Codex hooks are experimental and risky to rely on | Documented and stable behind `codex_hooks` flag; semantics are deterministic | Reduce hedging in user-facing docs. Stop calling hooks "experimental" if the feature flag is mature. |
| 11 | Codex creates worktrees from CLI | Worktree composer is **app-only**. CLI uses plain `git worktree`. | Branch-worktree-model doc must distinguish app-managed `~/.codex/worktrees/` from CLI-created `git worktree`s. |
| 12 | `developer_instructions` is unused / unknown | Top-level config string injected before AGENTS.md in first turn | Candidate location for self-host-only directives that should not pollute project AGENTS.md. |
| 13 | Self-host overrides must live in project AGENTS.md | `~/.codex/AGENTS.override.md` exists at user level for exactly this | Maintainer-only overrides should live there, not in the public framework AGENTS.md. |
| 14 | `subagents` are speculative / future work | Documented, gated by `[features] multi_agent = true`, TOML format at `~/.codex/agents/*.toml` and `.codex/agents/*.toml` | sage-reviewer subagent is implementable today. Limits: `max_threads=6`, `max_depth=1`, `job_max_runtime_seconds=1800`. |
| 15 | `.rules` Starlark policy files don't exist or aren't relevant | Documented on `developers.openai.com/codex/rules`; policy-as-code for command gating | Evaluate as L5 alternative or complement to `.githooks/pre-commit`. |
| 16 | Memories may be useful for Sage state | Off by default + geo-restricted (no EEA/UK/CH at launch) | Architecture must not depend on Codex memories. `.sage/decisions.md` stays the disk-of-record. |
| 17 | Outcome-driven verification needs a custom harness | `codex exec --json --output-schema --output-last-message` provides structured headless output | Empirical pilot harness (the 12–15 prompts gate from `decision-codex-outcome-driven-verification.md`) can be built directly on `codex exec`. |
| 18 | Workflow logic = prompt text in AGENTS.md + skills + parallel shell scripts | MCP is a first-class tool surface in Codex (`[mcp_servers.<id>]`); workflow logic can be exposed once and called from the agent, hooks, and `sage status` | **Adopt Sage MCP as the central workflow engine** (per `analysis-codex-sage-mcp-workflow-engine.md`). Move state machine, gate validation, approval proof, and routing behind 9 MCP tools (`sage_status`, `sage_route`, `sage_next_action`, `sage_validate_transition`, `sage_validate_mutation`, `sage_record_approval`, `sage_create_artifact`, `sage_checkpoint`, `sage_audit_turn`) backed by a shared library. Hooks become thin adapters over the same library. |
| 19 | MCP server presence/absence is invisible if it fails to start | `[mcp_servers.<id>] required = true` fails Codex session startup on init failure | Set `required = true` for the Sage MCP server. Converts silent-failure into loud-failure; `sage status` reports it. Single most important MCP key the rewrite should adopt. |
| 20 | MCP server tool surface is fixed per install | `enabled_tools` / `disabled_tools` per `[mcp_servers.<id>]` allow per-profile narrowing | Expose all 9 Sage MCP tools in `strict` profile; expose only the read-only subset (`sage_status`, `sage_next_action`, `sage_route`) in `fast-trusted`. Tighter surface = less drift. |

---

## 6. Architectural constraints for the rewrite

Hard rules the architect should treat as inviolable until evidence forces a revisit.

### 6.1 Don't

1. **Do not build custom slash command machinery.** Codex deprecated this surface. Use skills + `$skillname` mentions.
2. **Do not rely on prompt-text classification (regex or otherwise) as a primary enforcement gate.** Strategy-level dead end.
3. **Do not ship hooks without a runtime check that `[features].codex_hooks = true` is set in the loaded config AND the project is trusted.** Both are silent-failure preconditions.
4. **Do not claim "hard enforcement" anywhere in user-facing docs.** In `workspace-write` + `approval_policy = "never"` (Skip Permissions, the user's normal mode), `PreToolUse` is a guardrail, not a hard boundary. The honest framing is: layered behavioral guardrails + recovery + commit-time backstop. State this explicitly in `AGENTS.md`, `HOOKS.md`, and `sage status` output.
5. **Do not assume Codex creates worktrees from the CLI.** App-only.
6. **Do not depend on Codex Memories.** Geo-restricted at launch.
7. **Do not expose more than ~16 skills to default discovery.** 8000-char cap → routing degrades.
8. **Do not write a project-scoped `[projects."<abs>"]` trust block from the framework generator.** That's a user-global file (`~/.codex/config.toml`) and writing to it from a project-init flow is a sharp footgun. Instead, surface the exact one-line addition the user must paste, and have `sage status` verify.

### 6.2 Do

1. **Anchor enforcement on `PreToolUse` matching `apply_patch` and selected MCP write tool names.** Mutation is language-agnostic. This is the architectural core.
2. **Use `Stop` hook for end-of-turn recovery and decision-log integrity check.** Maps to "Layer 5: recovery" in the redesign brief.
3. **Evaluate `PermissionRequest` hook as decision-time gate** — fires when the model requests approval, before any tool runs. Strictly better than `UserPromptSubmit` for "should this approval be granted given current Sage state".
4. **Evaluate native `approval_policy = { granular = { ... } }` and `[permissions.<name>]` profiles** as primary approval-control surface. Custom hook approval code becomes secondary.
5. **Use `[agents.<name>]` with `multi_agent = true` for sage-reviewer.** Built-in subagent surface; respects `max_depth = 1`.
6. **Use `AGENTS.override.md` at user level for self-host maintainer overrides.** Keep public AGENTS.md portable.
7. **Use `developer_instructions` config key for cross-project Sage directives** that don't belong in any specific project's AGENTS.md.
8. **Build the empirical pilot harness on `codex exec --json`.** Deterministic, scriptable, geo-independent, runs in CI without app/cloud surface.
9. **Verify on every `sage status` run:** `[features].codex_hooks` set, project trusted, hook scripts executable, AGENTS.md size under cap, skill count under public-palette limit.
10. **Maintain `.sage/decisions.md` as the disk-of-record memory layer.** No dependency on Codex Memories.
11. **Adopt Sage MCP as the central workflow engine** with `required = true`. Hooks become thin adapters over a shared library; the same library backs `sage status`. See §4.7-bis for the 9-tool surface and what each one unblocks. This is the architectural change that lets §6.2.1 (mutation gating on `apply_patch`) be deterministic instead of regex-driven.

### 6.3 Open scope decisions for the architect

1. **CLI vs App vs Cloud surface scope.** What level of Cloud (GitHub `@codex` mention) support is in scope for v1? Cloud configuration schema is distinct from `config.toml`.
2. **`.rules` Starlark vs `.githooks/pre-commit` for L5.** Starlark is policy-as-code, native, and may cover more than commit-time. Evaluate.
3. **Mutation matcher list.** Confirm the exhaustive set of tool names that count as "mutation": `apply_patch`, `Bash` (for shell-level writes), MCP server-tool names (which?). May require a runtime-discoverable allowlist.
4. **AGENTS.md split.** Public framework contract vs self-host maintainer-only. Candidates: project AGENTS.md (portable) + `AGENTS.override.md` at user level (self-host) + `developer_instructions` config key (cross-project Sage).
5. **Public skill list (the 16).** Current de-facto list (build, fix, architect, research, design, analyze, reflect, continue, qa, map, autoresearch, design-review, status, review, learn, sage-navigator) — needs explicit contract + extensibility rule.
6. **Internal skill manifest location.** Codex-only or shared across platforms? Cost of cross-platform coordination is unknown.
7. **Subagent rollout.** Build sage-reviewer now (multi_agent flag) or defer? `[agents]` limits suggest rollout cost is low.
8. **Approval-proof schema.** Frontmatter (`approved_at`, `approved_by`, `approval_gate`) + matching `decisions.md` entry — sufficient, or also need a separate event log from v1?
9. **Stop hook v1 scope.** Warn-and-route only, or attempt automatic recovery / continuation?
10. **Diagnostic-temp-write allowlist.** Same Sage gate, or v1 allowlist?

---

## 7. Cross-cutting failure patterns to internalize (from Stream A)

These are recurring root causes, each citing initiative(s) where they showed up. The architect should design against each.

1. **Regex intent classification is structurally blind** (M0–M3). Strategy-level dead end. Replace with mutation-anchored gating.
2. **Unit test green ≠ outcome success** (M0–M3, 78/78 PASS but failed on first prompt). Behavioral outcome tests must gate close-out, not be deferred to the user.
3. **Once-per-session AGENTS.md forces salience-vs-duplication tradeoff** (04-23 v2). Compact, imperative, observable-signal phrasing wins over comprehensiveness.
4. **Codex hook activation has silent-failure preconditions** (`codex_hooks` flag, project trust). Every hook deployment must verify both at runtime.
5. **Dual-branch merge complexity under-tested late** (04-24 hybrid levers). sage-close atomic merge across `self-host/main` + `codex-port` was specced but never failure-tested.
6. **Generator must handle framework-repo and downstream layouts** (04-28 init hooks). Validators, hooks, docs, and tests must be path-flexible.

---

## 8. Recommended sequencing for the architect

The architect cycle that follows this research should not jump to the 6-layer architecture wholesale. Suggested order:

1. **Diagnostic replay of dummy-project failure** — 1 day. Verify whether the M0–M3 failure was regex-blind, hooks-silent (missing flag), or trust-untrusted. Conclusion changes the rewrite's confidence model.
2. **Correct the platform-truth deltas in existing docs** — 0.5 day. `HOOKS.md`, `runtime/platforms/codex/README.md`, anywhere claiming "PreToolUse only Bash" or "slash commands". Stops new code from inheriting wrong assumptions.
3. **Mutation-anchor proof of concept** — 2 days. Wire `PreToolUse` matching `apply_patch` to a minimal validator that consults `.sage/work/<active>/` for spec+plan. Run `codex exec --json` pilot on the 12–15 prompts. *This is the single most decisive experiment*; if it works, the rest of the architecture follows.
4. **Sage MCP engine spike** — 2 days, parallel with #3. Stand up `[mcp_servers.sage]` with `required = true` exposing `sage_status`, `sage_validate_mutation`, `sage_record_approval` (3 of the 9 v1 tools). Have the `PreToolUse(apply_patch)` validator from #3 call `sage_validate_mutation` instead of reading disk directly. Confirms the shared-library + MCP composition before the full 9-tool surface gets built.
5. **Status-flag + trust verification in `sage status`** — 0.5 day. Defends every future hook deployment. Should also report MCP server health (`required = true` startup result, last successful tool call, surface drift).
6. **Then** spec the 6-layer architecture against confirmed primitives, with Sage MCP as the workflow engine and hooks as adapters.

This sequencing front-loads the highest-uncertainty experiments and keeps the architect from designing on top of unverified assumptions.

---

## 9. Inputs preserved for traceability

The four research streams are preserved as standalone artifacts so the architect can drill into deeper context without re-reading the 30+ source files. **If anything in this synthesis feels under-justified, the corresponding stream file is the next read.**

- **[Stream A — initiative history](research-codex-stream-a-initiative-history.md)** — full per-initiative retrospective for the 9 Codex cycles (04-23 through 04-29) with problem / hypothesis / implementation / outcome / reason / surfaces structure, cross-cutting failure patterns, and 8 open questions. Source: `.sage/work/2026042{3,4,8,9}-codex-*` artifacts.
- **[Stream B — latest thinking digest](research-codex-stream-b-latest-thinking.md)** — per-file digest of all 31 files in `.sage/docs/` (16 from 2026-04-29 post-revert), with findings extracted by topic: enforcement architecture, AGENTS.md, skill discovery, hooks, `.codex/config.toml`, MCP-as-workflow-engine, worktrees, automations, `/review`, profiles, behavioral isolation. **Includes the explicit `analysis-codex-sage-mcp-workflow-engine.md` recommendation that motivates §4.7-bis here.** Top 5 actionable insights for the rewrite.
- **[Stream C — adapter map](research-codex-stream-c-adapter-map.md)** — current adapter inventory at `runtime/platforms/codex/{README, INSTALL, HOOKS, AUTOMATIONS, platform.yaml, hooks.example.json, setup/generate-codex.sh, hooks/, tests/}` and `runtime/mcp/json_to_toml.py`. Generated surfaces breakdown (AGENTS.md, `.agents/skills/`, `.codex/config.toml`, hooks, automations), workflow ↔ adapter coupling, Claude Code vs Codex parity gap, test coverage, recent commits, suspicious/dead code. **Note: contains the corrected claim about `PreToolUse + apply_patch` — Stream D from official docs invalidates Stream C's original "no file-edit gating" assertion. Both versions preserved with a corrective annotation in the file.**
- **[Stream D — Codex platform truth](research-codex-stream-d-platform-truth.md)** — verbatim findings from all 23 fetched URLs at `developers.openai.com/codex/{guides/agents-md, skills, hooks, config-reference, config-sample, mcp, cli/slash-commands, ide/slash-commands, concepts/sandboxing, concepts/subagents, subagents, memories, app/worktrees, app/automations, app/review, cloud, plugins, rules, feature-maturity, noninteractive, changelog}`. CLI vs Cloud vs App vs IDE distinctions, feature gap matrix vs Claude Code (17 rows), and an explicit "things docs don't promise" section.

For the MCP workflow engine specifically, the source ADR is `analysis-codex-sage-mcp-workflow-engine.md` (proposed, 2026-04-29). It carries the full reasoning that §4.7-bis above compresses, including the elicitation spec discussion and the strict-vs-fast-trusted profile mapping.

---

## 10. One-paragraph summary for the architect

The Codex port's previous failure was diagnosed as "regex prompt classification is structurally blind" — that conclusion is correct as a strategy-level principle, but the proximate empirical cause may have been a missing `codex_hooks` flag or untrusted project, neither of which the postmortem investigated. The rewrite's correct architectural anchor is twofold: (a) `PreToolUse` matching `apply_patch` (mutation-time gating, language-agnostic) — a primitive Sage's own adapter doc declared absent but which the official Codex docs document explicitly; and (b) **Sage MCP as the central workflow engine** with `required = true`, exposing 9 tools that move state machine, gate validation, and approval proof out of the model's voluntary memory and into a shared library that hooks and `sage status` also call (per the proposed but unimplemented `analysis-codex-sage-mcp-workflow-engine.md`). Three more under-leveraged primitives (`Stop` hook, `PermissionRequest` hook, `[projects].trust_level`, granular `approval_policy`, `[agents.<name>]` subagents, `.rules` Starlark, `AGENTS.override.md`, `developer_instructions`) significantly reduce the custom-code surface area the rewrite needs. Custom slash commands were deprecated in January and should not be reintroduced as a concept; `$build`/`$sage:build` are skill mentions. The architect should front-load a diagnostic replay of the dummy-project failure plus parallel proofs-of-concept for `PreToolUse + apply_patch` and a 3-tool Sage MCP spike (`sage_status`, `sage_validate_mutation`, `sage_record_approval`) *before* spec'ing the full 6-layer architecture, to avoid building on assumptions that have not been empirically verified.
