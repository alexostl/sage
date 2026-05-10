---
title: Plan — Codex enforcement activation (3 milestones)
status: approved
phase: plan
workflow: architect
scope: standard
created: 2026-04-29
updated: 2026-04-29
owner: alexostl
parent_spec: spec.md
related_adrs:
  - ../../docs/decision-codex-hook-activation.md
  - ../../docs/decision-self-host-aggressive-defaults.md
  - ../../docs/decision-githooks-custom-path-policy.md
  - ../../docs/decision-codex-narrow-palette-honest-framing.md
milestones:
  - id: M0
    title: Pre-flight (fixture + cmd_status scaffold + .versions.txt protocol)
    components: [scaffolding]
    risk: low
    independently_deployable: false  # foundation for M1-M3
  - id: M1
    title: Codex hook activation pipeline
    components: [A, B-full, C-L4-section]
    risk: high  # sha256 .versions.txt one-way commitment + JSON merge of nested user data
    independently_deployable: true
  - id: M2
    title: Githooks policy + force-githooks CLI flag
    components: [D, C-L5-section]
    risk: low
    independently_deployable: true  # depends on M0 scaffold, not on M1
  - id: M3
    title: Direct skill behavioral isolation (allow_implicit_invocation)
    components: [E, C-Skills-section, F]
    risk: high  # Codex feature dependency, empirical pilot gate, but failure non-breaking
    independently_deployable: true  # via render-stub pattern from M0
handoff: |
  4 milestones podzielone wg axes ryzyka i contract surface:
  - M0 — pre-flight scaffold: fixture, render-stub cmd_status pattern,
    .versions.txt append-only invariant doc. Foundation dla M1-M3.
  - M1 — Codex hook activation. Highest enforcement value (closes contract
    mismatch z briefa). HIGH risk: sha256 .versions.txt jest one-way
    commitment (każda zmiana hooków = append, never edit), JSON merge
    user data ma blast radius (corruption recovery via .sage-bak.<ts>).
  - M2 — githooks force flag. Low risk extension istniejącego
    ensure_hooks_wired + nowa flaga. High user ergonomic benefit.
  - M3 — direct skill behavioral isolation. HIGH risk (Codex feature
    dependency, empirical pilot gate). Failure mode jest non-breaking
    (yaml ignored = identyczne pre-cycle). Last w order żeby Codex risk
    nie blokował M1/M2 release.

  Każdy milestone (M1+) follows build workflow gates independently:
    spec (jeśli milestone dodaje detail) → plan → implement (tests first) →
    verify (pasted output) → checkpoint [A]/[R].

  Recommended order: M0 → M1 → M2 → M3. Sekwencyjnie (jeden developer).
  M3 jest "independently deployable" via render-stub pattern z M0
  (Skills section dodaje się do skeletu cmd_status bez merge konfliktu
  z M1 L4 section albo M2 L5 section).

  Failure containment cross-milestone: każdy milestone merges to
  selfhost only after own [A]/[R]. Failures w later milestones
  nie wymagają revertu earlier ones.
---

# Plan — Codex enforcement activation

## Milestone breakdown rationale

Brief identyfikuje trzy oddzielne osie problemu:
- **L4 enforcement** (Codex hooki nie wpięte mimo `codex_hooks: true`) → **M1**
- **L5 enforcement** (custom `core.hooksPath` nie aktywuje Sage pre-commit) → **M2**
- **Direct skill noise** (`simplify` strzela na user prompt) → **M3**

Każda oś ma osobny code path, osobne testy i osobny user benefit.
Każda jest valuable nawet bez pozostałych — dlatego niezależnie deployowalne.

**Kolejność wynikająca z risk + dependency:**

1. **M1 first** — closes główny contract mismatch z briefa (`alex-os-dev`
   case L4 DORMANT). Fundament dla `sage status` reporting którego M3 też
   potem rozszerza.
2. **M2 second (lub parallel)** — niski risk, high ergonomic benefit, brak
   dependency na M1 oprócz `sage status` cross-cutting.
3. **M3 last** — empirical pilot gate, fallback plan na wypadek gdyby
   `allow_implicit_invocation` nie działało. Risk nie powinien blokować
   M1/M2 release.

