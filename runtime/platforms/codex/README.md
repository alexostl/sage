# Sage on Codex

Setup guide for using Sage with OpenAI Codex.

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

## How It Works

### AGENTS.md = always-on routing and process

Codex reads `AGENTS.md` before doing any work. Sage uses that file as the
Codex-native always-on layer: routing, state-first behavior, workflow gates,
and quality expectations live there.

### Skills = lazy loading and workflow entry

Sage deploys workflow and direct skills into `.agents/skills/`.

- Workflow skills package `build`, `fix`, `architect`, `continue`, and the
  rest of the Sage workflow family for Codex-native discovery.
- Direct skills preserve Sage's progressive disclosure model: metadata first,
  `SKILL.md` when chosen, references/scripts only when needed.

### .codex/config.toml = native project config

The adapter generates `.codex/config.toml` as the Codex-native config surface.
When legacy Sage MCP JSON config exists, the Codex adapter translates it into
Codex-native `mcp_servers` entries.

### .sage/ stays shared

`.sage/` remains the platform-agnostic state directory. Claude Code,
Antigravity, and Codex all read and write the same project state.

## Current Limits

- Codex custom workflow entry is prompt-driven and skill-driven rather than
  custom slash-command driven.
- Hook parity is intentionally partial for now. Official Codex hooks are still
  under development, so Sage does not claim full lifecycle-hook parity yet.
- Codex built-in `/review` is still useful and should be preferred for
  diff-oriented review passes after implementation.

## Switching Between Platforms

Codex can coexist with Claude Code and Antigravity in the same project.
Generate whichever adapters you want; `.sage/` remains shared.

```bash
sage update
```

This regenerates platform files from the checked-in Sage source without
touching `.sage/` state.
