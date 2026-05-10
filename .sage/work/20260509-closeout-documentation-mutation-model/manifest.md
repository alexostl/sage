---
cycle_id: "20260509-closeout-documentation-mutation-model"
title: "Fix: closeout documentation mutation model"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
priority: P1
source_cycle: "20260509-runtime-process-closeout"
scope:
  - ".sage/work/20260509-closeout-documentation-mutation-model/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/**"
  - "core/constitution/sage-process.constitution.md"
  - "core/workflows/**"
---

# Fix: closeout documentation mutation model

## State

**Current phase:** intake — finding zapisany po review końcówki runtime/process
closeout. Implementacja nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix`, zdiagnozować hook classification i
zaprojektować wąski, audytowany tryb dla porządkowych zmian documentation/capture
bez wymuszania sztucznego cyklu.

## Finding

Podczas closeout po QA hooki zablokowały porządkową edycję artefaktów, bo:

- nie było aktywnego cyklu;
- patch dotykał więcej niż 3 pliki;
- reguła Moderate+ potraktowała zmiany w `.sage/**` jak implementation fix.

To wymusiło utworzenie technicznego `20260509-runtime-process-closeout` tylko po
to, żeby poprawić QA werdykt, utworzyć intake manifests i dopisać decyzję przed
commitem.

## Desired behavior

Hooki powinny rozróżniać typ mutacji:

- `implementation/runtime/test` — limit 3 plików i plan/manifest gate zostają;
- `documentation/capture/closeout` w `.sage/work/**`, `.sage/docs/**`,
  `.sage/decisions.md` — limit 3 plików nie powinien działać, jeśli patch nie
  dotyka kodu ani nie zmienia behavior;
- mixed patch `.sage/**` + implementation paths — normalne restrykcje wracają;
- cross-cycle `.sage/work/<kilka-cykli>` — dozwolone tylko dla folded/intake/QA
  closeout z audit evidence;
- same-thread epilogue po `completed` — dozwolony dla dokumentacji i decyzji,
  niedozwolony dla kodu.

## Candidate scope

- Dodać klasyfikację patcha: `implementation`, `test`, `runtime`,
  `documentation/capture`, `state-closeout`.
- Wyłączyć Moderate+ 3-file rule dla capture-only `.sage/**`.
- Dodać audit log dla documentation/capture closeout zamiast sztucznego hard
  stopu.
- Zaktualizować generated guidance, żeby agent wiedział kiedy wolno zrobić
  porządkowy closeout, a kiedy musi wejść w nowy `/fix`.
- Dodać regresje dokładnie dla sytuacji z runtime/process closeout.
- Jawnie rozważyć, czy zamknięcie cyklu wymaga wcześniejszego formalnego
  wznowienia, czy powinno istnieć wąskie `closeout-only` przejście stanu dla
  zaakceptowanych findings bez otwierania implementacji.

## Non-goal

Nie zapisujemy P2 z review jako osobnego findingu w tym cyklu. Alex wskazał, że
P2 go tutaj nie interesuje.
