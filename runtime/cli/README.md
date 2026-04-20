# Sage CLI

`runtime/cli` is the npm bridge for Sage's canonical shell CLI in
[`bin/sage`](../../bin/sage).

It no longer maintains a separate installer implementation. This keeps
platform support consistent across Claude Code, Antigravity, and Codex.

## Supported Commands

```bash
npx sage-kit init --platform codex
npx sage-kit new my-app --platform claude-code,codex
npx sage-kit update
npx sage-kit status
```

## Notes

- `init`, `new`, `update`, `upgrade`, `learn`, `setup`, `find`, `add`,
  `remove`, and `skills` forward directly to `bin/sage`.
- `status` remains a lightweight npm-native readout.
- The shell CLI is the source of truth for adapter generation.
