# Decisions

Shared log for significant decisions and context.
Both the AI agent and human collaborators write here.

- [2026-05-15] Zamknięto bieżący wątek bez pełnego RealHarness: targeted RealHarness dla `08-safe-autofix-metadata` i `13-mutation-preflight-lightweight` przeszedł (`present=2`, `missing=[]`), a pełny run został świadomie deferred decyzją Alexa przed commit/push.
---

### 2026-05-15 — Discovery Spike needs a small RealHarness patch first

**Decision:** Przed uruchomieniem porównania hooków nie przebudowujemy jeszcze
`pre-tool-validate.sh`. Najpierw robimy mały, izolowany patch RealHarness:
selector scenariuszy, izolowany `CODEX_HOME`, brak domyślnego `fast` oraz tryb
`HARNESS_HOOK_MODE=on|off`.

**Reason:** Obecny harness odpala pełny zestaw promptów, wcześniej twardo
przypinał `service_tier="fast"` i nie pozwalał porównać naturalnego zachowania
agenta bez hooków. Smoke runs pokazały też, że brak izolacji dziedziczy lokalne
`service_tier=flex`, które API odrzuca, a `service_tier=default` nie jest
akceptowaną wartością configu w tej wersji CLI. Izolowane `CODEX_HOME` musi
kopiować auth, ale nie kopiować `config.toml`.

**Next:** Audit-only zostaje decyzją po pierwszym hooks-on/hooks-off smoke runie,
bo najczystsza wersja może wymagać zmian w produkcyjnej logice hooka.

**Gate note:** Pierwsza próba runtime edit została zablokowana przez obecny hook,
bo scope expansion i wykonawczy plan powstały w tej samej turze. To jest zgodne
z aktualnym predicate, ale zarazem potwierdza problem badany w tym cyklu:
formalny approval contract bywa bardziej konserwatywny niż realna zgoda i
naturalny przepływ pracy.

**Approval:** Alex wybrał `[S] Skip review` dla canonical
`.sage/work/20260515-codex-hook-policy-consolidation/plan.md`. Implementacja
może ruszyć w ograniczonym scope RealHarness, bez zmian w produkcyjnym hooku.

**Smoke evidence:** Targeted RealHarness dla `11-bug-report-no-fix` przeszedł w
`hooks-off` i `hooks-on`. Bez hooków agent zapisał capture-only intake, a z
hookami zapis został zablokowany i agent zamiast tego poprosił o wejście w
`sage:fix`. To jest pierwszy twardy sygnał, że architektura hooków musi osobno
modelować capture-only intake, a nie traktować go jak implementację bez
workflow.

### 2026-05-15 — Hook policy architecture starts with Discovery Spike

**Decision:** Alex zatwierdził Milestone 0 dla
`20260515-codex-hook-policy-consolidation`: zanim powstanie docelowa
architektura enforcementu, trzeba zebrać realistyczne dane z wątków, w których
hooki realnie przeszkadzały albo pomagały.

**Direction:** Preferowany runner to RealHarness, ale scenariusze mają pochodzić
z prawdziwych thread traces, nie z promptów pisanych pod test. Spike ma porównać
`hooks-on`, `hooks-off` i `audit-only`, jeśli da się to zrobić bez dużej
przebudowy.

**Boundary:** Nie wyłączamy hooków w normalnym selfhost workflow. Wszystkie
porównania mają działać w izolowanym target repo/worktree albo kontrolowanym
harnessie.

### 2026-05-15 — Intake created for separate Sage-state Git

**Decision:** Alex poprosil o dodanie niskopriorytetowego build intake dla
modelu, w ktorym `.sage/` nie jest czescia historii produktu, ale ma wlasny
tor Git dla historii, merge i recovery.

**Context:** Rozmowa odrzucila wariant `.sage/` ignorowane per worktree bez
wlasnego Gita, bo merge historii pracy bylby trudniejszy i bardziej ryzykowny
niz zwykly Git merge. Rekomendowany kierunek to dwa Gity: product Git dla kodu
i normalnej dokumentacji, Sage-state Git dla operacyjnego stanu agenta.

**Next:** Przyszly build ma zaprojektowac kontrakt storage/branch/worktree,
snapshot/merge/recovery oraz pozniejszy handoff dla `alex-os-dev`. Bez
osobnej zgody nie mutowac `alex-os-dev`.

### 2026-05-14 — Same-turn guard fix approved and closed

**Decision:** Alex zaakceptował zweryfikowany fix i poprosił o commit oraz push.

**Closed scope:** Hook approval marker, hook regressions, `[I] Revise and
Implement in the same turn` w workflow/guidance surfaces oraz generated Codex
test zostały wdrożone i zweryfikowane.

**Next:** Po commit/push można wrócić do zaparkowanego
`20260514-doc-lifecycle-bookkeeping-architecture` albo wybrać kolejny intake.

