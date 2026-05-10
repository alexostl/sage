# Decision: `sage-selfhost` może mieć agresywniejsze enforcement defaulty niż upstream

## Context

Sage rozwija się w trzech gałęziach z różnym ryzykiem operacyjnym:

- `selfhost` — gałąź user-owned na której pracuje wąskie grono
  developerów rozumiejących Sage methodology głęboko. Tu eksperymenty
  i agresywne enforcement są **akceptowalne** (i pożądane — to lab).
- `codex-port/*` — gałąź port-owa adresowana do szerszego user base
  używającego Codex jako platformy. Default behavior musi być
  konserwatywny — surprise hook activation w cudzych projektach jest
  niedopuszczalny.
- `main` (upstream `alexostl/sage`) — public framework. Defaulty muszą
  być najbardziej ostrożne, kompatybilne z dowolnym setupem.

Bez explicit branch-policy decision, każdy fix do enforcement może
omyłkowo wyciec na upstream z self-host preferencjami (co już raz miało
miejsce — patrz cross-repo correction memory).

## Decision

**Per-branch defaulty dla generatora Codex template:**

| Klucz | selfhost | codex-port | main (upstream) |
|---|---|---|---|
| `[features].codex_hooks` w generowanym `.codex/config.toml` | `true` | `false` | `false` |
| Direct skills domyślnie deployowane | `true` | `true` | `true` |
| Direct skills `policy.allow_implicit_invocation: false` (per-skill `agents/openai.yaml`) | `true` | `true` | `true` |
| Description prefix `[lib]` dla direct skilli | `true` | `true` | `true` |
| `core.hooksPath` auto-set przy `sage init` (gdy puste) | `.githooks` | `.githooks` | `.githooks` |
| `--force-githooks` CLI flag dostępny | tak | tak | tak |

**Note:** `deploy_direct_skills: true`, `allow_implicit_invocation: false`
i `[lib]` prefix nie są self-host-specific — to nowe defaulty everywhere
po rewizji ADR-4 v3 (2026-04-29). Self-host od upstream różni się
obecnie **tylko aktywacją hooków Codex** (`codex_hooks: true`).

**Co NIE jest w tym cyklu (zgodnie z ADR-4 v3):**
- `name: zz-sage-<X>` rename — deferred do osobnego cyklu po empirical
  pomiarze visual palette clutter. Behavior izoluje
  `allow_implicit_invocation`; wizualne sortowanie to osobna decyzja.

**Mechanizm branch detection:**

Generator wykrywa "self-host profile" przez obecność pliku
**`.sage/profile`** w **framework root** (NIE w project root) z
zawartością YAML:

```yaml
profile: self-host
```

Bez pliku LUB z `profile: upstream` → upstream-friendly defaults.
To zapobiega przypadkowemu wyciekowi self-host defaultów do user-side
projektów inicjowanych z upstream framework.

**Framework root** = katalog z `bin/sage`, `runtime/`, `sage/skills/`
(tj. checkout sage-selfhost / sage-codex / sage). Project root =
katalog gdzie user wywołał `sage init/update` (consumer project).
Generator wczytuje profile z framework root (lokalizacja `bin/sage`
sama w sobie), nie z project root — chroni przed false-positive gdy
user przypadkowo dodaje plik do swojego projektu.

**Resolution chain (handle symlinks, brew, npm-global):**

```bash
# bin/sage start of file
SAGE_BIN_PATH="$0"
# Resolve symlinks (alex-os-dev case: ~/.local/bin/sage -> ~/Developer/sage-selfhost/bin/sage)
if command -v readlink >/dev/null 2>&1; then
  if readlink -f / >/dev/null 2>&1; then
    SAGE_BIN_RESOLVED=$(readlink -f "$SAGE_BIN_PATH")
  else
    # BSD readlink (macOS): use Python or while-loop fallback
    SAGE_BIN_RESOLVED=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$SAGE_BIN_PATH" 2>/dev/null \
      || while [ -L "$SAGE_BIN_PATH" ]; do SAGE_BIN_PATH=$(readlink "$SAGE_BIN_PATH"); done; echo "$SAGE_BIN_PATH")
  fi
fi
FRAMEWORK_ROOT=$(dirname "$(dirname "$SAGE_BIN_RESOLVED")")

# Validate that this looks like a framework checkout
if [ ! -d "$FRAMEWORK_ROOT/runtime" ] || [ ! -d "$FRAMEWORK_ROOT/sage/skills" ]; then
  # Brew/npm-global install: bin/sage points to /opt/homebrew/bin/sage symlink
  # to the actual framework checkout. If validation fails, framework root
  # cannot be determined → fallback to upstream profile (safest default).
  echo "WARN: framework root validation failed at $FRAMEWORK_ROOT — using upstream profile" >&2
  PROFILE="upstream"
else
  # Read .sage/profile from validated framework root
  if [ -f "$FRAMEWORK_ROOT/.sage/profile" ]; then
    PROFILE=$(grep '^profile:' "$FRAMEWORK_ROOT/.sage/profile" | awk '{print $2}')
  fi
  PROFILE="${PROFILE:-upstream}"
fi
```

