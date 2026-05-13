---
cycle_id: "20260509-cycle-workflow-entry-enforcement-fix"
title: "Root cause: Batch 1 workflow entry and resume contract"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
---

# Root cause: Batch 1 workflow entry and resume contract

## Zakres diagnozy

Ta diagnoza dotyczy całego Batcha 1:

- `20260509-cycle-workflow-entry-enforcement-fix`
- `20260509-agent-resume-intake-cycle-fix`
- `20260509-cycle-state-disclosure-fix`
- `20260509-codex-task-plan-visibility-fix`
- `20260509-fix-trigger-gate-fix`
- `20260509-active-cycle-lease-lock`

Nie obejmuje Batcha 2 (`mutation-intent-preflight`, recovery po hook blocku,
binary assets), choć runtime hooki są częścią dowodu, bo pokazują jak dyskowy
stan cyklu jest egzekwowany.

## Root cause

Batch 1 nie ma jednego, end-to-end kontraktu **state transition before work**,
który byłby jednocześnie:

1. widoczny dla agenta w routingu i workflowach,
2. widoczny dla Alexa w komunikacji i Codex task planie jako warstwie
   obserwowalności,
3. egzekwowalny przez hooki/runtime,
4. sprawdzany przez deterministic tests i real-agent harness.

Poszczególne warstwy już mają fragmenty tego modelu, ale nie składają się w
pełny kontrakt dla realnego agenta:

- navigator rozróżnia rozmowę, action mandate i Standard+ state transition;
- `continue.workflow.md` mówi, że `intake`/`paused` są parked i wymagają
  formalnego continuation;
- generated `AGENTS.md` ma już ogólną zasadę state transition i plan/progress
  visibility;
- hook `pre-tool-validate.sh` potrafi zablokować brak aktywnego cyklu, wybrać
  cycle z path intentu, obsłużyć parked capture i sprawdzić `active_session_id`;
- harness ma scenariusze dla action/resume i fix-trigger.

Problem polega na tym, że te fragmenty nie definiują jednego obserwowalnego
przepływu: **rozpoznaj mandate -> wybierz workflow/cykl -> zmień frontmatter ->
powiedz użytkownikowi co się zmieniło -> utrzymuj Codex plan -> dopiero potem
pisz artefakty/kod zgodnie z gate**.

## Dowody

### 1. Navigator zna boundary, ale nie rozpisuje pełnej sekwencji

`core/capabilities/orchestration/sage-navigator/SKILL.md` rozróżnia
read-only conversation od action mandate i mówi, że Standard+/Moderate+ entry
lub resume jest realnym state transition. To dobry fundament, ale w praktyce
nie wystarcza jako executable checklist dla realnego agenta: nie mówi, jak
spiąć to z task-plan UI, fix-trigger gate i lease ownership.

Dowód:

- `core/capabilities/orchestration/sage-navigator/SKILL.md:142`
- `core/capabilities/orchestration/sage-navigator/SKILL.md:198`

### 2. Continue workflow definiuje parked state, ale nie zamyka UX kontraktu

`continue.workflow.md` mówi, że `paused` i `intake` są resumable, ale nie
mutation-active, a formal continuation musi zmienić manifest przed artefaktami
lub kodem. Brakuje jednak wspólnego standardu: jaka faza jest ustawiana dla
danego workflow, kiedy komunikat ma paść po fakcie, i jak Codex plan ma pokazać
żywy postęp po wznowieniu.

Dowód:

- `core/workflows/continue.workflow.md:26`
- `core/workflows/continue.workflow.md:35`

### 3. Generated AGENTS.md ma ogólną regułę, ale Batch 1 wymaga ostrzejszego modelu

Generated Codex contract już mówi, że Standard+/Moderate+ entry/resume musi
utworzyć lub zaktualizować manifest przed artefaktami/kodem, oraz że agent ma
powiedzieć, który `status`/`phase` się zmienił. Ma też ogólny wymóg native
plan/progress view dla Standard+ pracy Codexa. Ten task-plan nie jest samodzielną
przyczyną blokad runtime; jest warstwą obserwowalności, która ma pokazywać
Alexowi, czy agent faktycznie przeszedł przez żywe kroki Sage.

To nadal nie łapie całego Batcha 1, bo fix-trigger i lease lock są tylko
pośrednio pokryte przez ogólne słowa. W efekcie realny agent może potraktować
"find and fix" jako szybki direct edit albo `status: in-progress` jako globalne
pozwolenie na zapis, zamiast jako stan z możliwym właścicielem/lease.

Dowód:

- `runtime/platforms/codex/setup/lib/agents-md.sh:230`
- `runtime/platforms/codex/setup/lib/agents-md.sh:239`

### 4. Runtime egzekwuje stan dysku, ale nie uczy agenta całej ścieżki

