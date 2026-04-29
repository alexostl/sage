# Sage on Codex

Technical setup and behavior guide for using Sage with OpenAI Codex.

## Status

The current Codex adapter is a conservative, release-ready port of Sage onto
Codex-native surfaces:

- `AGENTS.md` for always-on instructions
- `.agents/skills/` for workflow and direct skills
- `.codex/config.toml` for project-native Codex config and MCP servers
- Codex-native worktrees, Git flows, `/review`, and multi-agent execution

The adapter intentionally does not try to force full Claude Code UX parity
where Codex has a different or still-evolving native surface.

After deep E2E simulation inside throwaway test repos, the short repair list
identified there has been addressed in this branch. Remaining work is optional
follow-up, not a current release blocker for the port itself.

## Quick Setup

From your project root:

```bash
sage init
# Select Codex, or a multi-platform option that includes Codex
```

Or regenerate the Codex adapter directly:

```bash
bash sage/runtime/platforms/codex/setup/generate-codex.sh .
```

## What Gets Generated

```text
your-project/
├── AGENTS.md                # Codex always-on instructions
├── .agents/
│   └── skills/              # Sage workflow and direct skills
├── .codex/
│   └── config.toml          # Codex-native project config and MCP config
├── .sage/                   # Shared Sage project state
└── sage/                    # Sage framework source
```

## How Sage Maps onto Codex

### `AGENTS.md` = repository instruction entrypoint

Codex reads `AGENTS.md` before doing work. Sage uses the repository-root
`AGENTS.md` as the Codex-native always-on layer for routing, state-first
behavior, workflow gates, and quality expectations.

Current Codex also supports `AGENTS.override.md` and fallback filenames via
`project_doc_fallback_filenames`. Sage does not currently scaffold those
alternate names; the generated root `AGENTS.md` remains the adapter's primary
instruction entrypoint.

### `.agents/skills/` = primary Sage skill surface

Sage deploys workflow and direct skills into `.agents/skills/`.

- Workflow skills package `build`, `fix`, `architect`, `continue`, and the
  rest of the Sage workflow family for Codex-native discovery.
- Direct skills preserve Sage's progressive disclosure model: metadata first,
  `SKILL.md` when chosen, references/scripts only when needed.
- This remains the adapter's primary skill model because current Codex skill
  discovery still scans `.agents/skills` up to the repo root, and Codex's
  external-config import flow also migrates repo skills into `.agents/skills`.

Codex Team Config docs now also mention `.codex/skills/` as a shared team
surface. Sage does not yet generate or mirror `.codex/skills/` automatically,
because doing both naively would risk duplicate skill names and backward
compatibility problems. For now, treat `.codex/skills/` as an optional native
Codex layer you may manage separately, not as Sage's primary contract.

### `.codex/config.toml` = native project config

The adapter generates `.codex/config.toml` as the Codex-native project config
surface. When legacy Sage MCP JSON config exists, the Codex adapter translates
it into native `mcp_servers` entries.

Project-scoped `.codex/config.toml` loads only for trusted projects in Codex.
Sage now manages a marked block inside that file. `sage update` refreshes the
Sage-managed block while preserving user-owned native Codex settings outside
it.

### `.sage/` stays shared

`.sage/` remains the platform-agnostic state directory. Claude Code,
Antigravity, and Codex all read and write the same project state.

## Native Codex Features Sage Can Use

### Workflow entry in Codex

Codex does not need fake Sage-owned slash commands for good workflow entry.
The adapter now leans into Codex's native skill surfaces:

- type `$` to invoke a Sage workflow skill directly
- type `/` to open the slash list; enabled Sage skills also appear there

Recommended posture:

- `$sage` for routing or ambiguous requests
- `$build` for feature work and implementation
- `$fix` for debugging and repair
- `$architect` for redesigns and migrations
- `$continue` to resume in-progress work
- `$status` to inspect project state first
- `/review` as the native diff-review companion, with `$review` when review
  itself is the Sage workflow

This keeps the Codex port intentional and easy to discover without pretending
Codex supports the same custom slash-command layer as Claude Code.

### Worktrees

Codex supports Git worktrees natively in the app, including Local/Worktree
handoff. Sage does not generate a second worktree abstraction; it relies on
Codex's built-in worktree support.

In practice:

- worktrees are available only for Git repositories
- the same generated Sage files work in Local and Worktree checkouts because
  they are just repository files
- background automations in Codex can also run on dedicated worktrees

### Built-in Git flows

Codex includes built-in Git workflows for local and worktree tasks: diff view,
inline comments, staging or reverting chunks/files, commits, pushes, and pull
requests. Sage keeps using those native Git flows instead of layering its own
Git UI on top.

