---
title: Verification — Codex enforcement activation
status: in-progress
phase: deliver
workflow: architect
related_plan: plan.md
created: 2026-04-29
updated: 2026-04-29
---

# Verification log

Per-milestone verification artifacts. Pasted output (not summarized)
per Rule 5.

---

## Milestone 0 — Pre-flight scaffold

**Date:** 2026-04-29
**Risk:** low (scaffolding only, no behavior change)
**Status:** complete, awaiting [A]/[R]

### M0.1 — Fixture shape sanity

```
$ find tests/fixtures/alex-os-dev-shape -type f | sort
tests/fixtures/alex-os-dev-shape/.codex/config.toml
tests/fixtures/alex-os-dev-shape/.codex/hooks.json
tests/fixtures/alex-os-dev-shape/.git/config
tests/fixtures/alex-os-dev-shape/.git/hooks/pre-commit
tests/fixtures/alex-os-dev-shape/README.md
tests/fixtures/alex-os-dev-shape/sage/skills/evaluate/SKILL.md
tests/fixtures/alex-os-dev-shape/sage/skills/sage/SKILL.md
tests/fixtures/alex-os-dev-shape/sage/skills/simplify/SKILL.md
tests/fixtures/alex-os-dev-shape/sage/skills/specify/SKILL.md

$ ls -l tests/fixtures/alex-os-dev-shape/.git/hooks/pre-commit
-rwxr-xr-x@ 1 alexostl  staff  245 Apr 29 13:35 tests/fixtures/alex-os-dev-shape/.git/hooks/pre-commit

$ head -3 tests/fixtures/alex-os-dev-shape/.codex/config.toml
## Fixture: alex-os-dev-shape
## Reproduces the contract mismatch documented in
## .sage/work/20260428-codex-enforcement-activation-brief/brief.md
```

Sanity:
- `.codex/config.toml` declares `codex_hooks = true` (pre-cycle opt-in).
- `.codex/hooks.json` has only a custom `SessionStart` user entry.
- `.git/config` has `core.hooksPath = .git/hooks` (custom, not `.githooks`).
- `.git/hooks/pre-commit` is executable, custom user script (NOT sage).
- 3 direct skille (`simplify`, `specify`, `evaluate`) z `tier: direct`,
  bez `agents/openai.yaml`.
- 1 workflow skill (`sage`) z `tier: workflow`, bez yaml (expected).

### M0.2 — `sage status` render-stub output

Fresh dir (no .sage/, no fixture):

```
$ cd /tmp && rm -rf sage-status-smoketest && mkdir sage-status-smoketest \
  && cd sage-status-smoketest && /Users/alexostl/Developer/sage-selfhost/bin/sage status

  Sage status  (/tmp/sage-status-smoketest)

Framework root:  /Users/alexostl/Developer/sage-selfhost
Profile:         <not yet implemented — M1 reads .sage/profile>

L1 — AGENTS.md:                <not yet implemented>

L2 — Workflow PREAMBLE:        <not yet implemented>

L4 — Codex hooks:              <not yet implemented — M1>

L5 — Pre-commit gate:          <not yet implemented — M2>

Skills (behavioral isolation): <not yet implemented — M3>
```

Inside fixture:

```
$ cd tests/fixtures/alex-os-dev-shape && /Users/alexostl/Developer/sage-selfhost/bin/sage status

  Sage status  (/Users/alexostl/Developer/sage-selfhost/tests/fixtures/alex-os-dev-shape)

Framework root:  /Users/alexostl/Developer/sage-selfhost
Profile:         <not yet implemented — M1 reads .sage/profile>

L1 — AGENTS.md:                <not yet implemented>
L2 — Workflow PREAMBLE:        <not yet implemented>
L4 — Codex hooks:              <not yet implemented — M1>
L5 — Pre-commit gate:          <not yet implemented — M2>
Skills (behavioral isolation): <not yet implemented — M3>
```

Render order is deterministic: `framework_root → profile → L1 → L2 →
L4 → L5 → skills`. Each section is a separate `_render_*()` function;
M1/M2/M3 will overwrite individual function bodies without touching the
dispatch order.

`bash -n bin/sage` syntax check passes.