Cross-cutting **Component C (`sage status`)** jest budowany incremental:
- M1 dodaje L4 section + framework root print.
- M2 dodaje L5 DORMANT/ACTIVE handling.
- M3 dodaje Skills section z `agents/openai.yaml` count.

---

## Milestone 0 — Pre-flight scaffold

**Goal:** Create infrastructure foundation needed by M1/M2/M3:
test fixture, `cmd_status` render-stub pattern, `.versions.txt`
append-only protocol documentation. ~½ day work, unblocks parallel
milestone development on shared touchpoints.

**Tasks:**

1. **Create `tests/fixtures/alex-os-dev-shape/`** reprodukujący briefa
   scenario:
   - `.codex/config.toml` z `[features].codex_hooks = true`.
   - `.codex/hooks.json` z custom `SessionStart` user entry (np.
     `verify-wiring.sh`), bez framework entries.
   - `.git/config` z `core.hooksPath = .git/hooks` (custom = NIE
     `.githooks`).
   - `.git/hooks/pre-commit` (executable custom script bez Sage logic).
   - 3 representative direct skille (`simplify`, `specify`, `evaluate`)
     w `sage/skills/<name>/SKILL.md` BEZ `agents/openai.yaml` (pre-cycle
     state).
   - 1 workflow skill (`sage`) jako baseline.

2. **Implement `cmd_status` render-stub pattern w `bin/sage`:**
   - Define `render_l1_section()`, `render_l2_section()`,
     `render_l4_section()`, `render_l5_section()`, `render_skills_section()`,
     `render_framework_root()` jako bash functions.
   - Initially each returns minimal placeholder (`echo "L4: not yet
     implemented"`) — M1/M2/M3 wypełnią konkretną logikę.
   - `cmd_status()` wywołuje render funkcje w deterministic order:
     framework_root → l1 → l2 → l4 → l5 → skills.
   - Test: `sage status` w fresh fixture printuje wszystkie sekcje
     z placeholderami.

3. **Document `.versions.txt` append-only invariant** (per ADR-1):
   - Create `runtime/platforms/codex/hooks/.versions.txt` z initial
     entry per current hook (sha256 hash @ v1).
   - Create `runtime/platforms/codex/hooks/README.md` explaining:
     "When modifying any `*.sh` file in this directory, append new
     sha256 entry to `.versions.txt` in the same commit. Never
     edit/replace existing lines — historical hashes pozwalają
     `sage update` rozpoznać 'old framework version, replace with
     current' vs 'unknown shadow file, refuse overwrite'."
   - Add PR template check item: "If you modified
     `runtime/platforms/codex/hooks/*.sh`, did you append to
     `.versions.txt`?"

4. **Resolve Q1 (per I2): extend `cmd_status` (NOT add subcommand).**
   Single source of truth, simpler. Defer `--enforcement` subcommand
   tylko jeśli output staje się unwieldy w future cycle.

5. **Resolve Q3 (per I5): per-agent test feasibility decision.**
   Decyzja: jeśli M3 dev environment ma tylko default `openai` agent
   skonfigurowany — **test (e) jest skipowany jako known limitation,
   document w runbook + decisions.md.** Recovery path (manual
   `[[skills.config]]` per-skill workaround) jest sufficient
   mitigation. Alternatywa (configure temporary `[[agents]]` w
   fixture) zbyt złożona dla pilot value.

**Verification gate (M0 [A]/[R]):**
- `tests/fixtures/alex-os-dev-shape/` shape sanity check (`tree` output).
- `sage status` w fresh checkout printuje render-stub sections.
- `.versions.txt` + README committed; PR template updated.

**Risk:** low — wszystko scaffolding, no behavior change.

---

## Milestone 1 — Codex hook activation pipeline

**Goal:** `sage update` w projekcie z `[features].codex_hooks = true`
faktycznie wpina framework hooki do `.codex/hooks.json` i kopiuje
`*.sh` do `.codex/hooks/`. Idempotentnie. Z preservation user entries.
Z protection przed shadow file overwrite.

