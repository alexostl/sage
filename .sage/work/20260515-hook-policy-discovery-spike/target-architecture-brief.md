---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: target-architecture
status: approved
created: 2026-05-15
owner: codex
source: "Run 01, Run 02, first Minimization Path fix"
approval_required: false
approved_by: alexostl
approved_at: 2026-05-15
---

# Target Architecture Brief: Hook Policy Layer

## Purpose

Ten brief opisuje docelowy kierunek hooków po Milestone 0.2. Nie jest jeszcze
pełnym implementation planem ani zgodą na szeroki rewrite `pre-tool-validate.sh`.
Ma ustalić, jaki stan chcemy osiągnąć przez kolejne małe, mierzalne kroki.

Zasada nadrzędna: `Minimization Path`. Hooki mają być najmniejszą konieczną
warstwą bezpieczeństwa, nie głównym systemem prowadzenia workflow.

## Status After Milestone 0.2

Po Milestone 0.2 hooki są w stanie hybrydowym:

- hard enforcement nadal działa dla source/runtime/test/instruction mutation;
- `17-local-gitignored-config-artifact` ma pierwszy narrow allow:
  `.sage-local/**` ignorowane przez Git przechodzi bez `.sage/work` manifestu;
- RealHarness mierzy teraz cross-repo capture, completed-cycle reopen i local
  gitignored artifact;
- policy split istnieje jako kierunek, ale nie jest jeszcze pełnym runtime
  modułem;
- `pre-tool-validate.sh` nadal jest monolityczny i za długi (`predicate_loc`
  powyżej historycznego ceilingu), więc kolejne zmiany muszą być małe.

## Target Policy Outcomes

Docelowo hook powinien zwracać jedną z pięciu klas decyzji:

| Outcome | Meaning | Blocking? | Owner |
| --- | --- | --- | --- |
| `block` | Mutacja jest niebezpieczna bez workflow/scope. | yes | hook |
| `allow` | Mutacja jest jednoznacznie lokalna albo bezpieczna. | no | hook |
| `capture` | Zapisuje parked intake/docs/state w owning repo. | no, if scoped | capture router + hook |
| `recover` | Operacja jest potencjalnie legalna, ale wymaga mechanicznej ścieżki recovery. | usually yes | hook + workflow |
| `audit` | Operacja jest dozwolona, ale warto zostawić sygnał do kalibracji. | no | audit layer |

To nie oznacza dużej abstrakcji od razu. Najpierw można osiągnąć ten model przez
małe helpery i wspólną terminologię w komunikatach.

## Safety Boundary

Te klasy mają zostać hard-protected bez explicit workflow/scope approval:

- `src/**`
- `runtime/**`
- `tests/**`
- `bin/**`
- `.codex/**`
- `.agents/**`
- `AGENTS.md`, `CLAUDE.md`
- generated instruction/config surfaces
- `.sage/work/**` implementation-active mutations poza owning cycle
- secrets/auth/key-like local files

`Minimization Path` nie może oznaczać “więcej wolno wszędzie”. Ma oznaczać:
więcej wolno tylko tam, gdzie dane pokazują, że ryzyko jest lokalne i małe.

## First Proven Policy: Local Ignored Artifact

Wdrożony stan:

- `.sage-local/**` może przejść tylko jeśli Git faktycznie ignoruje ścieżkę;
- helper działa przed cycle resolution, więc nie dziedziczy unrelated active
  cycle;
- secret-like filenames są blokowane;
- mixed managed/source/runtime/test paths nadal blokują;
- RealHarness `17` i guard `03+17` przechodzą.

Residual:

- `claim_no_op` dla ignorowanych plików nadal istnieje jako audit noise.
  To jest osobny mały kandydat, nie blocker pierwszego fixu.

## Candidate Milestones

### Milestone 0.3: Audit Noise Calibration

Goal: local-only ignored artifact nie powinien emitować mylącego `claim_no_op`,
jeśli hook jawnie dopuścił go jako `local_ignored_artifact`.

Scope:

- dostroić `turn-audit.sh` albo session mutation log handling;
- nie ruszać cross-repo ani completed-cycle logic;
- RealHarness `17` powinien przejść bez `.sage/work` bloatu i bez mylącego warn.

Why next: to jest najmniejsza kontynuacja pierwszego fixu i domyka usability
tego samego przypadku.

### Milestone 0.4: Capture Ownership Calibration

Goal: capture-only `.sage/work` w owning repo ma być legalne bez mylenia z
implementation mutation.

Scope:

- doprecyzować target repo ownership;
- zachować blokadę source/runtime/test w obcych repo;
- nie uogólniać cross-repo writes.

Evidence:

- Run 01 `07`, `11`;
- Run 02 `15`;
- intake `20260515-cross-repo-sagedocs-permission-fix` jako osobny sygnał, ale
  nie mieszać go automatycznie z tym cyklem bez decyzji.

### Milestone 0.5: Completed-Cycle Recovery Model

Goal: completed-cycle protection zostaje hard by default, ale explicit user
reopen ma jasną mechaniczną ścieżkę.

Possible target:

- wrapper recovery jako domyślna legalna ścieżka;
- direct minimal reopen tylko jeśli manifest zapisuje reopen evidence w
  frontmatter i nie rozszerza scope bez decyzji.

Evidence:

- live block przy wznowieniu starego Milestone 0;
- Run 02 `16`.

### Milestone 1: Extract Policy Helpers

Goal: jeśli małe helpery zaczną rosnąć, wydzielić policy predicates z
`pre-tool-validate.sh` do małych, testowanych helperów.

Stop condition:

- jeśli zmiana wymaga szerokiego rewrite bez nowego evidence, zatrzymać się.

## Recommended Next Move

Nie zamykałbym jeszcze całego hook architecture work jako “done”. Po pierwszym
fixie mamy sensowny checkpoint i jasny następny najmniejszy krok:

1. Zamknąć i ewentualnie commitować dotychczasowy Milestone 0.2 + first fix.
2. Następnie uruchomić Milestone 0.3 jako mały follow-up:
   `claim_no_op` audit noise dla ignored local-only artifacts.

## Decision

Alex zaakceptował brief jako kierunek docelowej architektury hook policy layer.
To nie jest zgoda na szeroki rewrite. Następny legalny ruch to domknąć i
ewentualnie commitować Milestone 0.2 + pierwszy fix, a potem uruchomić osobny
mały follow-up dla `0.3 Audit Noise Calibration`, jeśli nadal uznamy go za
najlepszy następny krok.

Zamknięcie tego etapu ma zachować zasadę `Minimization Path`: hooki zostają
włączone, hard enforcement pozostaje dla source/runtime/test/instruction
surfaces, a jedyny wdrożony carve-out dotyczy wąskiego przypadku
`.sage-local/**` faktycznie ignorowanego przez Git.