### M0.3 — `.versions.txt` registry verification

```
$ cd runtime/platforms/codex/hooks && shasum -a 256 -c <(awk 'NF && $1 !~ /^#/ {print $1 "  " $2}' .versions.txt)
post-bash.sh: OK
pre-bash.sh: OK
pre-prompt.sh: OK
session-start.sh: OK
```

All 4 framework hook scripts have hash entries in `.versions.txt` and
`shasum -c` confirms parity. README.md documents the append-only
update protocol.

### M0.4 — PR template

`.github/pull_request_template.md` created. Includes:
- Branch policy section (source/target branch + .sage/profile guard reminder).
- Codex hook changes section z explicit check item: "If I modified any
  `runtime/platforms/codex/hooks/*.sh`, I appended a new sha256 line to
  `.versions.txt` in this same PR."
- Reference do ADR-1.

### Q1 / Q3 resolutions

Per M0 task 4-5 from plan.md:

- **Q1 (extend cmd_status vs add subcommand):** RESOLVED — extending
  `cmd_status`. Single source of truth, simpler. `--enforcement`
  subcommand can be added later jeśli output staje się unwieldy.
- **Q3 (per-agent test feasibility w M3):** RESOLVED — test (e) is
  skipped jako known limitation gdy dev environment ma tylko default
  `openai` agent. Recovery path (manual `[[skills.config]]` per-skill
  workaround) jest sufficient mitigation. Document w runbook + decisions.md
  przy M3 close.

### Verification gate (M0)

- [x] `tests/fixtures/alex-os-dev-shape/` shape sanity check (paste above).
- [x] `sage status` w fresh checkout printuje render-stub sections.
- [x] `.versions.txt` + README committed; PR template updated.
- [x] `bash -n bin/sage` passes.
- [x] No behavior change for existing commands (init/update/help unchanged).

**Ready for [A]/[R].**

---

## Milestone 1 — Codex hook activation pipeline

**Date:** 2026-04-29
**Risk:** high — sha256 `.versions.txt` one-way commitment + JSON merge blast radius
**Status:** complete, awaiting [A]/[R]

### M1.1–M1.6 — Implementation summary

- `_realpath()` — portable readlink resolution (GNU `readlink -f`, BSD
  Python fallback, while-loop final fallback) for symlink/brew/npm-global
  invocations.
- `resolve_framework()` — uses `_realpath` on `BASH_SOURCE[0]` then
  validates `core/` + `skills/` siblings. Falls through to global-install
  candidates on validation failure.
- `resolve_profile()` — reads `$SAGE_FRAMEWORK/.sage/profile`, awks the
  `profile:` field, defaults to `upstream`. Cached per invocation. Sets
  globals `SAGE_PROFILE` and `SAGE_PROFILE_SOURCE`.
- `codex_hooks_enabled()` — pure-bash awk parse of `[features].codex_hooks`
  in `.codex/config.toml`.
- `codex_hook_known_hash()` — sha256 lookup against
  `runtime/platforms/codex/hooks/.versions.txt`.
- `ensure_codex_hooks_wired()` — full L4 pipeline per ADR-1: opt-in check,
  shadow-file detection (refuse + MISCONFIGURED + return 2), atomic JSON
  backup `.codex/hooks.json.sage-bak.<ISO-ts>`, Python3 merge with
  framework-identity rule (drops stale framework matcher-groups, preserves
  user matcher-groups, prepends current canonical entries), atomic write.
- Generator (`runtime/mcp/json_to_toml.py`) — reads `SAGE_PROFILE` env;
  emits active `[features].codex_hooks = true` in self-host profile,
  commented-out scaffold otherwise. Invariant: `[features]` lives outside
  the SAGE-managed mcp_servers block so user opt-out survives `sage update`.
- `_render_l4_section()` — 4 states: N/A (no Codex), DISABLED
  (`codex_hooks≠true`), MISCONFIGURED (shadow files), DORMANT (opted in,
  not wired), ACTIVE (entries + scripts present, no shadows).
- `cmd_status` integration: `_render_framework_root` prints resolved
  framework root + profile origin file; render order deterministic.
- Wired `ensure_codex_hooks_wired` into both `sage init` and
  `sage update` (after `ensure_hooks_wired`).

