---
cycle_id: "20260509-workflow-entry-resume-recovery-autonomy-fix"
title: "Root cause: workflow entry, resume, recovery i autonomia"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-09
updated: 2026-05-10
---

# Root cause: workflow entry, resume, recovery i autonomia

## Problem

Klaster B wygląda jak kilka osobnych tematów: workflow declaration, resume
intake cycle, hook block recovery, komunikowanie wejścia/wyjścia z cyklu,
lease lock i `[F] Full autonomous implementation`. Wspólny problem jest jednak
jeden: Sage nie ma spójnego kontraktu **state transition before continuation**
dla pracy, która realnie wymaga stanu Sage.

Czyli: jeśli agent ma zacząć albo wznowić Standard+/Moderate+ workflow,
mutować aktywny cykl, odzyskać się po hook blocku, zapisać trwałą decyzję albo
kontynuować bez checkpointów po `[F]`, to najpierw musi istnieć obserwowalny
stan projektu albo zatwierdzony plan, który to uprawnia. Sama rozmowna
deklaracja nie wystarcza. Drobne Lightweight/Surgical zmiany nadal mogą zostać
wykonane bez tworzenia wpisów w `.sage`, o ile nie tworzą trwałej decyzji,
incydentu, learningu ani nie dotykają aktywnego cyklu.

## Root Cause

Obecny model rozdziela odpowiedzialność między kilka miejsc:

1. `AGENTS.md` / generated Codex contract klasyfikuje mandate i mówi, że
   Standard+ work ma routować do workflow.
2. `continue.workflow.md` rozróżnia `in-progress`, `paused` i `intake`, ale
   opisuje resume bardziej jako nawigację niż formalny state transition.
3. Hook `pre-tool-validate.sh` blokuje brak aktywnego cyklu i daje recovery
   message, ale nie ustanawia jasnego kontraktu, kiedy blokada jest recoverable
   i agent ma retry, a kiedy to hard stop.
4. Build/fix/build-loop opisują `[F]`, ale autonomia jest opisana jako tryb
   pracy bez wystarczająco jasnego powiązania z zatwierdzonym `plan.md` i
   `manifest.scope`.
5. Harness ma scenariusze dla "action creates/resumes manifest" i "blocked
   mutation next legal move", ale nie obejmuje pełnej sekwencji:
   declaration -> state transition -> artifact/code mutation albo
   recoverable block -> corrected retry.

To tworzy lukę między trzema prawdami:

- prawdą rozmowy: agent mówi, że jest w workflow albo że kontynuuje;
- prawdą dysku: `manifest.md` nadal jest `intake`, `paused` albo bez grant;
- prawdą runtime: hooki widzą tylko dysk i poprawnie blokują albo przepuszczają
  według niepełnego modelu.

## Evidence

### 1. Generated Codex contract wymaga routingu, ale nie mówi "state first"

`runtime/platforms/codex/setup/lib/agents-md.sh` klasyfikuje action mandate i
mówi, że explicit workflow command ma wejść w workflow, a Standard+ work ma
routować do workflow. To jest dobry kierunek, ale brakuje twardej reguły:
"nie deklaruj wejścia/resume, dopóki manifest/frontmatter nie został
utworzony albo zaktualizowany".

Relevant lines:

- `runtime/platforms/codex/setup/lib/agents-md.sh:202`
- `runtime/platforms/codex/setup/lib/agents-md.sh:211`
- `runtime/platforms/codex/setup/lib/agents-md.sh:221`

### 2. Continue workflow rozpoznaje parked state, ale nie definiuje resume mutation

`core/workflows/continue.workflow.md` mówi, że `paused` i `intake` są
resumable, ale nie mutation-active, dopóki user nie potwierdzi continuation.
To wyjaśnia dlaczego hook blokował artefakt w cyklu intake, ale nadal zostawia
agentowi nieostry krok: co dokładnie ma zmienić w `manifest.md`, w jakiej
fazie i kiedy może dopiero tworzyć artefakt.

Relevant lines:

- `core/workflows/continue.workflow.md:18`
- `core/workflows/continue.workflow.md:21`
- `core/workflows/continue.workflow.md:41`

### 3. Hook recovery message blokuje, ale nie wymusza corrected retry

`runtime/platforms/codex/hooks/pre-tool-validate.sh` daje sensowny komunikat
`sage:continue` / natural-language resume, ale z perspektywy zachowania agenta
brakuje kontraktu: jeśli message zawiera wykonalny next legal move i blokada
jest recoverable, agent powinien skorygować kształt akcji i spróbować legalną
ścieżką, zamiast kończyć turę samym raportem o blokadzie.

Relevant lines:

- `runtime/platforms/codex/hooks/pre-tool-validate.sh:67`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:69`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:87`

### 4. Autonomia jest scoped, ale wording nadal może brzmieć zbyt ogólnie

