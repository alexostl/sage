---
title: "Spec: Alex-native operating model"
workflow: architect
phase: design
status: completed
created: 2026-05-08
updated: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
brief: ".sage/work/20260508-alex-native-operating-model/brief.md"
adrs:
  - ".sage/docs/decision-alex-native-artifact-language.md"
  - ".sage/docs/decision-alex-native-conversation-contract.md"
  - ".sage/docs/decision-alex-native-checkpoint-autonomy.md"
handoff: |
  Key decisions: Polish prose applies to new `.sage` artifacts only; Sage
  framework terms stay English; conversation changes are moderate and focused
  on decision points/checkpoints; autonomous continuation is an explicit
  checkpoint option with hard stop conditions. v1 rejects a new shared snippet
  renderer; edit existing core workflow/capability/template text directly and
  mirror compact runtime text only where Codex/Claude require it.
  Open questions: None for architecture; planning owns exact test task shape.
  Risks: Over-localization, port divergence, and weakening checkpoint safety.
  Next agent should: Build a milestone plan that starts with shared core
  workflow/capability text, then updates Codex and Claude instruction surfaces
  with tests. Do not migrate historical `.sage` files.
---

# Spec: Alex-native operating model

## Cel

Wprowadzić Alex-native operating model jako umiarkowaną, przyszłościową zmianę
Sage Self Host. Zmiana ma sprawić, że nowe artefakty `.sage` będą pisane po
polsku, agent będzie dawał więcej krótkiego kontekstu w rozmowie z
junior/vibe-coderem, a checkpointy będą mogły oferować świadomy wybór między
normalnym zatwierdzaniem a autonomiczną kontynuacją.

To nie jest redesign metodologii Sage. Istniejące nazwy frameworkowe, nazwy
workflowów, nazwy artefaktów i formalne gate'y pozostają stabilne.

## Architektura

### Komponenty

1. **Core workflow text** (`core/workflows/*.workflow.md`)
   - Główne źródło zasad dla `architect`, `build`, `design` i podobnych
     workflowów.
   - Powinno określać język nowych artefaktów, styl checkpointów i opcję
     autonomicznej kontynuacji.
   - Implementacja v1 powinna edytować istniejące workflow files bez dodawania
     nowego shared snippet/include mechanizmu.

2. **Core capability prompts** (`core/capabilities/**/SKILL.md`)
   - Źródło szczegółowego zachowania przy elicitation, specification, planning
     i build-loop.
   - Powinno doprecyzować "jedno pytanie naraz", krótkie wyjaśnienia konceptów,
     sprawdzanie kodu zamiast pytania o fakty widoczne w repo, oraz linkowanie
     do kluczowych miejsc w artefaktach.

3. **Navigator / always-on routing** (`core/capabilities/orchestration/sage-navigator/SKILL.md`
   i `core/constitution/sage-process.constitution.md`)
   - Źródło tonu przy rozpoczynaniu i prowadzeniu Standard+ work.
   - Powinno zawierać lekki kontrakt: nie zakładaj, że użytkownik przeczytał
     pełny artefakt; przy checkpointach pokaż krótkie streszczenie i linki do
     najważniejszych sekcji.

4. **Codex instruction surface** (`runtime/platforms/codex/setup/lib/agents-md.sh`)
   - Renderuje zawsze załadowany `AGENTS.md` dla Codex.
   - Powinien przenieść kompaktowy Alex-native contract do generated
     `AGENTS.md`, bez nadmiernego rozrostu pliku.
   - To jest port-specific compact mirror: szczegółowe zasady żyją w `core/`,
     ale always-loaded Codex kernel musi zawierać krótki kontrakt.

5. **Claude instruction surface** (`runtime/platforms/claude-code/setup/generate-claude-code.sh`
   i generowane commands/skills)
   - Renderuje `CLAUDE.md` i `.claude/commands/`.
   - Powinien otrzymać równoważny kontrakt, najlepiej przez shared core text
     albo minimalnie zsynchronizowany fragment, żeby Codex i Claude zachowywały
     się podobnie.
   - `runtime/platforms/claude-code/setup/generate-plugin.sh` jest downstream:
     wyciąga treść z generatora Claude, więc nie powinien mieć osobnej filozofii,
     ale warto go uwzględnić w regression checku, jeśli dotykamy generatora.

6. **Test surfaces**
   - Codex: istniejące Bats testy Stage 3 już sprawdzają generowany `AGENTS.md`
     i shared routing text.
   - Claude: obecnie brakuje równie widocznego testu generatora; plan powinien
     dodać albo wskazać minimalny regression test dla `CLAUDE.md`/commands.

