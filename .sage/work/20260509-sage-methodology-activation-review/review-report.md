---
cycle_id: "20260509-sage-methodology-activation-review"
artifact: review-report
workflow: review
status: completed
created: 2026-05-09
updated: 2026-05-09
reviewed_samples: 8
missing_samples: 2
---

# Review: empiryczna aktywacja metodologii Sage w Codex

## Werdykt

**Needs focused follow-up, not broad routing rewrite.**

**Closeout:** Findings zaakceptowane 2026-05-09. Review zamknięty; dalsza
praca przechodzi do osobnych intake fixów wskazanych w rekomendacji.

Niska aktywacja `sage-navigator` nie jest sama w sobie dobrym sygnałem awarii.
W badanej próbce agent często poprawnie pomijał formalny workflow przy
pytaniach read-only albo wchodził bezpośrednio w konkretny workflow, gdy
użytkownik podał jawny skill (`sage:review`, `sage:build`, `sage:architect`) lub
zadanie było jednoznaczne.

Realny problem jest węższy: przejście z rozmowy albo researchu w mutację oraz
wybór właściwego cyklu przy równoległych pracach. To nie wymaga wymuszania
Navigatora w każdym Standard+ zadaniu. Wymaga lepszego momentu zatrzymania:
"to już jest mutacja / inny cykl / gated workflow, więc wybieram lub tworzę
cycle przed edycją".

## Zakres evidence

Manifest wskazywał 10 sesji JSONL. Dwie najnowsze ścieżki nie istnieją już na
dysku, więc review opiera się na 8 dostępnych sesjach:

- `rollout-2026-05-09T15-36-58-019e0cf4-9ed9-7972-b4d1-af11f5ca086d.jsonl`
- `rollout-2026-05-09T15-17-56-019e0ce3-3001-7ce2-bf10-ddc304e3b8e8.jsonl`
- `rollout-2026-05-09T11-54-14-019e0c28-b19f-74f0-85ac-be37e18e4437.jsonl`
- `rollout-2026-05-08T23-26-29-019e097c-1ecd-73f2-9992-928d1a81c98b.jsonl`
- `rollout-2026-05-08T23-26-29-019e097c-1c03-7fb3-9446-7e1707395287.jsonl`
- `rollout-2026-05-08T23-26-28-019e097c-180d-7181-bb9e-fc655eda682f.jsonl`
- `rollout-2026-05-08T22-55-02-019e095f-5328-7e40-a288-0a524d6e0d0d.jsonl`
- `rollout-2026-05-08T14-13-06-019e0781-7a63-7761-bbce-01fbee72f470.jsonl`

Brakujące pliki:

- `rollout-2026-05-09T16-06-27-019e0d0f-9d20-7030-87e2-7acd86cd182c.jsonl`
- `rollout-2026-05-09T15-48-46-019e0cff-6a59-78a0-8f3c-859ac6181fb9.jsonl`

## Klasyfikacja próbek

| Sesja | Mandat | Oczekiwany Sage behavior | Faktyczny behavior | Ocena |
| --- | --- | --- | --- | --- |
| `15-36-58` | Podłącz MCP SageWiki | Osobny fix/build albo capture cycle przed mutacją configu | Agent najpierw próbował pracować przy aktywnym scope PDF, potem utworzył osobny cykl MCP | Problem: wybór cyklu i multi-active model |
| `15-17-56` | Read-only review specu PDF/OCR | `sage:review`, bez edycji | Agent użył review workflow i nie edytował plików | Poprawne |
| `11-54-14` | Najpierw read-only OCR, potem rozbudowa skilla | Pytanie bez workflow, potem build przed trwałą adopcją/edycją | Pierwsza część poprawna; przejście do zmiany narzędziowni nastąpiło za miękko, zanim użytkownik wymusił `sage:build` | Problem: read-only -> mutacja |
| `23-26-29 1ecd` | Explorer feasibility, nie edytować | Read-only analyze/research, bez artefaktu | Agent użył analitycznej ramy i nie edytował | Poprawne |
| `23-26-29 1c03` | Explorer feasibility sage-wiki, nie edytować | Read-only research, bez artefaktu | Agent użył research workflow i nie edytował | Poprawne |
| `23-26-28` | Explorer feasibility sage-memory, nie edytować | Read-only research, bez artefaktu | Agent użył navigator/research style i nie edytował | Poprawne |
| `22-55-02` | Od rozmowy o SageWiki do architect/research | Najpierw read-only; po explicit `sage:architect` wejść w architect/research | Agent rozdzielił stan obecny od projektowania i użył subagentów po prośbie użytkownika | Poprawne z jednym wcześniejszym skorygowanym drift |
| `14-13-06` | Fireflies/Obsidian rozmowa, potem "dopisz inicjatywę" | Najpierw rozmowa; przy "dopisz" utworzyć intake/capture | Agent doszedł do manifestu/todo; późniejsze wątki pokazały problem scope przy closeout | Częściowo poprawne, powiązane z closeout/documentation model |

## Strengths

1. **Direct workflow activation działa.** Gdy użytkownik podaje `sage:review`,
   `sage:build` albo `sage:architect`, agent zwykle nie potrzebuje
   `sage-navigator` jako pośrednika.