`build.workflow.md` i `build-loop/SKILL.md` mówią, że `[F]` zatrzymuje się przy
scope expansion, decyzjach i failing tests requiring changed assumptions. To
dobry stop condition, ale wording nadal może pozwalać agentowi potraktować
`[F]` jako ogólną swobodę działania. Poprawka nie powinna wprowadzać ciężkiego
systemu grantów; wystarczy jasno powiedzieć, że `[F]` oznacza wykonanie
zatwierdzonego planu bez checkpointów, dopóki nie pojawi się kluczowa decyzja
zmieniająca założenia.

Relevant lines:

- `core/workflows/build.workflow.md:25`
- `core/workflows/build.workflow.md:30`
- `core/capabilities/orchestration/build-loop/SKILL.md:32`
- `.sage/work/20260509-autonomous-approval-boundary-fix/plan.md`

### 5. Harness łapie wybrane symptomy, ale nie pełny kontrakt

`v11-scenarios.json` ma release-blocker scenario `06-action-creates-or-resumes-manifest`
i `03-blocked-mutation-next-legal-move`. To weryfikuje ważne punkty, ale nie
spina całego modelu:

- deklaracja workflow musi być spełniona state transition;
- resume parked cycle musi zmienić frontmatter przed artefaktem;
- recoverable block musi prowadzić do corrected retry;
- `[F]` nie może rozszerzać scope bez nowego approval;
- active lease innej sesji ma blokować zapis do `in-progress`.

Relevant lines:

- `runtime/platforms/codex/harness/v11-scenarios.json:32`
- `runtime/platforms/codex/harness/v11-scenarios.json:42`
- `runtime/platforms/codex/harness/prompts/06-action-creates-or-resumes-manifest.txt`
- `runtime/platforms/codex/harness/prompts/03-build-out-of-scope.txt`

## Chain

1. User daje action mandate albo mówi "kontynuujmy ten cykl".
2. Agent poprawnie rozumie intencję, ale traktuje ją jako rozmowną zgodę.
3. `manifest.md` nie zmienia się do aktywnego, właściwego stanu albo `[F]`
   zaczyna być traktowane szerzej niż zatwierdzony plan.
4. Agent próbuje artefaktu/kodu albo scope expansion.
5. Hook/runtime widzi brak formalnego stanu i blokuje, albo przepuszcza
   przypadek, którego harness nie umie jeszcze ocenić.
6. Agent może zatrzymać się po recoverable blocku, zamiast zrobić legalny retry,
   albo kontynuować autonomię poza zatwierdzonym snapshotem.

## Diagnosis

Najwęższy systemowy fix nie powinien zaczynać od lease locka jako osobnego
mechanizmu. Najpierw trzeba wprowadzić wspólny kontrakt:

> Entry, resume, recovery i autonomy dla Standard+/Moderate+ pracy, aktywnych
> cykli i trwałych decyzji są legalne tylko wtedy, gdy istnieje odpowiedni,
> obserwowalny state transition na dysku albo zatwierdzony plan. Jeśli taki
> stan nie istnieje, agent ma zrobić formalny transition, zatrzymać się po
> approval, albo wykonać recoverable retry zgodnie z hook guidance.

Lease lock jest rozszerzeniem tego modelu: `status: in-progress` nie oznacza
automatycznie "każdy agent może pisać". Potrzebny jest właściciel/lease albo
jawne przejęcie, ale to powinno wejść dopiero po zatwierdzeniu scope, bo wymaga
osobnego designu źródła prawdy i TTL.

## User Calibration 2026-05-10

### Fix 1: Standard+ nie może połykać drobnych zmian

Agent klasyfikuje najpierw intencję, a dopiero potem ciężar procesu.
`Standard+` nie oznacza "każda zmiana w pliku". Oznacza pracę, która wymaga
formalnego workflow, bo ma ryzyko koordynacyjne albo decyzyjne.

W build workflow próg wygląda tak:

- `Lightweight`: jeden komponent, brak decyzji projektowej, brak widocznej
  zmiany zachowania dla innych osób; agent może zrobić zmianę bez pełnego
  spec/plan cycle.
- `Standard`: wiele komponentów, jakakolwiek decyzja projektowa albo
  koordynacja między modułami; wymagane są `spec.md` i `plan.md`.
- `Comprehensive`: nowy subsystem, cross-cutting change albo wiele
  stakeholder impacts; wymagany jest brief -> spec -> plan.

W fix workflow analogicznie:

- `Surgical`: 1-2 pliki, brak interface changes i nowych abstrakcji; nadal
  agent pokazuje scope, ale nie musi robić ciężkiego planu.
- `Moderate`: 3-5 plików, test infrastructure albo pattern zmiany błędów;
  wymagany jest plan i manifest scope przed kodem.
- `Systemic`: 5+ plików, API/interface, nowa abstrakcja albo architektoniczne
  konsekwencje; wymaga większego scope gate.

Plan dla Fix 1 ma więc doprecyzować: agent może "po prostu zrobić zmianę tak o"
tylko wtedy, gdy jest to Lightweight/Surgical i nie narusza aktywnego Sage
scope. Jeśli agent deklaruje workflow Standard+ albo Moderate+, wtedy deklaracja
musi otworzyć lub wznowić realny cykl.

