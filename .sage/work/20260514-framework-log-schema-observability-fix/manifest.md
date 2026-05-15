---
cycle_id: "20260514-framework-log-schema-observability-fix"
title: "Fix: schemat i czytelnosc logow frameworka Sage"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P2
source: "sage:analyze log review"
suggested_workflow: fix
related:
  - ".sage/.session-mutations.log"
  - ".sage/.session-baseline.log"
  - ".sage/.skipped-checks.log"
  - ".sage/.auto-fixes.log"
  - ".sage/.doctor-cursor"
  - "bin/sage"
  - "runtime/platforms/codex/hooks/**"
scope:
  - ".sage/work/20260514-framework-log-schema-observability-fix/*"
  - ".sage/decisions.md"
---

# Fix: schemat i czytelnosc logow frameworka Sage

## State

**Current phase:** intake. Implementacja nie zostala rozpoczeta.

**Next step:** Uruchomic `/sage:fix`, ustalic minimalny wspolny kontrakt logow
frameworka i rozdzielic rzeczy wymagajace migracji od rzeczy, ktore moga byc
dodane forward-only.

## Finding

Logi sa uzyteczne, ale maja za malo struktury do dobrej analizy zachowania
frameworka:

- `.sage/.session-baseline.log` ma wpisy z `session_id` typu `x` albo
  `unknown`, bez `cycle_id`, co oslabia korelacje baseline -> mutacja;
- `.sage/.session-mutations.log` ma pliki i cycle_id, ale brak obowiazkowego
  `kind`, wiec nie odroznia implementation, capture, closeout, bootstrap,
  recovery ani binary/file_change paths;
- `.sage/.skipped-checks.log` jest raw textem i nie ma pol `cause`,
  `selected_cycle`, `candidate_cycles`, `session_id`, `degraded`;
- `.sage/.auto-fixes.log` ma dobry opis safety, ale stare wpisy nie maja
  `session_id`;
- `.doctor-cursor` jest gole epoch timestamp, bez schematu, `last_checked_at`,
  source logu ani wersji.

## Desired Behavior

- Kazdy framework log ma jawny, stabilny minimalny schema.
- Nowe wpisy maja realne `session_id` tam, gdzie runtime je zna.
- Mutation log ma `kind`/`mutation_kind` albo inna jednoznaczna semantyke.
- Skipped/degraded checks sa JSONL, nie surowym tekstem.
- `.doctor-cursor` pozostaje prosty, ale jest czytelny operacyjnie, np.
  `{"kind":"doctor_cursor","last_checked_at":...,"source":".sage/.mcp-incidents.log"}`.
- Duplikaty pathow w mutation entries sa deduplikowane przed zapisem albo jawnie
  traktowane jako nieszkodliwa normalizacja.

## Candidate Scope

- `bin/sage` (`doctor` cursor write/read).
- `runtime/platforms/codex/hooks/lib/json_log.sh` i hooki piszace logi.
- Testy log schema dla session mutations, baseline, skipped checks, auto-fixes
  i doctor cursor.

## Boundary

Nie wymagac migracji historycznych logow, chyba ze root cause pokaze, ze
`sage doctor` albo harness nie poradza sobie z mieszanym formatem. Preferowany
model to forward-compatible parser: czyta stare wpisy best-effort, zapisuje nowe
w stabilnym schemacie.
