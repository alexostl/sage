---
cycle_id: "20260509-alex-readable-change-explanations-fix"
title: "Root cause: Alex-native communication contract is too implicit"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-14
updated: 2026-05-14
---

# Root cause: Alex-native communication contract is too implicit

## Summary

Sage ma juz ogolny Alex-native kontrakt, ale kontrakt nie daje agentowi
wystarczajaco mechanicznego wzorca dla trudnych wyjasnien. Agent wie, ze ma
byc junior-friendly, lecz moze nadal zaczac od nazwy wewnetrznego mechanizmu
albo od angielskiego template'u, bo instrukcje nie mowia wprost: najpierw
powiedz, co sie dzieje, potem czemu to boli, potem dopiero nazwij mechanizm i
powiedz, co zmienic.

Drugi kawalek tej samej przyczyny ujawnil sie najpierw w QA: workflow ma
poprawny ogolny `Artifact Language Contract`, ale Step 5 kaze uzyc angielskiego
`develop/templates/qa-report-template.md` bez doprecyzowania, ze template jest
szkieletem struktury, a nie jezykiem docelowym raportu. Po dodatkowym scanowaniu
widzimy, ze to nie jest tylko QA. `design-review.workflow.md` ma ten sam wzorzec:
zapisuje raport i wskazuje angielski `design-review-template.md` bez
project-language override.

## Evidence

- `core/constitution/sage-process.constitution.md` opisuje Alexa jako Polish
  Junior Dev Vibecoder i wymaga polskiej prozy w `.sage`, ale opisuje to jako
  ogolne "why this matters", nie jako konkretny porzadek wyjasniania bugow i
  findings.
- `runtime/platforms/codex/setup/lib/agents-md.sh` generuje kompaktowy
  kontrakt: `explain bugs/findings first as impact and cause, then name the
  technical mechanism`. To jest dobry kierunek, ale nadal nie zawiera pelnego
  wzorca "co sie dzieje -> czemu to problem -> jak to sie technicznie nazywa ->
  co trzeba zmienic".
- `core/workflows/qa.workflow.md` ma ogolny language contract w liniach
  15-19, ale w Step 5 linia 135 mowi tylko, zeby uzyc
  `develop/templates/qa-report-template.md`.
- `develop/templates/qa-report-template.md` jest po angielsku i nie ma
  ostrzezenia, ze Alex-native projekty maja zachowac strukture template'u, ale
  napisac naturalna proze po polsku.
- `core/workflows/design-review.workflow.md` ma analogiczny wzorzec:
  ogolny language contract, zapis `design-review.md` i instrukcje
  `Use template from develop/templates/design-review-template.md`.
- `develop/templates/design-review-template.md` jest po angielsku i rowniez nie
  ma Alex-native guidance. To oznacza, ze przyszly design review report moze
  powtorzyc ten sam blad co QA report.
- `build.workflow.md` tez uzywa template'u, ale jego glowne template'y
  (`manifest`, `spec`, `plan`) maja juz komentarz `Alex-native self-host —
  write prose po polsku`. To odroznia build od QA/design-review: tam istnieje
  lokalny hamulec, a w raportowych template'ach go brakuje.
- `.sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md` jest
  realnym przykladem: nowy `.sage` QA report ma angielskie sekcje opisowe,
  mimo ze lokalny kontrakt wymaga polskiej prozy.
- Obecne testy pilnuja tylko kompaktowego kontraktu w `AGENTS.md`
  (`impact and cause`, `technical mechanism`) oraz kilku ogolnych fraz w core.
  Nie pilnuja pelnego wzorca wyjasnienia ani QA zasady "template structure,
  project language".

## Cause

Root cause to rozjazd miedzy intencja a operacyjnym promptem. Intencja
Alex-native jest zapisana, ale agent dostaje ja jako ogolna zasade stylu.
Tam, gdzie workflow/template daje silniejszy sygnal proceduralny, np. "Use the
report template", agent moze skopiowac jezyk template'u albo uzyc skrotu
technicznego, zamiast przetlumaczyc sens dla Alexa.

Po rozszerzeniu diagnozy: root cause obejmuje raportowe workflowy korzystajace
z angielskich template'ow bez jawnego language override, obecnie co najmniej
`qa.workflow.md` i `design-review.workflow.md`. Nie wyglada na to, zeby ten sam
konkretny blad dotyczył wszystkich template-driven workflowow, bo czesc
template'ow ma juz Alex-native komentarze.

## Chain

1. Projekt wymaga polskiej, junior-friendly prozy.
2. Core i generated Codex guidance mowia to zbyt ogolnie.
3. QA i design-review dodatkowo wskazuja angielskie template'y bez language
   override.
4. Agent ma latwa sciezke: uzyc angielskiej struktury i technicznych etykiet.
5. Wynik jest formalnie poprawny dla frameworka, ale gorszy dla Alexa: trudniej
   zobaczyc skutek, przyczyne i nastepna decyzje.

## Confidence

High. Mamy zarowno zapisane intaki, rzeczywisty przyklad angielskiego QA
raportu, analogiczny pattern w design-review oraz brak testu na dokladny
kontrakt Batcha 7.

## Minimization pass

Najmniejszy sensowny fix nie powinien przepisywac wszystkich workflowow ani
tlumaczyc template'ow hurtowo. Wystarczy wzmocnic jeden wspolny Alex-native
kontrakt, doprecyzowac raportowe workflowy/template'y przy miejscu uzycia
(`qa` i `design-review`) oraz dodac regresje tekstowe dla generatora/core.
Jesli podczas planowania okaze sie, ze generator i core dubluja ten sam tekst,
trzeba preferowac jedno zrodlo prawdy plus test, a nie dokladanie dlugich
promptow w wielu miejscach.
