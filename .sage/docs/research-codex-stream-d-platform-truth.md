# Stream D — Codex Platform Ground Truth (Official Docs)

**Source:** general-purpose subagent with WebFetch over `developers.openai.com/codex/` and subpages.
**Scope:** ground-truth reference for what Codex actually offers, with URL citations on every claim. No reasoning by Claude-analogy.
**Parent:** `research-codex-port-rewrite-base.md`.
**Date framing:** 2026-04-29. Most recent changelog entry observed: 2026-04-23 (GPT-5.5 launch).

---

## Sources fetched

- https://developers.openai.com/codex/ — Doc tree root.
- https://developers.openai.com/codex/guides/agents-md — AGENTS.md discovery, merge order, size limits.
- https://developers.openai.com/codex/skills — Skills directory layout, SKILL.md frontmatter.
- https://developers.openai.com/codex/hooks — Hook events, payload, configuration.
- https://developers.openai.com/codex/config-reference — config.toml schema reference.
- https://developers.openai.com/codex/config-sample — Verbatim sample `config.toml`.
- https://developers.openai.com/codex/mcp — MCP server config (TOML).
- https://developers.openai.com/codex/cli — CLI overview, install commands.
- https://developers.openai.com/codex/cli/slash-commands — CLI slash commands list.
- https://developers.openai.com/codex/ide/slash-commands — IDE extension slash commands.
- https://developers.openai.com/codex/concepts/sandboxing — Sandbox modes.
- https://developers.openai.com/codex/concepts/subagents — Subagent concept.
- https://developers.openai.com/codex/subagents — Subagent file format.
- https://developers.openai.com/codex/memories — Memories feature.
- https://developers.openai.com/codex/app/worktrees — Worktrees.
- https://developers.openai.com/codex/app/automations — Scheduled tasks.
- https://developers.openai.com/codex/app/review — Review pane.
- https://developers.openai.com/codex/cloud — Codex Cloud overview.
- https://developers.openai.com/codex/plugins — Plugins.
- https://developers.openai.com/codex/rules — `.rules` Starlark policy files.
- https://developers.openai.com/codex/feature-maturity — Maturity label definitions only (no inventory).
- https://developers.openai.com/codex/noninteractive — `codex exec` headless mode.
- https://developers.openai.com/codex/changelog — Recent feature additions.

## Codex CLI vs Codex Cloud

**Codex CLI** — Local terminal binary (Rust, open source). Install with `npm i -g @openai/codex` or Homebrew. Operates on the current directory; spawns local model calls; supports headless mode (`codex exec`); reads `~/.codex/config.toml`. (cli/, cli/slash-commands)

**Codex Cloud** — Browser-hosted at `chatgpt.com/codex`. Runs tasks asynchronously in OpenAI-managed cloud environments, integrates with GitHub (`@codex` mentions on issues/PRs), supports parallel background tasks, has its own per-environment configuration. (cloud/)

**Codex App** — Desktop app with extra surfaces: Plugins directory, Automations pane, Worktrees composer, Review pane, in-app browser, computer use. Some features (automations, plugins UI, review pane) are app-only — the CLI doesn't replicate them. (app/, app/automations, app/review)

**Codex IDE Extension** — VS Code/JetBrains-style extension. Shares some plumbing with the app (settings sync, 2026-03-24). Has a much smaller slash command set (8 commands). (ide/)

The docs treat all four as facets of one product but features are not uniform. Notably: `codex_hooks`, `multi_agent`, `memories` are config-driven and apply across CLI/app; `automations` and the plugin browser are app-only; `/review` works in app and CLI; `--ephemeral`/`--full-auto`/`--json` are CLI-only.

## AGENTS.md

Source: `guides/agents-md`, `config-reference`, `config-sample`.

**Discovery order** (concatenated, blank line between, later overrides earlier):
1. Global: `~/.codex/AGENTS.override.md`, then `~/.codex/AGENTS.md` (or `$CODEX_HOME/...`). First non-empty wins.
2. Project: starting from project root (default marker `.git`, configurable via `project_root_markers`), Codex walks **down** to cwd, checking each directory for `AGENTS.override.md` → `AGENTS.md` → any name in `project_doc_fallback_filenames`.