## Decyzje Projektowe

### D1 — Język artefaktów jest regułą treści, nie migracją

Nowe artefakty `.sage` tworzone przez Sage mają mieć treść po polsku, ale
stabilne nazwy frameworkowe pozostają po angielsku. Dotyczy to m.in. `brief`,
`spec`, `plan`, `manifest`, `checkpoint`, `handoff`, `workflow`, `build`,
`architect`, `fix`, `design`, `review`, `scope`, `status`, `phase`.

Historyczne pliki w `.sage/work` i `.sage/docs` nie są częścią migracji.

**Trade-off:** To daje natychmiastowy efekt dla nowych prac i ogranicza scope,
ale repo pozostanie językowo mieszane w historii. To jest świadomy koszt, bo
historia decyzji ma pozostać nienaruszona.

Alternatywy odrzucone:

- **Migracja historycznych plików `.sage`:** odrzucona, bo rozdmuchuje scope i
  zmienia zapis historii.
- **Globalny language config:** odrzucony w v1, bo self-host ma działać dla
  Alexa i nie potrzebuje wielojęzycznej abstrakcji.
- **Tłumaczenie nazw frameworka:** odrzucone, bo osłabia zgodność z istniejącą
  metodologią i komendami.

### D2 — Styl rozmowy jest kontraktem checkpointów i elicitation, nie globalnym gadulstwem

Agent ma rozmawiać około 20-30% bardziej wspierająco dla junior/vibe-codera,
ale nie ma spowalniać każdego kroku. Najmocniejsza zmiana dotyczy:

- startu Standard+ workflow,
- `architect` elicitation/design,
- większych `build` flow,
- `design` i innych workflowów, które proszą użytkownika o decyzje,
- checkpointów po zapisaniu artefaktu.

Minimalny kontrakt rozmowy:

- daj krótki kontekst przed decyzją albo artefaktem,
- zadawaj jedno pytanie naraz, gdy decyzja jest niejasna,
- podawaj własną rekomendację, gdy pytasz o wybór,
- nie pytaj o rzeczy, które da się sprawdzić w kodzie lub dokumentacji,
- po zapisaniu artefaktu pokaż 1-3 klikalne linki do najważniejszych sekcji,
- nie zakładaj, że użytkownik przeczytał cały artefakt.

**Trade-off:** To zwiększa czytelność i zaufanie, ale może dodać trochę tekstu.
Ograniczeniem jest zasada "krótki kontekst, nie wykład".

Alternatywy odrzucone:

- **Pełne `grill-me everywhere`:** odrzucone, bo Sage jest już skuteczny i nie
  powinien spowalniać każdego workflowu.
- **Tylko port-specific tone text:** odrzucone, bo Codex i Claude rozjadą się
  zachowaniem.
- **Nowy shared snippet/include renderer:** odrzucony w v1. Repo już ma shared
  source w `core/workflows/*.workflow.md` i `core/capabilities/**/SKILL.md`;
  nowy mechanizm renderowania prose byłby dodatkową infrastrukturą dla małej
  zmiany.

### D3 — Autonomiczna kontynuacja jest opcją checkpointu z bezpiecznymi stopami

Przy checkpointach, szczególnie po `spec` i `plan`, Sage może oferować opcję
kontynuowania z normalnymi checkpointami albo pozwolenia agentowi na
autonomiczne dowiezienie dalszego cyklu.

Domyślną i rekomendowaną ścieżką pozostają checkpointy. Autonomia jest świadomą
opcją użytkownika w danym cyklu, nie globalnym ustawieniem.

Autonomia musi się zatrzymać, gdy:

- scope wychodzi poza zatwierdzony `manifest`,
- pojawia się decyzja architektoniczna niewyjaśniona w `spec`,
- planowanie po `spec` ujawnia ważne pytanie, nowy trade-off albo decyzję,
  której nie da się uczciwie potraktować jako mechanicznego rozbicia speca,
- testy albo quality gates ujawniają problem zmieniający plan,
- agent odkrywa konflikt z dokumentacją, konstytucją albo wcześniejszą decyzją,
- potrzebne jest usunięcie/deprecjacja publicznego zachowania,
- użytkownik mówi `pause`, `stop`, `czekaj` albo podobnie.

**Trade-off:** Opcja przyspiesza mniej ważne cykle, ale wymaga bardzo jasnego
opisu stopów, żeby nie osłabić Rule 4: Checkpoints Are Sacred.

