---
cycle_id: "20260514-same-turn-deliver-approval-guard-fix"
title: "Fix: same-turn guard blokuje deliver po jawnej zgodzie użytkownika"
workflow: fix
phase: completed
status: completed
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P0
needs-triage: false
semantic_reclassification: accepted
source: "side-conversation"
implementation_approval:
  mode: approved
  approved_by: alexostl
  approved_at: "2026-05-14"
  gate: fix-scope-gate
  artifact: ".sage/work/20260514-same-turn-deliver-approval-guard-fix/plan.md"
  scope: manifest
related:
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - ".sage/work/20260509-alex-readable-change-explanations-fix/manifest.md"
scope:
  - ".sage/work/20260514-same-turn-deliver-approval-guard-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
---

# Fix: same-turn guard blokuje deliver po jawnej zgodzie użytkownika

## State

**Current phase:** completed. Root cause i fix scope zostały zaakceptowane
przez Alexa po read-only subagent review oraz rewizjach planu. Implementacja
została wykonana, targeted verification przeszło, a Alex zaakceptował closeout.

**Next step:** Commit i push zmian tego fixa. Po handoff można wrócić do
zaparkowanego Architecta albo wybrać kolejny intake.

## Problem

Podczas Batcha 7 Alex zatwierdził fix scope przez `s`. Agent legalnie przesunął
manifest aktywnego cyklu z `fix-scope-gate` do `deliver`, a potem próbował
dodać pierwsze failing text assertions. Hook zablokował patch jako:

`same-turn self-created cycle`

To jest mylące. Plan nie był samowolnie użyty jako approval przez agenta:
użytkownik zatwierdził scope, a mutacja manifestu była wymaganą zmianą fazy
workflowu przed implementacją.

## Concrete observed example

W cyklu `20260509-alex-readable-change-explanations-fix` przebieg był taki:

1. Root cause został zdiagnozowany, zreviewowany przez subagenta i
   zaakceptowany przez Alexa.
2. Fix scope plan został zapisany w `plan.md`, zreviewowany przez subagenta,
   poprawiony i zaakceptowany przez Alexa przez `s`.
3. Manifest dostał `phase: deliver`, później także
   `semantic_reclassification: accepted`, a scope zawierał planowane testy:
   `runtime/platforms/codex/setup/tests/alex-native-core-text.bats` i
   `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`.
4. Pierwsza implementacyjna mutacja była zgodna z TDD i planem: dodać failing
   assertions do `alex-native-core-text.bats`.
5. Hook zablokował patch jako `same-turn self-created cycle`, bo w tym samym
   `turn_id` widział wcześniejszą mutację `manifest.md` / `plan.md`.

To był false positive: agent nie tworzył planu jako własnej zgody. Użytkownik
zatwierdził scope, a mutacja manifestu była obowiązkowym transition do
`deliver` przed implementacją. Legalny workaround polegał na odczekaniu kolejnej
tury, co potwierdza, że problem siedzi w predicate hooka, a nie w braku approval.

## Additional observed example

W wątku `codex://threads/019e25b2-3a20-7ad3-ac90-bf4ded52b907` ten sam
predicate zablokował start Milestone 1 w cyklu
`20260514-doc-lifecycle-bookkeeping-architecture`.

Przebieg z logu:

1. Plan `plan-milestone-1.md` przeszedł dwie rundy review i poprawek.
2. Alex wybrał `[F] Full autonomous implementation`, czyli jawnie zatwierdził
   implementację w granicach Milestone 1.
3. Agent ustawił manifest na `phase: implement`, rozszerzył scope pod
   Milestone 1, oznaczył plan jako approved/completed i zapisał autonomy grant.
4. Pierwsza próba source/test edit została zablokowana, bo hook zobaczył
   `plan-milestone-1.md` jako artifact utworzony w tej samej turze.
5. Po kolejnej wiadomości `kontynuuj` agent dopisał do manifestu
   `semantic_reclassification: accepted`; druga próba source/test edit, już w
   nowej turze, znów została zablokowana, bo manifest był zmieniony w tej samej
   drugiej turze.
6. Dopiero kolejna świeża tura miała pozwolić wejść w test edits bez dalszych
   manifest updates.

To rozszerza diagnozę: false positive nie dotyczy tylko klasycznego
`fix-scope-gate -> deliver`. Każdy wymagany workflow bookkeeping po jawnej
zgodzie użytkownika może odnowić blokadę, jeśli dotyka `manifest.md` albo planu
w tym samym `turn_id`, nawet gdy approval i scope są już semantycznie ustalone.

Najważniejszy sygnał z tego logu to podwójna blokada pod rząd:

- pierwsza blokada po approval `[F]`, kiedy agent wykonał wymagane przejście
  manifestu/scope przed implementacją;
- druga blokada po `kontynuuj`, kiedy agent wykonał wymagany checkpoint
  `semantic_reclassification: accepted` przed implementacją.

To pokazuje, że problem nie jest jednorazowym "approval happened too recently".
Każdy legalny metadata write w turze implementacyjnej może zresetować pułapkę
same-turn i wymusić następną turę. Fix musi obsłużyć sekwencję legalnych
metadata writes po approval, a nie tylko pierwszy transition.

## Log-derived conclusions

- `same_turn_bootstrapped_cycle` używa zbyt płaskiego sygnału:
  "czy w tej samej turze zmieniono `manifest.md` albo `plan.md`". Ten sygnał
  nie rozróżnia autorstwa approval od legalnego bookkeeping po approval.
- Legalne workflow transitions są obecnie karane za przestrzeganie zasad:
  agent ma obowiązek najpierw zaktualizować manifest/phase/scope, a dopiero
  potem ruszyć source/test edits; hook interpretuje tę obowiązkową aktualizację
  jako powód blokady.
- Workaround "napisz kontynuuj w kolejnej turze" jest dowodem na bug w
  granicy `turn_id`, nie na realny brak approval. Ten workaround rozbija
  flow i zachęca do sztucznego dzielenia jednej zatwierdzonej implementacji na
  wiele tur.
- `semantic_reclassification: accepted` nie może samo w sobie resetować
  same-turn guardu, jeśli jest dopisywane jako wymagany checkpoint po już
  zaakceptowanym planie/scope. Inaczej mechanizm ryzyka i mechanizm approval
  blokują się nawzajem.
- Przyszły fix powinien modelować legalny stan jako kombinację wcześniejszego
  approved plan/scope, jawnego user approval/autonomy grant i in-scope target
  paths, zamiast traktować każdy same-turn artifact write jako self-created
  authorization.

## Fault model

To nie musi być wyłącznie bug hooka. Log wskazuje na konflikt kontraktów między
hookiem a guardrails/procedurą agenta:

1. Hook może mieć zbyt płaski predicate: `same_turn_bootstrapped_cycle` sprawdza,
   czy w tym samym `session_id` i `turn_id` pojawiła się mutacja `manifest.md`
   albo `plan.md`, ale nie rozróżnia źródła approval.
2. Agent może wykonywać poprawne kroki w złej kolejności względem obecnego
   hooka: robi metadata bookkeeping (`phase`, scope,
   `semantic_reclassification`) i od razu próbuje source/test edit w tej samej
   turze, mimo że aktualny guard traktuje taki zapis jako potencjalne
   self-approval.
3. Instrukcje Sage mogą być wewnętrznie napięte: "manifest first, then code" i
   "same-turn self-created artifacts are not approval" są słuszne osobno, ale
   bez explicit approval marker / turn-boundary contract agent nie wie, kiedy
   metadata write jest tylko bookkeepingiem po approval, a kiedy nową próbą
   samoutoryzacji.

Dlatego fix powinien obejmować diagnozę obu powierzchni: hook predicate oraz
agent-facing recovery/ordering guidance. Nie wystarczy założyć, że wystarczy
poluzować Bash predicate.

## Suspected technical trigger

`same_turn_bootstrapped_cycle` w `pre-tool-validate.sh` sprawdza, czy w tym samym
`session_id` i `turn_id` pojawiła się mutacja `manifest.md` albo `plan.md`. Nie
rozróżnia:

- nielegalnego bootstrapu: agent tworzy manifest/plan i od razu używa go jako
  approval do source/runtime/test/instruction mutation;
- legalnego continuation: użytkownik zatwierdza plan/scope, agent zmienia
  `phase` na `deliver`, a potem zaczyna implementację w zatwierdzonym scope.

W praktyce legalny `fix-scope-gate -> deliver` po zgodzie użytkownika wygląda
dla hooka tak samo jak self-created approval.

## Desired behavior

Hook nadal ma blokować prawdziwe same-turn self-created approval. Nie wolno
osłabić ochrony przed sytuacją, w której agent tworzy plan i sam sobie nim
autoryzuje implementację.

Hook recovery musi też dawać wykonalną ścieżkę w tym samym turnie, gdy blokuje
legalny capture/intake. Przykład z tego wątku: nowy intake manifest był
dozwolony, ale dodanie `.sage/.auto-fixes.log` w tym samym patchu zepsuło
bootstrap detection; komunikat powinien wskazać poprawny kształt patcha, a nie
zostawić agenta z ogólnym "create a minimal intake cycle".