**Components covered:**
- Component A (full)
- Component B (profile detection + framework root resolution)
- Component C (L4 section + framework root print w `sage status`)

**Tasks:**

1. **Add `runtime/platforms/codex/hooks/.versions.txt`** — registry znanych
   sha256 hashes dla każdego framework hook script. Initial entries:
   current versions current hooków (`pre-prompt.sh`, `pre-bash.sh`,
   `post-bash.sh`, `session-start.sh`).

2. **Implement `ensure_codex_hooks_wired(target)` w `bin/sage`:**
   - Read `.codex/config.toml` `[features].codex_hooks`.
   - Jeśli `false` lub absent → no-op + emit info log.
   - Jeśli `true`:
     - Backup `.codex/hooks.json` → `.codex/hooks.json.sage-bak.<ISO-ts>`.
     - Merge logic per ADR-1:
       - Identity rule = path-prefix `.codex/hooks/<known>` + sha256 match.
       - Shadow file detection (path matches, content unrecognized) →
         skip overwrite, raise MISCONFIGURED.
       - Append framework entries do array per event, preserve user entries.
     - Atomic write (`tmp` + rename).
     - Copy `runtime/platforms/codex/hooks/*.sh` → `.codex/hooks/`
       (skip identical, skip shadowed).

3. **Implement framework root resolution chain** (per ADR-2):
   - `readlink -f` portable (BSD fallback Python `realpath`).
   - Validate `runtime/`, `sage/skills/` siblings.
   - Fallback to upstream profile na invalid layout.

4. **Implement `.sage/profile` parsing:**
   - Read YAML at framework root.
   - Default `profile: upstream` jeśli plik absent lub field missing.
   - Cache value w shell session (jedna read per `sage` invocation).

5. **Generator changes (`generate-codex.sh`):**
   - Profile-aware `[features].codex_hooks` default emission
     (self-host=true, upstream=false).
   - Emit `runtime/platforms/codex/hooks/hooks.template.json` jako
     reference shape dla merge.

6. **`cmd_status` enhancement** (Component C partial):
   - Print `Framework root: <resolved>` na początku.
   - Print `Profile: <self-host|upstream>` z origin file path.
   - Add L4 section z 4 stanami (ACTIVE / DORMANT / DISABLED /
     MISCONFIGURED). Brak L5 jeszcze (M2 dodaje).

7. **Tests:**
   - Unit: `ensure_codex_hooks_wired()` × 5 fixtures
     (codex_hooks=true empty hooks.json; codex_hooks=true z custom user
     entry; codex_hooks=true twice = idempotent; codex_hooks=false noop;
     shadow file detected = MISCONFIGURED).
   - Unit: profile detection × 4 fixtures (marker self-host; marker
     upstream; absent; invalid framework layout = upstream fallback).
   - Unit: framework root resolution × 3 fixtures (direct path; symlink
     chain; brew-style packaged).
   - Integration: fresh `git init` + `sage init` → L4 ACTIVE.
   - Integration: `alex-os-dev`-shape fixture → L4 ACTIVE post-update,
     custom SessionStart preserved.
   - `sage update` × 2 = 0 diff (idempotency).

**Verification gate (M1 [A]/[R]):**
- Pasted test output dla wszystkich unit + integration tests.
- Demo: `sage update` w `tests/fixtures/alex-os-dev-shape/` →
  before/after `cat .codex/hooks.json`.
- `sage status` output show L4 ACTIVE.

**Risk: HIGH — one-way commitments + blast radius:**
- `.versions.txt` jest **append-only contract**. Po ship, każda zmiana
  hooków = dodanie nowej linii (current version), historic linie zostają
  jako "framework-known historical hashes". Edycja/usunięcie linii =
  shadow detection regression dla projektów z poprzednią wersją.
- JSON merge operuje na nested user data — corruption ma blast radius
  (user traci custom hooków). Mitigation: atomic write + `.sage-bak.<ts>`
  backup + idempotency invariant test w CI.
- Cross-platform `realpath` chain (GNU/BSD/Python) — 3 paths do
  utrzymania, regression testy per-platform.