### Fix 3: hook block zawsze ma być instrukcją korekty

Docelowy model: hook blokuje nielegalną akcję, ale nie zostawia agenta przy
ścianie. Każdy blocking path powinien podać recovery path:

- co zostało zablokowane;
- dlaczego;
- jaka jest następna legalna akcja;
- czy agent ma retry po korekcie, czy potrzebna jest decyzja usera.

Hard stop nadal istnieje dla rzeczy typu destructive action, konflikt
instrukcji albo decyzja architektoniczna, ale nawet wtedy komunikat ma mówić,
jaką decyzję trzeba uzyskać, zamiast kończyć pracę pustym "blocked".

### Fix 5: komunikować każdą zmianę statusu

Zakres Fix 5 jest szerszy niż wejście/wyjście z cyklu. Agent powinien jawnie
komunikować każdą zmianę statusu albo phase, np. `intake -> in-progress`,
`plan-gate -> deliver`, `in-progress -> paused`, `in-progress -> completed`.

Ważny warunek: komunikat ma następować po faktycznej zmianie frontmatter, nie
jako zapowiedź bez pokrycia w pliku.

### Fix 6: lease lock tylko jeśli jest prosty

Active-cycle lease lock nie jest obowiązkową częścią implementacji. Plan ma
najpierw sprawdzić, czy istnieje bardzo prosty wariant, np. lekki metadata
field albo plik markerowy bez osobnego daemon/heartbeat systemu.

Jeśli sensowna implementacja wymaga TTL, session ownership, stale lock cleanup
i osobnych recovery flows, wtedy ten element trzeba odrzucić z tego klastra i
zostawić jako osobny design problem.

### Fix 7: autonomia jako zgoda na plan, nie ciężki grant system

`[F] Full autonomous implementation` powinno być opisane miękko:

> User zgadza się na wykonanie zatwierdzonego planu bez checkpointów.

Agent nie powinien wracać po zgodę przy każdej drobnej mechanicznej zmianie.
Ma wrócić dopiero wtedy, gdy pojawi się kluczowa decyzja, która zasadniczo
zmienia założenia planu, produkt, architekturę albo ryzyko. Sam fakt dodania
nowego pliku nie musi automatycznie anulować autonomii, jeśli mieści się w
zatwierdzonym planie i nie zmienia założeń.

### Poniżej Standard+: kiedy zapisujemy `.sage`

Poniżej Standard+ agent nie powinien automatycznie tworzyć `.sage/work` ani
dopisywać `.sage/decisions.md` dla każdej drobnej zmiany. To byłoby sprzeczne z
celem Lightweight/Surgical: szybka, oczywista praca bez ciężkiego workflow.

Zasada docelowa:

- Lightweight/Surgical może skończyć się tylko zmianą kodu i krótkim final
  summary w rozmowie.
- `.sage` zapisujemy mimo małej pracy, jeśli pojawia się trwała decyzja
  projektowa, follow-up/TODO, correction/self-learning, incydent/recovery albo
  zmiana dotyczy aktywnego cyklu.
- Jeśli mała zmiana zaczyna dotykać wielu plików, decyzji projektowej albo
  scope aktywnego cyklu, agent podnosi klasyfikację do Standard+/Moderate i
  wtedy wchodzi w formalny workflow.

### Fix 6: prosty lease rule oparty o aktywację `in-progress`

Najprostszy akceptowalny wariant lease lock:

> Cykl w `status: in-progress` może edytować tylko sesja, która aktywowała ten
> stan.

Nie trzeba na tym etapie rozdzielać `plan-gate`, `fix-scope-gate`, `deliver`
itd. To są `phase` w ramach tego samego aktywnego cyklu. Claim dotyczy całego
`status: in-progress`, aż cykl zostanie zaparkowany (`paused`) albo zamknięty
(`completed`).

Technicznie wygląda to możliwie prosto, bo Codex hook payload już ma
`session_id`. Plan powinien sprawdzić wariant:

1. Gdy sesja przełącza manifest cyklu na `status: in-progress`, runtime zapisuje
   prosty claim, np. `active_session_id`.
2. Pre-tool hook blokuje mutacje tego cyklu z innego `session_id`.
3. Recovery message mówi: ten cykl jest aktywnie obsługiwany przez inną sesję;
   utwórz osobny intake, poczekaj albo poproś usera o jawne przejęcie.

Jeśli implementacja wymagałaby heartbeat, TTL, stale-lock cleanup albo osobnego
procesu zarządzania lockami, to ten element wypada z zakresu Klastra B.

## Confidence

High.

Diagnoza jest potwierdzona przez zgodność wszystkich source intake'ów klastra B
oraz przez istniejące luki w generated contract, continue workflow, hook
recovery wording, autonomy wording i harness scenariuszach. Nie wymaga jeszcze
założenia konkretnego mechanizmu lease.
