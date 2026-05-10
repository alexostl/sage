---
cycle_id: "20260509-multi-active-cycle-model-fix"
title: "Fix: model wielu aktywnych cykli Sage"
workflow: fix
phase: folded
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: false
folded_into: "20260509-runtime-workflow-enforcement-hardening"
source_threads:
  - "codex://threads/019e0cf4-9ed9-7972-b4d1-af11f5ca086d"
related:
  - ".sage/work/20260509-hook-cycle-selection-capture/manifest.md"
  - ".sage/work/20260509-runtime-process-reliability-patch/manifest.md"
  - ".sage/work/20260509-runtime-process-dummy-qa/qa-report.md"
suggested_workflow: fix
---

# Fix: model wielu aktywnych cykli Sage

## State

**Current phase:** folded - podstawowy model wielu aktywnych cykli został
pokryty przez `20260509-runtime-workflow-enforcement-hardening`.

**Resolution:** Cycle Resolver wybiera ownera mutacji z path intentu i typu
mutacji zamiast globalnego newest active. Ambiguous multi-cycle implementation
patches są blokowane, a capture-only do parked/intake pozostaje legalne.

**Verification:** `.sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md`
potwierdza PASS dla ambiguous multi-cycle artifact patch oraz powiązanych
cross-cycle capture flows.

**Residual:** Active session lease/lock dla cyklu obsługiwanego przez inny
aktywny wątek pozostaje osobnym follow-upem:
`.sage/work/20260509-active-cycle-lease-lock/`.

## Finding

Podczas review wątku `codex://threads/019e0cf4-9ed9-7972-b4d1-af11f5ca086d`
wyszło, że agent musiał zapauzować aktywny cykl `20260509-pdf-ocr-skill`, żeby
utworzyć i wykonać osobny cykl `20260509-sagewiki-mcp-vault`.

To jest niepoprawny model operacyjny. Projekt może mieć kilka równoległych
aktywnych inicjatyw. Hook/runtime nie powinien zakładać, że istnieje dokładnie
jeden globalny aktywny cykl w repo.

## Why this matters

Ręczne pauzowanie niezwiązanego cyklu:

- zmienia stan workflow bez bezpośredniej zgody użytkownika;
- miesza "co jest aktywne w projekcie" z "który cykl obsługuje bieżący patch";
- może ukryć realnie aktywną pracę przed `/sage:status` i `/sage:continue`;
- zachęca agentów do manipulowania frontmatterem, żeby przejść przez hook,
  zamiast rozwiązać wybór cyklu na poziomie intencji patcha.

## Desired behavior

Sage powinien rozróżniać:

- **wiele aktywnych cykli w projekcie** - legalne i widoczne w statusie;
- **jeden bieżący cykl dla konkretnej mutacji** - wybrany z path intent,
  jawnego polecenia użytkownika albo mechanizmu wyboru;
- **ambiguous mutation** - blokowana z komunikatem proszącym o wybór cyklu,
  bez automatycznego pauzowania innych cykli.

## Acceptance direction

Przyszły fix powinien sprawdzić i poprawić co najmniej:

- resolver aktywnego kontekstu hooków, żeby nie wybierał globalnie newest
  `in-progress` jako jedynego źródła prawdy;
- bootstrap nowego cyklu przy istniejących innych `in-progress` cyklach;
- `sage status` / `sage continue` UX dla wielu aktywnych cykli;
- test regresyjny z dwoma aktywnymi cyklami, gdzie patch do cyklu B nie wymaga
  pauzowania cyklu A;
- blokadę lub ostrzeżenie, gdy agent próbuje zmienić status innego aktywnego
  cyklu wyłącznie po to, żeby odblokować własny patch.

## Boundary

Ten intake nie zatwierdza jeszcze implementacji. Nie należy dopisywać tej
poprawki do zamkniętego `20260509-runtime-process-reliability-patch` bez
nowego planu albo jawnego scope update.