### 2026-05-14 — Same-turn guard implementation verified

**Decision:** Implementacja `20260514-same-turn-deliver-approval-guard-fix`
jest gotowa do close checkpoint.

**Fix:** `pre-tool-validate.sh` dostał `implementation_approval` contract:
same-turn `manifest.md` / canonical `plan.md` bookkeeping może przejść tylko z
manifest markerem, istniejącym canonical `plan.md`, prior canonical plan
evidence i targetem w `manifest.scope`. `[I] Revise and Implement in the same
turn` zostało dodane do workflow/guidance surfaces jako bounded conditional
approval.

**Verification:** `pre-tool-validate.bats` 93/93, `stage3-agents-md.bats`
52/52, targeted approval-guard tests 10/10, targeted generated `AGENTS.md` test
1/1, `bash -n` i `git diff --check` pass.

### 2026-05-14 — Same-turn guard fix scope approved for implementation

**Decision:** Alex wybrał `[S] Skip review` po dwóch rundach read-only plan
review i zaakceptował poprawiony fix scope dla
`20260514-same-turn-deliver-approval-guard-fix`.

**Implementation approval:** Manifest dostał `phase: deliver`,
`semantic_reclassification: accepted` oraz `implementation_approval.mode:
approved` wskazujące canonical `plan.md`.

**Boundary:** Implementacja zostaje ograniczona do zatwierdzonego scope:
`pre-tool-validate.sh`, `pre-tool-validate.bats`, workflow docs oraz generated
Codex guidance/test. Scope expansion zatrzymuje cykl.

### 2026-05-14 — Implementation approval evidence narrowed to canonical plan

**Decision:** Druga runda read-only plan review zwróciła `NEEDS REVISION`, bo
pre-turn `manifest.md` evidence było za szerokie. Plan został poprawiony przed
implementacją.

**Change:** `implementation_approval` wymaga teraz istniejącego canonical
`.sage/work/<cycle>/plan.md` oraz prior `.session-mutations.log` evidence dla
canonical `plan.md`. Manifest-only pre-turn evidence bez canonical planu nie
wystarcza.

**Boundary:** Dodano wymagany negatywny test misuse: marker plus wcześniejszy
manifest log, ale brak canonical `plan.md` albo brak prior canonical plan
evidence, nadal blokuje source/runtime/test/instruction edits, szczególnie
`AGENTS.md`.

### 2026-05-14 — Fix scope plan revised after subagent review

**Decision:** Read-only subagent review dla fix-scope planu zwrócił
`NEEDS REVISION`. Plan został poprawiony przed implementacją.

**Change:** Plan wybiera teraz konkretny marker contract:
`implementation_approval` w `manifest.md`, allowowany przez hook tylko z
pre-turn evidence zatwierdzonego canonical `plan.md`/scope. Dodano brakujące
test cases dla `plan-milestone-1.md` oraz marker misuse.

**Boundary:** Same-turn dopisanie approval markera bez wcześniejszego plan/scope
evidence nadal ma blokować source/runtime/test/instruction edits, szczególnie
`AGENTS.md`.

### 2026-05-14 — Same-turn guard scope includes actionable recovery guidance

**Decision:** Rozszerzono scope
`20260514-same-turn-deliver-approval-guard-fix` o recovery guidance dla
blokad, które da się naprawić w tej samej turze.

**Example:** Nowy intake manifest był legalny, ale patch zawierał też
`.sage/.auto-fixes.log`, więc bootstrap detection spadł do aktywnego cyklu i
zablokował zapis. Przyszły fix ma wskazać agentowi poprawny kształt patcha:
nowy `manifest.md` plus opcjonalnie `.sage/decisions.md`, bez audit logu w tym
samym bootstrapie.

### 2026-05-14 — Intake: short Codex skill loader descriptions

**Decision:** Dodano intake
`20260514-codex-skill-loader-short-descriptions-fix`.

**Boundary:** Nazwy/namespace `Sage` zostają bez zmian. Przyszły fix ma tylko
sprawić, żeby opisy workflow skillów w GUI Codexa były bardzo krótkie i
czytelne, zamiast pokazywać `## Artifact Language Contract`.

### 2026-05-14 — Same-turn guard root cause accepted for scope planning

**Decision:** Alex wybrał `[S] Skip review` po read-only subagent review i
zaakceptował root cause dla
`20260514-same-turn-deliver-approval-guard-fix`.

**Root cause:** `same_turn_bootstrapped_cycle` zbyt płasko traktuje same-turn
`manifest.md` / canonical `plan.md` writes jako self-created approval, więc
blokuje legalny workflow bookkeeping po approval zanim `semantic_reclassification`
albo inny approval marker może mieć znaczenie.

**Next:** Cykl przechodzi do `fix-scope-gate`; plan ma objąć hook predicate,
regresje i minimalne workflow/guidance surface dla `[I] Revise and Implement in
the same turn`.

