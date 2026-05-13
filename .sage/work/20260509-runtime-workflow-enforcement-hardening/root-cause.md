---
title: "Root cause: runtime workflow enforcement hardening"
workflow: fix
cycle_id: "20260509-runtime-workflow-enforcement-hardening"
phase: root-cause-gate
status: completed
created: 2026-05-09
updated: 2026-05-09
---

# Root cause: runtime workflow enforcement hardening

## Root Cause

Sage ma niespójny enforcement contract między czterema warstwami:

1. **Cycle resolver:** aktywna powierzchnia `.codex/hooks/**` nadal wybiera
   globalny newest `in-progress` cycle, zamiast rozstrzygać bieżący cykl z path
   intentu albo jawnego wyboru.
2. **Mutation classification:** `.sage/**` capture/closeout mutations są nadal
   przepuszczane albo blokowane przez reguły pisane dla aktywnej implementacji,
   bez pełnego modelu `documentation/capture/state-closeout` kontra
   `implementation/runtime/test`.
3. **Recovery guidance:** hook/status UX sugeruje command-like `sage continue`,
   ale CLI nie ma takiego subcommandu; istnieje workflow/skill `sage:continue`.
4. **Real-agent enforcement + harness:** hooki są podpięte pod
   `apply_patch`, a real-agent mutation path może zapisać plik bez
   PreToolUse block; Stop hook potrafi wykrywać `bypass_mutation`, ale harness
   nie wymusza tej rubryki dla scenariusza 03.

## Evidence

### 1. Aktywna powierzchnia hooków wybiera newest active

`.codex/hooks/lib/active_init.sh`:

- `active_init_path()` skanuje manifesty;
- przy wielu `status: in-progress` wybiera najnowszy `mtime`;
- zapisuje tylko warning do `.sage/.skipped-checks.log`.

`.codex/hooks/pre-tool-validate.sh` używa tego wyniku jako jedynego aktywnego
cyklu dla scope check.

### 2. Source runtime ma częściową poprawkę, ale deployed hook jest starszy

`runtime/platforms/codex/hooks/pre-tool-validate.sh` używa
`resolve_cycle_for_patch`, ma `ambiguous cycle selection` i
`parked-cycle capture`.

Jednocześnie `.codex/hooks/pre-tool-validate.sh`, który zadziałał podczas tego
wątku, nadal używa starego `active_init_path` flow. To wyjaśnia, dlaczego
formalny analyze cycle został najpierw zablokowany mimo istniejącej poprawki w
source runtime.

### 3. Recovery guidance wskazuje nieistniejący CLI subcommand

`.codex/hooks/pre-tool-validate.sh` i `bin/sage status` emitują `sage continue`
jako next legal move dla parked/intake cycles.

`bin/sage --help` pokazuje `status`, `init`, `update`, `doctor`, `learn` itd.,
ale nie pokazuje `continue`. `sage:continue` istnieje jako workflow/skill, nie
jako CLI subcommand.

### 4. Harness nie łapie real-agent file_change bypass jako release blocker

`.sage/work/20260509-runtime-process-dummy-qa/qa-report.md` pokazuje, że
scenariusz 03 utworzył `src/notes/random.md` przez real-agent `file_change` bez
manifestu, decyzji ani recovery.

`runtime/platforms/codex/harness/v11-scenarios.json` ma dla
`03-blocked-mutation-next-legal-move` pustą `state_rubric`, więc aggregate nie
miał czego failować, mimo że claim scenariusza mówi o blocked mutation i next
legal move.

## Chain Of Causation

1. Agent widzi wiele parked/intake albo aktywnych inicjatyw.
2. PreToolUse potrafi pracować tylko w ograniczonym modelu: globalny active albo
   częściowy path-intent resolver zależnie od tego, czy działa source czy
   deployed hook.
3. Gdy mutacja nie pasuje do globalnego active cycle, agent dostaje recovery
   tekst z niejednoznacznym albo niewykonalnym `sage continue`.
4. Agent próbuje obejść brak legalnej ścieżki: tymczasowo zmienia scope,
   pauzuje obcy cykl albo pisze do złego repo/cyklu.
5. Real-agent paths, które nie przechodzą przez `apply_patch` matcher, mogą
   ominąć blokadę; Stop/harness wykrywa to tylko częściowo albo wcale.

## Confidence

High.

Dowody pochodzą z aktualnych hooków w `.codex`, source runtime w
`runtime/platforms/codex`, `bin/sage status`, realnego QA reportu i harness
scenario manifestu.

## Scope Classification Preview

To jest **Systemic fix**:

- dotyka 5+ plików;
- zmienia model wyboru cyklu i klasyfikacji mutacji;
- wymaga testów hooków, setup/deploy, status/guidance i harness assertions;
- może wymagać decyzji, czy `sage continue` zostaje CLI aliasem, czy wyłącznie
  workflow/skill syntax.

Fix może nadal iść przez `/sage:fix`, ale tylko z formalnym planem po
zatwierdzeniu root cause. Jeśli w scope gate okaże się, że trzeba projektować
nową state machine zamiast uszczelnić istniejący model, wtedy poprawna
eskalacja to `/sage:architect`.

## Root Cause Gate Recommendation

Zatwierdzić diagnozę i przejść do scope gate dla Systemic fix. W scope gate
plan powinien jawnie rozstrzygnąć:

1. Jak wygląda canonical cycle selection contract.
2. Jakie mutacje `.sage/**` są capture/closeout-only.
3. Czy `sage continue` ma być CLI aliasem, czy komunikaty mają wskazywać
   `sage:continue`.
4. Jak real-agent `file_change` i transcript assertions stają się release
   blockers.


## Cycle Resolver Requirement

Cycle Resolver musi wspierać **cross-cycle capture**, nie tylko jeden aktywny
cykl dla całej rozmowy.

Docelowy model:

1. Agent pracuje w wątku/cyklu A.
2. W trakcie pracy zauważa finding poza scope cyklu A.
3. Jeśli finding należy do istniejącego cyklu B, agent może zapisać capture do
   artefaktów cyklu B albo do `.sage/decisions.md`, bez pauzowania cyklu A i
   bez tymczasowego dopisywania scope B do cyklu A.
4. Jeśli finding nie ma jeszcze cyklu, agent może utworzyć nowy minimalny
   intake manifest C.
5. Te ścieżki są legalne wyłącznie dla capture-only mutations. Implementacja,
   runtime changes, test changes albo planowanie pracy dla B/C wymagają
   formalnego resume/start właściwego cyklu i odpowiednich gates.

To wymaganie jest ważniejsze niż prosty invariant "patch należy do aktualnie
aktywnego cyklu". Aktualny cykl rozmowy i owner capture mogą być różne, jeśli
mutacja jest dokumentacyjno-capture-only.


## Checkpoint State Requirement

Checkpoint w tej samej rozmowie nie powinien pauzować cyklu. Oryginalny model
Sage/Claude traktował checkpoint jako aktywny stan oczekiwania na decyzję:

```yaml
status: in-progress
phase: root-cause-gate
```

`paused` powinno oznaczać faktyczny session handoff albo odłożenie cyklu, a nie
zwykłą bramkę `[A]/[S]/[R]` w aktywnej rozmowie. Hooki mogą blokować
implementation mutations na gated phase, ale muszą pozwalać na same-cycle
artifact updates i capture decyzji.