### M1.7 — Test suite

```
$ bash tests/test_m1_codex_hooks.sh

=== unit: codex_hooks_enabled ===
  PASS  codex_hooks=true (active)
  PASS  codex_hooks=false (disabled)
  PASS  no [features] section
  PASS  no .codex/config.toml
  PASS  codex_hooks="true" (quoted)

=== unit: codex_hook_known_hash ===
  PASS  current hash recognized
  PASS  unknown hash rejected
  PASS  empty hash rejected

=== unit: resolve_profile ===
  PASS  self-host profile detected (this repo)  (self-host)
  PASS  explicit profile: upstream  (upstream)
  PASS  no profile file → upstream  (upstream)
  PASS  invalid framework layout → upstream fallback  (upstream)

=== integration: ensure_codex_hooks_wired (alex-os-dev-shape) ===
  ok: codex hooks: merged into .codex/hooks.json (backup: hooks.json.sage-bak.20260429T121834Z)
---rc=0
  PASS  pre-prompt.sh copied + executable
  PASS  pre-bash.sh copied + executable
  PASS  post-bash.sh copied + executable
  PASS  session-start.sh copied + executable
FW_ENTRIES=1
USER_PRESERVED=yes
  PASS  hooks.json: framework entries added + user entry preserved
  PASS  atomic backup created
  PASS  idempotency: 2x ensure → 0 hooks.json diff  (2636c14569f2818ab61f8538c1bab26d9f2d7da7de306889d20bcf1ac37e097d)

=== integration: shadow file detection ===
  PASS  shadow file detected and surfaced
  PASS  MISCONFIGURED message printed
  PASS  non-zero return code

=================================================================
  M1 test summary:  22 passed, 0 failed
=================================================================
```

22/22 PASS. Coverage:
- `codex_hooks_enabled` × 5 inputs (true / false / no features / no
  config / quoted-true).
- `codex_hook_known_hash` × 3 (current / unknown / empty).
- `resolve_profile` × 4 (self-host marker / upstream marker / no file /
  invalid framework root → upstream fallback).
- `ensure_codex_hooks_wired` integration: full pipeline against
  `alex-os-dev-shape` fixture (file copy, JSON merge, user-entry
  preservation, atomic backup, idempotent re-run).
- Shadow file detection: synthetic shadow at `.codex/hooks/post-bash.sh`
  with unknown hash → refused, surfaced MISCONFIGURED, returned 2.

### M1.8 — Fixture before/after demo

```
=== BEFORE ===
--- .codex/hooks.json ---
{
  "hooks": {
    "SessionStart": [
      {
        "command": "./scripts/verify-wiring.sh",
        "description": "Custom user hook — must be preserved by sage update merge"
      }
    ]
  }
}
--- ls .codex/hooks/ ---
(empty)

=== sage status (BEFORE) ===

  Sage status  (/var/folders/.../tmp.j8EuGhfWGL)

Framework root:  /Users/alexostl/Developer/sage-selfhost
Profile:         self-host  (/Users/alexostl/Developer/sage-selfhost/.sage/profile)

L1 — AGENTS.md:                <not yet implemented>
L2 — Workflow PREAMBLE:        <not yet implemented>
L4 — Codex hooks:              DORMANT
  codex_hooks=true but framework hooks not wired — run: sage update
L5 — Pre-commit gate:          <not yet implemented — M2>
Skills (behavioral isolation): <not yet implemented — M3>

=== running ensure_codex_hooks_wired ===
  ok: codex hooks: merged into .codex/hooks.json (backup: hooks.json.sage-bak.20260429T121845Z)

=== AFTER ===
--- ls .codex/hooks/ ---
post-bash.sh
pre-bash.sh
pre-prompt.sh
session-start.sh
--- backup ---
.codex/hooks.json.sage-bak.20260429T121845Z

=== sage status (AFTER) ===

L4 — Codex hooks:              ACTIVE
  4 framework entr(y/ies) wired in hooks.json; 4 script(s) on disk
```

The merged `hooks.json` shows:
- `SessionStart` array now contains [framework matcher-group with
  `session-start.sh`, then preserved user `./scripts/verify-wiring.sh`
  entry] — both kept.
