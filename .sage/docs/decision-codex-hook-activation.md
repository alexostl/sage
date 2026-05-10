# Decision: Codex hook activation via single key (`[features].codex_hooks`)

## Context

Po dwóch cyklach remediation Codex enforcement compliance osiąga ~45-55%
(audit `.sage/docs/analysis-codex-enforcement-surface-audit.md`). Sufit
text-only stacku to ~75-80%; aby przekroczyć go, potrzebujemy żeby
hooki Codex (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`) były
**realnie wpięte**, nie tylko obecne na dysku.

Stan przed decyzją (trzy oddzielne stany myleone z jednym):

1. `runtime/platforms/codex/hooks/*.sh` istnieją w frameworku.
2. `[features].codex_hooks = true` w `.codex/config.toml` (Codex runtime
   "ma czytać hooks.json").
3. `.codex/hooks.json` faktycznie wymienia framework entries (hook
   wpięty w sesji).

Stan (1) i (2) były obecne w `alex-os-dev`, ale (3) nie — `.codex/hooks.json`
miał tylko custom `SessionStart`. Skutek: agent zachowuje się jakby hooków
nie było, mimo że kontrakt update-u sugeruje że są.

## Decision

`[features].codex_hooks = true` w `.codex/config.toml` jest **jedynym
sygnałem aktywacji**. Gdy `sage update` lub `sage init` wykryje ten klucz:

1. Kopiuje `runtime/platforms/codex/hooks/*.sh` → `<projekt>/.codex/hooks/`
   (idempotentnie; identyczne pliki = no-op).
2. Merguje framework entries do `<projekt>/.codex/hooks.json`:
   - `UserPromptSubmit` → `pre-prompt.sh`
   - `PreToolUse` (Bash) → `pre-bash.sh`
   - `PostToolUse` (Bash) → `post-bash.sh`
   - `SessionStart` → `session-start.sh` (jeśli framework go dostarcza
     i nie ma user override)
3. **Merge logic, nie overwrite.** Custom user entries (np. własny
   `SessionStart` jak w `alex-os-dev`) zostają. Framework entries są
   dodawane jako kolejny element w array dla danego eventu (jeśli
   Codex hook spec to wspiera) lub appendowane do istniejącej listy.
4. Gdy `codex_hooks = false` lub brak — `sage update` nic nie ruszy
   w `.codex/hooks/` i `.codex/hooks.json`. Tylko diagnostyka w
   `sage status`.
5. **Atomic backup przed merge.** Przed nadpisaniem `hooks.json`
   merge zapisuje kopię `.codex/hooks.json.sage-bak.<ISO-timestamp>`.
   Recovery path udokumentowany w spec failure modes table.

### Identity rule for framework entries (deterministic idempotency)

Bez deterministycznej reguły "is this entry framework's?" idempotentność
jest aspirational — kolejny `sage update` doda duplikat. Reguła:

**Framework entry = `command` field zaczyna się od `.codex/hooks/`** AND
nazwa pliku po prefixie matchuje znanej liście framework hooków
(`pre-prompt.sh`, `pre-bash.sh`, `post-bash.sh`, `session-start.sh`).

```jsonc
// Framework entry — recognized by path prefix
{ "command": ".codex/hooks/pre-prompt.sh" }

// User entry — not recognized as framework
{ "command": "scripts/verify-wiring.sh" }
{ "command": "/usr/local/bin/custom-hook" }
```

Merge algorithm:
1. Dla każdego framework eventu (UserPromptSubmit, PreToolUse, PostToolUse,
   SessionStart):
   a. Znajdź wszystkie entries w array dla tego eventu.
   b. Filtruj: czy istnieje już framework entry (path prefix `.codex/hooks/` +
      known filename) AND content of `.codex/hooks/<filename>.sh` matchuje
      sha256 znanej framework version (current OR historical hashes)?
      - Jeśli **tak (current hash)** → no-op (idempotent re-run).
      - Jeśli **tak (historical hash)** → replace tylko ten entry, zostaw
        user entries. Update file content do current version.
      - Jeśli **path matchuje, ale hash NIE matchuje żadnej framework version**
        → **shadowed file detected**. NIE replace. Surface as
        `MISCONFIGURED` w `sage status`:
        ```
        L4 MISCONFIGURED — file .codex/hooks/pre-prompt.sh exists at
        framework path but content is unknown (sha256: <user hash>).
        Either:
          - Rename your custom hook to non-framework filename:
              mv .codex/hooks/pre-prompt.sh .codex/hooks/custom-pre-prompt.sh
          - Or run: sage update --force-codex-hooks (overwrites your file)
        ```
      - Jeśli **path NIE istnieje** → append framework entry do array,
        copy framework `*.sh` content to disk.
2. **Nigdy nie usuwa user entries** — filtr pracuje tylko na entries
   matchujących identity rule.
3. **Nigdy nie nadpisuje shadowed file bez explicit `--force-codex-hooks`**
   — chroni przed przypadkową utratą user content w pliku o framework
   filename.

**Known framework hashes** są utrzymywane w
`runtime/platforms/codex/hooks/.versions.txt`:
```
pre-prompt.sh@v1: sha256:abc123...
pre-prompt.sh@v2: sha256:def456...  (current)
pre-bash.sh@v1: sha256:...
...
```

To daje: deterministyczna idempotentność (run N razy = identyczny disk),
zero metadata polution (brak `_sage: true` JSON keys), preservation user
entries (path-prefix match nie złapie `scripts/`, `/usr/local/`, etc.),
**shadowed file containment** (user `pre-prompt.sh` o własnej logice
NIE zostanie cicho nadpisany).

Brak osobnego klucza `deploy_codex_hooks: true` w `.sage/config.yaml`.

## Alternatives considered

**Alternatywa A — Osobny klucz w `.sage/config.yaml`** (option 1B z briefu).
Plus: ortogonalna kontrola (Codex runtime ON, ale Sage hooks OFF).
Minus: dwa klucze do utrzymania, wyższy cognitive load, większy contract
surface area. Odrzucone — granularność nie jest realnym use-case'em
(jeśli ktoś chce Codex hooki ale nie chce Sage hooków, może je
manualnie usunąć z `.codex/hooks.json` po `sage update` — to edge case).

**Alternatywa B — Zostać przy obecnym kontrakcie** (sage update kopiuje
tylko AGENTS.md + skille, hooki manual). Plus: zero ryzyka surprise.
Minus: utrzymuje contract mismatch który był początkową motywacją tego
cyklu. Odrzucone.

## Consequences

### Positive

- Mental model: jeden klucz, jeden efekt. `codex_hooks = true` znaczy
  "wszystko wpięte"; `false` znaczy "nic nie ruszone".
- Idempotentność: `sage update` można odpalić wielokrotnie.
- Status reportable: `sage status` może deterministycznie odpowiedzieć
  "L4 (Codex hooks) ACTIVE / DORMANT / DISABLED".

### Breaking change (uznany)

Projekty które miały `codex_hooks = true` ale celowo nie chciały Sage
framework hooków (mają własne) zobaczą zmianę po następnym `sage update`:
framework entries zostaną wmergowane do ich `hooks.json`.

Mitygacja:
- Merge-not-overwrite: ich custom entries pozostają nietknięte.
- Manual unwire: usunąć framework entries z `hooks.json` lub ustawić
  `codex_hooks = false`.
- Migration note w changelog + `AGENTS.md` blurb.

**Cross-repo discipline:** sage-selfhost NIE odpala `sage update` w
`alex-os-dev` ani w innych external repos jako część tego cyklu (cross-repo
correction memory). User decyduje per-repo czy i kiedy to robi.

### Ongoing responsibility

- Generator merge logic musi mieć testy regresji (custom user entry
  zachowany, framework entry dodany, idempotentne re-run).
- Codex hook spec ewolucja: jeśli Codex zmieni format `hooks.json`
  (np. wymusi unique events), merge logic wymaga aktualizacji.

### Anti-patterns to avoid

- Cicha aktywacja przez sam fakt obecności pliku `*.sh` (bez `codex_hooks
  = true`) — config.toml MUSI być explicit signal.
- Overwrite `.codex/hooks.json` w całości — zawsze merge.
- Dodawanie kolejnych aktywacyjnych kluczy "dla pewności" — jeden klucz,
  jedno znaczenie.