Failure mode "merge corrupts user hooks.json" detection: JSON parse
test w CI. Recovery: restore z backup file.

**Out of scope (M2/M3):**
- L5 reporting w `sage status`.
- `--force-githooks` flag.
- Direct skill behavioral isolation.

---

## Milestone 2 — Githooks policy + `--force-githooks` CLI flag

**Goal:** `sage init` w projekcie z custom `core.hooksPath` (Husky,
lefthook, simple-git-hooks, custom scripts) szanuje cudzy setup
(default), ale daje user explicit unblock przez `--force-githooks`.
`sage status` rozpoznaje L5 DORMANT i wyjaśnia jak aktywować.

**Components covered:**
- Component D (full)
- Component C (L5 section dodana)

**Tasks:**

1. **Implement `detect_existing_hooks_framework(project_dir)`:**
   - Detection per ADR-3 lista (Husky/lefthook/pre-commit/simple-git-hooks/custom).
   - Return tuple: `(framework_name, hook_files_list)`.
   - `lefthook.yml` AND `lefthook.yaml` oba accepted.
   - simple-git-hooks: parse `package.json`, look for field.

2. **Implement `--force-githooks` arg parser w `cmd_init`:**
   - Bez flagi: zachowuje obecne behavior (skip gdy custom path).
   - Z flagą:
     - Wywołaj `detect_existing_hooks_framework()`.
     - **Always** `ls -la <custom_path>` i show user.
     - Confirm prompt: "This will deactivate <framework or 'these
       custom scripts'>. Continue? [y/N]".
     - On yes: `git config --unset core.hooksPath` + `git config
       core.hooksPath .githooks` + copy `.githooks/pre-commit` +
       audit log entry.
     - On no: exit 1, no changes.

3. **`cmd_status` enhancement** (Component C partial):
   - Add L5 section z 4 stanami (ACTIVE / DORMANT (custom path) /
     NOT INITIALIZED).
   - DORMANT output zawiera "How to activate" hint pointing do
     `sage init --force-githooks`.

4. **Tests:**
   - Unit: detection × 6 fixtures (Husky `.husky/`; Husky
     `node_modules/`; lefthook `.yml`; lefthook `.yaml`;
     pre-commit-config; simple-git-hooks; custom `.git/hooks` only).
   - Unit: `--force-githooks` × 4 (Husky + N input = abort; Husky +
     Y input = override; custom only + Y = override; no flag + custom
     path = skip).
   - Integration: `sage init --force-githooks` w fixture z Husky
     hooks.json post-condition.
   - `sage status` w custom-hookspath fixture → L5 DORMANT z hint.

**Verification gate (M2 [A]/[R]):**
- Pasted output testów.
- Demo: `sage status` przed `--force-githooks` (L5 DORMANT) → after
  flag (L5 ACTIVE).
- Demo: confirm prompt z `ls`-fallback dla custom case.

**Risk:** low — extension istniejącego `ensure_hooks_wired()`, nowa flaga
in-line, no nowy core feature.

**Out of scope (M1/M3):**
- Codex hook activation (M1).
- Behavioral isolation (M3).
- Wrapper hooks per Alt 3b (poza scope cyklu).

---

## Milestone 3 — Direct skill behavioral isolation

**Goal:** Direct skille (~60 library-tier methodologies) deployed jak
zwykle, ale **nie strzelają auto-suggest** na description match.
Workflow skille zachowują pełną reactive routing. `$<name>` invocation
i path read z workflow nadal działają.

**Components covered:**
- Component E (full, w 2 fazach: pilot + bulk)
- Component C (Skills section: count `agents/openai.yaml` deployed)
- Component F (honest config documentation)

**Tasks (Phase 1 — Pilot):**

1. **Generator changes:**
   - `generate-codex.sh` rozpoznaje direct vs workflow skill (heuristic:
     SKILL.md frontmatter `tier: workflow` vs missing/`tier: direct`).
     Direct skille dostają auto-generated `agents/openai.yaml`.
   - Generator emit `interface.short_description` = bit-identyczna
     copy SKILL.md `description:` field (SSoT per ADR-4 v3).
   - Idempotent: regen × 2 = 0 diff.