### 2026-05-14 — Add Revise and Implement checkpoint option

**Decision:** Sage ma dostać oficjalną opcję checkpointu
`[I] Revise and Implement in the same turn`.

**Semantics:** To jest explicit bounded conditional approval: Alex może
zatwierdzić konkretną rewizję oraz implementację po tej rewizji w jednej
decyzji. Agent może kontynuować bez kolejnego stopu tylko w granicach dokładnie
opisanych zmian.

**Boundary:** `[I]` nie pozwala na agentowe self-revision/self-approval. Scope
expansion, nowa decyzja, nowe ryzyko albo niejasna rewizja nadal zatrzymują
workflow na bramce.

### 2026-05-14 — P0 same-turn guard fix started, Architect paused

**Decision:** Alex kazał spauzować aktywny wątek
`20260514-doc-lifecycle-bookkeeping-architecture` i rozpocząć
`20260514-same-turn-deliver-approval-guard-fix`.

**State change:** Architect przeszedł z `status: in-progress` do
`status: paused` na `phase: implement`. Same-turn guard fix przeszedł z
`status: intake` / `phase: intake` do `status: in-progress` /
`phase: understand`.

**Boundary:** Ten fix zaczyna od diagnozy konfliktu hook-agent. Nie wolno z góry
rozstrzygać, że to wyłącznie false positive w hooku; root cause gate ma
porównać `same_turn_bootstrapped_cycle`, wymagany workflow bookkeeping po
approval i agent-facing recovery/ordering guidance.

### 2026-05-14 — AGENTS.md 12000-byte cleanup moved back to Architect

**Decision:** Usunięcie sztucznej reguły 12000 bajtów dla generated
`AGENTS.md` nie należy już do P0 batcha
`20260514-same-turn-deliver-approval-guard-fix`. Ten temat ma wydarzyć się w
aktywnym cyklu Architect.

**Effect:** P0 same-turn batch wraca do wąskiego scope: naprawić false positive
approval guard wokół legalnego workflow bookkeeping po user approval.

### 2026-05-14 — Approval guard batch includes AGENTS.md 12000-byte cleanup

**Decision:** `20260514-same-turn-deliver-approval-guard-fix` staje się jednym
P0 batchem: approval guard false positive plus usunięcie sztucznej reguły
12000 bajtów dla generated `AGENTS.md`.

**Why:** 12000-byte check w `stage3-agents-md.bats` był roboczym hamulcem
compactness, ale nie jest realnym limitem runtime. Realny Codex constraint to
`project_doc_max_bytes` / domyślnie 32 KiB. Compactness ma być pilnowana przez
osobny minimization/instruction-surface batch, a nie arbitralny byte cap.

### 2026-05-14 — Priority update: same-turn guard first

**Decision:** Najwyższy priorytet przed dalszymi batchami ma
`20260514-same-turn-deliver-approval-guard-fix`. To jest P0, bo false positive
same-turn guard blokuje legalny przepływ: user approval -> wymagany workflow
bookkeeping -> implementacja.

**Queue update:** Nowy, odrębny intake
`20260514-architect-claude-parity-fix` został dodany na koniec listy jako
future fix dotyczący aktualizacji Architecta pod Claude Parity. Nie jest
formalnie łączony z istniejącymi batchami.

### 2026-05-14 — Instruction minimization intake expanded to engineering practices review

**Decision:** Intake `20260514-instruction-surface-minimization-pass-fix`
został rozszerzony: przyszły fix ma najpierw zrobić review obecnych dobrych
praktyk programowania w Sage, a dopiero potem zdecydować, czy wystarczy dodać
minimization pass, czy brakuje jeszcze małej, konkretnej zasady.

**Why:** Alex nie chce tylko dokleić kolejnej instrukcji. Chodzi o ocenę, jakie
engineering principles już mamy, czy są spójne i operacyjne, oraz czy czegoś
ważnego brakuje poza minimalizacją instruction bloatu.

**Boundary:** Capture-only update. Nie rozpoczęto implementacji. Przyszły plan
ma unikać "best practices checklist bloat": każda nowa zasada poza
minimization pass wymaga konkretnego failure mode, właściwego surface i
minimalnej weryfikacji.

### 2026-05-14 — Same-turn guard intake updated with double-block fault model

**Decision:** Intake `20260514-same-turn-deliver-approval-guard-fix` dostał
dodatkowy przykład z wątku
`codex://threads/019e25b2-3a20-7ad3-ac90-bf4ded52b907`: po approval `[F]`
hook zablokował source/test edit dwa razy pod rząd, najpierw po milestone
plan/manifest bookkeeping, a potem po kolejnym wymaganym
`semantic_reclassification: accepted`.

