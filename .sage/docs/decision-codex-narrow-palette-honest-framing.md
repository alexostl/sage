# Decision: Direct skille deployowane domyślnie, behavioral isolation via `policy.allow_implicit_invocation: false`

## Context

Trzecia rewizja tego ADR-u. Poprzednie wersje tej decyzji:

- **v1 (2026-04-29 wcześniej tej sesji):** `deploy_direct_skills: false`
  jako mechanizm narrow palette. Odrzucone — workflow auto-discovery
  odpadł, behavioral cost zbyt wysoki.
- **v2 (2026-04-29 ten sam dzień):** `deploy_direct_skills: true` +
  rename `name: zz-sage-<original>` jako push-to-end alphabetical.
  Odrzucone po RTFM v3 (patrz niżej) — istnieje tańsze i czystsze
  rozwiązanie problemu behavioralnego, a `zz-sage-` adresuje tylko
  visual ordering, nie behavior.

Cel decyzji: direct skille (~60 library-tier methodologies) **nie
strzelają auto-suggest** na description match w Codex sesji, ale
**pozostają explicit-invokable** przez workflow skille (`$<name>`
albo path read `Read sage/skills/<name>/SKILL.md`). To jest realny
behavioral problem (skill `simplify` strzela na user prompt o
"uprościć kod" zamiast workflow `sage:fix`); palette visual clutter
to oddzielny problem niższego priorytetu.

### RTFM v3 finding (decydujący)

