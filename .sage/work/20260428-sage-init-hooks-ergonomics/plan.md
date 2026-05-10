---
cycle_id: "20260428-sage-init-hooks-ergonomics"
title: "Fix Plan: bin/sage L5 cross-project ergonomics"
type: fix-plan
workflow: fix
phase: plan
status: completed
scope: standard
created: 2026-04-28
related:
  - .sage/work/20260424-codex-enforcement-hybrid-levers/spec.md
  - .sage/work/20260424-codex-enforcement-hybrid-levers/plan.md
  - bin/sage
  - bin/sage-install-hooks
  - .githooks/pre-commit
  - runtime/platforms/codex/hooks/tests/test_pre_commit_hook.sh
  - runtime/platforms/codex/hooks/tests/test_install_hooks.sh
---

# Fix Plan: bin/sage L5 cross-project ergonomics

## Root cause (from approved gate)

Three independent gaps prevent L5 from functioning cross-project:

- **A.** `.githooks/` lives at framework repo root. `copy_framework` only
  copies `sage/`. Downstream projects after `sage init` never receive the
  hook.
- **B.** `.githooks/pre-commit:26` hardcodes `HOOKS_LIB="$REPO_ROOT/runtime/platforms/codex/hooks"`. After `sage init`
  the validator lives at `<project>/sage/runtime/platforms/codex/hooks/`.
  Copying the hook 1:1 without fixing path resolution would **block
  every Standard+ commit** with "hooks library missing" (lines 121-124).
- **C.** `bin/sage` has no `install-hooks` subcommand, no auto-wire in
  `sage_init`, no first-run nudge. Even sage-codex itself runs with
  dormant L5 — `git config --get core.hooksPath` returns empty.

Sticky-context, validator, and sage-close are useless if the gate that
enforces them at commit time never fires.

## Fix approach