**Why:** To nie jest jeszcze rozstrzygnięte jako wyłącznie bug hooka. Przyszły
fix ma zbadać konflikt kontraktów: predicate `same_turn_bootstrapped_cycle`
może być zbyt płaski, ale agent guidance może też prowadzić metadata writes w
kolejności, która przewidywalnie odnawia same-turn guard.

**Boundary:** Capture-only update. Nie zmieniono hooka ani source/test files.
Acceptance criteria intake'u mają teraz obejmować double-block pattern oraz
rozstrzygnięcie, czy poprawki wymagają hook predicate, agent ordering guidance,
czy obu powierzchni.

### 2026-05-14 — Milestone 1 implementation approved

**Decision:** Alex wybrał `[F] Full autonomous implementation` dla
`plan-milestone-1.md`.

**Boundary:** Autonomy grant obejmuje tylko Milestone 1 Codex core:
decision capture policy, retention/archive rotation, archive read policy i
Signal 8 narrowing. Scope expansion, unsafe PostToolUse assumption albo brittle
natural-language Signal 8 classifier zatrzymuje implementację.

### 2026-05-14 — Auto-review: revised Milestone 1 plan

**Verdict:** NEEDS REVISION. Subagent znalazł 1 critical, 1 major i 1 minor:
Codex PostToolUse assumption check jest za pozno, Signal 8 potrzebuje
explicit metadata contract zamiast semantycznego `decision-worthy`, a
`core/workflows/review.workflow.md` trzeba jawnie wykluczyc albo dodac do
inventory. User choice: R. (auto-review sub-agent)

### 2026-05-14 — Revised Milestone 1 plan sent to auto-review

**Decision:** Alex wybrał `[A] Subagent review` dla revised
`plan-milestone-1.md` po dopisaniu Codex core workflow surfaces i zawężeniu
platform scope.

**Review target:** Sprawdzić, czy critical workflow-surface gap jest zamknięty,
czy Signal 8 matrix jest wystarczający, czy archive rotation safety constraints
są kompletne i czy Codex-only scope nie zostawia sprzeczności.

### 2026-05-14 — Auto-review: Milestone 1 implementation plan

**Verdict:** NEEDS REVISION. Subagent znalazł 1 critical, 4 major i 2 minor
issues: brak workflow checkpoint surfaces w scope, niedoprecyzowane Signal 8,
brak safety constraints dla archive rotation w `post-tool-check.sh`, brak
Claude/Antigravity verification mimo ich obecnosci w scope oraz brak runtime
verification/stop condition dla Codex PostToolUse assumptions. User chose: R.
(auto-review sub-agent)

### 2026-05-14 — Milestone 1 implementation plan sent to auto-review

**Decision:** Alex wybrał `[A] Subagent review` dla
`plan-milestone-1.md`.

**Review target:** Plan ma zostać sprawdzony pod kątem scope creep,
minimalizmu, TDD ordering, archive rotation writer path, Signal 8 semantics i
czy nie wprowadza nowego token bloatu.

### 2026-05-14 — Milestone 1 implementation plan drafted

**Decision:** Dla `20260514-doc-lifecycle-bookkeeping-architecture` zapisano
milestone-specific build plan `plan-milestone-1.md` przed source edits.

**Plan approach:** Milestone 1 idzie TDD: najpierw tests dla decision capture
policy, potem wording; potem tests i implementacja archive rotation; na koniec
archive read policy oraz narrowing harness Signal 8, żeby frontmatter flip sam
w sobie nie wymagał `.sage/decisions.md`.

### 2026-05-14 — Doc lifecycle milestone plan approved

**Decision:** Alex wybrał `[S] Skip review` po rewizji planu. Milestone plan
`20260514-doc-lifecycle-bookkeeping-architecture` jest zaakceptowany do build.

**Approved scope:** Milestone 1: decisions policy/retention/archive read
policy. Milestone 2: closeout lifecycle i bookkeeping reconciliation, z
absorpcją `20260514-completed-cycle-bookkeeping-reconciliation-fix`. Milestone
3: live `work_index` / `sage status --json` formalization. Final verification:
pełny RealHarness.

### 2026-05-14 — Auto-review: doc lifecycle milestone plan

**Verdict:** NEEDS REVISION. Subagent znalazł 4 major i 2 minor issues w
milestone planie: brak archive read policy, niedoprecyzowany worktree writer
contract, konflikt wokół `.sage/decisions.md` w bookkeeping reconciliation oraz
zbyt szeroki Milestone 1. User chose: R. (auto-review sub-agent)

### 2026-05-14 — Doc lifecycle milestone plan sent to auto-review

**Decision:** Alex wybrał `[A] Subagent review` dla milestone planu
`20260514-doc-lifecycle-bookkeeping-architecture`.

**Plan approach:** Implementacja ma iść trzema milestone'ami: decisions
policy/retention, closeout lifecycle/reconciliation z absorpcją intake'u
`20260514-completed-cycle-bookkeeping-reconciliation-fix`, oraz live
work-index/status formalization. Finalny confidence check obejmuje pełny
RealHarness.

