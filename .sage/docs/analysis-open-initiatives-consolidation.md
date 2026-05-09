---
title: "Analysis: consolidation pass otwartych inicjatyw Sage"
workflow: analyze
cycle_id: "20260509-open-initiatives-consolidation"
status: findings-checkpoint
created: 2026-05-09
updated: 2026-05-09
---

# Analysis: consolidation pass otwartych inicjatyw Sage

## Cel

Ocenić, czy otwarte intake cycles z 2026-05-09 powinny zostać wykonane jako
jeden większy patchset, oraz jak je pogrupować, żeby patch nie stał się workiem
niepowiązanych zmian.

## Źródła

- `.sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md`
- `.sage/work/20260509-blocking-hook-guidance-review/manifest.md`
- `.sage/work/20260509-closeout-documentation-mutation-model/manifest.md`
- `.sage/work/20260509-cross-cycle-scope-workaround-fix/manifest.md`
- `.sage/work/20260509-cycle-state-disclosure-fix/manifest.md`
- `.sage/work/20260509-duplicate-sage-entrypoint-fix/manifest.md`
- `.sage/work/20260509-file-change-enforcement-fix/manifest.md`
- `.sage/work/20260509-fix-trigger-gate-fix/manifest.md`
- `.sage/work/20260509-hook-routing-command-audit/manifest.md`
- `.sage/work/20260509-multi-active-cycle-model-fix/manifest.md`
- `.sage/work/20260509-sage-navigator-skill-drift-fix/manifest.md`
- `.sage/work/20260509-target-repo-ownership-harness-fix/manifest.md`
- `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md`
- `.sage/work/20260509-runtime-process-reliability-patch/review-report.md`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `.codex/hooks/pre-tool-validate.sh`
- `bin/sage`
- `runtime/platforms/codex/setup/tests/status.bats`

## Executive Summary

Rekomendacja: zrobić **jeden umbrella patchset**, ale nie jeden amorficzny diff.
Otwarte inicjatywy układają się w cztery logiczne klastry:

1. Model cyklu, scope i closeout.
2. Recovery guidance i routing komend.
3. Egzekwowanie zachowania agentów i harness assertions.
4. Publiczna powierzchnia skilli oraz komunikacja stanu cyklu.

Najważniejsza zależność: najpierw trzeba poprawić model wyboru bieżącego cyklu
dla mutacji. Bez tego poprawki komunikatów hooków i testów będą dalej łatały
objawy: `newest in-progress`, `sage continue`, tymczasowe rozszerzanie scope i
sztuczne pauzowanie niezwiązanych cykli.

## Findings

### Major 1 - Jeden umbrella patchset ma sens, ale tylko jako patchset etapowy

**Evidence:** Wszystkie P1 intake cycles dotykają tej samej granicy runtime:
agent chce wykonać mutację, a Sage musi ustalić, czy mutacja należy do
aktywnie wybranego cyklu, parked cycle, closeout documentation path, czy
osobnej pracy. Widać to w:

- `multi-active-cycle-model-fix` - wiele `in-progress` cykli powinno być
  legalne;
- `cross-cycle-scope-workaround-fix` - agent tymczasowo rozszerzył scope obcego
  cyklu;
- `closeout-documentation-mutation-model` - closeout `.sage/**` został
  potraktowany jak implementation fix;
- `agent-resume-intake-cycle-fix` - rozmowna intencja kontynuacji nie zmieniła
  formalnego stanu cyklu.

**Impact:** Robienie tych cykli osobno grozi sprzecznymi invariantami: jeden
fix doda `closeout-only`, drugi wymusi `in-progress`, trzeci wybierze globalnie
newest active, a czwarty spróbuje obejść to komunikatem.

**Recommendation:** Utworzyć umbrella `/sage:fix` dla modelu
`cycle-selection + mutation-classification + closeout/resume`, z etapami i
osobnymi commitami.

### Major 2 - Recovery guidance musi zostać zrobione po modelu, nie przed nim

