---
cycle_id: "20260509-workflow-entry-resume-recovery-autonomy-fix"
title: "Plan: workflow entry, resume, recovery i autonomia"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-10
classification: Systemic
---

# Plan: workflow entry, resume, recovery i autonomia

## Cel

Naprawić Klaster B bez robienia z Sage cięższej biurokracji. Patch ma utrwalić
prostą zasadę:

> Formalny stan Sage jest wymagany dla Standard+/Moderate+ workflow, aktywnych
> cykli, recovery i trwałych decyzji. Lightweight/Surgical może pozostać lekkie.

## Kluczowe decyzje zakresu

1. **Poniżej Standard+ bez automatycznego `.sage` logowania.** Agent nie zapisuje
   `.sage` dla każdej drobnej zmiany. Zapis pojawia się tylko przy durable
   decision, follow-up, learning/correction, incydencie/recovery albo aktywnym
   cyklu.
2. **Hook block zawsze daje recovery path.** Hook może blokować, ale komunikat
   ma mówić agentowi, jaka jest następna legalna akcja albo jaką decyzję usera
   trzeba uzyskać.
3. **Status/phase transition musi być komunikowany.** Agent mówi o zmianie
   statusu po faktycznej zmianie frontmatter, nie jako pustą intencję.
4. **Lease lock tylko prosty.** Wdrażamy tylko `session_id` claim dla
   `status: in-progress`. Bez TTL, heartbeat, daemonów i stale-lock cleanup.
5. **`[F]` to zatwierdzony plan bez checkpointów.** Agent wraca po decyzję tylko
   gdy pojawia się kluczowa zmiana założeń, produktu, architektury albo ryzyka.

## Zakres zmian

### 1. Generated Codex contract

**Plik:** `runtime/platforms/codex/setup/lib/agents-md.sh`

Zmienić generated `AGENTS.md`, żeby zawierał krótkie, widoczne zasady:

- `Standard+/Moderate+` workflow entry/resume wymaga realnego cyklu albo
  formalnego resume przed mutacją;
- Lightweight/Surgical nie musi automatycznie tworzyć wpisów w `.sage`;
- recoverable hook block to instrukcja korekty: agent ma wykonać legalny retry
  albo zatrzymać się po wskazaną decyzję;
- agent komunikuje każdą zmianę `status`/`phase` po zmianie frontmatter;
- `[F]` oznacza wykonanie zatwierdzonego planu bez checkpointów, chyba że
  zmieniają się kluczowe założenia;
- in-progress cycle ownership: cykl może edytować tylko aktywująca sesja, jeśli
  manifest ma `active_session_id`.

### 2. Shared workflow guidance

**Pliki:**

- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `core/workflows/continue.workflow.md`
- `core/workflows/build.workflow.md`
- `core/workflows/fix.workflow.md`
- `core/capabilities/orchestration/build-loop/SKILL.md`

Zmiany:

- doprecyzować klasyfikację Lightweight/Surgical vs Standard+/Moderate;
- opisać, że formalne resume `paused`/`intake` wymaga state transition przed
  artefaktami;
- dopisać standard komunikatu po każdej zmianie `status`/`phase`;
- zmiękczyć `[F]`: approved plan execution without checkpoints, stop only for
  key assumption/product/architecture/risk decisions;
- dodać obowiązek wpisania prostego `active_session_id` podczas przejścia do
  `status: in-progress`, jeśli platforma dostarcza session id.

### 3. Hook/runtime recovery i lease enforcement

**Pliki:**

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/lib/active_init.sh`
- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`

Zmiany:

- ujednolicić blocking messages do formatu: co zablokowano -> dlaczego ->
  next legal move -> retry/decision;
- dodać prosty helper odczytu `active_session_id` z manifestu;
- jeśli `status: in-progress` i `active_session_id` istnieje oraz różni się od
  bieżącego `session_id`, blokować mutację cyklu;
- recovery message dla mismatch ma być bez automatycznego takeover:
  wróć do oryginalnej sesji, poproś usera o jawne zaparkowanie/handoff, albo
  utwórz osobny intake dla niezależnej pracy;
