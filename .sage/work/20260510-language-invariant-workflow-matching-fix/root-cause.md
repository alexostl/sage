---
title: "Root cause: Batch 5 harness/incidents/language-invariant matching"
cycle_id: "20260510-language-invariant-workflow-matching-fix"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-14
updated: 2026-05-14
source_intakes:
  - "20260509-mcp-incident-followup-fixes"
  - "20260509-target-repo-ownership-harness-fix"
---

# Root cause: Batch 5 harness/incidents/language-invariant matching

## Problem

Batch 5 łączy trzy intake'i, które na powierzchni wyglądają różnie:

1. incident log jest zasypywany fałszywymi albo powtarzalnymi wpisami;
2. RealHarness potrafi oblać poprawne zachowanie, jeśli agent odpowiada po
   polsku albo innym wordingiem;
3. target-repo ownership może być poprawny na końcu runu, ale transcript
   ujawnia wcześniejszą próbę zapisu do parent/framework repo.

Wspólny problem: Sage ocenia część zachowań przez kruche ślady techniczne
zamiast przez stabilny kontrakt stanu, eventu albo znaczenia.

## Root cause

Sage ma trzy niespójne warstwy oceny agent behavior:

- **Harness transcript rubrics** mieszają structural checks z natural-language
  semantic checks. `aggregate-signals.sh` traktuje każdy
  `required_transcript_patterns` jako zwykły regex, więc poprawna semantycznie
  odpowiedź może failować, jeśli nie zawiera oczekiwanej frazy.
- **Incident hooks** patrzą na cały bieżący dirty worktree, a nie na delta od
  startu sesji/runu. To sprawia, że stary brudny stan repo może wyglądać jak
  `unclaimed_change` albo `bypass_mutation` obecnej sesji.
- **Audit/frontmatter probes** nie rozróżniają typów `.sage` markdownów i
  zdarzeń. `decisions.md` jest zwykłym dziennikiem, ale Check C próbuje czytać
  fragment między separatorami `---` jak YAML frontmatter. `phase_jump_observed`
  jest logowany wielokrotnie za samo ponowne zobaczenie statusu `completed`,
  zamiast być deduplikowanym eventem lub metryką harnessu.
- **Mutation-class policy** ma tylko ciężki model "implementation mutation vs
  bypass/no-op", ale nie ma jawnego, lżejszego typu "documentation/capture-only
  `.sage/**` mutation". Przez to legalne capture/intake zmiany są oceniane tym
  samym mechanizmem co kod produkcyjny: jeśli bieżący `git status` nie pokazuje
  claimed path albo pokazuje dodatkowy stary dirty state, hook emituje
  `claim_no_op`/`unclaimed_change`, zamiast sklasyfikować zmianę jako audytowany
  capture event.

Target-repo ownership jest w aktualnym kodzie częściowo pokryty: generated
guidance zakazuje `.sage/**` poza target repo, a harness ma już forbidden
transcript patterns dla parent repo. Ten intake nadal jest ważny, ale jego
root cause jest teraz bardziej bookkeeping/evidence drift niż brak zupełnie
nowej runtime reguły.

## Evidence

### 1. Scenario 12 nadal używa językowo kruchego regexu

`runtime/platforms/codex/harness/v11-scenarios.json` ma dla scenario 12
natural-language pattern:

```json
"required_transcript_patterns": [
  "scoped autonomy|Full autonomous implementation|approved plan|manifest scope|bez checkpoint|without checkpoints",
  "scope expansion|grant|outside scope|poza scope",
  "key assumption|założen|checkpoint|decyz"
]
```

To wymaga obecności konkretnych fraz. QA Klastra B pokazała, że agent zatrzymał
się poprawnie przy zmianie założeń, ale rubric failował przez brak oczekiwanej
angielskiej frazy. Dowód jest w
`.sage/work/20260509-workflow-entry-resume-recovery-autonomy-fix/qa-report.md`.

