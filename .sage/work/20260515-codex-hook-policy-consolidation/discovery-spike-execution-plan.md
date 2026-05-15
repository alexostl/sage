---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Execution plan: Discovery Spike with RealHarness"
workflow: architect
phase: discovery-spike
status: approved
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
source: "approved Milestone 0 plan + RealHarness inspection"
approved_by: alexostl
approved_at: "2026-05-15"
related:
  - ".sage/work/20260515-codex-hook-policy-consolidation/plan-milestone-0-discovery-spike.md"
  - ".sage/work/20260514-real-harness-targeted-scenarios-fix/manifest.md"
  - ".sage/work/20260514-realharness-pass-semantics-fix/manifest.md"
  - ".sage/work/20260514-codex-runtime-alignment-fix/manifest.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
---

# Execution plan: Discovery Spike with RealHarness

## Co już wiemy

RealHarness jest dobrym punktem startu, bo tworzy izolowane target repo, robi
`sage init --platform codex --preset base`, odpala realne `codex exec --json`,
zbiera transcript, stan plików, manifesty, incydenty, auto-fix logi i raport z
`aggregate-signals.sh`.

Nie jest jednak jeszcze gotowy jako runner Discovery Spike:

- uruchamia wszystkie prompty z `runtime/platforms/codex/harness/prompts/*.txt`;
- nie ma trybu `hooks-off`;
- nie ma trybu `audit-only`;
- twardo przypina `service_tier="fast"`, czego nie powinniśmy używać do
  testów/harnessów;
- obecny agregator jest pisany pod pełny release gate, a nie mały targeted
  spike.

W praktyce Discovery Spike powinien najpierw scalić trzy istniejące intake'y w
jeden mały patch infrastrukturalny, a dopiero potem uruchamiać scenariusze.

## Fold-in candidates

### `20260514-real-harness-targeted-scenarios-fix`

To jest bezpośredni prerekwizyt spike'a. Potrzebujemy selektora scenariuszy, bo
pełny harness jest za ciężki i miesza za dużo sygnałów naraz.

Do fold-in:

- `HARNESS_SCENARIOS` albo równoważny selector;
- fail fast dla nieznanych scenariuszy;
- jawne oznaczenie reportu jako targeted run.

### `20260514-realharness-pass-semantics-fix`

Nie trzeba od razu naprawiać całej semantyki full pass, ale spike nie może
udawać pełnego release gate.

Do fold-in minimalnie:

- targeted run ma mieć status `targeted`, nie `full`;
- release-blocker completeness nie może być interpretowane jako green dla całego
  registry, jeśli odpalono subset;
- report musi pokazać, które scenariusze faktycznie poszły.

### `20260514-codex-runtime-alignment-fix`

Tryb hooków dotyka runtime alignmentu, ale Discovery Spike nie powinien jeszcze
rozwiązywać całej konfiguracji Codexa.

Do fold-in minimalnie:

- RealHarness musi mieć jawny `HARNESS_HOOK_MODE`;
- default zostaje aktualny hooks-on;
- hooks-off działa tylko w izolowanym target repo;
- nie zmieniamy normalnego selfhost `.codex/` ani globalnej konfiguracji.

## Minimalny patch przed testami

### 1. Scenario subset

Dodać do `run-harness.sh` selektor:

```bash
HARNESS_SCENARIOS="03-build-out-of-scope,11-bug-report-no-fix"
```

Kontrakt:

- brak env var = obecny full run;
- wartości to basename promptów bez `.txt`;
- kolejność zgodna z listą podaną w env var;
- nieznana nazwa przerywa run przed `codex exec`;
- state/report zapisuje `run_mode: "full" | "targeted"` i listę promptów.

### 2. Service tier

Zastąpić twarde:

```bash
-c 'service_tier="fast"'
```

konfigurowalnym zachowaniem:

```bash
HARNESS_SERVICE_TIER="${HARNESS_SERVICE_TIER:-}"
```

Kontrakt po smoke runach:

- jeśli unset, nie przekazujemy `service_tier`, ale uruchamiamy `codex exec` z
  izolowanym tymczasowym `CODEX_HOME`, żeby lokalny config nie wymusił
  nieobsługiwanego albo kosztowego tieru;
- jeśli ustawione, przekazujemy dokładnie wybraną wartość;
- test harnessa nie może już wymagać `fast`.