Codex built-in `/review` remains the best native companion for diff-oriented
review passes after implementation.

### Automations

Codex automations are a native app feature, not a Sage-managed scheduler. They
can reuse the same repo skills and can run either in Local mode or on dedicated
background worktrees for Git repositories.

Good fits for Sage-on-Codex automations include:

- recurring repo brief or status summaries
- review or CI triage passes
- lightweight reflect/retro prompts over recent changes

Sage currently documents these patterns and now ships a small template pack in
`sage/runtime/platforms/codex/AUTOMATIONS.md`, but it still does not generate
automation definitions or run its own automation runner inside the adapter.

### Hooks

Codex hooks exist, but they are explicitly experimental in the current official
docs. They require enabling `[features].codex_hooks = true`, and current hook
coverage is partial. In particular, current docs describe the most mature hook
interception around Bash-oriented events; they do not provide full parity for
all tool types or Claude-style lifecycle enforcement. Windows support is also
currently disabled in the official hooks docs.

Sage therefore treats hooks as opt-in and experimental rather than absent.

Minimal opt-in example:

```toml
[features]
codex_hooks = true
```

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.codex/hooks/validate.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

Treat that as a native Codex extension point, not as a full Sage lifecycle
replacement.

The adapter ships a starter pack that is intentionally opt-in but now
strengthens Sage enforcement when enabled:

- `session-start.sh` — rich Sage context on session start (active work
  with titles/status/phase, doc count, 3 latest decisions)
- `pre-prompt.sh` — `UserPromptSubmit` **pre-turn gate**. Matches build /
  fix / architect keywords in free-form prompts and, when required
  `.sage/work/` artifacts are missing, returns `decision: "block"` plus
  an `additionalContext` redirect that puts the agent back on the
  Sage rulebook. This is the strongest Codex-native enforcement lever
  and has no Claude equivalent.
- `pre-bash.sh` / `post-bash.sh` — narrow Bash guardrail and review
  reminder, unchanged from the previous starter.

Docs: `sage/runtime/platforms/codex/HOOKS.md`.
Starter config: `sage/runtime/platforms/codex/hooks.example.json`.
Sample scripts: `sage/runtime/platforms/codex/hooks/`.

Nothing is generated into `.codex/hooks.json` by default. Teams copy and
adapt the starter when they want runtime enforcement on top of the
`AGENTS.md` constitution.

## Enforcement Posture

The adapter uses three layers to keep the agent on the Sage rulebook
rather than treating the framework as inspiration:

