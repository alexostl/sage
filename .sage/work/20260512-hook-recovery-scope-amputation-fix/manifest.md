---
cycle_id: "20260512-hook-recovery-scope-amputation-fix"
title: "Fix: agent nie moze interpretowac hook recovery jako obciecia zakresu"
workflow: fix
phase: completed
status: completed
created: 2026-05-12
updated: 2026-05-13
owner: alexostl
priority: high
folded_into: "20260510-mutation-intent-preflight-gap"
tags:
  - needs-triage
  - codex-hooks
  - recovery-guidance
  - workflow-threshold
  - agent-behavior
source: "codex thread"
source_thread: "codex://threads/019e1ba5-292a-7483-8572-d7f63b9372db"
evidence_threads:
  - "codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19"
related:
  - ".sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md"
  - ".sage/work/20260510-mutation-intent-preflight-gap/manifest.md"
scope:
  - ".sage/work/20260512-hook-recovery-scope-amputation-fix/*"
  - ".sage/decisions.md"
---

# Fix: agent nie moze interpretowac hook recovery jako obciecia zakresu

## State

**Current phase:** completed - finding skonsumowany przez anchor cycle
`20260510-mutation-intent-preflight-gap`.

**Next step:** Brak osobnej implementacji w tym cyklu; patrz anchor cycle i
jego `verification.md`.

## Problem

W watku `codex://threads/019e1ba5-292a-7483-8572-d7f63b9372db` agent robil fix
pluginu `pdf-toolkit` w `alex-os-dev`. Po poprawkach w instrukcji i helperze
chcial jeszcze bumpnac `plugin.json` do `0.1.1`, ale `PreToolUse` zablokowal
edycje trzeciego pliku jako przekroczenie Surgical threshold.

Hook wskazywal legalna sciezke: skoro fix dotyka 3+ plikow, trzeba przejsc na
Moderate+ workflow, uzupelnic artefakty i dopiero potem kontynuowac. Agent
zinterpretowal to inaczej: potraktowal blokade jako sygnal, ze trzeci plik jest
poza zakresem, wiec zrezygnowal z bumpa `plugin.json`.

## Findings to preserve

- Hook block byl merytorycznie poprawny jako enforcement progu Surgical, ale
  agent nie potraktowal komunikatu jako recovery path.
- Zablokowany plik (`plugin.json`) byl prawdopodobnie potrzebny operacyjnie,
  bo bez bumpa wersji cache pluginu mogl dalej uzywac starej wersji `0.1.0`.
- Problem nie polega na tym, ze hook powinien zawsze przepuszczac trzeci plik.
  Problem polega na tym, ze agent wybral "amputacje zakresu", zamiast formalnie
  podniesc fix do Moderate.
- Ten wariant jest blisko `20260509-hook-block-recovery-behavior-fix`, ale
  ma osobny failure mode: agent kontynuuje po blokadzie, lecz w sposob
  zubazajacy cel uzytkownika.

## Additional evidence: Project Init whitelist thread

W watku `codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19` agent najpierw
planowal dotknac trzech plikow: template `.gitignore`, instrukcji
`alex-os:projectinit` i `.sage/docs/profiles.md`. Po bloku Moderate+ usunal
`.sage/docs/profiles.md` z zakresu, zeby zmiana zmiescila sie w lekkim progu.

To moze byc merytorycznie akceptowalne, jesli dokumentacja profili byla tylko
nice-to-have. Failure mode do zachowania jest subtelniejszy: po bloku agent nie
powiedzial wyraznie "ten trzeci plik jest opcjonalny, wiec go odkladam", ani
nie zapytal, czy podniesc zakres do Moderate+. Przyszly fix powinien wymagac
takiego rozroznienia: redukcja zakresu jest legalna tylko wtedy, gdy agent
jawnie stwierdzi, ze zablokowany plik nie jest potrzebny do celu uzytkownika.

## Desired diagnosis scope

Future fix powinien odpowiedziec:

- Czy obecne hook messages wystarczajaco jasno mowia, ze `Next legal move`
  jest instrukcja kontynuacji, a nie sugestia usuniecia zablokowanego pliku
  z zakresu?
- Czy AGENTS/runtime guidance powinno miec jawna regule: jesli zablokowany
  plik jest potrzebny do kompletnego celu, nie wolno redukowac zakresu tylko
  po to, zeby zostac w Surgical?
- Czy harness/RealHarness moze sprawdzac agent response po blokadzie 3. pliku:
  oczekiwane zachowanie to escalate-to-Moderate, a nie final answer z
  niepelna poprawka.
- Czy ten fix powinien zostac scalony z istniejacym
  `hook-block-recovery-behavior-fix`, czy zostac osobnym testem dla
  "scope amputation".

## Acceptance criteria

- Guidance po hook block jasno odroznia recovery/escalation od rezygnacji z
  potrzebnego zakresu.
- Agent contract mowi, ze nie wolno obchodzic workflow threshold przez
  wyrzucenie merytorycznie potrzebnego pliku z fixa.
- Test albo real-agent scenario pokrywa przypadek: 2 pliki juz zmienione,
  trzeci wymagany plik blokuje Surgical threshold, agent ma przejsc do
  Moderate+ zamiast konczyc niepelnie.
- Implementacja zachowuje prawo hooka do twardego blokowania faktycznie
  nieuzasadnionych scope expansions.