Ale hook powinien dopuścić implementację, gdy:

- aktywny manifest i plan istniały przed bieżącą implementacją;
- użytkownik jawnie zaakceptował scope/plan w rozmowie;
- bieżąca same-turn mutacja manifestu jest legalnym phase transition do
  `deliver`;
- bieżąca same-turn mutacja manifestu jest legalnym bookkeeping/checkpointem
  wymaganym po zatwierdzeniu, np. `semantic_reclassification: accepted`;
- implementacja dotyka tylko zatwierdzonego manifest scope.

Agent-facing guidance powinien też jasno mówić, co zrobić, jeśli aktualny
kontrakt wymaga metadata write przed implementacją:

- jeśli metadata write jest częścią zatwierdzonego transition, nie nazywać tego
  "approval created this turn";
- jeśli hook nadal wymaga turn boundary, agent powinien zatrzymać się raz z
  precyzyjnym komunikatem, a nie wykonywać kolejny metadata write w następnej
  turze i wpadać w drugą blokadę;
- jeśli `semantic_reclassification` jest wymagane dla testów/risky paths, musi
  być częścią zatwierdzonego transition contract albo mieć własny allowowany
  checkpoint marker.

## Candidate scope

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
- generated Codex guidance / recovery text, jeśli diagnoza pokaże, że agent
  prowadzi kroki w kolejności niekompatybilnej z hookiem
- opcjonalnie workflow docs, jeśli konflikt leży w zasadzie "manifest first,
  then code" bez explicit turn-boundary/approval marker
- oficjalna opcja checkpointu `[I] Revise and Implement in the same turn`,
  jeśli plan potwierdzi, że trzeba dodać explicit bounded conditional approval
  do workflow/guidance surfaces

## Acceptance criteria

- Regresja odtwarza false positive: prior-turn plan/manifest plus same-turn
  phase transition do `deliver` nie blokuje pierwszej implementacji w scope.
- Regresja odtwarza drugi false positive: prior approved milestone plan plus
  same-turn manifest bookkeeping (`phase: implement` albo
  `semantic_reclassification: accepted`) nie blokuje pierwszej implementacji
  w zatwierdzonym scope.
- Regresja odtwarza double-block pattern: po user approval `[F]` pierwszy
  legalny manifest/plan bookkeeping nie blokuje implementacji, a kolejny
  legalny manifest checkpoint w następnej turze też nie odnawia blokady.
- Oficjalna opcja `[I] Revise and Implement in the same turn` jest opisana jako
  legalny explicit bounded conditional approval: agent może nanieść wskazaną
  rewizję i od razu implementować tylko wtedy, gdy użytkownik jawnie autoryzuje
  oba kroki w tej samej decyzji.
- `[I]` nie działa jako agent self-revision/self-approval: materialny scope
  expansion, nowe decyzje, nowe ryzyka albo niejednoznaczna rewizja nadal
  zatrzymują workflow na kolejnej bramce.
- Same-turn changes to non-canonical milestone plan artifacts, takie jak
  `plan-milestone-1.md`, nie są automatycznie traktowane jak self-created
  approval, jeśli canonical approval/scope istniał wcześniej albo user approval
  jest zapisany w manifest/decisions contract.
- Istniejące testy nadal blokują:
  - same-turn manifest-only bootstrap;
  - same-turn plan bootstrap;
  - same-turn direct `AGENTS.md` / instruction mutation bez legalnego approval.
- Komunikat hooka nie sugeruje, że brakowało user approval, jeśli faktyczny
  problem dotyczy nierozpoznanego approval/phase transition.
- Komunikat hooka/recovery guidance wskazuje wykonalną ścieżkę, gdy blokada
  wynika z niepoprawnego kształtu patcha bootstrapującego intake, np. usuń
  `.sage/.auto-fixes.log` i utwórz tylko nowy `manifest.md` plus
  `.sage/decisions.md`.
- Diagnoza rozstrzyga, czy potrzebna jest zmiana hook predicate, agent ordering
  guidance, czy oba naraz. Fix nie może ukryć problemu przez samo zalecenie
  "spróbuj w kolejnej turze", jeśli kolejna tura może znów wykonać wymagany
  metadata checkpoint i odnowić blokadę.

## Boundary

Ten intake nie zmienia Batcha 7 ani nie omija obecnego hooka. To osobny fix do
późniejszej naprawy kontraktu hook-agent: predicate, agent ordering guidance
albo obu powierzchni. Implementacja Batcha 7 może być kontynuowana legalną
ścieżką dopiero w głównym wątku / kolejnej turze, zgodnie z obecnym guardem.