### 2026-05-14 — Doc lifecycle architecture approved for planning

**Decision:** Alex wybrał `[S] Skip review` po revised design. ADR
`.sage/docs/decision-doc-lifecycle-bookkeeping.md` został oznaczony jako
`accepted`, a cykl `20260514-doc-lifecycle-bookkeeping-architecture` przeszedł
do milestone planning.

**Plan direction:** Implementację dzielimy na trzy małe milestone'y: decisions
policy/retention, closeout lifecycle/reconciliation oraz live work-index/status
formalization. Na końcu cyklu ma przejść pełny RealHarness.

### 2026-05-14 — Batch 7 completed: Alex-native plain technical prose

**Decision:** Batch 7 został zaakceptowany do domknięcia. Sage ma używać
middle-ground stylu: plain technical prose z impact/cause przed technical
mechanism i next action, bez infantylizowania technicznych tematów.

**What changed:** Wspólny kontrakt trafił do
`core/constitution/sage-process.constitution.md` oraz generated Codex
`AGENTS.md` przez `runtime/platforms/codex/setup/lib/agents-md.sh`. `qa` i
`design-review` dostały lokalny language override przy użyciu angielskich
report template'ów, a same template'y dostały krótkie Alex-native guidance.

**Evidence:** Przeszły: `alex-native-core-text.bats` 5/5,
`stage3-agents-md.bats` 51/51, `bash -n agents-md.sh`, `bin/sage update` ze
Stage 10 sanity sweep oraz `git diff --check`.

### 2026-05-14 — Intake captured: source-mutating cycle concurrency

**Decision:** Alex zauważył, że w tym samym repo/workspace nie powinny być
równolegle otwarte dwa cykle typu `fix`/`build`, jeśli oba mogą zmieniać kod
źródłowy. Równoległe cykle koncepcyjne albo report-only mogą być legalne, ale
muszą być odróżnione od source-mutating work.

**Created:** `20260514-source-mutating-cycle-concurrency-fix`.

**Open question:** Granica wymaga diagnozy: per repo, per branch, czy per
worktree. `QA` jest osobnym znakiem zapytania, bo zwykle jest report-only, ale
pracuje blisko runtime evidence.

**Context:** Problem ujawnił się, gdy implementacja Batcha 7 została
zablokowana przez aktywny cykl `20260514-doc-lifecycle-bookkeeping-architecture`.
To wskazuje na potrzebę formalnego modelu concurrency, a nie ręcznego parkowania
na chybił-trafił.

### 2026-05-14 — Doc lifecycle architecture design drafted

**Decision:** Alex zaakceptował brief
`20260514-doc-lifecycle-bookkeeping-architecture`, więc przygotowano design
contract w `spec.md` oraz ADR
`.sage/docs/decision-doc-lifecycle-bookkeeping.md`.

**Key direction:** Manifest pozostaje source-of-truth dla state; `decisions.md`
ma być decision logiem, nie process logiem; `sage status --json` formalizujemy
jako live work-index bez nowego ręcznie edytowanego indeksu; current decisions
mają trzymać 50 wpisów, a archive ma być search-first i nie rotować w linked
worktrees.

### 2026-05-14 — Intake captured: same-turn deliver approval guard

**Decision:** Zapisano nowy fix intake
`20260514-same-turn-deliver-approval-guard-fix`.

**Why:** Hook `same_turn_bootstrapped_cycle` zablokował Batch 7 mimo jawnego
zatwierdzenia scope przez Alexa, ponieważ potraktował legalny manifest phase
transition `fix-scope-gate -> deliver` w tej samej turze jak self-created
approval.

**Boundary:** Ten intake nie osłabia zasady `same-turn self-created artifacts
are not approval`. Przyszły fix ma odróżnić prawdziwy bootstrap bez approval od
legalnej implementacji po user approval i wymaganym phase transition.

### 2026-05-14 — Subagent Polish handoff prompt extracted from Batch 6

**Decision:** Audit po zamknięciu Batcha 6 pokazał, że wymaganie "prompty
handoffowe dla subagentów mają mieć naturalną prozę po polsku" nie zostało
wdrożone w source/test surfaces. Było zapisane w artefaktach Batcha 6, ale nie
trafiło do `auto-review/SKILL.md`, generated `AGENTS.md` ani regresji.

**Created:** `20260514-subagent-polish-handoff-prompt-fix`.

**Boundary:** Batch 6 pozostaje historycznie completed dla realnie wykonanych
części: approval boundary, targeted self-learning recall i generated Codex
`AGENTS.md` recall contract. Polski subagent handoff prompt jest osobnym
follow-upem, a nie domkniętym elementem Batcha 6.