**Evidence:** `hook-routing-command-audit` i `blocking-hook-guidance-review`
pokazują, że komunikaty sugerują `sage continue`, mimo że `bin/sage continue`
nie istnieje. W repo widać to w:

- `.codex/hooks/pre-tool-validate.sh` - komunikat "Next legal move: run
  `sage status`, then explicitly `sage continue`...";
- `bin/sage` - `status` wypisuje `next: sage continue` dla parked/intake
  cycles;
- `.agents/skills/sage:continue/SKILL.md` - istnieje skill/workflow
  `sage:continue`, nie CLI subcommand.

**Impact:** Jeśli najpierw poprawimy teksty, ale nie model wyboru cyklu, hook
będzie tylko bardziej elegancko prowadził do starego ograniczenia. Jeśli
najpierw dodamy alias CLI bez diagnozy, możemy utrwalić zły model.

**Recommendation:** W umbrella patchu zrobić inventory komunikatów po ustaleniu
docelowego modelu. Dopiero potem zdecydować, czy poprawiamy teksty na
`sage:continue`, dodajemy CLI alias, czy oba.

### Major 3 - QA findings są symptomami braku egzekucji, nie osobnymi produktowymi bugami

**Evidence:** Project Dummy QA wykazało:

- scenariusz `03-build-out-of-scope` utworzył `src/notes/random.md` przez
  real-agent `file_change` bez manifestu i recovery;
- scenariusz `04-fix-trigger` poprawił `AGENTS.md` bez pełnego diagnose/scope
  gate;
- scenariusz `11-bug-report-no-fix` miał transient próbę zapisu workflow state
  w parent repo, mimo poprawnego final state.

**Impact:** Te trzy cykle są ważne, ale najlepiej traktować je jako acceptance
tests dla umbrella patcha. W przeciwnym razie naprawimy harness lokalnie, a
nie upewnimy się, że runtime/hook/instruction model blokuje rzeczywiste
zachowanie agenta.

**Recommendation:** Włączyć je jako etap `harness enforcement` po poprawie
modelu i guidance. Każdy powinien dostać regresję, ale nie powinien sam
dyktować architektury fixu.

### Minor 1 - Skill surface hygiene można zrobić w tym samym patchsecie, ale jako osobny etap

**Evidence:** `duplicate-sage-entrypoint-fix` i
`sage-navigator-skill-drift-fix` dotyczą publicznej powierzchni Codex skilli,
nie samego modelu hooków. Są powiązane z routingiem, ale mają inny blast
radius: `skills-deploy.sh`, Stage 7 tests i source-of-truth dla navigatora.

**Impact:** Łączenie ich z pierwszym etapem zwiększy szum review. Pominięcie
ich całkiem zostawi jednak mylący routing UI i możliwy drift instrukcji.

**Recommendation:** Trzymać je w umbrella branch/patchset, ale jako późniejszy
commit/etap `skill surface hygiene`.

### Minor 2 - Cycle state disclosure jest komunikacyjnym invariantem dla gotowego modelu

**Evidence:** `cycle-state-disclosure-fix` wymaga, żeby agent potwierdzał
wejście/wyjście z cyklu po faktycznej mutacji frontmatter, nie jako deklarację
intencji.

**Impact:** To poprawia zaufanie użytkownika i debuggowalność, ale bez
docelowego modelu resume/closeout trudno zapisać precyzyjne komunikaty.

**Recommendation:** Zrobić to po etapie modelu i przed finalną QA.

## Proposed Consolidation Map

