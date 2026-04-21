# Platforms

Sage is platform-agnostic at its core. Platform adapters translate Sage's
capabilities into the format each IDE/agent platform expects.

## Supported Platforms

| Platform | Tier | Status | How Sage Integrates |
|----------|:----:|--------|---------------------|
| [Claude Code](claude-code/) | 1 | **Stable** | `CLAUDE.md` + skills in `.claude/` |
| [Antigravity](antigravity/) | 1 | **New** | `GEMINI.md` + `.agent/rules/` + `.agent/skills/` + `.agent/workflows/` |
| [Codex](codex/) | 1 | **New** | `AGENTS.md` + `.agents/skills/` + `.codex/config.toml` + native worktrees/Git flows |
| [Generic](generic/) | 2 | **Stable** | Markdown-based instructions for any agent |

## Platform Architecture

```
Sage Core (platform-agnostic)
├── capabilities/      # Process engine
├── skills/            # Knowledge + methodology
├── constitution/      # Project principles
└── workflows/         # FIX / BUILD / ARCHITECT

        ↓ Platform Adapter ↓

Claude Code                     Antigravity                   Codex
├── CLAUDE.md                   ├── GEMINI.md                 ├── AGENTS.md
└── .claude/                    ├── .agent/rules/             ├── .agents/skills/
                                ├── .agent/skills/            └── .codex/config.toml
                                └── .agent/workflows/
```

All adapters share the same `.sage/` project state directory.

## Mapping

| Sage Concept | Claude Code | Antigravity | Codex |
|--------------|------------|-------------|-------|
| Constitution (always-on) | Inline in `CLAUDE.md` | `.agent/rules/*.md` | Inline in `AGENTS.md` |
| Skills (on-demand) | Inline or `.sage/skills/` | `.agent/skills/` with `SKILL.md` | `.agents/skills/` with `SKILL.md` |
| Workflow entry | Slash commands in `.claude/commands/` | `/fix`, `/build`, `/architect` workflows | Prompt-driven + skill-driven discovery, with built-in `/review` as a native review companion |
| Project config | `.claude/` and plugin assets | `.agent/` | `.codex/config.toml` (+ optional native `.codex/hooks.json`) |
| Project state | `.sage/` | `.sage/` | `.sage/` (shared) |

## Codex Notes

- The Codex adapter keeps `.agents/skills/` as its primary repo skill surface
  for compatibility with current Codex skills discovery and external-config
  import behavior.
- Codex worktrees, built-in Git flows, and automations are native platform
  features for Git repositories. Sage relies on those platform surfaces instead
  of generating parallel infrastructure.
- Codex hooks exist, but they are currently experimental and opt-in. The
  adapter documents them conservatively and does not claim full Claude-style
  lifecycle parity.
- Relative to Claude Code, the main remaining Codex gaps are a more mature
  hook-enforcement layer, optional future `.codex/skills/` posture if Codex
  stabilizes there, and CI-backed regression coverage for adapter flows.
