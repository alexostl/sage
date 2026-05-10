---
title: Spec — Codex enforcement activation
status: completed
phase: design
workflow: architect
scope: standard
created: 2026-04-29
updated: 2026-04-29
owner: alexostl
parent_brief: brief.md
related_adrs:
  - ../../docs/decision-codex-hook-activation.md
  - ../../docs/decision-self-host-aggressive-defaults.md
  - ../../docs/decision-githooks-custom-path-policy.md
  - ../../docs/decision-codex-narrow-palette-honest-framing.md
handoff: |
  Architecture-level decisions are locked in 4 ADRs (Osie 1-4 z briefu),
  ADR-4 zrewidowane do v3 po RTFM v3 finding.
  Key decisions:
    - Single key activation: [features].codex_hooks = true triggers full wiring
      with deterministic identity rule (path-prefix .codex/hooks/<known>) for
      idempotent re-merge.
    - Self-host vs upstream: marker .sage/profile (YAML) at framework root gates
      aggressive defaults; recovery paths documented.
    - core.hooksPath custom: warn by default, sage init --force-githooks for unblock
      with extended detection (Husky/lefthook/pre-commit/simple-git-hooks/custom)
      and ls-fallback in confirm prompt.
    - Behavioral isolation direct skilli: per-skill agents/openai.yaml z
      policy.allow_implicit_invocation: false. Brak rename name: field.
      Visual palette ordering (zz-sage-) deferred do osobnego cyklu.
  Open questions for milestone plan:
    - Component E milestone placement (3 czy parallel)
    - --force-githooks prompt UX (read -r vs TUI)
    - sage status output format (extend cmd_status czy --enforcement section)
  Risks:
    - allow_implicit_invocation: false może być ignorowany przez Codex —
      pilot (b) catches; fallback plan = re-open ADR-4 to v2 (zz-sage- rename)
    - 60+ NEW yaml files (low complexity, mechaniczny generator step)
    - Codex hook spec ewolucja (jeśli format hooks.json się zmieni)
  Next agent should:
    - Empirical pilot: deploy agents/openai.yaml dla ONE skill (rec. simplify),
      verify (a) plik istnieje, (b) Codex nie auto-suggestuje, (c) $simplify
      explicit działa, (d) path read działa. PRZED bulk.
    - Milestone plan w 3 niezależnie deployowalnych milestonach (sugestia:
      M1 hook activation + status, M2 githooks policy + force flag,
      M3 behavioral isolation deploy)
    - Każdy milestone follows build workflow gates independently
---

# Spec — Codex enforcement activation

## What we are building

System architectural change to the Codex platform port that closes the
contract mismatch between "framework files on disk" and "runtime
enforcement active". Three subsystems modified:

1. **Codex hook activation pipeline** in `bin/sage` + Codex generator —
   single-key activation via `[features].codex_hooks` (ADR-1).
2. **Per-branch profile defaults** in Codex generator — self-host vs
   upstream split (ADR-2).
3. **`sage status` enforcement reporting** + `sage init --force-githooks`
   CLI flag (ADR-3 + ADR-4).
4. **Direct skill behavioral isolation (`agents/openai.yaml` per direct skill)
   + honest config documentation** (ADR-4 v3).

Out of scope (deferred):
- Codex hook merge logic for non-bash hook frameworks (Husky/lefthook
  wrapper — ADR-3 alt 3b).
- L3 phase tracker (parked per memory `[PARKED]`).
- Cross-repo writes to `alex-os-dev` (Non-Goal w briefie).
- Display-only palette mechanism in Codex (RTFM confirmed not feasible).

## System components

### Component A: Codex hook activation in `sage update` / `sage init`

**Files affected:**
- `bin/sage` — new function `ensure_codex_hooks_wired(target)`,
  invocation points: `cmd_init`, `cmd_update`, `cmd_new`.
- `runtime/platforms/codex/setup/generate-codex.sh` — generator now
  emits framework hook entries into `.codex/hooks.json` (merge logic).
- `runtime/platforms/codex/hooks/hooks.template.json` — new file,
  reference shape of framework entries used by merge.

**Activation contract:**

