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

Sage currently documents these patterns but does not generate automation
definitions or run its own automation runner inside the adapter.

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

## Current Limits and Posture

- Codex custom workflow entry is prompt-driven and skill-driven rather than
  custom Sage slash-command driven.
- Sage does not claim full Claude parity for hooks, slash commands, or
  lifecycle integrations.
- `.agents/skills/` remains the primary Sage skill surface for now; there is no
  automatic migration or dual-write into `.codex/skills/`.
- Sage only manages a marked block inside `.codex/config.toml`. Keep user-owned
  Codex settings outside that block if you want them to survive regeneration.

## Recent E2E Repairs

The latest E2E simulation surfaced and this branch fixed:

- project-local `sage/bin/sage update`
- false-green MCP discovery for broken servers
- direct-skill refresh on `sage update`
- non-executable `bin/sage` in source checkouts

## Open Follow-Up Features

These remain the main non-blocking functional gaps versus the more mature
Claude Code adapter:

- Native Sage workflow entrypoints:
  Codex does not provide Sage-owned slash commands like `/sage`, `/build`, or
  `/fix`. Current workflow entry is prompt-driven and skill-driven.
- Stronger hook enforcement:
  Codex hooks exist, but Sage does not yet ship a mature, ready-to-enable hook
  pack equivalent to Claude's deeper lifecycle enforcement.
- Automation templates:
  Codex automations fit Sage workflows well, but the adapter does not yet ship
  ready-made recurring task templates such as repo brief, CI triage, or
  reflect/retro automation examples.
- Optional hook scaffolding:
  The adapter documents hooks and preserves `.codex/hooks.json` as the native
  path, but it does not yet generate an optional starter scaffold by default.
- Optional `.codex/skills` dual-support:
  Sage keeps `.agents/skills/` as the primary contract until Codex docs and
  runtime behavior around `.codex/skills/` are stable enough to support safely.
- Lightweight regression checks:
  The port has been smoke-tested manually, but the repo still lacks automated
  regression coverage for `sage init`, `sage update`, and the Codex MCP path.

## Switching Between Platforms

Codex can coexist with Claude Code and Antigravity in the same project.
Generate whichever adapters you want; `.sage/` remains shared.

```bash
sage update
```

This regenerates platform files from the checked-in Sage source while keeping
`.sage/` project state shared across adapters. On Codex today, it also refreshes
the Sage-managed block in `.codex/config.toml` from Sage-managed inputs.