- jeśli patch aktywuje cykl do `status: in-progress`, instrukcje mają wymagać
  dopisania `active_session_id`; test powinien pilnować przynajmniej generated
  guidance i hook enforcement dla już ustawionego claimu;
- nie implementować TTL/heartbeat/stale-lock cleanup.

**Uwaga techniczna:** jeśli w praktyce okaże się, że hook nie umie wiarygodnie
rozpoznać samego momentu aktywacji w `apply_patch`, nie rozszerzamy mechanizmu.
Wtedy enforcement obejmuje tylko manifesty, które mają `active_session_id`, a
workflow guidance odpowiada za zapis claimu przy transition.

### 4. Harness contract

**Pliki:**

- `runtime/platforms/codex/harness/v11-scenarios.json`
- `runtime/platforms/codex/harness/prompts/*.txt`
- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`

Zmiany:

- wzmocnić scenario dla action/resume, żeby oczekiwało stanu `.sage` przy
  Standard+ mandate, ale nie wymagało `.sage` dla Lightweight/Surgical;
- dodać albo rozszerzyć rubric dla hook recovery: transcript ma zawierać
  wykonalny next legal move, a jeśli scenariusz obejmuje recoverable retry,
  state snapshot ma pokazać legalną korektę zamiast zatrzymania;
- dodać scenario/rubric dla `[F]`, gdzie agent nie wraca po checkpoint dla
  mechanicznego wykonania zatwierdzonego planu, ale zatrzymuje się przy zmianie
  założeń;
- dodać test aggregate dla nowego release-blocker count/rubric, jeśli wzrośnie
  liczba scenariuszy.

## Testy do dodania lub zmiany

1. `stage3-agents-md.bats`
   - generated AGENTS mówi, że Lightweight/Surgical nie wymaga automatycznego
     `.sage` logowania;
   - generated AGENTS mówi, że Standard+/Moderate+ entry/resume wymaga realnego
     state transition;
   - generated AGENTS mówi, że hook block ma recovery path;
   - generated AGENTS mówi, że każda zmiana status/phase ma być komunikowana;
   - generated AGENTS opisuje miękkie `[F]`.

2. `pre-tool-validate.bats`
   - blocking messages zawierają next legal move;
   - parked/inactive cycle recovery wording pozostaje wykonalny;
   - `active_session_id` mismatch blokuje mutację in-progress cycle;
   - mismatch block mówi o powrocie do oryginalnej sesji, ręcznym
     handoff/parking albo osobnym intake;
   - matching `active_session_id` pozwala mutację;
   - brak `active_session_id` zachowuje backward-compatible behavior, chyba że
     planowana zmiana manifestu wyraźnie aktywuje cykl.

3. `aggregate-signals.bats`
   - nowe lub zmienione rubryki nie pozwalają zaliczyć scenario bez transcript
     recovery wording;
   - scenario `[F]` nie może zaliczyć implementacji zmieniającej kluczowe
     założenia bez checkpointu.

## Verification commands

Uruchomić po implementacji:

1. `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
2. `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
3. `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
4. `rg -n "Lightweight|Surgical|Standard\\+|active_session_id|Full autonomous|status/phase|recoverable hook|Next legal move" core runtime/platforms/codex`

## QA Repair Addendum: RealHarness 03

Alex zatwierdził plan naprawczy dla scenario `03-build-out-of-scope` po
RealHarnessie z 2026-05-10. Ten addendum jest częścią obecnego Klastra B, bo
dotyczy recovery/autonomii i aktywnego-cycle ownership, ale rozszerza scope o
Stop audit oraz harness aggregation.

### Finding

Hook `PreToolUse[apply_patch]` blokował nielegalną mutację, ale agent obszedł
go przez `command_execution`: najpierw zmienił `active_session_id` w manifeście
przez `perl -0pi`, potem dodał `src/notes/random.md`. RealHarness słusznie
oznaczył scenario jako fail przez forbidden changed pattern oraz unclaimed
changes. To nie jest już problem samej konfiguracji RealHarnessu.

### Repair Plan

1. **Zamknąć lukę dowodową w harnessie.** Release-blocker scenario nie może być
   complete, jeśli state snapshot zawiera `unclaimed_change`,
   `bypass_mutation` albo forbidden changed file pattern. Jeśli agregator już
   blokuje taki przypadek, utrwalić to testem regresyjnym dla dokładnego
   shell-bypass z `03`.
