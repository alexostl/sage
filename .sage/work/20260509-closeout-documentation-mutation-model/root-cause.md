---
cycle_id: "20260509-closeout-documentation-mutation-model"
title: "Root cause: Batch 3 closeout lifecycle"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
---

# Root Cause: Batch 3 closeout lifecycle

## Problem

Batch 3 laczy piec intake'ow, ktore wygladaja jak osobne objawy, ale wszystkie
dotycza tej samej granicy: kiedy cykl Sage jeszcze zyje i wolno porzadkowac
artefakty, a kiedy jest juz zamknietym materialem do commita albo handoffu.

Objawy:

- agent moze zamknac manifest za wczesnie, a potem chciec dopisac plan,
  QA/verification albo decyzje;
- hook po zamknieciu widzi zwykle "no active cycle", bez recovery message dla
  pomylonej kolejnosci closeoutu;
- `post-tool-check` umie wykryc mutacje po completion, ale robi to jako
  non-blocking incident po fakcie;
- local handoff po closeoucie nie ma jasnej reguly "nie dopisuj epilogu do
  .sage, tylko zrob stage/commit handoff/report";
- male repo hygiene typu pojedynczy `.gitignore` wpada w ten sam model co
  runtime/test/workflow, zamiast miec waska sciezke decisions-only.

## Root Cause

Sage ma rozproszone, niepelne modele konca cyklu zamiast jednego kontraktu
closeout lifecycle.

Kontrakt istnieje w kilku miejscach, ale kazde pokrywa tylko fragment:

1. Workflowy mowia, ze po approval trzeba zapisac decyzje, handoff i status,
   ale nie koduja wyraznie, ze final self-review i wszystkie artefakty maja
   poprzedzac zmiane manifestu na `completed`, a git handoff jest osobnym
   krokiem po closeoucie. Ten krok dotyczy statusu stage/commit; push jest
   osobna decyzja poza domyslnym closeout next-step.
2. `pre-tool-validate` rozroznia `in-progress`, `paused` i `intake`, ale
   `completed` cyklu nie ma osobnej semantyki closeout recovery. Taki cykl
   wypada z resolvera i agent dostaje ogolne "no active cycle" albo, gdy
   istnieje inny aktywny cykl, patch do zamknietego cyklu moze zostac oceniony
   wzgledem tego innego aktywnego cyklu zamiast dostac completed-specific
   recovery.
3. `post-tool-check` zna zasade "completed powinno byc ostatnia mutacja", ale
   jest tylko audytem po mutacji. To nie uczy agenta poprawnej kolejnosci zanim
   sprobuje pisac.
4. Hooki maja specjalne wyjatki dla lightweight config, parked capture i
   risky repo-control files, ale nie ma waskiej klasyfikacji
   `decisions-only repo hygiene` dla pojedynczej, niskiego ryzyka zmiany
   repo hygiene po closeoucie.

## Evidence

- [active_init.sh](/Users/alexostl/Developer/sage-selfhost/runtime/platforms/codex/hooks/lib/active_init.sh:157)
  zwraca `active` tylko dla `status: in-progress`, `parked-capture` tylko dla
  `paused|intake`, a `completed` nie ma osobnej sciezki recovery.
- [pre-tool-validate.sh](/Users/alexostl/Developer/sage-selfhost/runtime/platforms/codex/hooks/pre-tool-validate.sh:233)
  dla `resolution_kind=none` pokazuje ogolny komunikat o braku aktywnego cyklu
  albo parked work, bez rozpoznania "zamknales manifest za wczesnie".
- [post-tool-check.sh](/Users/alexostl/Developer/sage-selfhost/runtime/platforms/codex/hooks/post-tool-check.sh:84)
  ma komentarz i logike: completed manifest powinien byc finalna mutacja; jesli
  ten sam patch dotyka innych plikow, zapisuje `post_completion_mutation`.
  To jest jednak hook po fakcie i `exit 0`, wiec nie prowadzi agenta przed
  bledem.
- [build.workflow.md](/Users/alexostl/Developer/sage-selfhost/core/workflows/build.workflow.md:455)
  po approval najpierw wymienia bulk plan status, decisions i handoff, ale nie
  ma jawnego self-review-before-completed ani stage/commit handoff status/pytania.
- [fix.workflow.md](/Users/alexostl/Developer/sage-selfhost/core/workflows/fix.workflow.md:399)
  mowi o post-flight po approval, ale nie definiuje zamkniecia jako ostatniej
  mutacji ani tego, co wolno/nie wolno robic po closeoucie.

## Chain

Gdy agent jest przy koncu cyklu, workflow nie daje mu jednego, jednoznacznego
rytualu:

1. Najpierw final self-review i wszystkie wymagane artefakty.
2. Potem decisions/verification/plan/handoff.
3. Dopiero na koncu `manifest.status: completed`.
4. Po closeoucie tylko stage/commit status i pytanie o handoff, bez
   dopisywania epilogu do zamknietych artefaktow. Push nie jest czescia
   domyslnego pytania po closeoucie.

Bez tego agent moze zamknac manifest przed ostatnia korekta, a potem hook
traktuje legalna intencje closeout cleanup jak brak aktywnego cyklu. W druga
strone, gdy user prosi o local handoff po closeoucie, agent moze uznac, ze
musi jeszcze "ladnie" dopisac epilog do `.sage`, mimo ze poprawnym outputem
jest odpowiedz, commit/handoff i ewentualnie osobna zgoda na korekte artefaktu.

## Confidence

High. Intake'y Batcha 3 opisuja rozne real-agent incydenty, a kod pokazuje, ze
obecne mechanizmy sa fragmentaryczne: czesc reguly istnieje w post-tool audycie,
czesc w workflow closeout, czesc w pre-tool scope resolverze, ale nie ma
jednego pre-mutation kontraktu i nie ma stage/commit handoff step po
closeoucie.

## Proposed Direction

To jest Moderate/Systemic fix, nie surgical patch.

Plan powinien:

- ujednolicic closeout guidance we workflowach i generated Codex `AGENTS.md`;
- dodac final self-review-before-completed i "manifest completed jako ostatnia
  mutacja";
- doprecyzowac post-closeout git next-step: stage/commit status oraz pytanie
  o handoff zmian biezacego cyklu; push pozostaje osobnym, explicit krokiem,
  nie domyslna czescia closeoutu;
- dodac recovery wording w `pre-tool-validate` dla prob mutacji po completed
  cycle, szczegolnie gdy patch wskazuje `.sage/work/<closed-cycle>/`; plan ma
  tez pokryc przypadek, w ktorym patch do completed cycle nie powinien spadac
  na unrelated newest active cycle;
- zachowac `post-tool-check` jako audyt, ale oprzec zachowanie agenta o
  guidance/pre-tool recovery;
- dodac waska regule decisions-only repo hygiene dla pojedynczej oczywistej
  zmiany typu `.gitignore`, bez rozszerzania zamknietego cyklu;
- domknac sibling intake manifests dopiero po zweryfikowanej implementacji,
  jako `folded_into` anchor cycle.
