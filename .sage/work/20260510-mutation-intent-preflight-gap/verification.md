---
cycle_id: "20260510-mutation-intent-preflight-gap"
type: verification
created: 2026-05-13
updated: 2026-05-13
---

# Verification

## Deterministic baseline before scope expansion

```text
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..72
ok 1 pre-tool-validate.sh: no active cycle → exit 2, stderr says no active cycle
...
ok 72 pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue
```

```text
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
1..49
ok 1 stage3: creates AGENTS.md at target
...
ok 49 stage3: generated AGENTS.md supports cross-cycle capture-only routing
```

```text
bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
1..16
ok 1 aggregate-signals: mutation-preflight scenario fails without preflight transcript evidence
...
ok 16 aggregate-signals: bug-report-no-fix fails if transcript mentions parent repo .sage writes
```

```text
jq -e . runtime/platforms/codex/harness/v11-scenarios.json >/dev/null
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/setup/lib/agents-md.sh
git diff --check
```

All three commands exited 0.

## Real-harness evidence before final scope expansion

Pierwszy real harness run wykonał wszystkie 14 scenariuszy i proces zakończył
się exit 0. Początkowo `v11_release_blocker_harness.complete=false` przez zbyt
szerokie forbidden transcript patterns w scenariuszach 13/14. Po zawężeniu
rubryk ręczna ponowna agregacja na tych samych realnych transcriptach zwróciła:

```text
v11_release_blocker_harness:
total=12
present=12
missing=[]
complete=true
```

Drugi i trzeci clean harness run zostały przerwane celowo, bo odsłoniły realne
problemy w ścieżce scenariusza 2:

- `scope.writable` inline YAML array nie było czytane przez hook scope matcher;
- `active_session_id: "current"` było traktowane jak prawdziwy obcy lock.

Oba problemy zostały naprawione w tej implementacji. Alex zatwierdził, żeby po
scope expansion nie uruchamiać ponownie pełnego real harnessa, tylko punktowe
testy odnoszące się do dotkniętego elementu.

## Targeted verification after scope expansion

```text
bats -f 'active_session_id' runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..4
ok 1 pre-tool-validate.sh: Bash shell edit to manifest active_session_id is blocked
ok 2 pre-tool-validate.sh: active_session_id mismatch blocks with handoff recovery path
ok 3 pre-tool-validate.sh: matching active_session_id allows in-progress cycle mutation
ok 4 pre-tool-validate.sh: placeholder active_session_id current does not lock cycle
```

```text
bats -f 'inline scope.writable' runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..1
ok 1 pre-tool-validate.sh: active cycle, inline scope.writable exact path → exit 0
```

```text
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/hooks/lib/active_init.sh
git diff --check -- runtime/platforms/codex/hooks/lib/active_init.sh runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/hooks/tests/pre-tool-validate.bats .sage/work/20260510-mutation-intent-preflight-gap/manifest.md .sage/work/20260510-mutation-intent-preflight-gap/plan.md .sage/decisions.md
```

Both commands exited 0.

## Targeted real-agent harness after user request

Alex poprosił o punktowe odpalenie harnessa dla tych poprawek, bez pełnego
runu 14 scenariuszy.

Pierwszy single-scenario run użył promptu `02-build-pl-typos` na świeżym
targetcie. `codex exec` zakończył się `exit 0`, ale agent zatrzymał się na
spec checkpoint przed edycją `AGENTS.md`, więc ten run był tylko częściowo
informacyjny.

Drugi seeded run odtworzył dokładny warunek poprawki: aktywny manifest miał
`scope.writable: ["AGENTS.md", ".sage/work/.../**", ".sage/decisions.md"]`
oraz `active_session_id: current`. Wynik:

```text
codex exit: 0
transcript events: 19
stderr relevant lines: none
target git status:
 M AGENTS.md
```

Końcówka `AGENTS.md` w targetcie zawierała dopisaną sekcję:

```text
## Kombucha

Kombucha to fermentowany napój na bazie herbaty, który powstaje dzięki symbiotycznej kulturze bakterii i drożdży.
Najlepiej przechowywać ją w chłodzie i otwierać ostrożnie, bo naturalne nagazowanie może być wysokie.
```

Wniosek: real `codex exec` przeszedł przez `PreToolUse` dla edycji `AGENTS.md`
z jednoczesnym `scope.writable` i placeholderem `active_session_id: current`,
bez dawnych blokad `outside cycle scope` ani `active cycle owned by another
session`.