2. **Pilot deploy ONE skill (`simplify`):**
   - Add `sage/skills/simplify/agents/openai.yaml` z
     `policy.allow_implicit_invocation: false` + `[lib]` prefix
     description.
   - Update `sage/skills/simplify/SKILL.md` description field do `[lib] ...`.
   - Regenerate `.agents/skills/`.

3. **Empirical verification (pasted w verification.md):**
   - (a) Plik `.agents/skills/simplify/agents/openai.yaml` istnieje.
   - (b) Codex routing test:
     - **First batch N=5 prompts** (per ADR-4 v3 majority-rule).
     - **Pass criterion:** ≥4/5 correct routing → tentative PASS.
     - **Inconclusive zone:** 4/5 z 1 false-positive → run **second
       batch +5 prompts**. Final criterion: ≥9/10 PASS, <9/10 FAIL.
       (Codex routing non-deterministic; pojedynczy false-positive
       może być noise lub flag ignored — second batch disambiguates.)
     - **<4/5 first batch:** FAIL immediately, no second batch.
     - 5 base prompts: "uprość ten kod", "make this simpler",
       "refactor for readability", "clean up this function",
       "remove duplication here". 5 follow-up prompts (jeśli
       inconclusive): variants z innym wording ale tym samym intent.
   - (c) `$simplify` invocation z workflow działa.
   - (d) Path read `Read sage/skills/simplify/SKILL.md` działa.
   - (e) Per-agent test cross non-default agent — **per M0 decision:
     skip jeśli dev env nie ma non-default agent skonfigurowanego;
     document jako known limitation w runbook**. Recovery path
     (manual `[[skills.config]]` per-skill workaround) sufficient.

4. **Go/No-go decision checkpoint** (po pilot, BEFORE bulk):
   - PASS na (a)-(d) i (e) clean lub known-limitation → bulk Phase 2.
   - FAIL na (b) (Codex ignoruje flagę) → re-open ADR-4, fallback do
     v2 plan (`zz-sage-` rename). Pause M3.
   - FAIL na (c)/(d) → re-evaluate generator copy logic. Pause.

**Tasks (Phase 2 — Bulk, gated by Phase 1 pass):**

5. **Bulk deploy `agents/openai.yaml` dla wszystkich ~60 direct skilli:**
   - Mechaniczny script (idempotent) walking `sage/skills/*/SKILL.md`,
     filter by `tier != workflow`, emit yaml file.
   - Update SKILL.md descriptions z `[lib] ` prefix (jeśli jeszcze nie ma).
   - Regenerate `.agents/skills/` cross-platform.
   - Assert: `name:` field NIE zmieniony w żadnym SKILL.md (git diff check).

6. **`cmd_status` Skills section** (Component C final):
   - Print count `agents/openai.yaml` deployed vs total direct skille
     deployed. Discrepancy = warning.
   - Print Workflow skille count (no yaml expected).

7. **Component F — honest config docs:**
   - `runtime/platforms/codex/setup/generate-codex.sh` emit comment block
     w `.sage/config.yaml` template explaining `deploy_direct_skills`,
     `allow_implicit_invocation` mechanism, `[lib]` prefix.
   - `runtime/platforms/codex/README.md` "Config keys" section.
   - **Migration note** w `runtime/platforms/codex/README.md`
     "Migration" section z konkretnym tekstem:

     ```
     ## Migration: behavioral isolation of direct skills (2026-04-29)

     Po `sage update` direct (library-tier) skille NIE auto-suggestują
     się gdy user prompt matchuje ich description.

     What changed:
     - Each direct skill now has `agents/openai.yaml` with
       `policy.allow_implicit_invocation: false`.
     - Codex won't auto-fire `simplify`, `specify`, etc. on prompts.

     What still works:
     - Workflow skille (`/sage:build`, `/sage:fix`) auto-trigger as before.
     - Direct skille invokowalne explicit: `$simplify`, `$specify`, etc.
     - Workflow skille invocate direct skille via `$<name>` lub path read.

     How to opt out (per-skill):
     - Delete `.agents/skills/<name>/agents/openai.yaml` (will regenerate
       on next `sage update` — change source SKILL.md frontmatter to
       `tier: workflow` for permanent opt-out).
     ```