**Format:** Plain markdown (`.md`). No frontmatter required, no special directives mentioned.

**Size limit:** `project_doc_max_bytes` default **32768** bytes (32 KiB). Codex stops adding files once cumulative size hits the threshold. Empty files are skipped automatically.

**Interaction with system prompt:** AGENTS.md content is injected into first-turn instructions. The config key `developer_instructions` (string) is "injected before AGENTS.md" — i.e., user-level developer instructions precede project AGENTS.md in the prompt. `model_instructions_file` overrides built-in base instructions with a file path.

**Rebuild cadence:** "Once per run; in the TUI this usually means once per launched session."

## Skills / custom prompts / commands

Source: `skills`, `config-sample`, `cli/slash-commands`, `ide/slash-commands`.

### Skills
Codex has a first-class skills concept distinct from Claude's. Disk locations:
- `$CWD/.agents/skills/` and every parent up to repo root
- `$REPO_ROOT/.agents/skills`
- `$HOME/.agents/skills` (user)
- `/etc/codex/skills` (admin/system)
- Bundled OpenAI skills

**File layout:** A skill is a **directory** containing required `SKILL.md` plus optional `scripts/`, `references/`, `assets/`, `agents/openai.yaml`.

**Required frontmatter** in `SKILL.md`:
```yaml
---
name: skill-name
description: Explain exactly when this skill should and should not trigger.
---
```

Optional `agents/openai.yaml` carries `display_name`, `short_description`, icons, brand color, `default_prompt`, invocation policy.

**Auto-discovery:** Yes. "Codex detects skill changes automatically. If an update doesn't appear, restart Codex." Activation is either explicit (`$skillname` mention or `@`-menu — added 2026-03-19) or implicit description-match. Initial skill list context capped at ~8000 chars.