```
For each invocation of sage update / sage init / sage new in a project:
  1. Read .codex/config.toml -> [features].codex_hooks
  2. If true:
     a. Copy runtime/platforms/codex/hooks/*.sh -> <project>/.codex/hooks/
        (idempotent: skip identical files; warn on diverged user-edited).
     b. Read existing <project>/.codex/hooks.json (or {} if missing).
     c. Backup pre-merge:
        cp .codex/hooks.json .codex/hooks.json.sage-bak.$(date -u +%Y%m%dT%H%M%SZ)
        (skip if hooks.json absent — fresh wire has no prior state).
     d. For each framework event (UserPromptSubmit, PreToolUse,
        PostToolUse, SessionStart):
        - Identity rule: framework entry = command starts with
          ".codex/hooks/" AND filename in known set
          (pre-prompt.sh, pre-bash.sh, post-bash.sh, session-start.sh).
        - If framework entry exists in array AND matches template -> noop.
        - If framework entry exists in array BUT old version -> replace
          ONLY that entry, keep user entries intact.
        - If only user entries exist -> append framework entry to array.
        - If event missing -> create with framework entry.
     e. Write merged hooks.json atomically (tmp + rename).
  3. If false / missing: no-op on .codex/hooks/. Status output reports
     "L4 (Codex hooks) DISABLED".
```

**Identity rule (per ADR-1):** Framework entry recognition by `command`
field path-prefix `.codex/hooks/<known-filename>`. NIE używamy JSON
metadata key (`{"_sage": true}`) bo polution. Path-prefix daje
deterministyczną idempotentność (re-run = same disk) bez touchingu
user entries (które mają `command` typu `scripts/X`, `/usr/local/X`,
`npm run hook` itd.).

**Idempotency invariant:** Two consecutive `sage update` runs MUST
produce identical disk state.

**Custom user entry preservation invariant:** If user has
`[hooks.SessionStart]` with a custom command (e.g. `verify-wiring.sh`),
that entry survives merge. Framework entry is added alongside (not
replacing).

### Component B: Per-branch profile defaults in generator

**Files affected:**
- `runtime/platforms/codex/setup/generate-codex.sh` — profile detection
  + conditional template emission.
- `.sage/profile` — YAML sentinel file w **framework root** (gitignored
  w `codex-port` i `main`; tracked w `selfhost`).

**Profile detection logic (resolution chain per ADR-2):**

```
SAGE_BIN_PATH = $0
# Resolve symlinks portable (GNU readlink -f, BSD fallback to Python or while-loop)
SAGE_BIN_RESOLVED = realpath of SAGE_BIN_PATH
FRAMEWORK_ROOT = dirname(dirname(SAGE_BIN_RESOLVED))

# Validate framework checkout shape
if [ -d "$FRAMEWORK_ROOT/runtime" ] && [ -d "$FRAMEWORK_ROOT/sage/skills" ]:
   # Read profile
   if exists "$FRAMEWORK_ROOT/.sage/profile":
     parse YAML profile: field
     PROFILE = value (self-host or upstream)
   else:
     PROFILE = "upstream"  # absent file = upstream default
else:
   # Packaged install (brew/npm) or unrecognized layout — safe default
   warn user, PROFILE = "upstream"

Default values per profile:
  upstream:    codex_hooks=false (in generated .codex/config.toml)
  self-host:   codex_hooks=true  (in generated .codex/config.toml)

(deploy_direct_skills=true everywhere per ADR-4 v3;
 agents/openai.yaml + allow_implicit_invocation: false per direct skill
 per ADR-4 v3. NO name: field rename.)
```

**`sage status` musi printować resolved framework root** (per ADR-2)
żeby user diagnozował profile-related issues:

```
Framework root: /Users/alexostl/Developer/sage-selfhost
Profile:        self-host  (.sage/profile present, value: self-host)
```

**Profile file format:**

```yaml
# .sage/profile
profile: self-host
# (future-extensible: features: [aggressive-defaults], etc.)
```

**File location: framework root, NOT project root.** Profile detection
reads from where `bin/sage` lives, nie z `pwd` consumer projektu.
Chroni przed false-positive jeśli user przypadkowo `touch
.sage/profile` w swoim projekcie.

**`.gitignore` discipline:**
- W `selfhost`: `.sage/profile` jest **tracked** (z content
  `profile: self-host`).
- W `codex-port` i `main`: `.sage/profile` w `.gitignore` (absent
  od disk).
- Sage's own `.gitignore` template-emission (dla nowych user projektów)
  NIE includuje tego pliku — framework-internal, nie user-project state.

**Branch policy guard:**
- PR template (lub `CONTRIBUTING.md`) section: "Does this PR change
  default values w `generate-codex.sh`? If yes, document why for both
  upstream and self-host profiles."