1. **Always-on constitution in `AGENTS.md`.** Codex loads `AGENTS.md`
   once per session (root → cwd). The generated file states the
   Process Constitution with **observable compliance signals** per rule
   (e.g. "first line says `Sage → [workflow]`", "both `spec.md` and
   `plan.md` exist on disk before implementation", "completion message
   pastes actual test output"). Signals are what the agent is expected
   to show in its output — drift shows up as missing signals.
2. **First-turn PREAMBLE on workflow skills.** Each generated workflow
   skill in `.agents/skills/<workflow>/SKILL.md` opens with a `RULES
   (apply to every step — non-negotiable)` block. Codex does not carry
   skills across turns, so the PREAMBLE acts as framing when the user
   types `$build`, `$fix`, `$architect`, etc.
3. **Opt-in runtime gates via hooks.** The starter pack in
   `runtime/platforms/codex/hooks/` includes `pre-prompt.sh`, a
   `UserPromptSubmit` pre-turn gate that blocks Standard+ build / fix /
   architect prompts missing their required `.sage/work/` artifacts and
   redirects the model into the right workflow.

Layer 3 is the strongest Codex-native lever, and it is opt-in because
`[features].codex_hooks = true` remains experimental upstream.

4. **Direct skill behavioral isolation via `agents/openai.yaml`.**
   Direct (library-tier) skills are deployed to `.agents/skills/<name>/`
   along with `.agents/skills/<name>/agents/openai.yaml` carrying:
   ```yaml
   policy:
     allow_implicit_invocation: false
   interface:
     short_description: "<copy of SKILL.md description>"
   ```
   Codex still surfaces the skill via `$<name>` invocation and
   workflow `Read` calls, but does **not** auto-suggest the skill on
   description match. Workflow skills (frontmatter `tier: workflow`)
   keep full reactive routing. The `name:` field in `SKILL.md` is
   never altered, so existing slash commands keep working.

## Config Keys

The generator reads `.sage/config.yaml` for project-level toggles:

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `command_prefix` | bool | `false` | Namespace skills as `sage:build`, `sage:fix`, etc. |
| `deploy_direct_skills` | bool | `false` (self-host) | Copy direct (library-tier) skills to `.agents/skills/`. When `true`, each direct skill gets `agents/openai.yaml` with `allow_implicit_invocation: false` for behavioral isolation. |
| `auto_review` | bool | `true` | Enable Gate 4 review sub-agents during `/sage:build` and `/sage:fix`. |
| `auto_qa` | bool | `true` | Enable Gate 8 functional QA. |

`[features].codex_hooks` lives in `.codex/config.toml` (Codex-native),
not `.sage/config.yaml`. It controls layer 3 (hooks). Self-host profile
emits `codex_hooks = true` by default; upstream profile leaves it
commented out.

## Migration: behavioral isolation of direct skills (2026-04-29)

After `sage update`, direct (library-tier) skills no longer auto-suggest
themselves when the user prompt matches their description.

**What changed:**
- Each direct skill in `.agents/skills/<name>/` now ships with
  `agents/openai.yaml` containing `policy.allow_implicit_invocation: false`.
- Codex will not auto-fire `simplify`, `specify`, `evaluate`, etc. on
  prompts like "uprość ten kod" or "make this simpler".

**What still works:**
- Workflow skills (`/sage:build`, `/sage:fix`, `/sage:architect`, etc.)
  auto-trigger via routing keywords as before.
- Direct skills remain explicitly invocable: `$simplify`, `$specify`, etc.
- Workflow skills can still invoke direct skills via `$<name>` or
  by reading `sage/skills/<name>/SKILL.md` from disk.

**How to opt out (per-skill):**
- Delete `.agents/skills/<name>/agents/openai.yaml` (will regenerate on
  next `sage update`).
- For permanent opt-out: change source `SKILL.md` frontmatter to
  `tier: workflow`. The generator then skips yaml emission for that skill.

## Current Limits

- Codex custom workflow entry is prompt-driven and skill-driven rather
  than custom Sage slash-command driven.
- Sage does not claim full Claude parity for hooks, slash commands, or
  lifecycle integrations.
- `.agents/skills/` remains the primary Sage skill surface; there is no
  automatic migration or dual-write into `.codex/skills/`.
- Sage only manages a marked block inside `.codex/config.toml`. Keep
  user-owned Codex settings outside that block to survive regeneration.
- `PreToolUse` gating is available only for Bash in current Codex hook
  docs. File-edit tools (Write / Edit) cannot be gated; "no edits
  before root cause" relies on `pre-prompt.sh` plus the constitution.

## Recent E2E Repairs

The latest E2E simulation surfaced and this branch fixed:

- project-local `sage/bin/sage update`
- false-green MCP discovery for broken servers
- direct-skill refresh on `sage update`
- non-executable `bin/sage` in source checkouts

The adapter now also ships lightweight manual regression scripts:

- `sage/runtime/platforms/codex/tests/run-regression.sh`
- `sage/runtime/mcp/tests/run-regression.sh`

## Open Follow-Up Features

These remain the main non-blocking functional gaps versus the more
mature Claude Code adapter:

- Stronger checkpoint review via `features.guardian_approval` and a
  `sage-reviewer` subagent:
  Codex supports `[agents.<name>]` subagent definitions and an
  experimental `guardian_approval` routing flag. Wiring a dedicated
  `sage-reviewer` subagent (own `AGENTS.md`, own tools policy) would
  let the `[A]` approval gate route through an independent reviewer
  with a fresh context window, operationalizing Rule 5 ("spec
  compliance is adversarial") as a separate process. This is a
  natural next step after `pre-prompt.sh`; not shipped here because
  it expands scope beyond this fix.
- Optional `.codex/skills` dual-support:
  Sage keeps `.agents/skills/` as the primary contract until Codex
  docs and runtime behavior around `.codex/skills/` stabilize.
- CI-backed regression coverage:
  The repo now has manual regression scripts for `sage init`,
  `sage update`, and the Codex MCP path, but they are not yet wired
  into CI or a release gate.

Deliberate non-goals for the conservative port:

- custom Sage-owned slash commands layered on top of Codex
- a Sage-owned automation runner inside Codex
- a large Codex-only cockpit redesign for UX parity

## Switching Between Platforms

Codex can coexist with Claude Code and Antigravity in the same project.
Generate whichever adapters you want; `.sage/` remains shared.

```bash
sage update
```

This regenerates platform files from the checked-in Sage source while keeping
`.sage/` project state shared across adapters. On Codex today, it also refreshes
the Sage-managed block in `.codex/config.toml` from Sage-managed inputs.