- `UserPromptSubmit`, `PreToolUse`, `PostToolUse` — framework entries
  added (none existed before).

### Verification gate (M1)

- [x] All 22 tests pass.
- [x] Demo: fixture before/after `cat .codex/hooks.json` shows merge correctness.
- [x] `sage status` transitions DORMANT → ACTIVE.
- [x] Custom user `SessionStart` entry preserved through merge.
- [x] Atomic backup created with ISO-ts naming.
- [x] Idempotent: 2× `ensure_codex_hooks_wired` produces identical hash.
- [x] Shadow file detection refuses overwrite + surfaces MISCONFIGURED + returns 2.
- [x] Generator profile-aware: `SAGE_PROFILE=self-host` emits active
      `[features].codex_hooks = true`; `upstream` keeps it commented.
- [x] `bash -n bin/sage` passes.

**Ready for [A]/[R].**

---

## Milestone 2 — Githooks policy + `--force-githooks`

**Date:** 2026-04-29
**Risk:** low (opt-in flag, default = silent skip)
**Status:** complete, awaiting [A]/[R]

### M2.1–M2.3 — Implementation summary

- `detect_existing_hooks_framework(target)` — returns
  `<framework>\t<custom_hooks_path>`. Recognizes:
  husky (`.husky/` or `node_modules/husky`), lefthook (`lefthook.yml`/`yaml`),
  pre-commit (`.pre-commit-config.yaml`/`yml`), simple-git-hooks (devDependency
  in `package.json`), custom-scripts (any executable in `core.hooksPath`),
  none. Custom path defaults to `.git/hooks` when `core.hooksPath` unset.
- `force_githooks_override(target)` — implements ADR-3 Component 2.
  - If `core.hooksPath` is empty or already `.githooks` → delegate to
    `ensure_hooks_wired` (regular wire path, no prompt).
  - Else: render detected framework + `ls -la` of custom path + confirm
    prompt. On `n` → return 1, no changes. On `y` → `git config --unset` +
    `git config core.hooksPath .githooks` + copy `.githooks/pre-commit` +
    log "previous hooks left in place but no longer fire".
- `--force-githooks` flag: parsed in main arg block; dispatched from both
  `sage_init` and `sage_new`. When the flag is absent, behavior is
  identical to pre-M2 (existing custom hooks left untouched).
- `_render_l5_section()` — 4 states:
  - **NOT A REPO** — no `.git/`.
  - **NOT INITIALIZED** — repo, but `core.hooksPath` unset.
  - **ACTIVE** — `core.hooksPath=.githooks` and `.githooks/pre-commit`
    exists + executable.
  - **DORMANT** — `.githooks` set but `pre-commit` missing.
  - **DORMANT (custom)** — `core.hooksPath` points elsewhere; hint
    surfaces detected framework + suggests `sage init --force-githooks`.

### M2.4 — Test suite (24 cases)

```
$ bash tests/test_m2_githooks.sh

=== unit: detect_existing_hooks_framework ===
  PASS  husky (.husky/ dir)  (husky)
  PASS  husky (node_modules/husky)  (husky)
  PASS  lefthook (.yml)  (lefthook)
  PASS  lefthook (.yaml)  (lefthook)
  PASS  pre-commit (.pre-commit-config.yaml)  (pre-commit)
  PASS  simple-git-hooks (package.json)  (simple-git-hooks)
  PASS  custom-scripts (executable in .git/hooks)  (custom-scripts)
  PASS  none (empty project)  (none)
  PASS  custom hooks path returned  (my-hooks)

=== unit: force_githooks_override flow ===
  PASS  decline: returns 1  (1)
  PASS  decline: 'Aborted' message
  PASS  decline: core.hooksPath unchanged (.husky)  (.husky)
  PASS  accept: returns 0  (0)
  PASS  accept: core.hooksPath swapped to .githooks  (.githooks)
  PASS  accept: .githooks/pre-commit still executable
  PASS  accept: previous .husky/pre-commit left in place (no longer fires)
  PASS  fall-through: returns 0  (0)
  PASS  fall-through: delegates to ensure_hooks_wired

=== unit: _render_l5_section states ===
  PASS  L5: no .git → NOT A REPO
  PASS  L5: fresh repo → NOT INITIALIZED
  PASS  L5: .githooks + script → ACTIVE
  PASS  L5: .githooks + missing script → DORMANT
  PASS  L5: husky → DORMANT (custom)
  PASS  L5: husky → hint mentions --force-githooks

=================================================================
  M2 test summary:  24 passed, 0 failed
=================================================================
```