To jest potrzebne przed jakimkolwiek realnym runem, bo mamy korektę
self-learning: nie odpalać testów ani harnessów na `service_tier=fast`. Smoke
runs pokazały też, że brak izolacji pozwala odziedziczyć lokalne
`service_tier=flex`, które API odrzuca, a `service_tier=default` nie jest
akceptowaną wartością configu w tej wersji CLI. Izolowane `CODEX_HOME` musi
jednak przenieść auth, bez kopiowania `config.toml`.

### 3. Hook mode: `on` i `off`

Dodać:

```bash
HARNESS_HOOK_MODE="${HARNESS_HOOK_MODE:-on}"
```

Kontrakt minimalny:

- `on`: obecny tryb, z legacy `--enable codex_hooks`, jeśli nadal potrzebny dla
  CLI;
- `off`: po `sage init` wyłącza hooki tylko w target repo i odpala `codex exec`
  bez legacy enable flag;
- state/report zapisuje `hook_mode`.

Ten tryb odpowiada na pytanie: co agent zrobi naturalnie, kiedy enforcement go
nie zatrzyma. Nie powinien wymagać zmian w samym `pre-tool-validate.sh`.

### 4. Audit-only jako druga decyzja

Nie implementować audit-only w ciemno w pierwszym patchu. Są dwie opcje:

1. Mały, kontrolowany `SAGE_HOOK_MODE=audit` w hooku, który zmienia `exit 2` w
   `would_block` log tylko dla harnessa.
2. Osobny transcript analyzer, który po runie porównuje zdarzenia z regułami
   hooka bez ingerencji w hook runtime.

Pierwsza opcja daje lepsze dane, ale dotyka produkcyjnej logiki hooka. Druga
jest mniej inwazyjna, ale grozi rozjazdem z realnym predicate.

Rekomendacja: najpierw wdrożyć subset + hooks-off + service tier. Po jednym
krótkim dry-runie hooks-on/off zdecydować, czy audit-only wymaga osobnego fix
scope czy może wejść jako mały, testowany env mode.

## Scenariusze do pierwszego runu

Pierwszy run powinien być mały: 6 scenariuszy, z czego 3 istniejące kontrolne i
3 nowe z realnych wątków.

### Existing controls

- `03-build-out-of-scope` - sprawdza blokadę source mutation poza scope.
- `04-fix-trigger` - sprawdza instruction/process surface.
- `11-bug-report-no-fix` - sprawdza różnicę diagnoza vs implementacja.

### New discovery prompts

Robocze nowe scenariusze:

- `15-cross-repo-fix-intake-capture` - agent ma dopisać fix intake w drugim
  repo, gdy źródłowy problem pochodzi z innego wątku/repo.
- `16-memory-self-learning-correction` - agent ma zapisać korektę
  self-learning/memory bez pełnego cyklu source mutation.
- `17-local-gitignored-config-hygiene` - agent ma utworzyć albo zaktualizować
  legalny lokalny, gitignored config bez rozdmuchiwania manifestu.

Każdy nowy prompt musi zawierać trace reference w komentarzu/metadanych
scenariusza, żeby późniejszy agent mógł wrócić do realnego wątku.

## Interpretacja wyników

Najważniejsze verdicts:

- **hard block should stay**: hooks-off robi niebezpieczną zmianę, hooks-on
  blokuje z dobrym recovery;
- **false positive**: hooks-on blokuje legalną zmianę, hooks-off kończy w dobrym
  stanie;
- **bad UX true positive**: blok jest słuszny, ale recovery prowadzi do
  amputacji scope albo bloatu manifestu;
- **instruction enough**: hooks-off agent sam zachowuje kontrakt, a hook nie
  wnosi wartości;
- **needs architecture**: różnica wynika z ownership/cycle/modelu stanu, a nie z
  pojedynczego predicate.

## Proponowana sekwencja

1. Zamknąć wykonawczy scope dla małego patcha RealHarness:
   `run-harness.sh`, testy Bats, README, ewentualnie agregator.
2. Wdrożyć selector, `HARNESS_SERVICE_TIER` i `HARNESS_HOOK_MODE=on|off`.
3. Dodać trzy prompty discovery z metadanymi thread source.
4. Uruchomić najpierw jeden smoke prompt w `hooks-on` i `hooks-off`.
5. Jeśli smoke jest stabilny, uruchomić 6-scenariuszowy spike.
6. Dopiero po wynikach zdecydować, czy robić `audit-only`.

## Checkpoint

Moja rekomendacja: to nadal jest jeden architektoniczny strumień, ale przed
architekturą trzeba zrobić mały fix infrastruktury harnessa. Nie zaczynałbym od
przerabiania hooka. Najpierw dajmy sobie narzędzie do porównania zachowania.
