# Install Sage for Codex

## Requirements

- OpenAI Codex installed and authenticated
- Sage framework available in the project

## Install in an existing project

```bash
sage init
```

Pick a platform option that includes Codex.

## Regenerate after framework updates

```bash
sage update
```

## Generated files

- `AGENTS.md`
- `.agents/skills/`
- `.codex/config.toml`
- `.sage/` shared project state

## Notes

- Codex reads `AGENTS.md` natively and scans `.agents/skills`.
- Project-scoped `.codex/config.toml` loads only for trusted projects.
- Sage currently treats Codex hooks as partial support; hook lifecycle parity is
  intentionally conservative until the Codex hook surface stabilizes.