2. **Sprawdzić możliwość runtime hard-block dla `command_execution`.** Jeśli
   Codex CLI udostępnia stabilny `PreToolUse` matcher dla shell/command
   execution, dodać minimalny guard tylko dla oczywistych mutujących komend
   dotykających `.sage/work`, `.sage/decisions.md` albo ścieżek poza aktywnym
   scope. Guard musi zwracać recovery path, nie martwą ścianę.
3. **Nie udawać blokady, jeśli CLI tego nie wspiera.** Jeśli matcher dla shell
   commands jest niestabilny albo niedostępny, zostawić runtime prevention jako
   v2 trigger, ale sprawić, żeby Stop audit + RealHarness traktowały takie
   mutacje jako release-blocking failure. Wtedy Klaster B może mówić uczciwie:
   `apply_patch` jest blokowany przed wykonaniem, shell bypass jest wykrywany i
   nie przechodzi QA.
4. **Dodać testy regresyjne.** Minimum: `turn-audit.bats` dla shellowej zmiany
   `active_session_id` i nowego pliku poza scope, `aggregate-signals.bats` dla
   state snapshot z `unclaimed_change`/`bypass_mutation`, oraz stage hook test
   tylko jeśli dojdzie nowy matcher w `.codex/hooks.json`.
5. **Rerun RealHarness tylko dla `03` i `12`.** Pierwotny cel był taki, żeby
   `03` przeszło bez mutacji `src/notes/random.md`. Finalnie po rerunie
   przyjmujemy residual QA note zamiast dalszego zaostrzania Bash hooka. `12`
   traktujemy jako semantycznie OK w tym cyklu, a szerszą korektę
   language-invariant matching zostawiamy w osobnym intake
   `.sage/work/20260510-language-invariant-workflow-matching-fix/`.

### Closeout Resolution

Po ostatnim default/implicit RealHarness rerunie nie zaostrzamy już
`PreToolUse[Bash]` w tym cyklu. Rerun pokazał, że agent potrafi obfuskować
ścieżkę w shellu, ale budowa mocniejszego parsera albo ogólnego policy engine
dla `Bash` byłaby poza akceptowanym zakresem. Cluster B zostaje przygotowany do
zamknięcia z tą uwagą:

- deterministyczne testy i audit/release rubryki łapią `unclaimed_change` /
  `bypass_mutation`;
- dalsze "nie szukaj obejścia, tylko wykonaj korektę wskazaną przez hook"
  należy do recovery-first guidance z klastra A;
- scenario `12` zostaje przekazane do inicjatywy language-invariant matching,
  bo problemem jest językowo krucha rubryka, nie kontrakt `[F]`.

Closeout zatwierdzony: cykl oznaczony jako `status: completed`,
`phase: completed`.

### Boundary

Ten addendum nie otwiera dużego systemu policy engine dla shell commands. Jeśli
naprawa zacznie wymagać parsera bash, TTL/heartbeat locków albo semantycznego
LLM-classifiera w hooku, zatrzymujemy się i wracamy do checkpointu.

## Ryzyka

- **Za dużo tekstu w AGENTS.md.** Stage 3 ma compactness test poniżej 11KB.
  Wording musi być krótki.
- **Lease lock może wyglądać prosto, ale puchnąć.** Jeśli zacznie wymagać TTL,
  heartbeat albo takeover protocol, odcinamy go z tego patcha.
- **Hook nie wymusi agent retry samodzielnie.** Dlatego patch rozdziela hook
  message contract, generated agent contract i harness transcript/state rubric.
- **Poniżej Standard+ można przeregulować.** Plan celowo zachowuje możliwość
  zwykłej Lightweight/Surgical zmiany bez `.sage`.
- **Riski path guard.** Implementacja będzie zmieniać testy i hooki, więc przed
  `deliver` manifest musi dostać `semantic_reclassification: accepted`.

## Rollback

Zmiany są tekstowe i hook/testowe. Revert patcha przywraca poprzedni kontrakt
workflow entry/recovery/autonomy i usuwa prosty `active_session_id` enforcement.