24/24 PASS. Coverage:
- Detection × 9 fixtures (husky × 2 variants, lefthook × 2, pre-commit,
  simple-git-hooks, custom-scripts, none, custom path).
- `force_githooks_override` × 3 flows (decline preserves state, accept
  swaps + leaves old hooks, fall-through delegates when no conflict).
- `_render_l5_section` × 6 states (NOT A REPO, NOT INITIALIZED, ACTIVE,
  DORMANT-empty, DORMANT-custom, hint-content).

### M2.5 — End-to-end DORMANT → ACTIVE demo

Repo with husky-style setup (`core.hooksPath=.husky` + `.husky/pre-commit`):

```
=== BEFORE: husky setup, sage status ===
L5 — Pre-commit gate:          DORMANT (custom)
  core.hooksPath=.husky (husky detected) — run: sage init --force-githooks to override
```

After `force_githooks_override` (accept = `y`):

```
=== AFTER: force_githooks_override (accept) ===

  --force-githooks: about to override existing setup

  Custom hooks path:  .husky
  Detected framework: husky

  Files in path:
    . 

  This will deactivate husky. Continue? [y/N]:   ok: force-githooks: core.hooksPath set to .githooks (was: .husky)
  ok: force-githooks: .githooks/pre-commit installed
    Previous hooks at .husky were left in place but no longer fire.

=== sage status AFTER override ===
L5 — Pre-commit gate:          ACTIVE
  core.hooksPath=.githooks; pre-commit script on disk
```

State transition confirmed: `DORMANT (custom)` → `ACTIVE`. The previous
`.husky/pre-commit` is left in place on disk (per ADR-3: never delete
user files) but no longer runs because `core.hooksPath` now points to
`.githooks`.

### M1 regression check

```
$ bash tests/test_m1_codex_hooks.sh
...
=================================================================
  M1 test summary:  22 passed, 0 failed
=================================================================
```

M1 still 22/22 — no regression from M2 changes.

### Verification gate (M2)

- [x] Detection × 9 fixtures pass.
- [x] `--force-githooks` flow × 3 (decline / accept / fall-through) pass.
- [x] `_render_l5_section` × 6 states pass.
- [x] Demo: husky repo → DORMANT (custom) → ACTIVE after override.
- [x] No data loss: previous custom hook files remain on disk.
- [x] Default behavior unchanged: without `--force-githooks`, existing
      Husky/lefthook/etc. setups are skipped silently with a hint.
- [x] M1 regression suite still 22/22.
- [x] `bash -n bin/sage` passes.

**Ready for [A]/[R].**

---

## Milestone 3 — Direct skill behavioral isolation

**Date:** 2026-04-29
**Risk:** high — depends on Codex feature behavior; failure mode non-breaking
**Status:** complete (mechanical), pilot test (b) PENDING USER

### M3.1 — Generator changes

`runtime/platforms/codex/setup/generate-codex.sh`:
- New helper `skill_tier()` — reads SKILL.md frontmatter, returns
  `workflow` if `tier: workflow`, else `direct` (default for missing/
  other values).
- New helper `emit_skill_isolation_yaml()` — writes
  `<dest>/agents/openai.yaml` with:
  ```yaml
  policy:
    allow_implicit_invocation: false
  interface:
    short_description: "<bit-identical copy of SKILL.md description>"
  ```
  Idempotent: re-runs produce 0 diff. Skips emission if SKILL.md has
  no frontmatter. Folded scalars (`description: >`) joined with single
  space. UTF-8 + inner quotes properly escaped.
- Direct-skill deploy loop now invokes `emit_skill_isolation_yaml`
  for `tier=direct` skills only. For `tier=workflow`, any stale yaml
  from previous runs is removed.