| Klaster | Inicjatywy | Rola w patchsecie | Priorytet |
| --- | --- | --- | --- |
| A. Cycle/scope/closeout model | `multi-active-cycle-model-fix`, `cross-cycle-scope-workaround-fix`, `closeout-documentation-mutation-model`, `agent-resume-intake-cycle-fix` | rdzeń architektury runtime | P1 |
| B. Recovery guidance/routing | `hook-routing-command-audit`, `blocking-hook-guidance-review` | inventory + teksty + ewentualny CLI/skill routing | P1 |
| C. Enforcement/harness | `file-change-enforcement-fix`, `fix-trigger-gate-fix`, `target-repo-ownership-harness-fix` | acceptance/regresje real-agent behavior | P1/P2 |
| D. Skill surface + disclosure | `duplicate-sage-entrypoint-fix`, `sage-navigator-skill-drift-fix`, `cycle-state-disclosure-fix` | porządek UI/instrukcji i komunikacja stanu | P2 |

## Recommended Patch Order

1. **Diagnosis/inventory:** spisać wszystkie resolvery cyklu, hook guidance
   strings, `sage status` next-step strings i harness scenario assumptions.
2. **Cycle context resolver:** przestać traktować newest `in-progress` jako
   jedyne źródło prawdy; dopuścić wiele aktywnych cykli; wybrać bieżący cykl z
   path intentu albo jawnego wyboru.
3. **Mutation classification:** rozróżnić implementation/runtime/test,
   documentation/capture i state-closeout; mixed patches wracają pod normalne
   gates.
4. **Resume/closeout transitions:** ustalić legalne ścieżki dla
   `intake/paused -> in-progress` oraz wąski closeout-only transition dla
   zaakceptowanych findings, jeśli diagnoza to potwierdzi.
5. **Recovery guidance:** poprawić `sage continue` i inne command-like strings
   po ustaleniu modelu.
6. **Harness assertions:** dodać regresje dla real-agent `file_change`,
   fix-trigger, target repo ownership, temporary scope expansion i multiple
   active cycles.
7. **Skill surface hygiene:** usunąć redundantny `sage:sage` albo formalnie
   uzasadnić jego istnienie; uszczelnić drift `sage-navigator`.
8. **Disclosure:** dodać krótki invariant komunikacyjny po formalnym
   wejściu/wyjściu z cyklu.

## Co foldować, a co zostawić jako osobny intake

Foldować do umbrella `/sage:fix`:

- `20260509-multi-active-cycle-model-fix`
- `20260509-cross-cycle-scope-workaround-fix`
- `20260509-closeout-documentation-mutation-model`
- `20260509-agent-resume-intake-cycle-fix`
- `20260509-hook-routing-command-audit`
- `20260509-file-change-enforcement-fix`
- `20260509-fix-trigger-gate-fix`
- `20260509-target-repo-ownership-harness-fix`

Potraktować jako zależne lub późny etap umbrella patchsetu:

- `20260509-blocking-hook-guidance-review`
- `20260509-cycle-state-disclosure-fix`
- `20260509-duplicate-sage-entrypoint-fix`
- `20260509-sage-navigator-skill-drift-fix`

Nie zamykać źródłowych intake cycles automatycznie po tej analizie. Zamknięcie
powinno nastąpić dopiero, gdy umbrella fix ma zaakceptowany plan albo gdy
konkretny finding zostanie formalnie oznaczony jako folded/superseded.

## Rekomendowany następny cykl

Utworzyć `/sage:fix`:

```yaml
cycle_id: "20260509-runtime-workflow-enforcement-hardening"
title: "Fix: hardening modelu cyklu, scope, recovery i harness"
workflow: fix
```

Pierwszy checkpoint tego fixu powinien być diagnozą, nie kodem. Diagnoza ma
potwierdzić proposed consolidation map i rozstrzygnąć dwa pytania:

1. Czy `closeout-only` state transition jest legalnym wyjątkiem od formalnego
   resume do `in-progress`?
2. Czy `sage continue` ma zostać realnym CLI aliasem, czy wszystkie komunikaty
   mają wskazywać `sage:continue` jako workflow/skill?

## Findings Checkpoint

Status: gotowe do review.

Rekomendacja dla Alexa: zaakceptować consolidation map i przejść do umbrella
`/sage:fix`, zamiast implementować intake cycles pojedynczo.
