# Sage Starter Hooks for Codex

Codex hooks are experimental and opt-in. Treat this starter pack as a
native extension point that **strengthens enforcement** of the Sage
Process Constitution from `AGENTS.md`. Without hooks, the constitution
still applies; hooks are belt-and-suspenders.

The starter pack now ships four scripts:

- `session-start.sh` — rich Sage context on session start (active work
  from `.sage/work/*/` frontmatter, doc count, 3 latest decisions).
- `pre-prompt.sh` — **pre-turn gate**. When a prompt matches `build` /
  `fix` / `architect` keywords and the required `.sage/work/` artifact
  is missing, the hook returns `decision: "block"` with an
  `additionalContext` block that redirects the model into the right
  workflow. This is Codex's strongest lever for keeping the agent on
  the Sage rulebook — the model never sees the original prompt without
  the redirect.
- `pre-bash.sh` — narrow Bash guardrail blocking clearly destructive
  commands.
- `post-bash.sh` — review reminder after Bash commands that may have
  mutated files.

Nothing in this folder is enabled by default.

## Why `pre-prompt.sh` matters

Codex builds the instruction chain (`AGENTS.md`) **once per session**,
walking root → cwd. Skills are eager-loaded only by `name` +
`description`; their bodies are read on activation and are not carried
across turns unless re-mentioned. That makes free-form prompts like
"add a login button" the weakest point in enforcement — the model can
drift from the constitution because no runtime gate fires on the prompt.

`UserPromptSubmit` is the only pre-turn hook Codex exposes, and it can
both `block` and inject `additionalContext`. That combination is the
strongest native mechanism for converting "framework as inspiration"
into "framework as rulebook" on Codex.

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

Restart your Codex session (or start a new one) so the hook config is
picked up.

## Tuning `pre-prompt.sh`

The gate is narrow on purpose:

- Explicit `$skill` / `/slash` invocations are always allowed through —
  skills run their own gate.
- Tier 1 questions (`what`, `why`, `how`, `show`, `list`, `explain`,
  …) pass through without matching.
- Build-keyword prompts only block when **neither** `spec.md` nor
  `plan.md` exists anywhere in `.sage/work/*/`.
- Architect-keyword prompts block when no `brief.md` exists.
- Fix-keyword prompts always redirect to the root-cause gate, because
  the fix rule is behavioral, not file-backed.

Edit the regex patterns in `pre-prompt.sh` if your repo needs a
narrower or broader match set. The hook never crashes your session on
malformed stdin or missing tools — it exits silently and lets the turn
through.

## Deliberate Limits

- No Windows-specific support (upstream Codex hook limitation).
- No claim of parity with Claude hook ecosystems.
- `PreToolUse` gating is available only for Bash in current Codex
  hook docs. File-edit tools (Write / Edit) cannot be gated today, so
  enforcement of "no edits before root cause" relies on
  `pre-prompt.sh` + the constitution in `AGENTS.md`.
- No automatic generation into projects; teams opt in manually.

## Stronger options (not in the starter pack)

For checkpoint review delegation via a dedicated reviewer subagent,
see `[agents.sage-reviewer]` and `[features].guardian_approval` in
`README.md` — documented as an optional follow-up, not shipped here.

If you need stronger policy later, use this starter pack as a seed and
grow it incrementally.