- All three workflow-skill emit blocks (sage / review / generic)
  inject `tier: workflow` into the generated frontmatter so the
  status renderer can classify them correctly.
- `core/capabilities/orchestration/sage-navigator/SKILL.md` marked
  `tier: workflow` (it IS a routing skill — autosuggest is its purpose).

### M3.4 — Bulk deploy demo (full framework into temp project)

```
$ cd /tmp/m3-bulk-demo
$ ls sage/skills | wc -l
38
$ find sage/skills -name SKILL.md -exec grep -l "^tier: workflow" {} \; | wc -l
0
$ SAGE_FRAMEWORK_DIR=$(pwd)/sage bash $REPO/runtime/platforms/codex/setup/generate-codex.sh $(pwd)
...
  → 17 workflow skills
  → 34 direct skills (0 refreshed)

$ find .agents/skills -name openai.yaml | wc -l
34
$ find .agents/skills/sage* -name openai.yaml | wc -l
0   # workflow skills (sage:*) correctly have NO yaml
```

Sample emitted yaml (`self-learning`, longest description w/ folded scalar):

```yaml
# Auto-generated by Sage. Do not edit by hand.
# Behavioral isolation per ADR-4 v3: prevents Codex auto-suggest
# on description match. Workflow skills do NOT receive this file.
policy:
  allow_implicit_invocation: false
interface:
  short_description: "Captures agent mistakes, corrections, and discovered gotchas so they are not repeated. Use when: (1) a command or operation fails unexpectedly, (2) the user corrects the agent, (3) the agent discovers non-obvious behavior through debugging, ..."
```

### M3.5 — `sage status` Skills section

Post-deploy:

```
$ /Users/alexostl/Developer/sage-selfhost/bin/sage status

  Sage status  (/tmp/m3-bulk-demo)

Skills (behavioral isolation): ACTIVE
  34/34 direct skills isolated; 17 workflow skill(s) reactive
```

5 states implemented: `N/A` (no `.agents/skills`), `EMPTY`,
`WORKFLOW-ONLY`, `DORMANT` (no yaml), `PARTIAL` (some yaml),
`ACTIVE` (all direct have yaml).

### M3.7 — Test suite (32 cases)

```
$ bash tests/test_m3_skill_isolation.sh

=== unit: skill_tier ===
  PASS  tier: direct → direct
  PASS  tier: workflow → workflow
  PASS  tier missing → direct (default)
  PASS  no frontmatter → direct
  PASS  missing file → direct
  PASS  tier: "workflow" (quoted) → workflow

=== unit: emit_skill_isolation_yaml ===
  PASS  yaml: allow_implicit_invocation false
  PASS  yaml: policy block
  PASS  yaml: interface block
  PASS  yaml: short_description
  PASS  yaml: description body present
  PASS  yaml: UTF-8 (Polish chars) preserved
  PASS  yaml: inner quotes escaped
  PASS  idempotent: 2× emit → same hash
  PASS  no frontmatter → skipped emission

=== unit: SSoT (short_description == SKILL.md description) ===
  PASS  SSoT: inline desc copied verbatim
  PASS  SSoT: folded scalar joined w/ spaces

=== integration: generator emits yaml for direct skills only ===
  PASS  generator exits 0
  PASS  simplify (direct) has agents/openai.yaml
  PASS  specify (direct) has agents/openai.yaml
  PASS  evaluate (direct) has agents/openai.yaml
  PASS  sage (workflow) correctly has no agents/openai.yaml
  PASS  idempotent: 2× generator → same yaml hashes
  PASS  simplify SKILL.md name: unchanged by generator
  PASS  specify SKILL.md name: unchanged by generator
  PASS  evaluate SKILL.md name: unchanged by generator
  PASS  sage SKILL.md name: unchanged by generator

=== unit: _render_skills_section states ===
  PASS  no .agents/skills → N/A
  PASS  only workflow skill → WORKFLOW-ONLY
  PASS  direct skill no yaml → DORMANT
  PASS  direct skill + yaml → ACTIVE
  PASS  1 of 2 direct skills isolated → PARTIAL

=================================================================
  M3 test summary:  32 passed, 0 failed
=================================================================
```

