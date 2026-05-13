---
cycle_id: "20260510-mutation-intent-preflight-gap"
title: "Plan: Batch 2 mutation preflight i hook recovery"
workflow: fix
phase: fix-scope-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
classification: systemic
---

# Plan: Batch 2 mutation preflight i hook recovery

## Cel

Zrobic z Batcha 2 jeden spojny kontrakt:

> Przed pierwsza mutacja agent sprawdza mutation intent: tool surface, typ
> mutacji, aktywny cykl, scope, threshold workflow, closeout state i recovery
> path. Hooki nadal twardo blokuja nielegalne zapisy, ale normalna praca ma
> prowadzic agenta zanim odbije sie od hooka.

To jest **Systemic fix**, bo dotyka instrukcji runtime, hook predicate, testow i
real-harness scenariuszy.

## Zmiany w plikach

### `core/constitution/sage-process.constitution.md`

- Dodac krotka zasade "Mutation preflight before write" do Rule 0.
- Doprecyzowac, ze scope reduction po hook block jest legalne tylko, gdy agent
  jawnie stwierdza, ze zablokowany plik nie jest potrzebny do celu. Jesli plik
  jest potrzebny, nastepny ruch to escalation/review, nie amputacja zakresu.
- Dopisac kontrakt binarnych assetow: tekst przez `apply_patch`; binarki przez
  jawny, audytowalny binary mutation path, tylko w zatwierdzonym scope.

### `core/capabilities/orchestration/sage-navigator/SKILL.md`

- W sekcji state transition/hook recovery dodac praktyczna sekwencje preflight:
  `active cycle -> scope -> file count -> threshold -> closeout state -> tool
  path`.
- Dopisac regule po hook block: retry legal path albo zatrzymaj sie dla
  wskazanej decyzji; nie koncz z niepelna poprawka i nie wyrzucaj wymaganego
  pliku z zakresu tylko po to, zeby zostac Surgical.

### `runtime/platforms/codex/setup/lib/agents-md.sh`

- Przeniesc ten sam skondensowany kontrakt do generowanego `AGENTS.md`.
- Zachowac bardzo lakoniczna forme: tylko kilka punktow kontraktu, bez
  poradnika, przykladow i teorii. `AGENTS.md` ma przypominac zasade, a nie
  uczyc mechaniki hookow.
- Zachowac kompaktowosc pliku, bo istnieje test limitu rozmiaru.
- Dodac jasne rozroznienie:
  - text mutation -> `apply_patch`;
  - binary asset mutation -> jawny binary mutation path;
  - unknown/compound shell write -> stop albo plan/scope update.

### `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`

- Dodac asercje, ze generowany `AGENTS.md` zawiera:
  - mutation preflight przed write;
  - zakaz scope amputation dla wymaganego pliku;
  - legalna sciezke binary asset mutation poza `apply_patch`.

### `runtime/platforms/codex/hooks/pre-tool-validate.sh`

- Ulepszyc komunikaty blokujace, bez rozluzniania safety:
  - no active cycle/out-of-scope/Moderate+ block maja mowic o preflight i
    konkretnej recovery/escalation path;
  - Moderate+ block ma jawnie mowic, ze usuniecie potrzebnego trzeciego pliku z
    zakresu nie jest legalnym obejsciem.
- Dodac waska sciezke dla binarnych assetow poza `apply_patch`:
  - tylko dla prostych `Bash` operacji z jawna intencja, np.
    `SAGE_BINARY_MUTATION=1`;
  - tylko dla operacji na parsowalnych, dokladnych sciezkach bez globow i bez
    redirection magic;
  - tylko gdy sciezki sa w aktywnym, zatwierdzonym `manifest.scope`;
  - zapisac taka mutacje do `.sage/.session-mutations.log` jak inne legalne
    mutacje.
- Nie dodawac szerokiego parsera shell. Nieparsowalne albo zlozone komendy maja
  nadal fail-closed z instrukcja uzycia `apply_patch`, helpera/generatora albo
  plan/scope update.

### `runtime/platforms/codex/hooks/lib/active_init.sh`

- Scope expansion odkryty przez real harness scenariusz 2: minimalny manifest
  moze zawierac placeholder `active_session_id: "current"`.
- Znormalizowac placeholdery `current`/`unknown`/`TODO` jak brak locka sesji,
  zeby agent mogl naprawic manifest albo kontynuowac legalna sciezka.
- Zachowac twarda blokade dla prawdziwego obcego `active_session_id`, np.
  `other-session`.

### `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`

- Test-first:
  - block message dla trzeciego pliku zawiera escalation i zakaz amputacji
    wymaganego scope;
  - binary mutation bez jawnej intencji jest blokowana;
  - binary mutation z jawna intencja i sciezka w scope przechodzi i loguje
    mutation;
  - binary mutation z path poza scope jest blokowana;
  - zlozony shell/glob/redirection binary path jest blokowany fail-closed.
  - `scope.writable` w formie inline YAML array dopuszcza dokladne sciezki
    typu `AGENTS.md`.
  - placeholder `active_session_id: "current"` nie blokuje cyklu jak obca
    sesja, ale prawdziwy mismatch nadal blokuje.

### `runtime/platforms/codex/harness/v11-scenarios.json`