Autonomia po `plan` jest najniższym ryzykiem, bo plan już określa scope,
zadania i verification path. Autonomia po `spec` jest dopuszczalna, ale ma
ostrzejszą granicę: agent może stworzyć plan i kontynuować tylko wtedy, gdy
planowanie nie ujawnia nowej istotnej decyzji ani scope expansion. Jeśli coś
takiego się pojawia, zatrzymuje się przed implementation.

Alternatywy odrzucone:

- **Autonomia tylko po `plan`:** bezpieczna, ale nie spełnia sytuacji, w której
  Alex po dobrym `spec` chce pozwolić agentowi dowieźć rutynowy cykl.
- **Autonomia po `spec` z implicit approval każdego planu:** odrzucona, bo
  plan może wprowadzić nowe decyzje, których użytkownik nie zatwierdził.
- **Globalny tryb autonomii:** odrzucony, bo checkpoint choice ma być lokalną
  decyzją per cykl.

## Zachowanie Workflowów

### Architect

`architect` powinien zachować trzy rundy elicitation, ale prowadzić je w stylu
"jedno pytanie naraz" i nie przepychać rund, jeśli użytkownik słusznie wskaże,
że dana informacja już padła. Po `brief` i `spec` agent pokazuje krótkie
podsumowanie oraz linki do sekcji, które warto przeczytać.

Checkpoint po designie powinien zachować obecne opcje review/revise/new session,
ale może dodać autonomiczną ścieżkę tylko po świadomym zatwierdzeniu spec.

### Build

`build` wymaga największej korekty stylu. Przed pisaniem plików agent powinien:

1. krótko powiedzieć, co już wie z repo i dokumentacji,
2. wskazać, gdzie są niejasności,
3. zadać jedno pytanie, jeśli decyzja wpływa na spec albo scope,
4. dopiero potem zapisać artefakt.

Po `spec` użytkownik powinien móc wybrać:

- review/skip-review i normalne przejście do planu,
- revise,
- new session,
- autonomous continuation przez plan/build/verify, ale tylko jeśli planowanie
  nie ujawni istotnej nowej decyzji, scope expansion albo ważnego pytania.
  W przeciwnym razie agent zapisuje plan/draft i zatrzymuje się przed
  implementation.

Po `plan` użytkownik powinien móc wybrać:

- review/skip-review i start build-loop,
- revise,
- new session,
- autonomous continuation przez build-loop/quality gates/final checkpoint.

### Fix

`fix` pozostaje bardziej samodzielny, bo root cause często da się ustalić bez
pytań. Zmiana stylu dotyczy głównie wyjaśnienia root cause prostszym językiem
i linkowania do dowodów. Nie należy dodawać zbędnej autonomicznej opcji tam,
gdzie fix już ma własny diagnose → scope → fix → verify contract.

### Design i Analyze

Jeśli `design` albo `analyze` proszą użytkownika o decyzję, powinny stosować
ten sam lekki kontrakt rozmowy: kontekst, jedno pytanie, rekomendacja, link do
artefaktu po zapisie.

## Wymagania Funkcjonalne

FR1. Nowe `brief.md`, `spec.md`, `plan.md`, `manifest.md`, `decision-*.md` i
checkpoint summaries tworzone w `.sage` powinny mieć treść po polsku, chyba że
target project lub użytkownik wyraźnie poprosi inaczej.

FR2. Framework terms i nazwy artefaktów pozostają po angielsku.

FR3. Prompting w `architect`, `build`, `design` i podobnych workflowach musi
preferować jedno pytanie naraz przy decyzjach wymagających użytkownika.

FR4. Agent powinien najpierw sprawdzić repo/dokumentację, gdy odpowiedź da się
ustalić lokalnie, zamiast zadawać pytanie użytkownikowi.

FR5. Po zapisaniu checkpoint artifact agent pokazuje krótkie streszczenie oraz
1-3 linki do najważniejszych sekcji lub linii.

FR6. Checkpointy po `spec` i `plan` w Standard+ work powinny oferować opcję
autonomicznej kontynuacji, ale tylko jako świadomy wybór użytkownika.

FR7. Autonomiczna kontynuacja musi mieć jawne stop conditions.

FR8. Codex `AGENTS.md` i Claude `CLAUDE.md`/commands muszą przenosić ten sam
kontrakt zachowania na runtime agentów.

## Non-Functional Requirements

NFR1. Zmiana nie powinna znacząco zwiększyć długości zawsze ładowanych plików
instrukcji, szczególnie Codex `AGENTS.md`.