2. **Read-only nie jest przemetodyzowane.** W próbkach explorer/research agent
   zwykle respektuje "nie edytuj plików" i zwraca findings bez tworzenia
   artefaktów na siłę.

3. **Routing conversation-first poprawił UX.** Wątki OCR, Fireflies i SageWiki
   pokazują, że pytania koncepcyjne mogą pozostać rozmową, dopóki nie pojawia
   się mutacja albo explicit workflow.

## Issues Found

### P1: Transition from read-only to mutation is under-guarded

**Observation:** W sesji PDF/OCR agent poprawnie zaczął od odpowiedzi
koncepcyjnej, ale po "rozbudować skill" przeszedł w adopcję/zmiany
narzędziowni zanim formalny `sage:build` został jawnie podjęty przez
użytkownika.

**Impact:** To jest dokładnie moment, w którym metodologia może odpalić się za
późno: nie przy pierwszym pytaniu, tylko przy zmianie charakteru zadania.

**Suggested action:** Traktować jako follow-up do istniejących P1/P2 hook/runtime
intake, nie jako globalny fix Navigatora. Dodać do testów/harnessu scenariusz:
read-only advice -> user says "zróbmy/rozbuduj/dopisz" -> agent musi zatrzymać
się na workflow/cycle selection przed mutacją.

### P1: Cycle selection is the sharper failure than Navigator activation

**Observation:** W sesji MCP agent chciał zrobić zmianę konfiguracyjną podczas
istniejącego aktywnego scope dla PDF. Guardrail zatrzymał część ruchów, ale
agent zaczął rozważać pauzowanie innego cyklu i tworzenie osobnego cyklu jako
mechaniczny workaround.

**Impact:** Problem nie polega na tym, że agent nie czyta `sage-navigator`.
Problem polega na tym, że runtime ma nie dość dobry model wielu aktywnych lub
zaparkowanych cykli i intencji mutacji.

**Suggested action:** Kontynuować
`.sage/work/20260509-multi-active-cycle-model-fix/` przed ogólnym routing
rewrite. To jest bardziej źródłowe niż poprawianie opisów skillów.

### P2: Public skill surface still has cleanup work, but not as activation blocker

**Observation:** Intake już trafnie identyfikuje dwa osobne problemy:
redundantny `sage:sage` i drift `sage-navigator`. Review nie znalazło jednak
dowodu, że te dwa problemy są główną przyczyną błędnych mutacji.

**Impact:** Naprawienie surface poprawi czytelność UI i reachability instrukcji,
ale prawdopodobnie nie rozwiąże P1: przejścia rozmowa -> mutacja oraz wyboru
cyklu.

**Suggested action:** Zostawić oba jako P2 cleanup. Nie blokować nimi P1 runtime
work.

### P2: Evidence capture should tolerate missing JSONL paths

**Observation:** 2 z 10 ścieżek `source_threads` z manifestu były już
niedostępne.

**Impact:** Review/harness traci powtarzalność, jeśli zapisujemy tylko ścieżki
do ephemeral session logs.

**Suggested action:** Przy kolejnych empirycznych review zapisywać obok
manifestu małe `evidence-index.md` albo kopię skrótu: user mandate, expected
route, actual route, mutation verdict, key transcript line refs. Nie trzeba
kopiować całych JSONL.

## Ryzyka

- Zbyt agresywne wymuszanie `sage-navigator` pogorszy UX dla prostych pytań i
  explicit workflowów.
- Zbyt wąski fix w hookach może nadal nie złapać mutacji wykonywanych przez
  kanały inne niż `apply_patch`, co jest już objęte osobnym intake
  `file-change-enforcement-fix`.
- Jeśli `sage:continue` będzie wybierał "najnowszy" cykl zamiast pytać o
  intencję mutacji, multi-active fix może ponownie odtworzyć ten sam błąd pod
  inną nazwą.

## Rekomendacja

1. **Nie robić szerokiego "Navigator must always activate" fixa.**
   To jest zła metryka. Poprawne pominięcia Navigatora są częste.

2. **Najpierw zrobić P1 runtime/process follow-upy:**
   `multi-active-cycle-model-fix`, `file-change-enforcement-fix` i
   `fix-trigger-gate-fix`.

3. **Dodać mały regression harness dla transition routing:**
   prompt zaczyna się jako read-only, potem użytkownik prosi o mutację. Oczekiwany
   wynik: agent nie edytuje, dopóki nie wybierze workflow/cycle i nie ma
   legalnego scope.

4. **Potem wykonać P2 cleanup skill surface:**
   `duplicate-sage-entrypoint-fix` i `sage-navigator-skill-drift-fix`.

5. **Zamknąć ten review po akceptacji wniosków** i przepisać zaakceptowaną
   decyzję do `.sage/decisions.md`.

## Checkpoint

[A] Accept findings - traktujemy review jako zakończone i przechodzimy do
wyboru następnego fixa.

[R] Revise - doprecyzować review, np. dodać brakujące sesje albo ostrzejszą
metrykę.

[D] Discuss - omówić, czy priorytetem ma być P1 runtime, czy P2 surface cleanup.