**Hook note:** Próba dopisania post-completion note bezpośrednio do zamkniętego
manifestu Batcha 6 została zablokowana przez completed-cycle protection. Ten
wpis w `decisions.md` jest historią audytu bez reopenowania zamkniętego cyklu.

### 2026-05-14 — Intake captured: Architect elicitation density preference

**Decision:** Prośba o tryb prowadzenia `architect` nie wchodzi do Batcha 7.
Zapisano osobny future fix intake
`20260514-architect-elicit-question-density-fix`.

**Desired behavior:** Przy wejściu w `architect` agent ma zapytać, czy Alex
woli jedno pytanie naraz z większym kontekstem i rekomendacją, czy kilka
wątków w jednej wiadomości z mniejszą ilością kontekstu. Grill.me /
premise-challenge część `deep-elicit` ma respektować wybrany tryb.

**Boundary:** Capture-only. Implementacja nie została rozpoczęta i nie
powiększa scope `20260509-alex-readable-change-explanations-fix`.

### 2026-05-14 — Batch 7 root cause accepted

**Decision:** Alex zaakceptował diagnozę Batcha 7 po read-only subagent review:
QA jest miejscem, gdzie problem ujawnił się na realnym raporcie, ale podobny
surface istnieje też w `design-review`.

**Root cause:** Alex-native kontrakt jest zapisany zbyt ogólnie, a raportowe
workflowy wskazują angielskie template'y bez jawnego przypomnienia, że template
daje strukturę, nie język docelowy. Agent może więc użyć angielskiej prozy albo
zacząć od technicznych etykiet zamiast wyjaśnić po kolei: co się dzieje, czemu
to problem, jak to się technicznie nazywa i co trzeba zmienić.

**Boundary:** Scope planning ma objąć `qa` i `design-review` raport/template
touchpoints oraz regresje tekstowe. `build` zostaje odróżniony, bo ma
workflow-level guidance i główne template'y z Alex-native komentarzami.

### 2026-05-14 — Selfhost Bash hook false positive fixed

**Decision:** Bash `PreToolUse` guard został uspokojony bez wyłączania ochrony
przed realnymi shell writes do managed/project paths.

**What changed:** Descriptor/no-op redirects (`2>/dev/null`, `>/dev/null`,
`/dev/fd/*`, `/proc/self/fd/*`, `&1`, `&2`) nie są już traktowane jak mutacja.
Mutacje Bash poza repo są legalne dla tego guardu. Lokalne ignored hook/log
artifacts w repo mogą przechodzić, ale managed/generated surfaces jak
`.codex/hooks.json` nadal są blokowane przy Bash write.

**Evidence:** Przeszły: `bash -n`, `pre-tool-validate.bats` 82/82,
`bin/sage update`, `stage5-6-hooks.bats` 13/13, `stage10-tighten.bats` 14/14,
active hook byte-identity check, `jq` matcher/count check, generated surfaces
diff check i `git diff --check`.

### 2026-05-14 — Intake captured: completed-cycle bookkeeping reconciliation

**Decision:** Alex zaakceptował kierunek: completed-cycle artifacts nadal mają
być chronione po closeoucie, ale hook powinien dopuszczać wąski wyjątek na
bookkeeping-only reconciliation bez każdorazowej ręcznej zgody.

**Created:** `20260514-completed-cycle-bookkeeping-reconciliation-fix`.

**Scope intent:** Fix ma objąć globalną zasadę w
`core/constitution/sage-process.constitution.md` po angielsku, mechaniczny
allowlist w `runtime/platforms/codex/hooks/pre-tool-validate.sh` oraz regresje
w `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`.

**Boundary:** Nie dodawać tego do `AGENTS.md`. Wyjątek nie może zmieniać scope,
deliverables, verification evidence, implementation, approval meaning ani
faktów historycznych zamkniętego cyklu.

### 2026-05-14 — Selfhost Bash hook false positive after thread read

**Decision:** Rewizja `PreToolUse` musi objąć logikę Bash hooka, nie tylko
liczbę matcher groups w Codex UI.

**Why:** Wątek `019e25e7-de3f-7271-a2dd-7c99fbd215a3` pokazał, że read-only
`sed ... 2>/dev/null || true` został zablokowany. Root cause to regex w
`pre-tool-validate.sh`, który traktował `2>/dev/null` jako mutujący file write,
a obecność ścieżki `runtime/...` w tej samej komendzie aktywowała guarded path
block.

**Boundary:** Jeden matcher group `Bash|apply_patch|Edit|Write` zostaje jako
UI cleanup, ale właściwa poprawka musi odróżniać shell redirection do
`/dev/null` i deskryptorów od realnych writes do project/managed paths. Mutacje
Bash poza repo mają być jednoznacznie legalne dla tego guardu. Gitignored
lokalne artefakty hooków/logów w repo mogą przechodzić, ale managed surfaces
typu `.codex/hooks.json` pozostają chronione.

