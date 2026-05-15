---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Brief: Codex hook policy consolidation"
workflow: architect
phase: elicitation
status: draft
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
source: "conversation + subagent reviews + hook fix backlog"
related:
  - ".sage/work/20260515-codex-hook-policy-consolidation/manifest.md"
  - ".sage/work/20260514-codex-runtime-alignment-fix/manifest.md"
  - ".sage/work/20260514-surgical-wording-hook-threshold-fix/manifest.md"
  - ".sage/work/20260514-source-mutating-cycle-concurrency-fix/manifest.md"
  - ".sage/work/20260514-multi-cycle-attribution-fix/manifest.md"
  - ".sage/work/20260514-framework-log-schema-observability-fix/manifest.md"
---

# Brief: Codex hook policy consolidation

## Round 1 - Vision

Codex/Sage hooki mają przestać być zbiorem kolejnych wyjątków dopisywanych do
`pre-tool-validate.sh`, a stać się czytelnym kontraktem: agent, użytkownik i
testy mają rozumieć, dlaczego dana mutacja jest dozwolona, blokowana,
audytowana albo wymaga recovery.

Problem nie polega już na jednym błędnym predicate. Ostatnie wątki i fixy
pokazały kilka powtarzalnych klas awarii:

- legalny workflow bookkeeping po approval potrafił wyglądać dla hooka jak
  same-turn self-approval;
- małe zmiany wordingowe albo configowe potrafiły generować nadmiar manifestów;
- cross-repo `.sage/work` capture z repo A do repo B nie ma jasnego target-repo
  modelu;
- memory/self-learning CRUD jest traktowany jak zwykła mutacja pliku albo Bash,
  więc korekty pamięci wpadają w procesowy labirynt;
- aktywne cykle i multi-cycle mutations nie mają jednego prostego ownership
  modelu;
- logi i recovery messages nie niosą jeszcze stabilnych `reason_code`, które
  można traktować jako publiczny kontrakt.

Docelowo chcemy mechanicznej macierzy decyzji, nie "sprytnego" klasyfikatora:

`tool + op + path_category + cycle_state + approval_evidence -> allow/block/audit/autofix + recovery_message`

Sukces oznacza, że przyszłe hook-fixy będą implementować decyzje z tej
macierzy, zamiast lokalnie dopisywać kolejne regexy i wyjątki.

## Round 2 - Constraints

### Twarde granice

- Nie osłabiać ochrony dla `runtime`, hooków, security, MCP, generated output,
  source/test/instruction changes ani configów wysokiego ryzyka.
- Nie robić dużego parsera semantycznego ani MCP v2 jako pierwszego kroku.
- Nie mieszać tego cyklu z `20260514-doc-lifecycle-bookkeeping-architecture`.
  Tamten cykl dotyczy lifecycle/decisions/bookkeeping; ten dotyczy polityki
  hooków i ownership mutacji.
- Nie budować kolejnego "mini workflow". Alex odrzucił ten kierunek w wątku
  `019e2874`.
- Nie traktować `gitignored` jako "zawsze wolno". Gitignored local artifacts
  mogą być legalne, ale managed surfaces pozostają chronione.
- Nie traktować cross-repo writes jako ogólnej zgody na mutację innych repo.
  Legalny może być tylko jawnie wskazany, wąski target, np. `.sage/work`
  capture/docs w drugim Sage repo.

### Kierunki techniczne

- Preferowana forma to mała warstwa `decision matrix` / taxonomy w hook runtime.
- Naturalne komponenty do zaprojektowania:
  - event parser: normalizacja `Bash`, `apply_patch`, `Edit`, `Write`,
    `file_change`;
  - path taxonomy: kategorie ścieżek i ich ryzyko;
  - cycle resolver: path-owned cycle, active cycle, parked capture, completed,
    bootstrap, ambiguous, source-mutating owner;
  - approval evidence: same-turn, prior-turn, canonical plan,
    `implementation_approval`;
  - policy matrix: czysta decyzja bez efektów ubocznych;
  - recovery messages: reason/message codes zamiast długich inline printf;
  - audit/log schema: spójne `mutation_kind`, `reason_code`, `target_repo`.
