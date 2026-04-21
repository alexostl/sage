# Sage Starter Hooks for Codex

Codex hooks are currently experimental. Treat this starter pack as an opt-in
native extension point, not as full Claude-style lifecycle enforcement.

The examples here are intentionally conservative:

- `SessionStart` adds light Sage-specific orientation
- `PreToolUse` only watches Bash commands
- `PostToolUse` only reacts to Bash results and adds a gentle review reminder

Nothing in this folder is enabled by default.

## Enable Hooks

First, opt into hooks in `.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

Then copy the starter files into your repo-local Codex config:

```bash
mkdir -p .codex/hooks
cp sage/runtime/platforms/codex/hooks.example.json .codex/hooks.json
cp sage/runtime/platforms/codex/hooks/*.sh .codex/hooks/
chmod +x .codex/hooks/*.sh
```

## What the Starter Pack Does

- `session-start.sh`
  Adds a small reminder to read `.sage/work/` and `.sage/decisions.md` before
  substantial work.
- `pre-bash.sh`
  Demonstrates a narrow Bash guardrail by blocking a short list of clearly
  destructive commands. Edit this list to match your repo's safety posture.
- `post-bash.sh`
  Adds a review reminder after Bash commands that look like they may have
  mutated files.

## Deliberate Limits

- No Windows-specific support
- No claim of parity with Claude hook ecosystems
- No assumption that every tool type emits the same hook coverage
- No automatic generation into projects; teams opt in manually when they have a
  concrete need

If you need a stronger hook policy later, use this starter pack as a seed and
grow it incrementally.
