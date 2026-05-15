---
cycle_id: "20260515-decisions-log-parser-format-fix"
title: "Fix: parsers decyzji nadal zakladaja naglowki ###"
workflow: fix
phase: intake
status: intake
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
suggested_workflow: fix
tags:
  - codex-hooks
  - decisions
  - status
  - parser-drift
related:
  - "20260514-doc-lifecycle-bookkeeping-architecture"
  - "20260515-hook-policy-discovery-spike"
  - "runtime/platforms/codex/hooks/lib/decisions_rotate.sh"
  - "bin/sage"
  - "runtime/platforms/codex/hooks/session-init.sh"
  - "runtime/platforms/codex/hooks/tests/post-tool-check.bats"
  - "runtime/platforms/codex/setup/tests/status.bats"
scope:
  - ".sage/work/20260515-decisions-log-parser-format-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/lib/decisions_rotate.sh"
  - "bin/sage"
  - "runtime/platforms/codex/hooks/session-init.sh"
  - "runtime/platforms/codex/hooks/tests/post-tool-check.bats"
  - "runtime/platforms/codex/setup/tests/status.bats"
---

# Fix: parsers decyzji nadal zakladaja naglowki ###

## State

**Current phase:** intake. Implementacja nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix`, ustalić jeden kanoniczny parser wpisów
`decisions.md` i dopiero potem zmienić runtime oraz testy.

## Finding

Potwierdzone w kodzie: część Codex runtime nadal traktuje wpis decyzji jako
wyłącznie linię pasującą do `^### `.

To jest problem, bo obecny `decisions.md` może zawierać także krótkie wpisy
prependowane jako `- [YYYY-MM-DD] ...`. Taki najnowszy wpis istnieje już na
górze `.sage/decisions.md`, a obecne parsery go ignorują. Efekt praktyczny:
`sage status --json`, session banner i rotacja decyzji mogą pokazywać albo
liczyć niepełny stan decision logu.

Technicznie to drift parsera formatu decision logu: źródła runtime i fixture'y
testowe zakładają markdown headingi `###`, podczas gdy realny log ma format
mieszany albo co najmniej wymaga parsera odpornego na krótkie wpisy listowe.

## Confirmed source hits

- `runtime/platforms/codex/hooks/lib/decisions_rotate.sh` liczy i dzieli wpisy
  po `grep '^### '`.
- `bin/sage` buduje `recent_decisions` / `decisions` dla `sage status --json`
  przez `awk '/^### /'` i parsuje tytuł przez `sed 's/^### ...//'`.
- `runtime/platforms/codex/hooks/session-init.sh` pokazuje `Recent decisions`
  przez `grep -E '^### '`.

## Tests to update

- `runtime/platforms/codex/hooks/tests/post-tool-check.bats` helper
  `write_decisions`, `decision_entry_count` i assertiony rotacji używają
  `###`.
- `runtime/platforms/codex/setup/tests/status.bats` fixture'y recent decisions
  używają tylko `###`.
- Jeżeli session banner zostanie objęty fixem, dodać/zmienić też testy w
  `runtime/platforms/codex/hooks/tests/session-init.bats`.

## Desired behavior

Fix powinien w jednym miejscu zdefiniować, co jest wpisem decyzji dla
`decisions.md`, i użyć tego samego kontraktu w:

- rotacji 50 najnowszych decyzji,
- `sage status --json` oraz plain `sage status`,
- session bannerze,
- testach runtime/setup.

Minimum: parser nie może ignorować najnowszych krótkich wpisów w formacie
`- [YYYY-MM-DD] ...`. Jeśli docelowo `### YYYY-MM-DD — Title` zostaje jedynym
kanonicznym formatem, fix musi też zawierać migrację albo jawny test, który
wyłapie niekanoniczny wpis zanim runtime go pominie.

## Boundary

Nie zmieniać w tym intake polityki tego, które wydarzenia są decision-worthy.
Zakres dotyczy tylko spójnego rozpoznawania, wyświetlania i rotowania już
istniejących wpisów decision logu.
