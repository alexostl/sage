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
- For workflow entry, prefer the skill-first path:
  `$sage`, `$build`, `$fix`, `$architect`, `$continue`, `$status`, and
  `$review`. The same enabled skills also show up in the slash list when you
  type `/`, while native `/review` stays the best diff-review companion.
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

Starter materials now ship with the adapter:

- `sage/runtime/platforms/codex/HOOKS.md`
- `sage/runtime/platforms/codex/hooks.example.json`
- `sage/runtime/platforms/codex/hooks/`

Copy them into `.codex/` only when you want an explicit experimental hook
setup.

## Automation examples

The adapter now ships a small examples pack for Codex-native automations:

- `sage/runtime/platforms/codex/AUTOMATIONS.md`

Use thread automations when the work should continue in the same conversation.
Use standalone automations when you want a clean recurring task, especially on
Git repos where Codex can isolate the work on a worktree.

## Operational caveat

`sage update` now refreshes only the Sage-managed block inside
`.codex/config.toml`. Keep user-owned native Codex settings outside that marked
block if you want them preserved across regeneration.

## Recent repair pass

The latest end-to-end simulation found and this branch fixed:

- project-local `sage/bin/sage update`
- false-green MCP discovery for broken servers
- direct-skill refresh on `sage update`
- non-executable `bin/sage` in source checkouts

Manual regression scripts now ship with the adapter:

- `sage/runtime/platforms/codex/tests/run-regression.sh`
- `sage/runtime/mcp/tests/run-regression.sh`

## Open follow-up work

Remaining optional follow-up items are:

- stronger hook enforcement patterns beyond the conservative starter scaffold
- optional future dual-support for `.codex/skills/`
- CI integration for the shipped `init`, `update`, and MCP regression scripts