`pre-tool-validate.sh` i `active_init.sh` mają już sporo właściwej logiki:
`file_change` jest parsowany, brak aktywnego cyklu blokuje mutacje,
`active_session_id` blokuje obcą sesję, parked capture ma osobny zakres, a path
intent może wygrać z globalnym newest active.

To egzekwuje stan, ale nie zastępuje kontraktu agenta. Hook widzi dopiero próbę
mutacji; Batch 1 potrzebuje, żeby agent robił precyzyjne entry/resume i
komunikował status zanim runtime musi go zatrzymywać.

Dowód:

- `runtime/platforms/codex/hooks/pre-tool-validate.sh:55`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:167`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:180`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:188`
- `runtime/platforms/codex/hooks/lib/active_init.sh:133`

### 5. Lease-lock ma osobne źródło intencji

`active-cycle-lease-lock` nie jest przypadkowym dodatkiem do entry/resume. Jego
intencja została zapisana osobno: aktywny lease ma blokować implementation paths
oraz artefakty aktywnego `in-progress` cyklu należącego do innej sesji, ale nie
ma zamrażać koncepcyjnej pracy w osobnych `intake`/`paused` cycles.

To potwierdza, że Batch 1 potrzebuje ownership predicate, nie tylko ogólnego
"status in-progress oznacza można pisać".

Dowód:

- `.sage/work/20260509-active-cycle-lease-lock/manifest.md:30`
- `.sage/work/20260509-active-cycle-lease-lock/manifest.md:40`
- `.sage/decisions.md:95`

### 6. Real-agent QA pokazuje symptomy Batcha 1

QA na Project Dummy pokazało, że scenariusz `04-fix-trigger` zmienił
`AGENTS.md` bez pełnej diagnozy i gate'u fix. To jest bezpośredni objaw braku
ostrzejszego kontraktu: "find and fix" w pliku instrukcji/procesu nie powinien
omijać diagnose -> root cause -> scope.

Ten sam raport pokazał też, że scenariusz 03 i inne mutacje dotykają Batcha 2,
dlatego nie powinny być mieszane z obecnym scope poza dowodem ogólnej potrzeby
runtime/harness spójności.

Dowód:

- `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md:45`
- `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md:93`

## Chain

1. User daje action mandate albo wskazuje konkretny intake/paused cycle.
2. Agent rozumie intencję, ale nie zawsze wykonuje formalny transition jako
   pierwszą operację workflow.
3. Rozmowa, task-plan UI Codexa, manifest i hooki zaczynają mówić różnymi
   językami: jeden kanał mówi "pracujemy", drugi nadal widzi `intake`, brak
   planu albo brak właściciela aktywnej sesji.
4. Agent próbuje pisać artefakt/kod, albo robi direct fix-trigger edit.
5. Runtime czasem blokuje próbę, a czasem harness dopiero później pokazuje, że
   agent wykonał legalnie wyglądający, ale procesowo błędny patch.

## Diagnosis

Najwęższy poprawny fix to nie "dopisać jedno zdanie" i nie osobny mechanizm
lease jako pierwszy krok. Trzeba wprowadzić jeden Batch 1 contract:

> Dla Standard+/Moderate+ pracy, formalnego resume, fix-trigger w
> instruction/process files i aktywnych cykli z możliwym właścicielem, agent
> musi najpierw utworzyć albo wznowić obserwowalny stan `.sage`, potem
> zakomunikować konkretną zmianę `status`/`phase`, utrzymywać Codex task-plan
> dla żywego postępu i dopiero potem mutować artefakty/kod zgodnie z gate.

Lease lock jest częścią tego kontraktu, ale jako ownership predicate:
`status: in-progress` oznacza, że cykl jest implementation-active; jeśli ma
`active_session_id`, inna sesja nie może go mutować bez handoffu. Równoległa
praca koncepcyjna pozostaje legalna tylko jako capture/planning-only `.sage/**`
dla osobnych `intake`/`paused` cycles, bez mieszania implementation paths.

## Confidence

High.

Dowody pochodzą z aktualnych workflowów, generated Codex contract, runtime
hooków i real-agent QA reportu. Dodatkowo wcześniejsze completed root cause'y
opisują podobny problem jako "state transition before continuation"; Batch 1
zawęża ten model do entry/resume/disclosure/task-plan/fix-trigger/lease.

## Scope classification preview

To będzie co najmniej **Moderate**, prawdopodobnie **Systemic**:

- dotknie więcej niż dwóch plików;
- obejmie generated Codex `AGENTS.md`, navigator/continue guidance, testy
  Stage 3 oraz prawdopodobnie hook tests/harness scenarios;
- może wymagać doprecyzowania semantyki `active_session_id` i task-plan UI.

Scope gate powinien rozstrzygnąć, czy robimy to jako jeden systemic fix w
Batchu 1, czy rozbijamy implementację na dwa kroki: najpierw instruction/harness
contract, potem runtime lease predicate.
