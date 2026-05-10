---
title: "Report: Project Dummy artifact documentation tests"
workflow: qa
phase: report
status: completed
created: 2026-05-09
cycle_id: "20260508-alex-native-operating-model"
run_root: ".sage/work/20260508-alex-native-operating-model/dummy-artifact-matrix-20260509002336"
target: "/Users/alexostl/Developer/dummy-project"
model: "gpt-5.4"
reasoning_effort: "medium"
---

# Report: Project Dummy artifact documentation tests

## Cel

Domknąć brakujący test z briefu: sprawdzić nie tylko rozmowę agenta, ale realnie
zapisywane dokumenty `.sage` dla typowych workflowów. Każdy scenariusz został
uruchomiony na osobnej izolowanej kopii Project Dummy przez `codex exec` z
`gpt-5.4` i `model_reasoning_effort=medium`.

## Scenariusze

| ID | Workflow | Powstałe artefakty | Wynik językowy |
| --- | --- | --- | --- |
| S07 | `build` | `manifest.md`, `spec.md`, `plan.md` | Partial pass |
| S08 | `architect` | `brief.md`, `spec.md` | Pass / minor leakage |
| S09 | `fix` | `manifest.md`, `plan.md` | Partial pass |

## S07 — Build docs

Powstały:

- `.sage/work/20260509-task-search-filter/manifest.md`
- `.sage/work/20260509-task-search-filter/spec.md`
- `.sage/work/20260509-task-search-filter/plan.md`

Ocena:

- Główna treść dokumentów jest po polsku.
- `manifest.md` ma polskie body, ale zachowuje angielskie template headings:
  `State`, `Context summary`, `Decisions so far`, `Open questions`,
  `Provenance`, `Handoff guidance`.
- `spec.md` ma polskie sekcje merytoryczne, ale frontmatter `title` i `handoff`
  są po angielsku: `Spec for...`, `Key decisions`, `Open questions`, `Risks`,
  `Next agent should`.
- `plan.md` ma polski opis i zadania, ale część nagłówków/template labels
  pozostała po angielsku: `Plan for...`, `Tasks`, `Done criteria`,
  `Files involved`, `Scope`.

Wniosek: behavior jest blisko celu, ale nie spełnia literalnie "wszystkie pliki
dokumentacyjne po polsku poza terminami frameworka". Leakage pochodzi głównie z
szablonów i przyzwyczajonych nazw sekcji.

## S08 — Architect docs

Powstały:

- `.sage/work/20260509-projects-and-task-lists/brief.md`
- `.sage/work/20260509-projects-and-task-lists/spec.md`

Ocena:

- `brief.md` jest zasadniczo po polsku. Angielskie elementy to głównie
  frameworkowe rundy `Round 1 — Vision`, `Round 2 — Constraints`, `Round 3 —
  Gaps` oraz techniczne terminy typu `localStorage`, `backend`, `completed`.
- `spec.md` jest bardzo dobry językowo w body: model danych, migracja, UI,
  trade-offy i acceptance criteria są opisane po polsku z naturalnymi
  anglicyzmami.
- Minor leakage: `handoff` używa angielskich etykiet `Key decisions`, `Open
  questions`, `Risks`, `Next agent should`.
- Architect nie zapisał ADR w `.sage/docs/decision-*.md`, mimo że workflow
  architect zwykle tego oczekuje przy pełnym design checkpoint. To jest osobny
  process/gate finding, niezależny od języka.

Wniosek: architect najlepiej realizuje polską dokumentację, ale `handoff` i ADR
coverage nadal wymagają poprawki.

## S09 — Fix docs

Powstały:

- `.sage/work/20260509-localstorage-persist-failure/manifest.md`
- `.sage/work/20260509-localstorage-persist-failure/plan.md`

Ocena:

- `manifest.md` ma polską diagnozę, root cause, evidence, chain, scope decision
  i handoff guidance. Angielskie nazwy sekcji i pola nadal pochodzą z template:
  `State`, `Context summary`, `Root cause`, `Scope decision`, `Open questions`,
  `Provenance`, `Handoff guidance`.
- `plan.md` ma dobry polski opis zadań i ryzyk, ale template labels nadal są
  angielskie: `Fix Plan`, `Tasks`, `Done criteria`, `Files involved`, `Tests`,
  `Risks`, `Rollback`, `Scope`.

Wniosek: fix zapisuje merytorykę po polsku, ale format planu jest wciąż zbyt
angielski, szczególnie w nagłówkach i labels.

## Ogólny wynik

Dokumentacja jest dużo bliżej celu niż pierwsze testy pokazywały, ale nie jest
jeszcze w pełni zgodna z briefem.

Pass:

- Nowe artefakty są zapisywane w `.sage/work`.
- Merytoryczne akapity są w większości po polsku.
- Techniczne anglicyzmy są używane naturalnie i sensownie.
- Agent nie implementował kodu aplikacji w tych trzech scenariuszach.
- Po zapisie artefaktów pokazał krótkie streszczenia i linki do kluczowych
  sekcji.

Fail / Partial:

- Template headings i labels są nadal często po angielsku.
- `handoff` frontmatter jest szczególnie angielski.
- `title` frontmatter czasem generuje angielskie frazy.
- `plan.md` i `manifest.md` zachowują dużo angielskich nazw sekcji, które nie
  są konieczne jako canonical Sage terms.
- Architect docs nie utworzyły ADR, więc pełny architect design checkpoint nie
  został zachowany.

## Follow-up wymagany

Następny patch powinien dodać checklistę lub test snapshotów dla generowanych
artefaktów:

- `brief.md`
- `spec.md`
- `plan.md`
- `manifest.md`
- `decision-*.md`
- `.sage/decisions.md`

Test powinien łapać zwłaszcza:

- angielskie `handoff` labels,
- angielskie tytuły typu `Spec for...` i `Fix Plan for...`,
- template headings typu `State`, `Context summary`, `Tasks`, `Tests`, `Risks`,
  gdy nie są świadomie traktowane jako canonical Sage terms.