- Pierwszy implementacyjny milestone powinien raczej wyciągać taxonomy/matrix
  bez zmiany zachowania. Dopiero później naprawiać osobne klasy problemów.

### Evidence inputs

Zamknięte fixy pokazują, że pojedyncze naprawy działają, ale rośnie liczba
wyjątków:

- `20260514-same-turn-deliver-approval-guard-fix`
- `20260514-completed-cycle-bookkeeping-reconciliation-fix`
- `20260514-selfhost-sage-update-pass`
- `20260511-surgical-config-workflow-threshold-fix`
- `20260513-lightweight-repo-hygiene-decisions-fix`
- `20260509-closeout-documentation-mutation-model`
- `20260509-mutation-enforcement-target-safety-fix`

Otwarte intake'y wskazują na wspólne jądro architektoniczne:

- `20260514-codex-runtime-alignment-fix`
- `20260514-surgical-wording-hook-threshold-fix`
- `20260514-source-mutating-cycle-concurrency-fix`
- `20260514-multi-cycle-attribution-fix`
- `20260514-framework-log-schema-observability-fix`
- `20260510-codex-worktree-support-build`

Nowy wątek `019e2874` dodaje klasę `memory CRUD / self-learning correction`:
hook formalnie zadziałał poprawnie, ale recovery path nie był odpowiedni dla
usunięcia błędnego learningu i doprowadził do próby ręcznego `sqlite3`.

## Round 3 - Gaps

### Decyzje do podjęcia w designie

1. Czy `source-mutating ownership` jest per repo, per branch, per worktree, czy
   per workspace path?
2. Jaka jest minimalna oficjalna lista `path_category` i `mutation_kind`?
3. Które istniejące wyjątki są docelowym kontraktem, a które tylko długiem
   historycznym do refactoru?
4. Czy safe auto-fix może nadal mutować manifest z poziomu `PreToolUse`, czy
   ma zostać przeniesiony do osobnej, jawnej recovery ścieżki?
5. Jak traktować `.sage-memory` i narzędzia SageMemory/SageWiki: jako pliki,
   jako memory CRUD, czy jako osobną kategorię operacji?
6. Jak testować recovery UX: pełny tekst, `reason_code`, czy oba?
7. Które otwarte intake'y foldować pod architect plan, a które zostawić jako
   osobne implementacyjne follow-upy?

### Wstępna hipoteza

Najmniejszy sensowny design to:

- nie przepisywać całych hooków;
- najpierw zaprojektować kontrakt i decision matrix;
- potem zrobić milestone 1 jako behavior-preserving extraction;
- potem osobne, małe milestones dla:
  - cross-repo `.sage` capture/docs;
  - memory CRUD / learning correction recovery;
  - source-mutating cycle ownership;
  - surgical wording threshold;
  - log schema / reason codes.

### Ryzyka

- Zbyt szeroki redesign może zatrzymać praktyczne naprawy hooków.
- Zbyt wąskie fixy będą dalej powiększać `pre-tool-validate.sh` i koszt
  rozumienia systemu.
- Jeśli taxonomy będzie zbyt inteligentna albo zbyt zależna od intencji
  modelu, hooki stracą przewidywalność.
- Jeśli taxonomy będzie zbyt mechaniczna, legalne przypadki nadal będą wpadały
  w blokady bez dobrego recovery.

## Brief Checkpoint

Proponowany workflow: kontynuować w `/sage:architect`.

Korekta z 2026-05-15: przed `spec.md` robimy **Milestone 0 Discovery Spike**.
Najpierw testy porównawcze, potem architektura.

Discovery Spike ma sprawdzić realne zachowanie agentów w kontrolowanych
wariantach:

- hooks-on: obecne twarde enforcement;
- hooks-off: naturalne zachowanie agenta bez blokad;
- audit-only: hooki logują `would_block`, ale nie blokują.

Następny artefakt po akceptacji briefu: `plan-milestone-0-discovery-spike.md`
z listą scenariuszy, trybów uruchomienia, metryk i stop conditions. Dopiero po
wynikach Discovery Spike powstanie `spec.md` z decision matrix, ownership
modelem i decyzją, które intake'y są inputs/folded/split.
