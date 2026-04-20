# Platforms

Sage is platform-agnostic at its core. Platform adapters translate Sage's
capabilities into the format each IDE/agent platform expects.

## Supported Platforms

| Platform | Tier | Status | How Sage Integrates |
|----------|:----:|--------|---------------------|
| [Claude Code](claude-code/) | 1 | **Stable** | `CLAUDE.md` + skills in `.claude/` |
| [Antigravity](antigravity/) | 1 | **New** | `GEMINI.md` + `.agent/rules/` + `.agent/skills/` + `.agent/workflows/` |
| [Codex](codex/) | 1 | **New** | `AGENTS.md` + `.agents/skills/` + `.codex/config.toml` |
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
| Workflow entry | Slash commands in `.claude/commands/` | `/fix`, `/build`, `/architect` workflows | Prompt-driven + skill-driven discovery |
| Project config | `.claude/` and plugin assets | `.agent/` | `.codex/config.toml` |
| Project state | `.sage/` | `.sage/` | `.sage/` (shared) |
