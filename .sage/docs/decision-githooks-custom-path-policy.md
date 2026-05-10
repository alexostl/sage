# Decision: Custom `core.hooksPath` policy — warning + opt-in unblock

## Context

`bin/sage` `ensure_hooks_wired()` aktywuje L5 (git pre-commit gate
sprawdzający verification.md przed commitem dla Moderate+ initiatives)
przez:

1. Skopiowanie `.githooks/pre-commit` z frameworka.
2. `git config core.hooksPath .githooks` — **tylko gdy** obecna wartość
   jest pusta lub już `.githooks`.

Gdy `core.hooksPath` jest custom (`alex-os-dev` ma `.git/hooks`, inne
projekty mogą mieć Husky / lefthook / pre-commit framework), Sage
celowo **nie nadpisuje** tej wartości — szanuje cudzy ekosystem. Skutek:
plik `.githooks/pre-commit` istnieje, ale L5 nigdy nie strzela.

Brief otwiera pytanie: czy zostawić to po cichu (warning only), czy
zaproponować mechanizm aktywacji.

## Decision

**Hybrid 3a + 3c. Default = informacyjny warning. Explicit opt-in
unblock przez CLI flag.**

### Component 1: Diagnostic warning (default behavior)

`sage status` raportuje L5 stan jako jeden z trzech:

- `L5 ACTIVE` — `core.hooksPath = .githooks` AND `.githooks/pre-commit`
  istnieje AND wykonywalny.
- `L5 NOT INITIALIZED` — `core.hooksPath` puste AND brak `.githooks/`.
  Sugestia: `sage init`.
- `L5 DORMANT (custom hooks path)` — `core.hooksPath = <custom>` (cokolwiek
  innego niż `.githooks`). Output:
  ```
  L5 DORMANT — git hooks path is set to <custom_path>.
  Sage pre-commit (.githooks/pre-commit) exists but does NOT fire.
  To activate L5 (DESTRUCTIVE — overrides current config):
    sage init --force-githooks
  Or merge manually: copy .githooks/pre-commit into <custom_path>/.
  ```

`sage update` printuje to samo jako notice (nie jako error/exit).

### Component 2: `sage init --force-githooks` (explicit unblock)

Nowa flaga dla `sage init`:

- Bez flagi: `sage init` zachowuje obecne zachowanie (skip gdy custom path).
- Z flagą: `sage init --force-githooks` wymusza:
  1. `git config --unset core.hooksPath` (jeśli ustawione na cokolwiek
     innego niż `.githooks`).
  2. `git config core.hooksPath .githooks`.
  3. Kopiuje `.githooks/pre-commit`.
  4. Printuje co zmieniło się + co zostało nadpisane.

User explicit przejmuje odpowiedzialność za zniszczenie cudzego
hookpath setupu. Friction by design.

**Bezpiecznik:** Jeśli flaga jest podana ale obecny custom path zawiera
hooks innych frameworków, Sage wykrywa i pyta:

**Detection heuristics (rozszerzona lista):**

| Framework | Detection signal |
|---|---|
| Husky | `.husky/` directory exists OR `node_modules/husky/` exists |
| lefthook | `lefthook.yml` OR `lefthook.yaml` exists (oba extensions) |
| pre-commit framework | `.pre-commit-config.yaml` exists |
| simple-git-hooks | `package.json` zawiera `"simple-git-hooks":` field |
| Custom scripts | Żaden z powyższych, ale `<custom_path>` zawiera executable hooki (case `alex-os-dev` z plain `.git/hooks` overlay) |

**Procedura:**

1. Wykryj framework (jeśli jakikolwiek match).
2. **Zawsze** `ls <custom_path>` i pokaż faktyczną zawartość:
   ```
   Custom hooks path: .git/hooks
   Detected framework: Custom scripts (no recognized framework)
   Files in path:
     - pre-commit (executable)
     - prepare-commit-msg (executable)
   ```
   Daje user informed consent — widzi co konkretnie zostanie odłączone,
   nawet gdy framework guess to "Custom" albo "None".
3. Pyta: "This will deactivate <framework or 'these custom scripts'>. Continue? [y/N]".
4. Bez confirm = abort, exit code 1.

**Rationale rozszerzonej detection:** Pierwotna lista (Husky/lefthook/pre-commit)
miała false-negatives dla `simple-git-hooks` (popularny w Node.js
ecosystem) i dla case `alex-os-dev` gdzie `core.hooksPath = .git/hooks`
ma plain custom scripts bez frameworka. `ls`-fallback gwarantuje że
user nigdy nie traci hooków bez zobaczenia ich nazw.

## Alternatives considered

**Alt 3b — Sage instaluje pre-commit jako wrapper w custom path.** Plus:
coexistence z Husky/lefthook bez friction. Minus: per-runner adaptery
(każdy framework ma inny układ) + ryzyko zepsucia custom hooków przez
buggy wrapper. Out of scope tego cyklu — trzymamy jako future option
w `.sage/docs/runbooks/` jeśli okaże się że many users używa Husky
i nie chce migrować.

**Alt 3a only (warning, brak unblock CLI).** Plus: zero ryzyka. Minus:
self-host promise "85-90% compliance" wymaga że L5 DA SIĘ aktywować
prosto. User musiałby manualnie git config + skopiować plik.

**Alt 3c only (default = override custom).** Plus: maksymalna aktywacja
L5. Minus: cross-repo correction memory — Sage NIE ma prawa
nadpisywać cudzego setupu bez consent. Niedopuszczalne.

## Consequences

### Positive

- Świeży `git init` + `sage init` → L5 aktywny automatycznie (bez zmian
  w obecnym `ensure_hooks_wired()`).
- Custom path projekty → user widzi explicit warning, ma jeden command
  do unblocku.
- Husky/lefthook detection chroni przed accidental wymazaniem.

### Failure mode: user nie czyta warning

User pomija "L5 DORMANT" w `sage status` output, mysli że L5 działa,
robi commit bez verification.md → commit przechodzi (bo gate nie strzela).

Mitygacja:
- `sage status` pokazuje L5 stan blisko góry outputu.
- `sage update` printuje notice z kolorem yellow gdy L5 DORMANT.
- Future: `sage doctor` (osobny cykl) raportujący wszystkie inactive
  enforcement.

### Edge case: worktree-specific hooksPath

`git config core.hooksPath` jest per-worktree by default (już
udokumentowane w `bin/sage` komentarzu). `--force-githooks` ustawia
config w aktualnej worktree. Inne worktree z tego samego repo mogą
mieć inny stan. Status output musi być honest o tej granularności.

### Anti-patterns to avoid

- Default-overriding custom path bez explicit user action.
- Cichy fallback (np. "ustaw `.githooks` i licz że user się domyśli").
- Skomplikowany merge wrapper (alt 3b) bez konkretnego pull-request use case.