- Reviewer SOP: spot-check że `.sage/profile` presence NIE travels
  through merge do upstream.

**Recovery paths (udokumentowane w `runtime/platforms/codex/README.md`):**

1. *Self-host fork chce upstream defaults:* `echo 'profile: upstream' > .sage/profile`
   lub `rm .sage/profile` w framework root.
2. *Upstream fork chce self-host defaults:* `mkdir -p .sage && echo 'profile: self-host' > .sage/profile`
   w framework root.
3. *Marker wyciekł na main przez bad merge:* delete + add do `.gitignore`
   tej brancha. Reviewer SOP wymienia explicit check.

### Component C: `sage status` enforcement reporting

**File affected:**
- `bin/sage` — extend `cmd_status` (or create if absent) with
  enforcement section.

**Output format (extension to existing status):**

```
Sage Enforcement Status
=======================

L1 (AGENTS.md):           ACTIVE   (313 lines, all rules present)
L2 (Workflow PREAMBLE):   ACTIVE   (16/16 workflow skills)
L4 (Codex hooks):
  - .codex/config.toml [features].codex_hooks: true
  - .codex/hooks/*.sh:                          4 files present
  - .codex/hooks.json:                          UserPromptSubmit, PreToolUse,
                                                PostToolUse, SessionStart wired
  - Status:                                     ACTIVE
L5 (Git pre-commit):
  - .githooks/pre-commit:                       present, executable
  - core.hooksPath:                             .githooks
  - Status:                                     ACTIVE

Skills
------
Workflow skills:    16/16 deployed (.agents/skills/{sage,build,fix,...})
Direct skills:      0/N  deployed  (deploy_direct_skills: false)
Source skills:      N    available (sage/skills/*)
Discovery surface:  .agents/skills/ (Codex native)
```

For each L4/L5 component, possible states:
- `ACTIVE` — all conditions met.
- `DORMANT` — files present but not wired (e.g. custom `core.hooksPath`).
  Includes "How to activate" hint.
- `DISABLED` — feature flag off (`codex_hooks = false`). Includes
  "How to enable" hint.
- `NOT INITIALIZED` — files absent. Includes "Run `sage init`" hint.
- `MISCONFIGURED` — partial state (e.g. `codex_hooks = true` but
  `.codex/hooks.json` missing entries — should not happen post-Component-A
  but possible in legacy state). Includes recovery hint.

### Component D: `sage init --force-githooks` CLI flag

**File affected:**
- `bin/sage` — `cmd_init` argument parser + `force_githooks` branch in
  `ensure_hooks_wired()`.

**Behavior:**

```
sage init [--force-githooks]

Without flag (current behavior):
  ensure_hooks_wired() honors current core.hooksPath if non-empty
  and not .githooks. L5 stays DORMANT.

With flag:
  1. Detect existing core.hooksPath.
  2. If detected as Husky / lefthook / pre-commit-framework
     (heuristic: presence of node_modules/husky, .husky/,
     lefthook.yml, .pre-commit-config.yaml in current path):
     a. Print detected framework + list of existing hooks.
     b. Prompt: "This will deactivate <framework>. Continue? [y/N]"
     c. If no -> abort with exit code 1.
  3. git config --unset core.hooksPath (if set to non-.githooks value).
  4. git config core.hooksPath .githooks.
  5. Copy .githooks/pre-commit (idempotent).
  6. Print summary of changes.
```

**Detection heuristics (explicit, rozszerzona lista per ADR-3):**

| Framework | Detection signal |
|---|---|
| Husky | `<project>/.husky/` OR `<project>/node_modules/husky/` |
| lefthook | `<project>/lefthook.yml` OR `<project>/lefthook.yaml` |
| pre-commit-framework | `<project>/.pre-commit-config.yaml` |
| simple-git-hooks | `<project>/package.json` zawiera `"simple-git-hooks":` |
| Custom scripts | None of above, but `<custom_path>` zawiera executable hooki |

If multiple detected: list all, single confirmation covers all.

**`ls`-fallback (zawsze, nawet gdy framework wykryty):**

Przed confirm prompt Sage wykonuje:
```
ls -la <custom_path>
```

i pokazuje user listę plików (executable + non-executable). Daje
informed consent — user widzi co konkretnie zostanie odłączone, np.:

```
Custom hooks path: .git/hooks
Detected framework: Custom scripts (no recognized framework)
Files in path:
  - pre-commit (executable)
  - prepare-commit-msg (executable)
  - applypatch-msg.sample (sample, not active)

This will deactivate these custom scripts. Continue? [y/N]
```

Adresuje case `alex-os-dev` (custom `.git/hooks` overlay bez frameworka)
i `simple-git-hooks` (popularny w Node.js ecosystem).

### Component E: Direct skill behavioral isolation via `agents/openai.yaml`

**Files affected:**
- All `sage/skills/*/SKILL.md` — frontmatter `description:` field
  prefix `[lib] ` (~60 files, jednorazowy edit).
- All `sage/skills/*/agents/openai.yaml` — **NEW files** (~60 files,
  per-skill, jeden `agents/openai.yaml` na każdy direct skill).
- Generator `runtime/platforms/codex/setup/generate-codex.sh` — kopiuje
  `agents/openai.yaml` razem z `SKILL.md` do `.agents/skills/<name>/`.
  Brak rename logic, brak `name:` field touch.
- Workflow skille (`sage/skills/<workflow>/SKILL.md`, `core/skills/`,
  `.claude/commands/*.md`) — **bez zmian**. `$specify` invocation
  nadal działa, path reads nadal działają.

**Co NIE robimy w tym cyklu (deferred per ADR-4 v3):**
- `name:` field rename (`zz-sage-<X>` prefix) — pozostawione na
  osobny cykl po empirical pomiarze visual palette clutter.
- Cross-reference audit workflow skilli — niepotrzebny, bo żadne
  references się nie zmieniają.
- Folder rename — niepotrzebny.
- Claude Code slash command remapping — niepotrzebny (`name:` zostaje).

**Per-skill `agents/openai.yaml` template (kopiowany do każdego direct skill folderu):**

```yaml
# sage/skills/<name>/agents/openai.yaml
policy:
  allow_implicit_invocation: false
interface:
  short_description: "[lib] <copy of description from SKILL.md>"
```

`policy.allow_implicit_invocation: false` blokuje auto-suggest na
description match. Skill nadal explicit-invokable przez workflow
(`$<name>`) i path read (`Read sage/skills/<name>/SKILL.md`).

**Description prefix `[lib]`** (zarówno w SKILL.md frontmatter jak
i w `agents/openai.yaml` `interface.short_description`) — visual cue
dla usera szukającego po fuzzy search.

**Empirical verification gate (BEFORE bulk deploy):**

Pilot deploy: pick ONE direct skill (rekomendowany: `simplify` — per
project memory najczęściej fałszywe alarmy w `alex-os-dev`), dodaj
`sage/skills/simplify/agents/openai.yaml` z
`policy.allow_implicit_invocation: false`. Regenerate `.agents/skills/`.

Verify (pasted output w verification.md):
- (a) Plik `.agents/skills/simplify/agents/openai.yaml` istnieje po regen.
- (b) **Codex routing test (N=5 prompts, majority-rule):** Codex w
  realnej sesji nie auto-suggestuje `simplify` na prompty trigger-style.
  Pięć różnych user prompts:
  1. "uprość ten kod"
  2. "make this simpler"
  3. "refactor for readability"
  4. "clean up this function"
  5. "remove duplication here"
  Expected: każdy z prompts routuje przez workflow (`sage:fix` /
  `sage:build`), NIE wywołuje `simplify` direct skill auto-suggest.
  **Pass criterion:** ≥4 z 5 prompts route correctly. <4 = fail
  (Codex not honoring flag deterministically). Codex routing jest
  inherentnie non-deterministic, więc binary check z jednego promptu
  zbyt wąski.
- (c) Workflow skill może wciąż invokować `$simplify` explicit
  (test: w workflow skill body referencja `$simplify` działa).