### 2026-05-14 — Selfhost PreToolUse duplicate fixed

**Decision:** Skonsolidowano generated Codex `PreToolUse` hook registry do
jednego matcher group `Bash|apply_patch|Edit|Write`.

**Why:** Codex Desktop pokazywał dwa aktywne hooki, bo Stage 5 generował dwa
matcher groups wskazujące na tę samą komendę `pre-tool-validate.sh`. Jeden
regex matcher zachowuje coverage dla `Bash`, `apply_patch`, `Edit`, `Write`,
ale UI i operacyjny model widzą jeden zainstalowany hook.

**Evidence:** Aktywny `.codex/hooks.json` ma `.hooks.PreToolUse | length == 1`.
Przeszły: `jq -e .`, `bash -n`, `stage5-6-hooks.bats` 13/13,
`bin/sage update`, `stage10-tighten.bats` 14/14, generated surfaces diff check
i `git diff --check`.

### 2026-05-14 — Selfhost sage update PreToolUse duplicate UI finding

**Decision:** Po `bin/sage update` Alex zauważył w Codex Desktop dwa aktywne
hooki pod `PreToolUse`. Rewizja update passu ma skonsolidować generated
`PreToolUse` matcher groups w jeden wpis.

**Root cause:** `.codex/hooks.json` generował dwa matcher groups uruchamiające
tę samą komendę `pre-tool-validate.sh`: osobno dla `apply_patch|Edit|Write` i
osobno dla `Bash`. To nie powinno podwajać wykonania dla jednego tool call, ale
UI pokazuje to jako dwa zainstalowane hooki.

**Boundary:** Oficjalny Codex hooks contract mówi, że `matcher` jest regexem po
tool name / aliases i wspiera `Bash`, `apply_patch`, `Edit`, `Write`. Legalna
minimalna poprawka to jeden matcher group `Bash|apply_patch|Edit|Write`.

### 2026-05-14 — Log analysis findings captured as fix intakes

**Decision:** Po zatwierdzeniu findings z analizy logow zapisano nowe follow-upy
jako fix intake cycles oraz doprecyzowano istniejacy runtime alignment fix.

**Created:** `20260514-realharness-pass-semantics-fix`,
`20260514-multi-cycle-attribution-fix`,
`20260514-framework-log-schema-observability-fix`.

**Updated:** `20260514-codex-runtime-alignment-fix` dostal jawny scope na drift
miedzy source hooks `runtime/platforms/codex/hooks/**` i aktywnymi
`.codex/hooks/**`, bo logi pokazaly stare false positives mimo naprawionego
source.

**Boundary:** To jest capture-only. Implementacja nie zostala rozpoczeta.
Istniejace fixy z Batcha 5 nadal licza sie jako source-level naprawy; nowy
runtime alignment fix ma sprawdzic, czy aktywne surface'y rzeczywiscie je
wdrazaja.

### 2026-05-14 — Selfhost sage update reached completion checkpoint

**Decision:** `bin/sage update` został wykonany po Batchu 6 i doprowadzony do
completion checkpoint w cyklu `20260514-selfhost-sage-update-pass`.

**Evidence:** Update zakończył się `exit 0`. Tracked generated surfaces
(`AGENTS.md`, `CLAUDE.md`, `.agents`, `.claude`, `.codex/config.toml`,
`.codex/hooks`, `.codex/hooks.json`) nie mają diffu. Jedyna zmiana generatora
w tracked files to managed `.gitignore` block dla lokalnych Sage hook artifacts.
Przeszły: `git diff --check`, generated diff check, `git check-ignore -v`,
`bash -n`, `stage9-bootstrap.bats` 18/18, `stage3-agents-md.bats` 51/51 oraz
`stage7-skills.bats` 12/12.

**Boundary:** Cykl zostaje `status: in-progress`,
`phase: completion-checkpoint` do finalnej akceptacji Alexa. Nie wykonano
stage/commit/push.

### 2026-05-14 — Selfhost sage update pass started after Batch 6

**Decision:** Alex potwierdził, że Batch 6 jest skończony i można wykonać
kontrolowany `bin/sage update` w `sage-selfhost`.

**Why:** Batche 1-6 dotykały generated instruction surfaces, hooków, loaderów i
prompt policy. Selfhost update pass ma sprawdzić, czy regenerowane platform
files pozostają spójne z aktualnym frameworkiem.

**Boundary:** Utworzono osobny cycle
`20260514-selfhost-sage-update-pass`. To jest update/regeneration audit, nie
nowy feature. Jeśli `bin/sage update` wygeneruje duży lub nieoczekiwany diff,
zatrzymujemy się po diagnozie i targeted verification.

### 2026-05-14 — Intake captured: targeted real harness scenarios

**Decision:** Alex zauważył, że real harness powinien móc targetować dowolną
liczbę scenariuszy zamiast wymuszać pełny run. Utworzono capture-only cycle
`20260514-real-harness-targeted-scenarios-fix`.