Mechanizm w `runtime/platforms/codex/harness/lib/aggregate-signals.sh` jest
czysto regexowy: dla każdego patternu robi `grep -E -q` po transkrypcie i
dopiero wtedy uznaje rubric za passed. To jest dobre dla ścieżek, eventów i
forbidden absolutnych pathów, ale kruche dla znaczenia wypowiedzi.

### 2. Incident hooks nie mają baseline'u dirty state z początku sesji

`post-tool-check.sh` i `turn-audit.sh` zbierają aktualne ścieżki przez
`git status --porcelain -uall`. To łapie untracked files i jest potrzebne, ale
nie odróżnia:

- pliku brudnego przed startem sesji;
- pliku zmienionego legalnie przez wcześniejszą sesję;
- bieżącego, realnego bypassu obecnej sesji.

W `turn-audit.sh` claimed paths są filtrowane po `session_id`, ale actual paths
pochodzą z całego repo statusu. Jeśli repo było brudne przed sesją, actual path
nie ma odpowiadającego claimu w bieżącym session logu i może zostać
`bypass_mutation`.

Aktualny `.sage/.mcp-incidents.log` potwierdza skalę szumu: ma ponad 16k linii,
w tym tysiące `unclaimed_change` i `bypass_mutation`. To jest za dużo, żeby
incident log był użytecznym sygnałem operacyjnym.

### 3. `decisions.md` jest fałszywie traktowany jak frontmatter file

`post-tool-check.sh` uruchamia Check C dla każdego zmienionego `.sage/*.md`.
Nie rozróżnia `manifest.md`/`plan.md`/`spec.md` od `.sage/decisions.md`.

Reprodukcja read-only pokazała, że ekstraktor frontmatteru bierze treść między
pierwszymi separatorami `---` w `decisions.md`, a potem `yq` failuje:

```text
Error: bad file '-': yaml: line 2, column 34: mapping values are not allowed in this context
```

To tłumaczy powtarzalne `broken_frontmatter` dla poprawnego dziennika decyzji.

### 4. `claim_no_op` nie zna capture/intake-only semantyki

`post-tool-check.sh` porównuje `claimed_paths` z `actual_paths` z
`git status --porcelain -uall`. Następnie emituje `claim_no_op`, jeśli claimed
path nie jest w aktualnym dirty state albo jeśli `actual_paths` jest puste.

To jest sensowne dla zwykłego patcha kodu: agent powiedział "zmieniam plik",
ale repo nie pokazuje zmiany. Dla capture/intake-only `.sage/**` to jest za
mało precyzyjne, bo legalny capture może:

- tworzyć lub aktualizować intake manifest, który jest poprawnym śladem pracy;
- być częścią dokumentacyjnego porządkowania bez kodu produkcyjnego;
- współistnieć z wcześniejszym dirty state z poprzedniej sesji;
- nie mieć semantyki "no-op" nawet wtedy, gdy finalny diff jest nietypowy
  albo został skonsumowany przez inną ścieżkę zapisu.

Root cause nie jest więc samo `claim_no_op`. Root cause jest brak policy-level
klasyfikacji "audytowany capture/documentation-only mutation" przed
zastosowaniem generycznej diff-claim rubryki.

### 5. Documentation/capture-only nie ma lżejszego audytowanego trybu

MCP incident intake wymaga lżejszego trybu dla zmian typu `.sage/work/**`,
`.sage/docs/**` i `.sage/decisions.md`, gdy nie dotykają runtime/code/test
behavior. Obecny model zna głównie:

- workflow implementation, które wymaga planu/scope/testów;
- hook bypass/no-op incidents, które zakładają podejrzaną mutację;
- safe auto-fix, który obejmuje wąskie metadata hygiene przypadki.

Brakuje środka: legalnego, jawnego, audytowanego "capture/documentation-only"
path. Bez tego agent musi czasem otwierać cięższy cykl tylko po porządkową
dokumentację, albo incident hooks produkują szum, bo nie mają typu zdarzenia
pasującego do małej dokumentacyjnej mutacji.