**Per-skill toggles** in `config.toml`:
```toml
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

**Arguments:** No built-in arg-passing mechanism — skills are "instruction-only format or scripts". Doc does not mention `$ARGUMENTS`-style placeholders.

### Slash commands
**Built-in CLI slash commands (~25):** `/model`, `/fast`, `/personality`, `/permissions`, `/status`, `/clear`, `/new`, `/plan`, `/diff`, `/review`, `/mention`, `/fork`, `/resume`, `/agent`, `/mcp`, `/apps`, `/plugins`, `/experimental`, `/copy`, `/compact`, `/feedback`, `/logout`, `/quit`, `/exit`, `/memories`, `/theme`.

**IDE extension slash commands:** `/auto-context`, `/cloud`, `/cloud-environment`, `/feedback`, `/local`, `/review`, `/status` (8 total — much narrower than CLI).

**Custom slash commands:** **The CLI slash-commands page does not document any user-defined slash command mechanism, file format, or prefix override.** The 2026-01-22 changelog entry explicitly says: "Custom prompts deprecated — users directed to use skills for reusable instructions instead." That is the closest thing to "no equivalent in Codex docs" for Claude's `~/.claude/commands/*.md`.

## Hooks / lifecycle

Source: `hooks`, `config-reference`, `config-sample`.

Codex **does** have hooks, gated by feature flag.

**Enable:**
```toml
[features]
codex_hooks = true
```

**Six events:** `SessionStart`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `UserPromptSubmit`, `Stop`.

**Configuration locations** (all matching hooks run):
- `~/.codex/hooks.json`
- `~/.codex/config.toml` (inline `[hooks]` tables)
- `<repo>/.codex/hooks.json`
- `<repo>/.codex/config.toml`
- Enterprise managed via `requirements.toml` with `managed_dir` / `windows_managed_dir`

**Payload (stdin JSON)** — shared fields: `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `model`, `turn_id` (turn-scoped only). `PreToolUse` adds `tool_name`, `tool_use_id`, `tool_input`.

**Output control (stdout JSON):**
- `SessionStart` / `UserPromptSubmit` / `Stop` → `"continue": false` halts.
- `PreToolUse` → `"permissionDecision": "deny"` or **exit code 2** to block.
- `PostToolUse` → `"decision": "block"`.
- `PermissionRequest` → `"behavior": "allow" | "deny"`.
- All events accept `"systemMessage"` for UI warnings.

**Matcher (regex):** Supported on `PreToolUse`, `PostToolUse`, `PermissionRequest` (matches tool names like `Bash`, `apply_patch`, MCP names) and `SessionStart` (matches `startup|resume|clear`). **Not** supported on `UserPromptSubmit` or `Stop`.

**Example block** (config.toml):
```toml
[[hooks.PreToolUse]]
matcher = "^Bash$"

[[hooks.PreToolUse.hooks]]
type = "command"
command = 'python3 "/abs/path/pre_tool_use_policy.py"'
timeout = 30
statusMessage = "Checking Bash command"
```

Hooks run **concurrently** (no inter-hook blocking) and provide "deterministic injection into the agentic loop."

## Configuration (config.toml)

Source: `config-reference`, `config-sample`.

**File location:**
- User: `~/.codex/config.toml` (or `$CODEX_HOME/config.toml`)
- Project: `<repo>/.codex/config.toml` — **only loaded when project is marked `trust_level = "trusted"`** under `[projects]`.

**Top-level keys (selected, all verbatim):**
- `model` (e.g., `"gpt-5.5"`), `model_provider` (default `"openai"`), `model_context_window`, `model_reasoning_effort` (`minimal|low|medium|high|xhigh`), `plan_mode_reasoning_effort` (adds `none`), `model_reasoning_summary` (`auto|concise|detailed|none`), `model_verbosity` (`low|medium|high`), `model_instructions_file`, `model_catalog_json`, `model_auto_compact_token_limit`, `tool_output_token_limit`.
- `personality` (`none|friendly|pragmatic`), `service_tier` (`fast|flex`), `developer_instructions`, `compact_prompt`, `commit_attribution`.
- `approval_policy` — string (`untrusted|on-request|never`) or `{ granular = { sandbox_approval, rules, mcp_elicitations, request_permissions, skill_approval } }`. `approvals_reviewer` (`user|auto_review`).
- `sandbox_mode` (`read-only|workspace-write|danger-full-access`), `default_permissions`, `allow_login_shell`.
- `web_search` (`disabled|cached|live`).
- `project_doc_max_bytes`, `project_doc_fallback_filenames`, `project_root_markers`.
- `file_opener` (`vscode|vscode-insiders|windsurf|cursor|none`).
- `cli_auth_credentials_store`, `chatgpt_base_url`, `openai_base_url`, `forced_login_method`, `forced_chatgpt_workspace_id`, `mcp_oauth_credentials_store`, `mcp_oauth_callback_port`, `mcp_oauth_callback_url`.
- `notify` (argv array for external notifier).

**Tables:** `[sandbox_workspace_write]` (`writable_roots`, `network_access`, `exclude_slash_tmp`, `exclude_tmpdir_env_var`), `[shell_environment_policy]`, `[history]` (`persistence: save-all|none`, `max_bytes`), `[tui]`, `[analytics]`, `[feedback]`, `[notice]`, `[features]`, `[memories]`, `[hooks]`, `[mcp_servers]`, `[model_providers]`, `[apps]`, `[tool_suggest]`, `[profiles]`, `[projects]`, `[tools]`, `[otel]`, `[windows]`, `[agents]`, `[skills.config]`, `[permissions.<name>]`.

**Complete `[features]` flag list:** `apps`, `codex_hooks`, `enable_request_compression`, `fast_mode`, `memories`, `multi_agent`, `personality`, `prevent_idle_sleep`, `shell_snapshot`, `shell_tool`, `skill_mcp_dependency_install`, `undo`, `unified_exec`. Deprecated: `web_search`, `web_search_cached`, `web_search_request`.

**Profiles:** `[profiles.<name>]` overrides nearly any top-level key. Activate via `profile = "default"` at root or `--profile`.

**Project trust:** `[projects."/abs/path"] trust_level = "trusted" | "untrusted"`. Project-local config layer is only honored when trusted.

## MCP

Source: `mcp`, `config-sample`.

**Format:** TOML under `[mcp_servers.<id>]`. Two transports: **STDIO** (local process) and **Streamable HTTP**.

**STDIO keys:** `command` (required), `args`, `env`, `env_vars` (forward parent env), `cwd`, `experimental_environment = "remote"`, `startup_timeout_sec` (default 10), `tool_timeout_sec` (default 60), `enabled`, `required` (fail startup if init fails), `enabled_tools`, `disabled_tools`, `scopes`, `oauth_resource`.

**HTTP keys:** `url` (required), `bearer_token_env_var`, `http_headers`, `env_http_headers`, plus the timeout/enable/scope keys above.

**Verbatim example:**
```toml
[mcp_servers.docs]
command = "docs-server"
args = ["--port", "4000"]
env = { "API_KEY" = "value" }
env_vars = ["ANOTHER_SECRET"]
startup_timeout_sec = 10.0
enabled_tools = ["search", "summarize"]

[mcp_servers.github]
url = "https://github-mcp.example.com/mcp"
bearer_token_env_var = "GITHUB_TOKEN"
http_headers = { "X-Example" = "value" }
```

**SSE:** The MCP page lists only "STDIO" and "Streamable HTTP" — doc does not mention plain SSE as a separate transport.

**Differences from Claude's `.mcp.json`:** Claude uses JSON; Codex uses TOML embedded in the same `config.toml` (no separate file). Codex adds `enabled`/`required`/`enabled_tools`/`disabled_tools`/timeouts/`oauth_resource`/`scopes` natively. Codex docs do not provide a side-by-side comparison.

## Sandboxing & approval

Source: `concepts/sandboxing`, `config-reference`, `config-sample`.

**Three sandbox modes** (`sandbox_mode`):
- `read-only` (default) — inspect only, no edits or commands without approval.
- `workspace-write` — read+edit within workspace + routine local commands. Default low-friction mode.
- `danger-full-access` — no sandbox; no fs/network boundary.

**Three approval policies** (`approval_policy`):
- `untrusted` — only known-safe read-only commands auto-run; others prompt.
- `on-request` (default) — model decides when to ask.
- `never` — never prompt (risky; used by automations).
- Granular: `{ granular = { sandbox_approval, rules, mcp_elicitations, request_permissions, skill_approval } }`.

**Workspace-write extras** (`[sandbox_workspace_write]`): `writable_roots`, `network_access` (default false), `exclude_slash_tmp`, `exclude_tmpdir_env_var`.

**OS enforcement:** Seatbelt (macOS), Windows Sandbox / WSL2 (Windows), bubblewrap (Linux).

**Permissions profiles:** `default_permissions = "<name>"` activates `[permissions.<name>.filesystem]` glob rules and `[permissions.<name>.network]` proxy/domain controls.

**Per-tool approval:** `PreToolUse` and `PermissionRequest` hooks gate tool calls. Apps connectors have per-tool `approval_mode = "auto|prompt|approve"` under `[apps.<id>.tools."<tool>"]`.

## Worktrees / git

Source: `app/worktrees`, `app/review`.

**Native worktree support: yes, but app-only as a UI surface.** "Worktrees only work in projects that are part of a Git repository since they use Git worktrees under the hood."

Invocation in the **Codex App**: select "Worktree" in the thread composer, choose starting branch. Codex creates a detached-HEAD worktree under `$CODEX_HOME/worktrees`. Auto-cleanup keeps up to 15 by default; permanent worktrees opt out. Snapshots restore deleted worktrees.

The CLI doc does not describe a `codex worktree` command; the doc surface for worktrees is the app composer.

**`/review`** is built in (CLI + IDE + app). Scope options: uncommitted (default), all branch changes, last turn, staged vs unstaged. Inline comments on diffs are first-class. `review_model` config key can override the model used. PR context surfaces when GitHub is connected.

## Automations / scheduled tasks

Source: `app/automations`.

**Yes — but app-only.** Configured via the Codex app sidebar "Automations" pane. Frequencies: predefined (daily, weekly), minute intervals, or custom **cron syntax**. Two types:
- **Thread automations** — heartbeat-style recurring wake-ups attached to a thread.
- **Standalone/project automations** — independent runs reporting to "Triage" inbox.

Run on dedicated Git worktrees when the project is a repo; otherwise directly in project dir. Use `approval_policy = "never"` and respect `sandbox_mode`. **For project-scoped automations the app must be running.** "No CLI-specific automation configuration details are provided" in the docs.

## Memory / context

Source: `memories`, `config-sample`, changelog.

Feature is called **Memories**. Standard (not labeled experimental) but **off by default and unavailable in EEA, UK, Switzerland at launch.**

**Enable:** `[features] memories = true`. Tune via `[memories]`: `generate_memories`, `use_memories`, `disable_on_external_context`.

**Storage:** `~/.codex/memories/` — generated state with summaries, durable entries, recent inputs. Updated **asynchronously**, not after every session.

**Commands:** `/memories` (thread-level toggle for use/generate). **Chronicle** is a paired feature that "helps Codex recover recent working context from your screen."

**Compaction:** Built-in. `/compact` slash command. `model_auto_compact_token_limit` controls auto-compact threshold. `compact_prompt` and `experimental_compact_prompt_file` override the compaction prompt.

## Subagents / delegation

Source: `subagents`, `concepts/subagents`, `config-reference`, `config-sample`.

**Yes.** Gated by `[features] multi_agent = true`. Definition format is **TOML files**:
- Personal: `~/.codex/agents/<name>.toml`
- Project: `<repo>/.codex/agents/<name>.toml`

**Required fields:** `name`, `description`, `developer_instructions`.
**Optional:** `nickname_candidates`, `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`.

**Global limits** under `[agents]`: `max_threads = 6`, `max_depth = 1`, `job_max_runtime_seconds = 1800`. Per-role declaration:
```toml
[agents.reviewer]
description = "Find correctness, security, and test risks."
config_file = "./agents/reviewer.toml"
nickname_candidates = ["Athena", "Ada"]
```

**Built-in agents:** `default`, `worker`, `explorer`. **Invocation:** prompt-driven ("spawn one agent per point") or via `/agent` to inspect/switch threads. There is **no dedicated tool name** like Claude's `Task` / `subagent` exposed in the docs — it's done via natural-language requests plus the agent definitions.

## Feature gap matrix vs Claude Code

| Feature | Claude Code has | Codex has | Notes |
|---|---|---|---|
| Project instructions file | `CLAUDE.md` (+ frontmatter optional) | `AGENTS.md` (plus `AGENTS.override.md`) | Codex walks root→cwd, hard 32 KiB cap (`project_doc_max_bytes`); Claude has no documented hard byte cap. |
| settings.json hooks | Yes (`~/.claude/settings.json`, project, user) | Yes — `~/.codex/hooks.json` + `[hooks]` in `config.toml`, gated by `codex_hooks` feature flag | Six events vs Claude's set; payload format and `exit 2` semantics very similar. |
| Plugins/marketplace | Yes (plugins, slash-commands, MCP bundles) | Yes — `/plugins`, plugin directory in app, bundles skills+apps+MCP | Architecturally similar but separate registries. |
| Skill auto-discovery | `~/.claude/skills`, project `.claude/skills`, frontmatter `name`+`description` | `.agents/skills/`, `~/.agents/skills`, `/etc/codex/skills`. Same SKILL.md + name/description frontmatter pattern | Path differs; both use directory-of-SKILL.md model. |
| Custom slash commands | Yes — `~/.claude/commands/*.md`, supports `$ARGUMENTS` | **No.** Custom prompts deprecated 2026-01-22; "directed to use skills instead." | This is a real gap — Codex has no user-defined slash commands documented. |
| Slash-command prefix override | Configurable | Not documented | Codex uses `/` only; no override key in config sample. |
| MCP config format | `.mcp.json` + settings.json (JSON) | `[mcp_servers.<id>]` in `config.toml` (TOML) | Both support stdio + HTTP; Codex adds native `enabled_tools`/`disabled_tools`/timeouts/`required`. |
| Sandbox model | Permission system w/ allow/deny rules | Three modes (`read-only`/`workspace-write`/`danger-full-access`) + Starlark `.rules` files for command gating | Codex has OS-level sandboxing (Seatbelt/Sandbox/bubblewrap) — stronger isolation guarantee. |
| Worktree commands | Via Bash/git | Native — composer in app, `$CODEX_HOME/worktrees`, automatic cleanup | App-only UI; no `codex worktree` CLI documented. |
| `/review` | Not documented as built-in | Built-in across CLI/IDE/app with diff scopes and inline comments; `review_model` config | First-class. |
| Scheduled tasks | Background tasks via SDK / hooks | App-only Automations with cron syntax + Triage inbox | Codex CLI has nothing equivalent documented. |
| Subagent tool | `Task` tool with subagent definitions in `.claude/agents/*.md` | `[agents.<name>]` + TOML files in `~/.codex/agents/` and `.codex/agents/`, gated by `multi_agent` feature | Codex requires explicit prompt invocation; no exposed tool name documented. |
| Memory tool / `/memory` | `/memory` editor + memory tool | `/memories` + `[memories]` table; `~/.codex/memories/` async-generated state | Codex memories off by default, geo-restricted (no EEA/UK/CH at launch). |
| Plan mode | Plan mode + planning tool | `/plan` slash command + `plan_mode_reasoning_effort` (incl. `none`) | Both first-class. |
| Headless mode | `claude -p` | `codex exec` with `--ephemeral`, `--full-auto`, `--json`, `--output-schema`, `--output-last-message`, `resume --last`. Auth via `CODEX_API_KEY`. | Codex headless surface looks more elaborated. |
| Project trust | Implicit | Explicit: `[projects."/path"] trust_level = "trusted"` required before project `.codex/config.toml` is honored | Codex more explicit. |

## Things the docs explicitly DON'T promise

- **Custom slash commands** — `cli/slash-commands` lists only built-ins; `changelog` 2026-01-22 explicitly deprecated "Custom prompts." No file format documented.
- **`feature-maturity` page** is only a glossary of `Under development | Experimental | Beta | Stable` labels — there is no master inventory of which features are which.
- `experimental_environment = "remote"` (MCP), `experimental_compact_prompt_file`, `experimental_bearer_token`, `experimental_use_profile` — labeled experimental in the sample config.
- `[features]` block contains many flags described as "set explicit booleans to opt in/out" — defaults aren't enumerated; behavior depends on Codex's internal defaults.
- Web search flags `web_search`, `web_search_cached`, `web_search_request` under `[features]` are **deprecated** in favor of top-level `web_search`.
- Plain SSE transport for MCP — only "STDIO" and "Streamable HTTP" are documented.
- IDE extension feature parity with CLI — only 8 IDE slash commands; doc says nothing about hooks/skills/automations applying inside the IDE extension specifically.
- Per-skill arguments / templating — docs do not document a `$ARGUMENTS`-style placeholder in SKILL.md.
- `subagents` page does not document a callable tool/function name; invocation is described as natural-language ("spawn an agent...") plus `/agent` for management.
- Cloud Codex configuration — distinct from `config.toml`; documented under `cloud/environments` but the schema isn't reproduced in the config-reference.
- Memories availability: "off by default and aren't available in the European Economic Area, the United Kingdom, or Switzerland at launch."

Key takeaway for the Sage rebuild: Codex's primitives map close to Claude's for **AGENTS.md, skills, hooks, MCP, subagents** (different paths, similar shapes). The two biggest gaps to design around are **no user-defined slash commands** (Codex actively deprecated them in favor of skills) and **automations being app-only** (no CLI cron). The `[features].codex_hooks` flag must be set or hooks silently don't run — that's a likely root cause of any prior "enforcement reverted" attempts.