**Why:** Batch 6 pokazał potrzebę punktowego real-agent evidence dla scenariuszy
takich jak `09-memory-correction-reuse`, bez kosztu pełnego harnessa.

**Boundary:** Intake dotyczy runner/reporting ergonomics:
`runtime/platforms/codex/harness/run-harness.sh`, ewentualnie agregatora,
testów i docs. Nie zmienia semantyki istniejących scenariuszy ani nie oznacza,
że partial run spełnia full release-blocker harness.

### 2026-05-14 — Codex runtime alignment scope narrowed

**Decision:** Alex wskazał, że pomysł "OpenAI/Codex alignment gate do
przyszłych batchy" jest już zapisany w memory, więc nie powinien powiększać
manifestu `20260514-codex-runtime-alignment-fix`.

**Scope impact:** Z manifestu usunięto wymaganie dodawania alignment gate do
przyszłych root-cause/plan checkpoints oraz stop condition o rozjeździe docs vs
runtime warning. Inicjatywa zostaje zawężona do bieżącego Codex runtime/config:
effective config check, stabilne hook command paths i sync/check aktywnego
`.codex/hooks.json`.

### 2026-05-14 — Batch 6 implementation verified

**Decision:** Batch 6 implementation is ready for completion checkpoint.
Workflow `[A] Subagent review` wording now returns findings to the user instead
of approving the next phase, auto-review prompts include targeted self-learning
recall, and generated Codex `AGENTS.md` uses targeted recall rather than broad
session-start memory preload.

**Verification:** `bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats
runtime/platforms/codex/setup/tests/stage3-agents-md.bats
runtime/platforms/codex/setup/tests/alex-native-core-text.bats` passed 58/58.
`bash -n runtime/platforms/codex/setup/lib/agents-md.sh` and `git diff --check`
passed. `validate-workflows.sh` exited 0 but reported 0 workflows discovered.

### 2026-05-14 — Codex runtime alignment fix captured

**Decision:** Alex zdecydował, że worktree cleanup zostaje w osobnym wątku, a
pozostałe problemy alignmentu Codex runtime/config mają wejść do jednej
inicjatywy fix.

**Created:** `.sage/work/20260514-codex-runtime-alignment-fix/manifest.md`.

**Scope intent:** Fix ma objąć effective config check, stabilne repo-local hook
command paths, sync/check aktywnego `.codex/hooks.json` względem generatora
oraz zasadę, że przy konflikcie stale OpenAI docs z aktualnym Codex
Desktop/CLI warning lokalny runtime warning wygrywa dla kompatybilności.

**Boundary:** Worktree cleanup i stare worktree configi są poza tym zakresem.
Implementacja nie została rozpoczęta.

### 2026-05-14 — Batch 6 semantic reclassification accepted

**Decision:** Batch 6 mutuje workflow docs, auto-review capability, generated
Codex instruction renderer and tests. Po zatwierdzonym Systemic fix scope
dodano `semantic_reclassification: accepted` do manifestu, żeby runtime hooki
legalnie dopuściły test/runtime/instruction surface mutations.

**Boundary:** To nie rozszerza scope poza zatwierdzony plan; odblokowuje tylko
mutacje już wymienione w manifest scope i planie.

### 2026-05-14 — Batch 6 fix scope approved for implementation

**Decision:** Alex wybrał `[S] Skip review` po rewizji planu Batcha 6. Plan
jest zatwierdzony do implementacji bez kolejnego auto-review.

**Boundary:** Implementacja ma trzymać się zatwierdzonego scope: workflow
approval wording, auto-review prompt policy, generated Codex `AGENTS.md`
guidance, source-level regression test, stage3 regression tests i artefakty
cyklu. Manifest przeszedł do `phase: deliver`.

### 2026-05-14 — Batch 6 fix plan revised after auto-review

**Decision:** Plan Batcha 6 został zrewidowany po verdict Hooke’a `NEEDS
REVISION`. Rewizja adresuje MAJOR findings: testy nie mogą opierać się głównie
na generated `AGENTS.md`, muszą też pilnować canonical source surfaces.

**Plan impact:** Plan dodaje konkretny source-level regression test
`runtime/platforms/codex/setup/tests/subagent-review-policy.bats`, który ma
sprawdzać `core/workflows/{fix,build,architect}.workflow.md` oraz
`core/capabilities/review/auto-review/SKILL.md`. Test ma łapać stare `[A]`
wording (`then implement`, `then start building`, `then continue to plan`,
`then proceed`), zachowanie osobnych ścieżek `[S]`, `[C]`, `[F]`, oraz targeted
recall contract (`sage_memory_set_project`, `filter_tags: ["self-learning"]`,
`.sage-memory/self-learning.md`, `prevention rules`).