To jest osobna przyczyna od dirty baseline. Dirty baseline tłumaczy stare
zmiany widziane jako nowe; brak capture-only mode tłumaczy, dlaczego legalne
małe `.sage/**` zmiany nie mają spokojnej, strukturalnej ścieżki oceny.

### 6. `phase_jump_observed` jest zdarzeniem powtarzalnym, nie deduplikowanym

`turn-audit.sh` loguje `phase_jump_observed` za każdy claimed
`.sage/work/*/{manifest,spec,plan}.md`, jeśli on-disk frontmatter ma
`status: completed`. W praktyce ten sam completed manifest może emitować
kolejne wpisy przy późniejszych hook runach. W logu Batcha 4 widać
wielokrotne wpisy dla tych samych completed cycles i turnów.

Samo "plik jest completed" nie jest błędem. To powinno być deduplikowane
zdarzenie albo metryka harnessu, inaczej zasypuje incident log i obniża
czytelność realnych problemów.

### 7. Target repo ownership assertion istnieje częściowo, ale intake nie jest
zamknięty

Current harness ma już forbidden transcript patterns dla scenario
`11-bug-report-no-fix`:

```json
"__FRAMEWORK_ROOT__/\\.sage/decisions\\.md",
"__FRAMEWORK_ROOT__/\\.sage/work/[^/]+/manifest\\.md"
```

`aggregate-signals.bats` ma też test, że scenario 11 failuje, jeśli transcript
wspomina parent repo `.sage` write. Generated `AGENTS.md` source mówi jawnie:
nie pisać `.sage/**` poza target repo.

To znaczy, że "trójka" jest przede wszystkim RealHarness suite/bookkeeping
follow-upem: sprawdzić, czy obecny assertion wystarcza, ewentualnie domknąć
coverage i oznaczyć intake jako folded/completed po verified fixie Batcha 5.

## Chain

1. Real agent działa w języku i wordingach, które nie są w pełni przewidywalne.
2. Harness sprawdza część semantycznych zachowań przez regex po raw transcript.
3. Hooki i audit logi sprawdzają część zdarzeń przez globalny dirty state, bez
   baseline'u sesji/runu i bez deduplikacji.
4. Capture/documentation-only `.sage/**` nie ma osobnego, lżejszego typu
   mutacji, więc wpada w ciężkie implementation/bypass/no-op rubryki.
5. Testy potrafią failować poprawne zachowanie albo przepuszczać zachowanie
   kończące się poprawnym final state, ale ze złym transient transcript.
6. Incident log traci wartość: miesza prawdziwe obejścia, historyczny brudny
   stan, poprawne decyzje i powtarzalne eventy.

## Confidence

High.

Diagnoza ma trzy niezależne źródła: aktualny kod rubryk/agregatora, aktualny
kod hooków oraz realne evidence z QA/historii `.mcp-incidents.log`. Nie
zakłada konkretnego błędu modelu ani konkretnego driftu Codex GUI/CLI; opisuje
warstwę Sage, którą możemy naprawić deterministycznie.

## Scope implication

To jest Systemic root cause, ale plan powinien zacząć od minimalizacji:

- najpierw przenieść możliwe checks na strukturalne state/audit fields;
- natural-language transcript regex zostawić tylko tam, gdzie sprawdza path,
  event albo krótką, wielojęzyczną kategorię;
- dodać lub doprecyzować audytowany capture/documentation-only path zanim
  zaostrzymy incidenty, żeby legalne `.sage/**` porządki nie wyglądały jak
  bypass/no-op;
- nie dodawać LLM classifiera do harnessu bez osobnej decyzji;
- nie robić dużej przebudowy target ownership, jeśli obecny assertion i
  generated guidance już zamykają problem.

Przewidywany fix scope będzie co najmniej Moderate, bo dotyka harness rubrics,
hook incident logic i testów. Ostateczny zakres trzeba zatwierdzić osobno w
fix scope gate.