OpenAI Codex docs ([developers.openai.com/codex/skills](https://developers.openai.com/codex/skills))
dokumentują dwa **niezależne** mechanizmy:

1. **`enabled = false`** w `~/.codex/config.toml` `[[skills.config]]`
   — skill jest **unloaded** (nie da się wywołać nawet `$name`).
   Przekreśla auto-discovery przez workflow skille. Niedostępne dla nas.

2. **`policy.allow_implicit_invocation: false`** w
   `<skill>/agents/openai.yaml` (per-skill, plik leży obok SKILL.md):
   - Skill **pozostaje loadable**.
   - Codex **nie auto-invokuje** na description match.
   - Explicit `$<name>` invocation **nadal działa** (potwierdzone w docs).

To dokładnie nasze "library-tier, no auto-fire" requirement, bez
kosztu rename'u 60+ plików.

Caveat: `allow_implicit_invocation: false` **nie ukrywa** skilli z
palety UI. Paleta nadal pokazuje wszystko alfabetycznie. Visual
clutter pozostaje — ale to estetyka, nie behavior.

## Decision

**`deploy_direct_skills: true` jako default everywhere.** Direct skille
są deployowane do `.agents/skills/<name>/SKILL.md` plus nowy plik
`.agents/skills/<name>/agents/openai.yaml`.

### Primary mechanism: `policy.allow_implicit_invocation: false`

Każdy direct skill dostaje plik `agents/openai.yaml` (nowy plik dodawany
obok SKILL.md, nie edycja samego SKILL.md):

```yaml
# sage/skills/specify/agents/openai.yaml
policy:
  allow_implicit_invocation: false
interface:
  short_description: "[lib] Write a clear, testable specification for a feature."
```

**Skutek:**
- Codex nie auto-suggestuje skilla `specify` gdy user pisze "spec this".
- Workflow skill `sage:build` może invokować `$specify` (explicit, nadal działa).
- Workflow skill może też `Read sage/skills/specify/SKILL.md` (path-based, niezmienione).
- `name:` field w SKILL.md zostaje **niezmieniony** (`name: specify`).
- Folder name zostaje **niezmieniony** (`sage/skills/specify/`).
- Workflow skill cross-references zostają **niezmienione** (żaden audit nie potrzebny).

### Secondary (kept): description prefix `[lib]`

**Single source of truth: SKILL.md `description:` field.** Generator
emit `agents/openai.yaml` `interface.short_description` jako
**bit-identyczną kopię** SKILL.md description. Nigdy nie edytujemy
ręcznie `interface.short_description` — dryft = bug.

```yaml
---
# sage/skills/specify/SKILL.md (CANONICAL)
name: specify
description: "[lib] Write a clear, testable specification for a feature."
---
```

```yaml
# sage/skills/specify/agents/openai.yaml (GENERATED)
policy:
  allow_implicit_invocation: false
interface:
  short_description: "[lib] Write a clear, testable specification for a feature."
  # ^ generator copies SKILL.md description verbatim
```

**Generator contract:** `runtime/platforms/codex/setup/generate-codex.sh`
przy każdym `sage update`/`sage init`:
1. Czyta SKILL.md frontmatter `description` field.
2. Renderuje `agents/openai.yaml` z `interface.short_description` =
   wartość z (1) jeden-do-jednego.
3. Test regression: assertion `short_description == description`.

Visual cue dla usera szukającego skilla po fuzzy search w palecie —
zobaczy że to library-tier skill. Niska cena (~60 frontmatter edits
description field), wysoki visual benefit. Robione razem z
`allow_implicit_invocation` deployment w jednym sweep.

**Anti-pattern: hand-editing `interface.short_description`.** Plik yaml
jest generated artifact. User edits w SKILL.md description, generator
re-syncuje yaml. Jeśli user edytuje yaml ręcznie, następny `sage update`
to nadpisze (intencjonalnie).

### Workflow skille — bez zmian

`name: sage`, `name: build`, `name: fix` itd. zostają.
`policy.allow_implicit_invocation` w workflow skillach pozostaje na
default `true` — workflow ma pojawiać się natywnie gdy user pisze
"build feature X".

### Visual palette ordering — DEFERRED do osobnego cyklu

`zz-sage-` rename `name:` field (push-to-end alphabetical) jest
**poza scope tego cyklu**. Revisit trigger:

- Po zaimplementowaniu `allow_implicit_invocation: false` zmierzyć
  realny visual clutter w sesji Codex.
- Jeśli paleta wizualnie nadal disrupting (60 entries scattered) —
  otworzyć osobny cykl `palette-visual-ordering` z empirical pilot.
- Jeśli `allow_implicit_invocation` rozwiązał perceived problem —
  `zz-sage-` może być niepotrzebny.

Decision do deferalu: visual disruption jest perceived/cosmetic, nie
behavior. Behavior izoluje `allow_implicit_invocation`. Nie inwestujemy
w 60+ rename + Q6 (Claude Code slash command break) + folder-match
contingency BEZ empirycznych dowodów że visual sorting daje value
ponad behavioral isolation.

## Empirical verification BEFORE bulk

Pilot deployment: pick ONE direct skill (rekomendowany: `simplify` —
najczęściej fałszywe alarmy w `alex-os-dev` per memory),
dodać `sage/skills/simplify/agents/openai.yaml` z
`policy.allow_implicit_invocation: false`. Regenerate `.agents/skills/`.

Verify (pasted output w verification.md):
- (a) Plik `.agents/skills/simplify/agents/openai.yaml` istnieje po regen.
- (b) Codex w realnej sesji **nie auto-suggestuje** `simplify` gdy user
  pisze "simplify this code" (powinien zamiast tego routować przez
  workflow `sage:fix` lub `sage:build`).
- (c) Workflow skill może wciąż invokować `$simplify` explicit
  (test: w `.codex/skills/sage` workflow zawiera `$simplify`,
  działa po deployment).
- (d) Path read `Read sage/skills/simplify/SKILL.md` z workflow działa.

Jeśli (b) failuje — Codex i tak auto-suggestuje mimo flagi —
mechanizm nie działa jak docs sugerują, **abandonujemy podejście**
i wracamy do `zz-sage-` rename plan (v2). Re-open ten ADR.

Jeśli (c) lub (d) failuje — workflow integration broken,
re-evaluate.

Jeśli wszystko pass — bulk: dodaj `agents/openai.yaml` do każdego
~60 direct skilla.

## Alternatives considered (archiwum decyzji wcześniejszych)

**Alt v1 — `deploy_direct_skills: false`.** Odrzucone (v1 → v2 pivot):
workflow auto-discovery odpada.

**Alt v2 — `name: zz-sage-<X>` rename push-to-end.** Odrzucone (v2 → v3 pivot):
- Adresuje tylko visual axis, nie behavior.
- 60+ frontmatter edits + cross-reference audit + Q6 (slash command break
  w Claude Code) + folder-match contingency (worst case 60 folder renames).
- `allow_implicit_invocation: false` daje primary benefit (behavior) bez
  tych kosztów.

**Alt B — `enabled = false` w `[[skills.config]]`.** Odrzucone:
unloaduje skill, kill `$invocation`, nie da się używać z workflow.

**Alt C — Hybrid `allow_implicit_invocation: false` + `zz-sage-` razem.**
Odrzucone w tym cyklu: pełne benefit oba osie, ale max scope cyklu i
ryzyka. Defer do osobnego cyklu jeśli pilot pokaże że visual ordering
też potrzebny po behavioral fix.

**Alt D — Display-only Codex feature** (np. `palette_visible: false`).
Odrzucone (RTFM v3 confirmed): nie istnieje. Najbliższe to
`enabled = false` które unloaduje skill całkowicie.

## Consequences

### Positive

- **Behavior izolowany cleanly** — direct skille nie tradely strzelają
  na description match, workflow skille wybierają library-tier methodology
  explicit.
- **Niska cena implementacji** — ~60 NEW files (`agents/openai.yaml`),
  brak edits w SKILL.md (oprócz `[lib]` prefix description), brak
  cross-reference audit, brak workflow refactor.
- **Bezpieczny rollback** — usunąć plik `agents/openai.yaml` = revert
  do `allow_implicit_invocation: true` (default).
- **Brak Q6 problem** — `name:` zostaje, slash commands `/specify`
  działają w Claude Code bez zmiany muscle memory.
- **Brak folder-match contingency** — folder names zostają, path
  references zostają.
- **Forward compatible** — jeśli kiedyś dodajemy `zz-sage-` rename
  (osobny cykl), to addytywne, nie konfliktujące.

### Cost / Risk

- **~60 NEW yaml files** — mechaniczny deploy, ale jest pilot gate
  przed bulk (na wypadek gdyby Codex nie respektował flagi).
- **Description prefix update** — ~60 frontmatter edits dla `[lib]`
  prefix. Robione w jednym sweep z yaml deploy.
- **Visual palette pozostaje mixed** — paleta nadal pokazuje 60+
  entries alfabetycznie zmieszane z workflow skillami. Akceptujemy
  jako cosmetic-tier, defer do osobnego cyklu.
- **Codex bug [#14161](https://github.com/openai/codex/issues/14161)**
  — sub-agent TOML overrides ignorowane. Affects `[[skills.config]]`
  per-agent path. Nasz mechanizm (`agents/openai.yaml` per-skill)
  jest **inny code path**, ale RTFM v3 nie potwierdził empirycznie
  że flaga apply cross non-default agents. **Pilot test (e)
  weryfikuje** to przed bulk:
  - Jeśli flaga apply universally (default + non-default agents) —
    dokumentujemy w runbook.
  - Jeśli flaga apply tylko dla default `openai` agent —
    **known limitation**, nie blocker. User uses non-default agent
    może manual override przez `~/.codex/config.toml`
    `[[skills.config]]` per-skill `enabled = false` (workaround).
  - Jeśli flaga ignored entirely — pilot fails (b), fallback do
    v2 plan (`zz-sage-` rename).
  Monitorujemy bug, ale `[[skills.config]]` issue nie blokuje
  decision — to inny mechanizm.
- **Stability** — feature shipped late 2025/early 2026, względnie świeży.
  Empirical pilot zweryfikuje real behavior przed bulk.

### Anti-patterns to avoid

- Ustawianie `allow_implicit_invocation: false` w workflow skillach
  (zabije discovery przez user prompt — ich sednem jest właśnie
  reactive routing).
- Mieszanie: niektóre direct skille z `agents/openai.yaml`, inne bez
  — niespójność, część tradely strzela.
- Dodanie `zz-sage-` rename "przy okazji" — defer to osobny cykl,
  nie smarujemy scope tego.
- Zakładanie że `allow_implicit_invocation: false` ukrywa z palety —
  nie ukrywa, tylko blokuje auto-suggest.

### Revisit trigger

Otworzyć osobny cykl gdy:
- Pomiar po deployment pokaże że paleta nadal jest visually
  disruptive (user feedback "nie mogę znaleźć workflow skilla
  bo zalany lib").
- Codex doda dedicated palette-hide flag (np. `palette_visible: false`)
  — wtedy może w ogóle bez rename.
- Codex doda priority/order/group field w SKILL.md spec.

W tych przypadkach rozważamy `zz-sage-` rename jako visual axis fix,
osobno od behavioral isolation tej decyzji.
