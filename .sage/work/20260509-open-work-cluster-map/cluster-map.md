---
cycle_id: "20260509-open-work-cluster-map"
title: "Mapa klastrów otwartych prac Sage"
workflow: analyze
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-09
---

# Mapa klastrów otwartych prac Sage

## Cel

Ta mapa jest orientacyjnym wejściem dla kolejnych agentów. Otwarte manifesty z
2026-05-09 mają być traktowane jako kilka większych patchy, a nie jako lista
samotnych intake'ów.

## Klaster A - Mutation enforcement i target safety

**Cel:** dopilnować, że agent nie omija workflow realnymi mutacjami plików,
nawet jeśli ścieżka narzędziowa nie jest klasycznym `apply_patch`.

**Wątki źródłowe:**

- `20260509-file-change-enforcement-fix`
- `20260509-binary-asset-mutation-contract-fix`
- `20260509-fix-trigger-gate-fix`
- `20260509-target-repo-ownership-harness-fix`
- `20260509-mcp-incident-followup-fixes`
- `20260509-closeout-documentation-mutation-model`

**Dlaczego razem:** wszystkie dotyczą granicy: co jest legalną mutacją, kto jest
ownerem repo/cyklu, co jest tylko capture/documentation, a co już implementacją.
Binary asset contract nie może być osobnym wyjątkiem bez spięcia z
`file_change` enforcement, bo inaczej staje się furtką dla zwykłych zmian
tekstowych poza `apply_patch`.

**Pierwszy sensowny krok:** `/sage:fix` z diagnozą defense-in-depth:
`apply_patch`, `file_change`, shell/unified exec, binary asset paths, transcript
assertions i harness rerun dla scenariuszy 03/04/11.

## Klaster B - Workflow entry, resume, recovery i autonomia

**Cel:** sprawić, żeby deklaracja workflow, wznowienie cyklu, recoverable hook
block i autonomia po approval miały jeden spójny model stanu na dysku.

**Wątki źródłowe:**

- `20260509-cycle-workflow-entry-enforcement-fix`
- `20260509-agent-resume-intake-cycle-fix`
- `20260509-hook-block-recovery-behavior-fix`
- `20260509-blocking-hook-guidance-review`
- `20260509-cycle-state-disclosure-fix`
- `20260509-active-cycle-lease-lock`
- `20260509-autonomous-approval-boundary-fix`

**Dlaczego razem:** pojedynczo wyglądały jak trzy samotne tematy: lease lock,
task/status disclosure i approval boundary. W praktyce wszystkie pytają o to
samo: kiedy rozmowna deklaracja agenta staje się formalnym stanem Sage i kiedy
agent musi zatrzymać się po decyzję człowieka.

**Pierwszy sensowny krok:** zacząć od formalnego entry/resume contract:
pewna klasyfikacja Standard+ tworzy albo wznawia cykl; recoverable block
prowadzi do poprawionego retry; `[F]` działa tylko dla zatwierdzonego snapshotu
plan/scope; lease lock jest rozszerzeniem tego samego modelu ownership.

## Klaster C - Codex surface, config i skill reachability

**Cel:** naprawić powierzchnię, przez którą Codex w ogóle dociera do Sage:
config, loader stubs, navigator i entrypointy.

**Wątki źródłowe:**

- `20260509-selfhost-codex-loader-path-fix`
- `20260509-codex-hooks-feature-flag-migration-fix`
- `20260509-sage-navigator-skill-drift-fix`
- `20260509-duplicate-sage-entrypoint-fix`

**Dlaczego razem:** to są problemy instruction reachability i adaptera Codex.
Jeśli loader wskazuje złą ścieżkę albo navigator driftuje, agent może nawet nie
dotrzeć do poprawnych reguł workflow.

**Pierwszy sensowny krok:** najpierw mały fix loaderów selfhost/target, bo to
już realnie zablokowało odczyt workflow. Potem migracja `codex_hooks` -> `hooks`
i cleanup publicznych skilli.

## Klaster D - Alex-native communication i widoczność pracy

**Cel:** praca Sage ma być czytelna dla Alexa: po polsku tam, gdzie to nowa
proza projektu, prostym językiem przy findings, oraz z widocznym postępem w
Codex UI.

**Wątki źródłowe:**

- `20260509-alex-readable-change-explanations-fix`
- `20260509-qa-workflow-polish-report-contract`
- `20260509-codex-task-plan-visibility-fix`

**Dlaczego razem:** wcześniejszy punkt `codex-task-plan-visibility-fix` nie
powinien zostać samotnym UX ogonkiem. Task plan UI, proste wyjaśnienia i polska
proza QA to jedna warstwa: jak Sage komunikuje stan, ryzyko i postęp pracy.

**Pierwszy sensowny krok:** dodać do generated Codex contract i workflow docs
krótki wzorzec komunikacji: "co się dzieje" -> "czemu to problem" -> "nazwa
techniczna" -> "co zmieniamy", plus próg kiedy Standard+ work używa
`update_plan`.

## Kolejność rekomendowana

1. **Klaster A** - bo dotyczy realnych mutacji plików i bezpieczeństwa
   workflow.
2. **Klaster C** - bo bez poprawnej powierzchni Codex kolejne workflowy mogą
   nie wczytać właściwych instrukcji.
3. **Klaster B** - bo domyka semantykę wejścia/wznowienia/autonomii i recovery.
4. **Klaster D** - bo poprawia czytelność i komfort pracy, a nie twardą
   egzekucję.

## Reguła dla kolejnych agentów

Nie zaczynać od pojedynczego intake'u bez sprawdzenia tej mapy. Jeśli intake
należy do klastra, nowy `/sage:fix` powinien jawnie wskazać, czy robi cały
klaster, jego etap, czy świadomie wycina wąski surgical fix z klastra.
