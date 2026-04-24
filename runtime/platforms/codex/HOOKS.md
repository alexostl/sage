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

- **Explicit skill invocation** — any prompt starting with `$<skill>` or
  `/<skill>` (e.g. `$build`, `/status`, `$autoresearch`,
  `/design-review`) is allowed through unconditionally. The skill's
  PREAMBLE runs its own gate. Pattern:
  `^\s*[$/][a-z][a-z0-9-]*(?:\s|$)` — works for every current and future
  workflow skill without maintaining a whitelist.
- **Tier 1 read-only questions** (`what`, `why`, `how`, `show`, `list`,
  `explain`, `describe`, …) pass through without matching.
- **Tier 1 fixes** (`typo`, `indent`, `whitespace`, `formatting`,
  `rename`, `comment`, `log statement`, `import`, `lint`, `docstring`,
  `spelling`, …) pass through with a soft nudge that reminds the agent
  to escalate if the work turns out to touch 3+ files or change
  behavior broadly. Matches `fix.workflow.md` Surgical carve-out.
- **Build-keyword prompts** block when **no active initiative** has
  both `spec.md` and `plan.md` on disk. "Active" means the initiative's
  frontmatter `status` is non-terminal (anything other than `completed`
  or `abandoned`). Completed prior initiatives no longer satisfy the
  gate — each new build needs its own active spec + plan pair.
- **Build verbs are verb + noun.** `build a feature`, `implement a new
  endpoint`, `add a migration` match. `add tests`, `add logging` do
  not (they fall through to the default allow path; AGENTS.md Rule 3
  and the `$build` PREAMBLE are the second line of defense).
- **Architect-keyword prompts** block when no active initiative has
  `brief.md` on disk.
- **Fix-keyword prompts that are not Tier 1** always redirect to the
  root-cause gate, because the fix rule is behavioral (root cause
  approved), not file-backed.

Edit the regex patterns in `pre-prompt.sh` if your repo needs a
narrower or broader match set — especially the `BUILD_NOUNS` list,
which controls what counts as a "concrete build target". The hook
never crashes your session on malformed stdin or missing tools — it
exits silently and lets the turn through.

### Why status-aware (and not global)

An earlier version of this gate used a global check: "any
`.sage/work/*/spec.md` + `plan.md` anywhere satisfies the build gate."
That held for the first build of a new project, then passed every
subsequent unrelated build prompt because prior completed initiatives
still had their files on disk. The current check restricts
satisfaction to initiatives in a non-terminal status, which matches how
the human actually uses `.sage/work/`: completed work is reference,
not authorization for new work.

If an initiative stays `status: in-progress` after its work is really
done, the gate will be permissive for that project until the status is
flipped to `completed`. Session-start already surfaces in-progress
initiatives to make this drift visible.

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

## Future considerations

- **AGENTS.md size escape hatch.** The generated AGENTS.md is currently
  ~12 KiB, comfortably under Codex's 32 KiB cap. If future enforcement
  additions push it above ~20 KiB, split the Workflow Gates block to a
  dedicated `sage/core/constitution/workflow-gates.md` and reference it
  via `@` imports so only the top-level rules stay always-on.
- **Initiative-slug-aware build gate.** The current build gate accepts
  passthrough if *any* active initiative has a complete spec + plan
  pair. A stricter variant would parse an initiative slug from the
  prompt (e.g. `build the payments thing` → match `payments`) and
  require the matching initiative specifically. Deferred — current
  heuristic is "good enough and beats global passthrough", and a
  slug-parser would introduce fragile regex logic without a clear win.