Two complementary mechanisms (the user's options [2] + [3]):

- **Auto-wire path** — extend `sage_init` (new projects) and `sage_update`
  (existing projects) to copy the hook + set `core.hooksPath` if not
  already set.
- **Self-locate path** — make the hook path-flexible so it works for
  both layouts (framework vs downstream), not templated per-project
  (templating means `sage update` clobbers user edits).
- **First-run nudge** — `bin/sage` dispatcher prelude detects "sage
  project + hooks unwired" and prints a one-line suggestion, except
  when the user is running `init`, `update`, `help`, or
  `install-hooks` itself.

## Files to change (5 files)

### 1. `.githooks/pre-commit` — path-flexibility

Replace hardcoded `HOOKS_LIB` resolution with a search list. Two
candidate paths, in order:

1. `$REPO_ROOT/sage/runtime/platforms/codex/hooks` (downstream layout
   after `sage init`)
2. `$REPO_ROOT/runtime/platforms/codex/hooks` (framework / self-host
   layout)

Pick the first that exists. If neither: exit 1 with a message naming
both paths tried (so users know the project is misconfigured, not that
their commit is wrong).

**No backward incompatibility:** existing test fixtures use the
framework layout (path #2); they keep working.

### 2. `bin/sage` — three additive changes

**(a) New function `sage_install_hooks()` near line 825.** Wraps the
logic from `bin/sage-install-hooks` so the dispatcher can call it as
`sage install-hooks`. The standalone `bin/sage-install-hooks` script
stays as a convenience entry point and now delegates to `bin/sage
install-hooks` to avoid drift.

**(b) New step in `sage_init()` after `print_success`** (around line
826) and in `sage_update()` (around line 832): a function call
`ensure_hooks_wired "$target"` that:

- Copies `$SAGE_FRAMEWORK/.githooks/pre-commit` to `$target/.githooks/pre-commit`
  if the target file does not exist OR has identical sha256 (so user
  edits are preserved). On preserved-user-edit case, prints a one-line
  notice, does not abort.
- Runs `git -C "$target" config core.hooksPath .githooks` if `$target`
  is a git repo AND `core.hooksPath` is currently unset OR equals
  `.githooks` (idempotent, never clobbers a custom value).
- Skips silently if `$target` is not a git repo.
- Self-host case: when `framework_repo=true`, the hook source file
  already exists in place (sage-codex/.githooks/pre-commit); just run
  the wire step.

**(c) Dispatcher prelude (around line 1338)** — first-run nudge.
Before the `case "$COMMAND"` block:

```
if _should_nudge_hooks "$COMMAND"; then
  _nudge_hooks_once
fi
```

`_should_nudge_hooks`: returns true iff
- COMMAND is not in {init, update, install-hooks, help, --help, -h, ""}
- Current dir is a git repo
- `.githooks/pre-commit` exists in the repo root
- `core.hooksPath` is unset (or set to something other than `.githooks`)

`_nudge_hooks_once`: prints a single dim-text line:
`Sage: hooks not wired in this clone. Run: sage install-hooks` to stderr.
**Marker mechanism** (plan-reviewer note): hash repo root path with
`git rev-parse --show-toplevel | shasum -a 256 | cut -d' ' -f1 | head -c 12`,
write/touch `/tmp/sage-hooks-nudge.<hash>` on emission, then on next
call read the marker mtime and skip if `now - mtime < 60`. Use
`stat -f %m <file>` (BSD/macOS) with fallback to `stat -c %Y <file>`
(GNU/Linux). Opt-out: `SAGE_HOOKS_QUIET=1` skips the entire prelude.

**(d) New dispatcher case** `install-hooks) sage_install_hooks ;;`.

### 3. `bin/sage-install-hooks` — convergence

Refactor to a thin wrapper around `bin/sage install-hooks` so the two
entry points cannot drift. **No fallback** (plan-reviewer note: cargo
cult — both scripts ship from the same repo, if `bin/sage` is missing
then the standalone script being present alone is also broken). One
source of truth, one failure mode. If `bin/sage` is unreachable, the
script exits with a clear "framework not found" error pointing at
`bin/sage`.

### 4. `runtime/platforms/codex/hooks/tests/test_pre_commit_hook.sh` — new cases

Add two cases to verify the path-flexibility:

- **`case_downstream_layout`**: builds a fixture repo where the
  validator lives under `<repo>/sage/runtime/platforms/codex/hooks/`
  (mimicking post-`sage init` layout), confirms hook finds the
  validator there and gates correctly.
- **`case_neither_layout_present`**: removes both candidate paths;
  hook exits non-zero with both paths named in the error message.

Existing 8 cases keep passing (same fixture layout = framework path
still resolves first or second on the search list).

### 5. `runtime/platforms/codex/hooks/tests/test_sage_init_hooks.sh` — new file

End-to-end test for the auto-wire on `sage init`. Steps:

1. Create a temp dir with `git init`.
2. Run `bin/sage init --self-host --platform codex` (or equivalent
   that does not require interactive prompts).
3. Assert: `<temp>/.githooks/pre-commit` exists.
4. Assert: `git -C <temp> config core.hooksPath` returns `.githooks`.
5. Assert: a fresh commit with valid spec + missing verification.md
   gets blocked by the wired hook (proves end-to-end wiring works).

**Drive non-interactively** — `sage init --self-host --platform codex
--preset base` already bypasses interactive prompts (line 469
`PRESET_FLAG`, line 359 `PLATFORM_FLAG`). For re-init confirm prompt
(line 813), pipe `printf 'A\n'`. Plan-reviewer note: do NOT fall back
to direct-call testing as primary path — the end-to-end commit-block
assertion is the most important coverage. If end-to-end driving fails,
add BOTH a direct `ensure_hooks_wired` call test AND a separate test
that drives a real commit block against an `ensure_hooks_wired`-prepared
repo.

## Tests to add or modify

- `test_pre_commit_hook.sh`: +2 cases (downstream layout, neither
  layout). Existing 8 keep passing.
- `test_install_hooks.sh`: existing 4 cases keep passing — the standalone
  `bin/sage-install-hooks` still works.
- `test_sage_init_hooks.sh`: new file, ~3-5 cases for the init/update
  wiring.
- Manual smoke after merge: `cd /Users/alexostl/Developer/sage-codex &&
  bin/sage install-hooks` should set `core.hooksPath` on this repo,
  then a Standard+ commit attempt without verification.md should be
  blocked.

## Rollback approach

The fix is additive and behavior-preserving for the framework-layout case:

- Path-flexibility is backward-compatible (framework path is still in
  the search list).
- Auto-wire skips silently when not in a git repo or when
  `core.hooksPath` is already user-set to a custom value.
- First-run nudge prints once per minute to stderr; opt-out by setting
  `SAGE_HOOKS_QUIET=1` env var.

If something breaks: `git revert` of the fix commit returns to today's
behavior (hook works in framework, dormant in downstream). No data
migration, no schema changes, no irreversible operations.

## Risks

- **R1.** Auto-wire on `sage update` runs against existing projects
  that may have intentionally disabled hooks. Mitigation: only set
  `core.hooksPath` when unset OR already `.githooks`; never clobber.
- **R2.** Path search picks wrong layout when both exist (rare —
  developer-only edge case). Mitigation: search downstream layout
  first, since it is the more likely user scenario; framework layout
  works as fallback.
- **R3.** `sage init`'s interactive flow may resist non-interactive
  driving in T9-equivalent end-to-end test. Mitigation: scope the test
  to `ensure_hooks_wired` directly, document the boundary.
- **R4.** First-run nudge becomes spam if marker file mechanism fails.
  Mitigation: marker is in `/tmp/sage-hooks-nudge.<repo-hash>`,
  expires after 60 seconds; opt-out env var documented.

## Out of scope (explicit)

- Cross-project hook content evolution as a versioning system (semver,
  upgrade prompts, deprecation warnings). **However**: `ensure_hooks_wired`
  uses a sha256 match check that has the side-effect of auto-upgrading
  unmodified hooks (if user never edited the hook, framework's newer
  version replaces it transparently). User-edited hooks are preserved
  with a one-line notice. This is intended behavior — call it out in
  the implementation comment so future maintainers do not "fix" it.
- Wiring hooks for non-git directories (no git repo = no hooks; no fix
  for that).
- Other git hook events (post-commit, pre-push) — only `pre-commit`
  in scope.
- Rewriting `bin/sage init`'s interactive flow to be non-interactive
  (test workaround instead).

## Order of work

1. **`.githooks/pre-commit` path-flexibility** + add 2 new test cases.
   Verify all 10 pre-commit tests pass before touching anything else.
2. **`bin/sage` `ensure_hooks_wired` function** + standalone test
   driving it. Verify it correctly handles new project, existing
   wiring, custom user wiring, non-git, self-host.
3. **`bin/sage` dispatcher case** for `install-hooks` + nudge prelude.
   Verify nudge fires/skips for the right command set.
4. **`sage_init` and `sage_update`** call `ensure_hooks_wired`. Verify
   end-to-end via `test_sage_init_hooks.sh`.
5. **`bin/sage-install-hooks`** delegate refactor.
6. **README** update — edit the "Repo hooks" section (added in
   `20260424-codex-enforcement-hybrid-levers`, ~line 232 of README.md):
   replace `bin/sage-install-hooks` references with `sage install-hooks`
   as the canonical command, and add one sentence noting that
   `sage init`/`sage update` auto-wire on a fresh clone. Standalone
   `bin/sage-install-hooks` script kept for users who run it from
   muscle memory.
7. Self-test on this very repo: `bin/sage install-hooks`, then attempt
   a Standard+ commit without verification.md, see the block fire.