- (d) Path read `Read sage/skills/simplify/SKILL.md` z workflow działa.
- (e) **Per-agent verification (Codex bug #14161 hedge):** powtórzenie
  testu (b) z non-default Codex agent (jeśli user ma skonfigurowany
  alternative agent w `~/.codex/config.toml` `[[agents]]`). Jeśli
  flaga apply tylko dla default `openai` agent — **document jako
  known limitation**, nie blocker. Recovery: user może override
  per-agent przez `[[skills.config]]` (manual workaround).
  Jeśli flaga apply cross all agents — bonus, document w runbook.

Pasted output (b)-(e) musi być w verification.md przed bulk deploy.

**Go/No-go decision gate (po pilot, PRZED bulk):**

| Pilot outcome | Action |
|---|---|
| PASS na (a)-(d) | Bulk: dodaj `agents/openai.yaml` do każdego ~60 direct skilla + `[lib]` prefix description w SKILL.md. |
| FAIL na (b) | Codex nie respektuje flagi → mechanizm nie działa jak docs. **Re-open ADR-4** — wracamy do `zz-sage-` rename plan (v2). |
| FAIL na (c) lub (d) | Workflow integration broken → re-evaluate generator copy logic albo Codex skill loading. Pause bulk. |

User decyduje explicit przy go/no-go checkpoint na podstawie verification.md.

**Failure mode containment:** workflow skille **continue to work** w
worst case (jeśli `agents/openai.yaml` zignorowany przez Codex,
fallback to default `allow_implicit_invocation: true` = identyczne
zachowanie jak przed cyklem). Mechanizm jest addytywny, nie
breaking.

### Component F: Honest config documentation

**Files affected:**
- `runtime/platforms/codex/setup/generate-codex.sh` — emitted
  `.sage/config.yaml` template comments.
- `runtime/platforms/codex/README.md` — "Config keys" section.
- `.sage/docs/comm-style.md` (no change — already in scope).

**Generator emits this comment block** dla `deploy_direct_skills`
zgodnie z ADR-4 (full Polish text in ADR).

## Data flows

### Flow 1: `sage update` in self-host project

```
user $ sage update
  -> bin/sage cmd_update
     -> ensure_hooks_wired(.) [existing — for L5]
     -> generate-codex.sh [existing]
        -> profile detection: .self-host-profile present -> "self-host"
        -> emit AGENTS.md, .agents/skills/, .codex/config.toml
           [features].codex_hooks = true
     -> ensure_codex_hooks_wired(.) [NEW — for L4]
        -> read .codex/config.toml
        -> codex_hooks=true -> copy *.sh + merge hooks.json
     -> print summary
        -> calls cmd_status internally for enforcement section
```

### Flow 2: `sage status` in custom-hookspath project

```
user $ sage status
  -> bin/sage cmd_status
     -> probe L1: read AGENTS.md, validate rules
     -> probe L2: count workflow skills with PREAMBLE
     -> probe L4: read .codex/config.toml, list .codex/hooks/, parse hooks.json
     -> probe L5: read core.hooksPath, stat .githooks/pre-commit
     -> probe Skills: count .agents/skills/, sage/skills/
     -> render report
        -> L5 row: "DORMANT — custom path: <path>" + activate hint
```

### Flow 3: `sage init --force-githooks` against Husky project

```
user $ sage init --force-githooks
  -> bin/sage cmd_init --force-githooks
     -> detect_existing_hooks_framework()
        -> finds .husky/, returns "Husky"
     -> print: "Detected: Husky. Hooks: pre-commit, commit-msg"
     -> prompt: "Override Husky and use Sage .githooks? [y/N]"
     -> if y:
        -> git config --unset core.hooksPath
        -> git config core.hooksPath .githooks
        -> copy framework .githooks/pre-commit
        -> print summary
     -> if n:
        -> exit 1 (no changes made)
```

## Failure modes

| Mode | Trigger | Detection | Recovery |
|---|---|---|---|
| Merge corrupts user hooks.json | Buggy merge logic, edge case in Codex hook spec | `bash -n` + JSON parse test in CI | Restore from `.codex/hooks.json.sage-bak.<ts>` (atomic merge writes backup) |
| Profile detection wrong branch | Marker file accidentally committed/removed | `sage status` shows unexpected defaults | User checks `.sage/profile` presence/content; reviewer in PR |
| `--force-githooks` removes Husky in shared repo | Multi-dev project, one dev runs flag | Other devs lose Husky hooks | Git history; revert by `git config core.hooksPath .husky` (recoverable) |
| `allow_implicit_invocation: false` ignored by Codex | Feature regression / version mismatch | Pilot (b) fails — direct skill nadal auto-suggestuje | Re-open ADR-4, fallback to `zz-sage-` rename plan v2 |
| Codex hook spec changes upstream | OpenAI ships new hooks.json format | Merge logic fails to parse | Pin tested Codex version in `runtime/platforms/codex/README.md`; manual remediation |

## Tests required (per build workflow Rule 5)

Unit tests:
- `ensure_codex_hooks_wired()`: codex_hooks=true with empty hooks.json
  -> 4 framework entries present.
- `ensure_codex_hooks_wired()`: codex_hooks=true with custom
  SessionStart user entry -> custom entry preserved + framework
  SessionStart appended to array (or coexisting per Codex spec).
- `ensure_codex_hooks_wired()`: codex_hooks=true twice in a row -> diff
  between runs = 0 (idempotent).
- `ensure_codex_hooks_wired()`: codex_hooks=false -> hooks.json
  unchanged.
- Profile detection: with marker -> self-host defaults; without -> upstream.
- `cmd_status` enforcement section: each of the 5 states (ACTIVE,
  DORMANT, DISABLED, NOT INITIALIZED, MISCONFIGURED) has a fixture +
  asserted output line.
- `--force-githooks`: with Husky fixture + N input -> abort, no changes.
- `--force-githooks`: with Husky fixture + Y input -> Husky hooks
  disabled, .githooks active, audit log emitted.
- Generator emits `agents/openai.yaml` for every direct skill (NOT for
  workflow skills) z `policy.allow_implicit_invocation: false`.
- Idempotentność: regen dwa razy → 0 diff w `.agents/skills/`.

Integration tests:
- Fresh `git init` + `sage init` in tmp dir -> L1+L2+L4+L5 all ACTIVE
  (when self-host profile, codex_hooks default true).
- `sage update` in fixture matching alex-os-dev state (codex_hooks=true,
  custom SessionStart, custom hooksPath) -> L4 ACTIVE post-update,
  L5 DORMANT (warned), custom SessionStart preserved.
- `sage update` twice in same fixture -> 0 diff.

Pasted-output verification at each milestone checkpoint.

## Open questions for milestone planning

1. Czy Component E (`agents/openai.yaml` deploy + `[lib]` prefix) jest
   milestone 1 czy 3? Pilot deploy (1 skill) musi być pierwszy — to
   verification gate przed bulk. Bulk może być parallel z innymi
   komponentami albo na końcu.
2. Czy Component D (`--force-githooks`) potrzebuje TUI/prompt
   abstraction, czy `read -r` w bash wystarczy? (Kwestia ergonomiki.)
3. Czy Component C status output wymaga zmiany formatu istniejącego
   `cmd_status` (jeśli jest), czy dodanie nowej sekcji `--enforcement`?
4. **Resolved:** `.sage/profile` jako YAML z `profile: self-host` —
   forward-compat scaling (future `features: [...]`) bez rename pliku.
   Patrz Component B.

(Open questions Q5 i Q6 z poprzedniej wersji spec — folder-match
contingency oraz Claude Code slash command mapping — **usunięte**
po pivocie ADR-4 v3. Brak rename `name:` field = brak tych problemów.)

## Success criteria

Spec uznawany za zaimplementowany gdy:

- [ ] Wszystkie 4 ADR-y referencjonowane są przez kod / generator.
- [ ] Test fixture `tests/fixtures/alex-os-dev-shape/` reprodukuje
      scenariusz briefa, a `sage update` w tym fixturze powoduje:
      L4 ACTIVE (od DORMANT), L5 DORMANT (z warningiem), każdy direct
      skill ma plik `.agents/skills/<name>/agents/openai.yaml` z
      `policy.allow_implicit_invocation: false`, description
      zaczyna się od `[lib]`.
- [ ] `sage status` w sage-selfhost samym w sobie raportuje L1-L5
      jako ACTIVE / ACTIVE / ACTIVE / ACTIVE / ACTIVE (po wpięciu
      hooks.json).
- [ ] `sage init --force-githooks` w fixture z Husky aborts on N input.
- [ ] Empirical pilot dla Component E pass na (a)-(d), pasted output
      w verification.md. Codex w realnej sesji nie auto-suggestuje
      direct skilla na user prompt match (test: prompt typu "uprość
      ten kod" nie wyzwala `simplify` direct skill, routuje przez
      workflow `sage:fix`/`sage:build`).
- [ ] Post-deploy assertion: każdy `sage/skills/*/SKILL.md` ma
      **niezmieniony** `name:` field (skanowanie git diff potwierdza
      brak rename slip).
- [ ] Cross-branch test: `git checkout codex-port` + regen generator =
      defaulty upstream-friendly; `git checkout selfhost` + regen
      = defaulty self-host.
- [ ] No writes to `alex-os-dev` ani innych external repos w trakcie
      cyklu.

Pasted test output dla każdego z powyższych przy verification checkpoint.