NFR2. Zmiana powinna być możliwie centralna w `core/`; porty powinny odziedziczyć
albo wygenerować zachowanie.

NFR3. Zachowanie musi być testowalne przez string-level generator tests i/lub
workflow text tests.

NFR4. Zmiana nie może osłabić istniejących gate'ów: spec/plan before code,
manifest scope, verification-before-done, root-cause-before-fix.

## Granice

In scope:

- `core/workflows/architect.workflow.md`
- `core/workflows/build.workflow.md`
- `core/workflows/design.workflow.md`
- `core/workflows/fix.workflow.md`
- `core/workflows/analyze.workflow.md`
- `core/capabilities/elicitation/deep-elicit/SKILL.md`
- `core/capabilities/elicitation/quick-elicit/SKILL.md`
- `core/capabilities/planning/specify/SKILL.md`
- `core/capabilities/planning/plan/SKILL.md`
- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `core/capabilities/orchestration/build-loop/SKILL.md`
- `core/constitution/sage-process.constitution.md`
- `develop/templates/manifest-template.md`
- `develop/templates/spec/full.spec-template.md`
- `develop/templates/spec/minimal.spec-template.md`
- `develop/templates/plan/standard.plan-template.md`
- `develop/templates/architecture/decision-template.md`
- Codex `AGENTS.md` generator and tests
- Claude `CLAUDE.md`/commands generator and tests
- Claude plugin generation as an inherited downstream surface
- `.github/workflows/codex-port-ci.yml` if new Claude tests need CI coverage

Out of scope:

- tłumaczenie historycznej `.sage` dokumentacji,
- zmiana nazw plików, komend albo workflowów,
- globalny language config,
- publiczny produkt dla wszystkich polskich użytkowników,
- rework hook enforcement poza tekstem/instrukcjami potrzebnymi do tej zmiany.
- nowy shared snippet/include mechanism dla prose.
- `runtime/platforms/antigravity/**` i `runtime/platforms/generic/**` w v1,
  bo aktywny self-host target to `claude-code,codex`.

## Ryzyka i Mitygacje

1. **Ryzyko: zbyt dużo rozmowy.**
   - Mitygacja: instrukcje mówią "krótki kontekst", nie długie tutoriale.

2. **Ryzyko: instrukcje deklaratywne nie zmienią zachowania.**
   - Mitygacja: dodać testy na generated instruction surfaces i konkretne
     checkpoint option text.

3. **Ryzyko: Codex i Claude rozjadą się stylem.**
   - Mitygacja: preferować shared core text i dodać regression checks dla obu
     platform.

4. **Ryzyko: autonomia osłabi checkpointy.**
   - Mitygacja: autonomia jako opcja per checkpoint z twardymi stop conditions.

5. **Ryzyko: realne zachowanie agenta nie zmieni się mimo testów stringowych.**
   - Mitygacja: po implementacji wykonać dogfood QA na krótkim fikcyjnym
     `architect`/`build` prompt i sprawdzić, czy agent daje kontekst, linkuje
     artefakty i zatrzymuje się przy istotnych decyzjach.

## Rollback

Rollback tej zmiany jest operacyjny, nie migracyjny: jeśli nowy styl okaże się
gorszy, cofamy commit(y) zmieniające core/port instruction surfaces i testy.
Artefakty `.sage` utworzone w międzyczasie po polsku zostają jako historyczne
pliki danego cyklu; nie robimy reverse-migracji treści dokumentów.

## Verification Strategy

- Bats: rozszerzyć Codex Stage 3 testy o generated `AGENTS.md` contract:
  Polish artifact prose, junior/vibe-coder context, key-link checkpoint summary,
  autonomous continuation option and stop conditions.
- Claude generator: dodać minimalny test lub harness check, że generated
  `CLAUDE.md`/commands zawierają równoważny contract.
- Claude plugin: jeśli generator Claude się zmienia, sprawdzić, że plugin
  generation dziedziczy właściwy text albo nie wymaga osobnej zmiany.
- Shared text tests: sprawdzić `core/workflows`/`core/capabilities`, że
  checkpoint option text i artifact language rules istnieją w core.
- Manual review: przed buildem porównać plan z tym spec, czy nie migruje
  historycznej dokumentacji.
- Dogfood QA: po implementacji uruchomić krótką próbę zachowania na fikcyjnym
  Standard+ workflow i ocenić, czy styl zmienił się o zakładane 20-30%.

## Open Questions for Planning

None. Plan ma zdefiniować dokładny kształt testów, ale nie wymaga już decyzji
architektonicznej od użytkownika.