**Edge cases:**
- *Brew/npm-global install:* `bin/sage` jest typically symlink do faktycznego
  checkout. `readlink -f` znajduje real path. Jeśli faktyczny binary jest
  packaged (no `runtime/`, `sage/skills/` siblings), validation failuje →
  fallback do upstream profile (safe default).
- *Relative `$0`:* `readlink -f` (lub Python `realpath`) absolutizuje path.
- *Worktree:* git worktree shares `.git/` ale ma własny working tree —
  `bin/sage` tam NIE istnieje (worktree to consumer project). Resolution
  chain z user invocation `sage <cmd>` znajduje binary z `$PATH`, nie z
  worktree.
- *macOS BSD readlink (no `-f`):* fallback do Python `os.path.realpath` lub
  while-loop manual resolution. `bin/sage` musi container detection w
  bashu portable (no GNU-only flags).

**`sage status` musi printować resolved framework root** dla transparency:

```
$ sage status
Framework root:  /Users/alexostl/Developer/sage-selfhost
Profile:         self-host (.sage/profile present)
...
```

User widzi gdzie generator się resolve'uje, łatwiej diagnozować
"my profile leak" issues.

**Naming rationale:** `.sage/profile` (nie `.sage/.self-host-profile`):
- Dotfile-w-dotfolder (`/.sage/.foo`) jest skipowany przez niektóre
  tooling (rsync, find bez `-name '.*'`).
- YAML format extensibility — później może mieć `features: [...]`,
  `aggressive: true` etc. bez rename pliku.

**Recovery paths (explicit, udokumentowane w runbook):**

1. *"Mam fork sage-selfhost ale chcę upstream defaults"* — w fork
   frameworku: `echo 'profile: upstream' > .sage/profile` lub po prostu
   `rm .sage/profile`.
2. *"Klonowałem sage upstream ale chcę self-host defaults w swoim
   forku"* — w fork frameworku: `mkdir -p .sage && echo 'profile:
   self-host' > .sage/profile`.
3. *"`.sage/profile` z markerem self-host wyciekł na main przez
   bad merge"* — usuń plik z `main` branch, dodaj do `.gitignore`
   tej brancha. PR review SOP wymienia ten check explicit.

**False-positive containment:**

Jeśli user **klonuje sage-selfhost as their framework copy** (zamiast
sage-codex / sage), marker travels — i to jest correct behavior. User
operuje self-host frameworkiem, więc dostaje self-host defaults. Nie
jest to bug — to design intent. Documentation w `runtime/platforms/codex/README.md`
musi być explicit że sage-selfhost ≠ sage-codex jako consumer framework.

**Branch policy enforcement (procesowo):**

- Każdy PR z `selfhost` → `codex-port` lub `main` musi explicit
  zaznaczyć w opisie czy zmienia template defaulty. Reviewer sprawdza
  `.sage/profile` guard.
- Self-host-only zmiany NIE muszą być portowane.
- Upstream-friendly zmiany muszą być portowalne (no self-host-only
  syntax/struktura).

## Alternatives considered

**Alt A — Single default everywhere.** Plus: prosty kontrakt. Minus:
albo upstream dostaje agresywne defaulty (cross-user surprise), albo
self-host nie dostaje benefitu z agresywnych defaultów (cel kontraktu
sprzed cyklu nieosiągnięty).

**Alt B — Per-project config przez `--profile self-host` flag.** Plus:
explicit per-invocation. Minus: user musi pamiętać flagę; default
zachowanie zostaje konserwatywne więc benefit "zero-config" w self-host
znika.

## Consequences

### Positive

- Self-host realizuje promise "85-90% compliance" ASAP bez ryzyka dla
  upstream users.
- Upstream pozostaje konserwatywny, kompatybilny z legacy projektami.
- Branch-policy explicit, reviewer ma checklistę.

### Risk: branch contamination

Jeśli ktoś w przyszłości zmerguje `selfhost` → `main` bez
filtrowania self-host-only zmian, defaulty wyciekną na upstream.

Mitygacja:
- Plik `.sage/profile` jest gitignored w branchu który go nie potrzebuje
  (więc nie wycieka mechanicznie przez merge). Marker checked at
  framework root, nie project root.
- Generator profile detection ma test fixture sprawdzający że bez markeru
  defaulty są upstream-friendly.
- Reviewer SOP w `CONTRIBUTING.md` wymienia explicit check `.sage/profile`
  presence przy każdym PR `selfhost → codex-port` lub `→ main`.
- Recovery paths (patrz Decision section) udokumentowane w
  `runtime/platforms/codex/README.md`.

### Anti-patterns to avoid

- Hardcodowanie `codex_hooks = true` jako globalnego defaultu w
  generatorze "bo działa w self-host".
- Zakładanie że self-host = każdy `alex-os-dev` style projekt (to są
  oddzielne repos, oddzielne defaulty).
- Forward-merging self-host defaultów na upstream "bo i tak są lepsze"
  bez explicit branch review.