8. **Tests (full):**
   - Unit: generator emits yaml dla direct skille only.
   - Unit: yaml `interface.short_description` == SKILL.md `description`
     (SSoT regression).
   - Unit: regen × 2 = 0 diff.
   - Unit: assertion `name:` unchanged w bulk deploy.
   - Integration: `sage update` w `tests/fixtures/alex-os-dev-shape/`
     deployuje yaml dla wszystkich direct skille, generator stable.
   - Pilot test (b) regression: scripted prompts replay (jeśli możliwe
     przez Codex CLI test mode).

**Verification gate (M3 [A]/[R]):**
- Phase 1: pasted pilot output (a)-(e) z verification.md.
- Phase 2: pasted bulk deploy diff + test output + `sage status` Skills
  section showing counts match.
- Demo: `sage update` w fixture before/after — show count direct skille
  z `agents/openai.yaml`.

**Risk:** **high** — depends on Codex feature behavior. Failure mode jest
non-breaking (yaml ignored = identyczne pre-cycle behavior), ale benefit
nie zrealizowany. Pilot gate jest singlepoint of failure detection.

**Fallback plan:** Jeśli pilot (b) fails — re-open ADR-4, decyzja:
1. Defer M3 całkowicie (ship M1+M2 only).
2. Fallback do v2 plan (`zz-sage-` rename) — open new cycle z
   architect workflow.
3. Hybrid (rare): część skilli z v3 (te które działają), część z v2.

User decyduje przy go/no-go checkpoint.

---

## Cross-milestone concerns

### Decisions log
Każdy milestone close prepends decision do `.sage/decisions.md` per Rule 7.

### Memory storage
Self-learnings z M1/M2/M3 implementacji storowane przez `sage_memory_store`
per Rule 6. Szczególnie ważne: M3 pilot results (regardless pass/fail)
jako project memory (tag `behavioral-isolation`, `codex-skill-policy`).

### Test fixture: `tests/fixtures/alex-os-dev-shape/`
**Created w M1**, extended w M2 (custom hooksPath) i M3 (direct skille).
Jeden coherent fixture odzwierciedlający scenariusz briefa.

### Cross-repo discipline
**No writes do `alex-os-dev` ani innych external repos** w trakcie żadnego
milestonu. User decyduje per-repo czy/kiedy `sage update` (cross-repo
correction memory).

### Slash command compatibility
Zachowane przez ADR-4 v3 design (`name:` field niezmieniony). Q6 z
poprzedniej wersji spec usunięte. `/specify`, `/plan`, `/sage:build`
nadal działają jak przed cyklem.

---

## Success criteria (cycle-level, beyond per-milestone)

- [ ] `tests/fixtures/alex-os-dev-shape/` reprodukuje scenariusz briefa,
      `sage update` w nim → L1+L2+L4 ACTIVE, L5 DORMANT z warningiem,
      direct skille z `agents/openai.yaml` deployed.
- [ ] sage-selfhost samym w sobie raportuje L1-L5 = ACTIVE × 5 (po
      `sage update`).
- [ ] Cross-branch test: `git checkout codex-port`/`main` → defaults
      upstream-friendly (`codex_hooks=false`); `git checkout selfhost` →
      defaults aggressive.
- [ ] Wszystkie 4 ADR-y referencjonowane przez kod w bin/sage / generator.
- [ ] M3 pilot pasted output w verification.md (regardless pass/fail).
- [ ] Migration note w changelog wyjaśnia dla user-side projektów co
      zmieni się przy następnym `sage update`.
- [ ] No external repo writes.

---

## Open questions for milestone implementation

(Q1 i Q3 z poprzedniej wersji **resolved w M0** — patrz Milestone 0
tasks 4-5. Pozostała jedna deferred:)

1. **`--force-githooks` confirm prompt:** `read -r` w bashu wystarczy
   czy potrzebny TUI (`whiptail`/`gum`)? Default: `read -r` (bash builtin).
   Revisit only if user feedback says clunky. Decyzja w M2 implementation.
