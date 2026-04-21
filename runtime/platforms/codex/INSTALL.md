# Install Sage for Codex

## Requirements

- OpenAI Codex installed and authenticated
- Sage framework available in the project
- Git repository if you want native Codex worktrees or worktree-backed
  automations

## Install in an existing project

```bash
sage init
```

Pick a platform option that includes Codex.

## Regenerate after framework updates

```bash
sage update
```

Or regenerate the Codex adapter directly:

```bash
bash sage/runtime/platforms/codex/setup/generate-codex.sh .
```

## Generated files

- `AGENTS.md`
- `.agents/skills/`
- `.codex/config.toml`
- `.sage/` shared project state

## Notes

- Codex reads `AGENTS.md` natively. Current Codex also supports
  `AGENTS.override.md` and fallback filenames, but Sage currently generates the
  root `AGENTS.md` path as its primary instruction entrypoint.
- Sage deploys repo skills into `.agents/skills/`. This stays the primary
  adapter contract for now, even though newer Team Config docs also mention
  `.codex/skills/`.
- Project-scoped `.codex/config.toml` loads only for trusted projects.
- Codex built-in Git flows, worktrees, and automations are native platform
  features. Sage relies on those surfaces instead of generating parallel Git or
  worktree infrastructure.
- Codex hooks exist, but they are experimental and opt-in rather than a default
  Sage lifecycle mechanism.

## Optional hooks enablement

If you want to experiment with native Codex hooks, enable them in
`.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

Then add a repo-local `.codex/hooks.json` only if you have a clear validation or
policy use case. Keep expectations conservative: current Codex hook coverage is
partial and does not provide full Claude-style lifecycle parity.

## Operational caveat

`sage update` now refreshes only the Sage-managed block inside
`.codex/config.toml`. Keep user-owned native Codex settings outside that marked
block if you want them preserved across regeneration.

## Open follow-up work

The current adapter is usable as-is. Remaining optional follow-up items are:

- richer Sage-specific workflow entrypoints beyond prompt-driven routing
- optional hooks scaffold and stronger hook enforcement patterns
- automation templates for recurring Codex tasks
- optional future dual-support for `.codex/skills/`
- automated regression tests for `init`, `update`, and MCP discovery/runtime