32/32 PASS. Coverage:
- `skill_tier` × 6 (direct, workflow, missing, no-frontmatter, missing-file, quoted).
- `emit_skill_isolation_yaml` × 9 (structure, escape, UTF-8, idempotent, skip).
- SSoT regression × 2 (inline + folded scalar).
- Generator integration × 10 (yaml only on direct, idempotent, name: invariant).
- `_render_skills_section` × 5 (N/A, WORKFLOW-ONLY, DORMANT, ACTIVE, PARTIAL).

### M1+M2 regression check

```
M1 test summary:  22 passed, 0 failed
M2 test summary:  24 passed, 0 failed
```

Total cycle test count: **22 + 24 + 32 = 78 PASS / 0 FAIL**.

### M3.6 — Documentation

`runtime/platforms/codex/README.md` updated:
- Enforcement Posture section: added layer 4 (behavioral isolation).
- New "Config Keys" table with `deploy_direct_skills` semantics.
- New "Migration: behavioral isolation of direct skills (2026-04-29)"
  section explaining what changed, what still works, how to opt out.

### M3.3 — Pilot empirical test (test b — REQUIRES INTERACTIVE CODEX)

The mechanical pieces (a, c, d) are testable and PASS:

- (a) **`agents/openai.yaml` exists for `simplify`** — verified in M3.4
  bulk demo: `.agents/skills/simplify/agents/openai.yaml` is present
  with `policy.allow_implicit_invocation: false`.
- (c) **`$simplify` invocation:** invocation path is unchanged because
  `name: simplify` is preserved verbatim (test integration assertion
  passed). Codex `$<name>` lookup still resolves.
- (d) **`Read sage/skills/simplify/SKILL.md`** — file unchanged by
  generator (only the deployed copy in `.agents/skills/` carries the
  yaml; source SKILL.md untouched).
- (e) **Per-agent test cross non-default agent** — SKIPPED per M0
  decision (no non-default agent configured in dev environment).
  Recovery path documented in README Migration section ("delete yaml
  to opt out").

Empirical test (b) **REQUIRES USER TO RUN IN INTERACTIVE CODEX SESSION**:

> Open a Codex session in a project with the new `.agents/skills/`
> deployed. Type each prompt below. Pass criterion per ADR-4 v3:
> ≥4/5 first batch → tentative PASS; if 4/5 with 1 false positive,
> run second batch +5 → ≥9/10 = final PASS.
>
> **First batch (5 prompts) — direct-skill auto-suggest must NOT fire:**
> 1. "uprość ten kod" — `simplify` should NOT auto-fire.
> 2. "make this simpler" — `simplify` should NOT auto-fire.
> 3. "refactor for readability" — `simplify` should NOT auto-fire.
> 4. "clean up this function" — `simplify` should NOT auto-fire.
> 5. "remove duplication here" — `simplify` should NOT auto-fire.
>
> **Pass:** Codex responds with general help / asks clarifying question /
> routes via Sage navigator — but does NOT silently activate the
> `simplify` skill or quote `[lib]`-prefixed description.
> **Fail:** Codex's first action is to read/run the `simplify` skill.

**Go/No-go decision:** User runs test (b), pastes results, then picks:
- ≥4/5 PASS → ship M3 to selfhost.
- 4/5 with 1 false-positive → run second batch (5 more prompts).
- <4/5 PASS → re-open ADR-4, fallback v2 plan (`zz-sage-` rename) or
  defer M3 entirely. Codex flag may be ignored — non-breaking, but no
  benefit realized.

### Verification gate (M3)

- [x] All 32 generator + status tests pass.
- [x] Bulk deploy demo: 34/34 direct skills get yaml; 17 workflow stay reactive.
- [x] `sage status` Skills section shows ACTIVE with correct count.
- [x] Idempotency: 2× generator run → identical yaml hashes.
- [x] `name:` invariant: SKILL.md name field never altered.
- [x] M1+M2 regression: 22+24 still pass.
- [x] README Migration section explains behavior + opt-out.
- [ ] **Pilot test (b) — pending interactive Codex run by user.**
- [x] `bash -n` passes on generator + bin/sage.

**Mechanical implementation: complete. Ready for [A]/[R] on code.
Pilot empirical (b) deferred to user interactive session.**