- Dodac dwa release-blocker scenariusze:
  - `13-mutation-preflight-lightweight`: lekkie zadanie ma pokazac preflight
    przed pierwsza mutacja i nie moze prowadzic do serii hook bounce'ow.
  - `14-hook-block-scope-amputation`: agent po bloku trzeciego potrzebnego
    pliku ma eskalowac do Moderate+/scope gate albo zapytac, zamiast konczyc
    niepelny fix.
- Rubryki maja byc state-based tam, gdzie sie da: forbidden changed patterns,
  forbidden audit kinds i required transcript patterns.

### `runtime/platforms/codex/harness/prompts/13-mutation-preflight-lightweight.txt`

- Nowy prompt real-agent dla lekkiej mutacji, zaprojektowany tak, zeby poprawne
  zachowanie bylo widoczne w transcripcie: agent najpierw nazywa preflight i
  legalna sciezke, potem dopiero ewentualnie tworzy minimalny formalny ksztalt
  albo zatrzymuje sie dla user gate.

### `runtime/platforms/codex/harness/prompts/14-hook-block-scope-amputation.txt`

- Nowy prompt real-agent dla failure mode "dwa pliki zmienione, trzeci jest
  wymagany". Oczekiwane zachowanie: escalation/plan/scope gate, nie final answer
  z niepelna poprawka.

### `runtime/platforms/codex/harness/tests/aggregate-signals.bats`

- Rozszerzyc synthetic transcript/state helpers o scenariusze 13 i 14.
- Dodac test, ze scenariusz 14 failuje, gdy transcript sugeruje skip/defer
  wymaganego pliku zamiast escalation.
- Dodac test, ze scenariusz 13 failuje, gdy transcript nie zawiera preflight
  albo gdy pojawia sie forbidden audit kind.
- Nie robic z 13 tylko "transcript contains preflight". Bez scope expansion do
  parsera kolejnosci aggregate ma laczyc broad transcript patterns z forbidden
  audit/changed state i real transcript review evidence dla kolejnosci
  "preflight przed pierwsza mutacja".

### Sibling intake manifests

Po zweryfikowanej implementacji, jako bookkeeping-only:

- `.sage/work/20260509-file-change-enforcement-fix/manifest.md`
- `.sage/work/20260509-binary-asset-mutation-contract-fix/manifest.md`
- `.sage/work/20260512-hook-recovery-scope-amputation-fix/manifest.md`
- `.sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md`
- `.sage/work/20260509-blocking-hook-guidance-review/manifest.md`

oznaczyc jako skonsumowane przez anchor cycle
`20260510-mutation-intent-preflight-gap`, bez ukrytej implementacji w tych
cyklach.

## Testy i verification

Minimalny deterministic verification przed real harness:

```bash
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
jq -e . runtime/platforms/codex/harness/v11-scenarios.json >/dev/null
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/setup/lib/agents-md.sh
git diff --check
```

Real-agent verification:

```bash
runtime/platforms/codex/harness/run-harness.sh
```

Completion blocker: cykl nie moze przejsc do `completed`, jesli real harness
nie ma aktualnego evidence dla nowych release-blocker scenariuszy 13 i 14 oraz
nie zachowuje pass dla scenariuszy 03 i 04.

## Ryzyka

- Parsowanie Bash jest latwe do przeszacowania. Dlatego binary mutation path ma
  byc waski i fail-closed.
- Binary mutation implementation ma uzyc malego allowlistu prostych ksztaltow
  komend. Nie dodawac szerokiego parsera shell; compound syntax, globy,
  redirection i niejednoznaczne sciezki maja zostac zablokowane.
- Dodatkowe required transcript patterns moga byc kruche jezykowo. Uzyc kilku
  wariantow PL/EN i laczyc je z state assertions.
- Generowany `AGENTS.md` ma limit rozmiaru w testach; kontrakt musi byc zwiezly.
- Alex jawnie poprosil, zeby czesc w `AGENTS.md` byla lakoniczna, wiec jesli
  trzeba gdzies dopisac wiecej kontekstu, ma trafic do workflow/skilla albo
  planu, nie do generowanego `AGENTS.md`.
- Nie mozna przypadkiem cofnac Batcha 1: entry/resume/state transition zostaje
  bez zmian poza doprecyzowaniem preflight.

## Rollback

- Revert zmian w `pre-tool-validate.sh` i odpowiadajacych testow przywroci
  dotychczasowy fail-closed model Bash.
- Revert zmian w `v11-scenarios.json` i promptach usuwa nowe release blockers,
  ale zostawia istniejace 03/04.
- Guidance w constitution/navigator/generated AGENTS moze byc cofniety osobno,
  bo nie zmienia runtime behavior bez hook/harness zmian.

## Scope guard

Nie implementowac poza lista w manifest `scope:`. Jesli w trakcie wyjdzie, ze
trzeba zmienic `post-tool-check.sh`, `turn-audit.sh`, log parser albo
`run-harness.sh`, zatrzymac sie i poprosic o scope expansion.

Scope expansion 2026-05-13: real harness scenariusz 2 pokazal, ze potrzebna
jest mala zmiana w `runtime/platforms/codex/hooks/lib/active_init.sh`, bo
`cycle_active_session_id` jest wspolnym miejscem interpretacji placeholderow
sesji. Bez tego poprawka w `pre-tool-validate.sh` musialaby duplikowac logike
ownership locka.
