# Agent A4 — Codex CLI/doctor/profiles feasibility (4 ADRs)

Recenzent: zewnętrzny subagent feasibility (oś ADR ↔ Codex docs).
Data: 2026-04-30. Zakres: CLI surface, doctor/status, profiles,
public surface (skills/plugins/palette).

## Sources fetched

1. https://developers.openai.com/codex — entry, mapa podstron.
2. https://developers.openai.com/codex/cli/reference — global flags,
   subcommands.
3. https://developers.openai.com/codex/cli/slash-commands — built-in
   slash commands.
4. https://developers.openai.com/codex/cli/features — session-control,
   `/status` semantics.
5. https://developers.openai.com/codex/config-reference — `[profiles.*]`,
   trust levels, approval/sandbox.
6. https://developers.openai.com/codex/skills — progressive disclosure,
   `policy.allow_implicit_invocation`, `[[skills.config]]`.
7. https://developers.openai.com/codex/plugins — plugin = bundle
   (skills + apps + MCP servers).

7/7 WebFetch budget zużyty.

## Verdict summary

| ADR | Verdict | Główne ryzyko |
|-----|---------|---------------|
| decision-codex-doctor-and-status | **GREEN with caveats** | Naming kolizja `sage status` vs natywny Codex `/status`; brak sprzężenia z Codex `--profile` w D1 |
| decision-codex-enforcement-profiles | **GREEN** | Mapowanie `fast-trusted` / `strict` → realne klucze `[profiles.*]` jeszcze nie zlokowane (spec.md) |
| decision-codex-public-workflows-internal-library | **YELLOW** | "`.agents/skills` jako product contract" zakłada hierarchię discovery, ale ADR myli pojęcia plugin vs skill — wymaga doprecyzowania |
| decision-codex-narrow-palette-honest-framing | **GREEN with empirical gate** | Ścieżka `agents/openai.yaml` per-skill potwierdzona w docs; pilot test obowiązkowy (bug #14161 sub-agent override) |

Ogólnie: 4 ADRy są **technicznie wykonalne** w Codex 0.126 — żaden
nie wymaga API którego Codex nie udostępnia. Główne otwarte pytania
dotyczą **nazewnictwa** (kolizja z natywnym `/status`) oraz
**precyzji pojęciowej** (skill vs plugin).

## Findings (per ADR)

### ADR — `sage doctor` + `sage status` scope

**Co docs potwierdzają:**

- Codex **NIE** ma wbudowanego `codex doctor` ani
  `codex diagnose` jako subcommandu CLI. CLI reference wymienia
  tylko: `codex`, `codex exec/e`, `codex resume`, `codex fork`,
  `codex apply/a`, `codex login/logout`, `codex app`, `codex cloud`,
  `codex mcp`, `codex features`, `codex completion`. Cytat z
  reference: brak `doctor`, brak `diagnose`, brak `health-check`.
- Codex **MA** wbudowany **slash command `/status`** w sesji TUI:
  cytat z slash-commands docs — *"`/status` – Display session
  configuration and token usage"*. To jest **in-session command**,
  nie subcommand CLI. Sage planuje `bin/sage status` (subcommand
  CLI poza sesją Codex) — **dwie różne powierzchnie**, nie kolidują
  technicznie.
- Codex **MA** też `/init` (generuje AGENTS.md scaffold), `/model`,
  `/permissions`, `/plan`, `/diff`, `/compact`, `/agent`. Brak
  `/doctor`, `/help`, `/version` w spisie.

**Konsekwencje dla ADR:**

1. **Naming kolizja: `sage status` ↔ `/status` natywne.** ADR D1
   dobrze definiuje że `bin/sage status` jest CLI poza sesją Codex,
   ale junior dev pisząc "status" pomyśli o natywnym `/status` (token
   usage + session config). Rekomendacja recenzenta: spec.md powinno
   explicit pokazać tabelę różnic — `/status` (natywny, in-session,
   token/model) vs `bin/sage status` (Sage, CLI, project state). To
   nie blocker, to UX risk.
2. **`sage doctor` jest cleanly w przestrzeni Sage** — nie ma
   konfliktu z Codex bo Codex nie ma swojego `doctor`. Cytat z CLI
   features docs: *"The page does not mention a dedicated 'doctor',
   'diagnose', or 'health-check' command in Codex."* — wolna nisza.
3. **D1 check #2 (Profile)** czyta `~/.codex/config.toml` ze
   `approval_policy` + sandbox state. Docs config-reference
   potwierdzają że to są realne klucze pod `[profiles.<name>]`
   (cytat: *"approval_policy, sandbox_mode, web_search,
   model_instructions_file"*). **Wykonalne.**
4. **D1 check #4 (Trust state)** czyta
   `[projects."<abs>"].trust_level`. Docs potwierdzają: *"Trust
   levels control whether project-scoped configurations load. Set
   via projects.<path>.trust_level as 'trusted' or 'untrusted'."*
   **Wykonalne.**
5. **D1 check #6 (MCP reachable)** — `codex mcp` jest realnym
   subcommandem (CLI reference). Sage MCP server może być
   sprawdzony niezależnie przez transport. **Wykonalne.**
6. **D2.5 (platform routing)** — detekcja przez markery
   `<repo>/.codex/config.toml` jest natywna i niezawodna (Codex
   sam czyta ten plik per config-reference).

**Ostrzeżenie nieblokujące:**

- D1 nie wspomina o **aktywnym profilu** w outputcie statusu.
  Skoro Codex `--profile <name>` jest pierwszorzędnym
  mechanizmem konfiguracyjnym (potwierdzone w reference: *"--profile,
  -p (string): Configuration profile name to load"*), `sage status`
  powinno surfaceować nazwę aktywnego profilu i jego zmapowane
  guarantee-level (z ADR enforcement-profiles). Linijka header w
  D1 mówi `profile: fast-trusted` ale nie wyjaśnia jak Sage to
  detektuje (profile "fast-trusted" to **Sage'owa abstrakcja**, nie
  natywna nazwa Codex profile). Spec.md musi określić mapping:
  jak Sage identyfikuje aktywny natywny `[profiles.X]` Codex i
  klasyfikuje go jako `fast-trusted` vs `strict`.

**Verdict: GREEN with caveats.** Wszystkie checki D1/D2 są
implementowalne na bazie istniejących Codex surfaces.

---

### ADR — Codex enforcement profiles

**Co docs potwierdzają:**

- Codex **MA** koncept profile jako pełnoprawny:
  `[profiles.<name>]` w `config.toml`. Cytat z config-reference:
  *"Profiles are defined in config.toml under the
  [profiles.<name>] section. Each profile can override any
  supported configuration key."*
- Switching: trzy ścieżki — (1) `--profile <name>` flag, (2)
  default w config (`profile = "<name>"`), (3) env var
  niepotwierdzony.
- Profile-scoped overrides obejmują: `model`, `service_tier`,
  `personality`, `approval_policy`, `sandbox_mode`,
  `web_search`, `model_instructions_file`, `model_catalog_json`.

**Konsekwencje dla ADR:**

1. **`fast-trusted` i `strict` jako Sage labels są spójne z
   architekturą Codex.** Codex sam nie definiuje tych nazw —
   to Sage'owe etykiety **klasyfikujące** kombinacje
   `approval_policy` + `sandbox_mode`. Mapping (rekomendowany do
   spec.md):
   - `strict` → `approval_policy = "on-request"` lub `"untrusted"`,
     `sandbox_mode = "read-only"` lub `"workspace-write"`
   - `fast-trusted` → `approval_policy = "never"`,
     `sandbox_mode = "danger-full-access"` (Skip Permissions)
2. **ADR poprawnie odróżnia "blocked by sandbox" od "redirected by
   Sage guardrail".** Docs config-reference potwierdzają że
   sandbox jest egzekwowany przez Codex runtime; Sage hooks
   (`PreToolUse`) są **dodatkową warstwą**, nie zastępczą. ADR
   honoruje to rozróżnienie — to jest poprawna semantyka.
3. **`--dangerously-bypass-approvals-and-sandbox, --yolo`** istnieje
   jako globalna flaga. Spec.md powinno dodać check w `sage doctor`
   wykrywający tę flagę w shell history / aliasach (informacyjnie),
   bo pod nią nawet `strict` profile traci OS-level enforcement.

**Verdict: GREEN.** ADR poprawnie odzwierciedla rzeczywistość
docs — Codex daje narzędzia, ale nie gwarantuje hard-enforcement w
trybie pełnego dostępu. ADR honestly framing pasuje 1:1 do tego co
docs mówią o `danger-full-access`.

---

### ADR — Public workflow skills and internal Sage library

**Co docs potwierdzają:**

- Skills są discoverowane z hierarchii: `.agents/skills` (repo,
  workspace), `~/.agents/skills` (user), `/etc/codex/skills`
  (admin), bundled. Cytat skills docs.
- Progressive disclosure: *"Codex starts with each skill's name,
  description, and file path. Codex loads the full SKILL.md
  instructions only when it decides to use a skill."* — skill list
  ~2% kontekstu.
- ADR mówi że Codex docs nie dają "hidden but native" flagi —
  **częściowo prawda** w sensie strict-hide-from-palette, ale
  `policy.allow_implicit_invocation: false` (z drugiego ADR i
  potwierdzone w skills docs) blokuje auto-suggest. To jest
  najbliższy "hidden" mechanizm — ADR nie wymienia go w kontekście
  tego ADR-u, choć drugi ADR (narrow-palette) go używa.

**Konsekwencje dla ADR:**

1. **Pomieszanie skill vs plugin.** ADR mówi o "60 Sage skills"
   widocznych w palecie. Per docs plugins:
   *"Plugins bundle skills, app integrations, and MCP servers into
   reusable workflows for Codex. A plugin can contain: Skills:
   reusable instructions for specific kinds of work."* — Sage może
   też być **plugin**, który **bundle** skille (workflow + library)
   w jeden produkt. ADR nie rozważa tej opcji wcale.
   - **Recenzent rekomenduje:** spec.md powinno zaadresować
     pytanie "Czy Sage jest plugin (jeden bundle) czy zbiór luźnych
     skilli?". Plugin może mieć cleaner UX (jedna jednostka
     instalacji) i być może własną palette-curation.
2. **".agents/skills jako product contract"** — to dobra
   formulacja, ale ADR nie precyzuje czy chodzi o `<repo>/.agents/skills`
   czy `~/.agents/skills`. To ma znaczenie: workflow skille jako
   "product contract" prawdopodobnie powinny być **per-projekt**
   (`<repo>/.agents/skills`), żeby nie zaśmiecać user-global.
   Library skille (lazy-loaded) mogą być w innej lokalizacji —
   poza hierarchią discovery Codex (np. `sage/skills/` w repo)
   żeby je nie discovery-fire'owało wcale.
3. **"Workflow-library drift caught before runtime"** — to wymaga
   manifestu z hashami plus walidacji. Docs nie dają tego
   nativnie; Sage musi to zbudować (referenced in ADR-4
   shared-skill-manifest, poza scope tego ADR-u).

**Verdict: YELLOW.** ADR ma poprawną intencję, ale:
- pomija wątek plugin (potencjalnie cleaner ścieżka),
- nie precyzuje lokalizacji w hierarchii Codex discovery,
- duplikuje logikę narrow-palette ADR-u nie odwołując się do
  niej (oba ADRy mówią o palecie z różnych kątów).

Spec.md powinien rozstrzygnąć: czy direct skille są pod
`<repo>/.agents/skills/` z `allow_implicit_invocation: false`
(jak narrow-palette ADR), czy poza hierarchią discovery (jak
ten ADR sugeruje "internal library, lazy-loaded by manifest").
**Te dwa podejścia są niespójne**.

---

### ADR — Narrow palette honest framing

**Co docs potwierdzają (1:1 z wersją v3 ADR-u):**

- Mechanizmy 1 i 2 z ADR-u są **dokładnie tym co dokumentuje
  docs**:
  - `enabled = false` w `[[skills.config]]` — unloaduje skill,
    przekreśla `$invocation`. Cytat skills docs: *"Users can also
    disable skills via [[skills.config]] in ~/.codex/config.toml
    by setting enabled = false."*
  - `policy.allow_implicit_invocation: false` w
    `agents/openai.yaml` — skill loadable, brak auto-suggest,
    explicit `$<name>` działa. Cytat skills docs: *"When set to
    false, Codex won't implicitly invoke the skill based on user
    prompt; explicit $skill invocation still works."* — **dosłownie
    co ADR cytuje**.
- ADR poprawnie identyfikuje że `allow_implicit_invocation: false`
  **nie ukrywa z palety** — docs mówią o blokowaniu *implicit
  invocation*, nie o display.

**Caveats potwierdzone:**

1. **Bug #14161 (sub-agent TOML overrides ignored)** — ADR
   adresuje to świadomie z pilot gate (test (e)). Recenzent nie
   ma niezależnej weryfikacji bugu (nie pobierał GitHub issues),
   ale mechanizm `agents/openai.yaml` jest **per-skill plik**, nie
   `[[skills.config]]` per-agent override. To są różne code paths
   per ADR — to jest **prawdopodobnie poprawna analiza**, ale
   pilot test obowiązkowy.
2. **Forward compat z `zz-sage-` rename** — ADR poprawnie defer'uje
   visual axis. Docs nie dają lepszego mechanizmu palette-hide; jeśli
   Codex doda `palette_visible: false`, ADR ma czysty path do
   adopcji.

**Drobiazg do spec.md:**

- **Single source of truth** dla description — ADR mówi
  `agents/openai.yaml`'s `interface.short_description` jest
  generated 1:1 z `SKILL.md` `description`. Docs nie wymieniają
  jaki dokładnie jest precedence gdy oba pola istnieją i się
  różnią. **Recenzent nie znalazł w docs definitive answer.**
  Pilot test powinien zweryfikować empirycznie który field Codex
  pokazuje w palecie (`SKILL.md.description` czy
  `interface.short_description`?). Jeśli `interface.short_description`
  ma precedence — bit-identical kopia jest niezbędna, jak ADR
  zakłada. Jeśli `SKILL.md.description` — yaml jest redundantny
  dla display, służy tylko `policy`.

**Verdict: GREEN with empirical gate.** ADR jest najbardziej
RTFM-grounded z czwórki. Pilot test jest właściwy; nie ma pretense
że teoria działa bez dowodu. Single empirical risk: precedence
fields, łatwo testowalne w piloci.

## Cross-cutting

### 1. Naming hygiene — kolizja z natywnymi Codex commands

Sage używa `bin/sage status` (CLI) i `bin/sage doctor` (CLI). Codex
ma natywny `/status` (in-session slash command). To są **różne
powierzchnie** technicznie, ale junior dev tego nie rozróżni z
nazwy. Spec.md powinien:

- Tabelę: kiedy używać `/status` (token usage, session config)
  vs `bin/sage status` (project state, MCP, hooks).
- Rozważyć czy `bin/sage status` nie powinno być `bin/sage info`
  albo `bin/sage state` żeby uniknąć kolizji nazewniczej. To jest
  decyzja nieblokująca, do empirycznej walidacji.

### 2. Profile mapping — Sage labels → Codex `[profiles.*]`

ADR enforcement-profiles definiuje `fast-trusted` i `strict` jako
Sage abstrakcje. ADR doctor-and-status header pokazuje
`profile: fast-trusted` w outputcie. Brakuje deterministycznego
mappingu jak Sage z natywnego `[profiles.X]` Codex wnioskuje
"to jest fast-trusted" vs "to jest strict". Rekomendacja do
spec.md:

```
fast-trusted ⇔ approval_policy ∈ {"never"} OR
              sandbox_mode = "danger-full-access" OR
              --yolo flag detected

strict       ⇔ approval_policy ∈ {"on-request","untrusted"} AND
              sandbox_mode ∈ {"read-only","workspace-write"}

unknown      ⇔ żadnego z powyższych
```

Ten mapping jest **policy decision**, nie wymóg docs — ale ADR
profiles bez niego jest wisi.

### 3. Plugin question — pominięta strategiczna alternatywa

Żaden z 4 ADRów nie rozważa Sage jako Codex **plugin**. Docs
plugins potwierdzają że plugin = bundle (skills + apps + MCP
servers). Sage ma dokładnie te trzy elementy (skills + MCP server
+ hooks-as-app-integration). **Plugin path mogłaby:**

- Dać Sage'owi **jednostkę dystrybucji** (jeden plugin) zamiast
  60 luźnych skilli.
- Możliwe natywne palette-curation per plugin (docs nie potwierdzają
  ani nie przekreślają — wymaga RTFM jeszcze głębiej w docs/plugins
  lub `codex plugins` subcommand jeśli istnieje; reference go nie
  wymienia).
- Cleaner uninstall path.

To **nie jest blocker** dla 4 obecnych ADRów, ale recenzent
sygnalizuje że plugin angle jest **niedoeksplorowany** w research
base. Warto dorzucić jednorazowy WebFetch na docs/plugins do spec.md
research extension.

### 4. Doctor `--codex-version-changed` ↔ Codex CLI version surface

ADR D3 zakłada `codex --version` jako mechanizm detekcji wersji.
Docs CLI reference **nie wymieniają** jawnie `--version` ani
`--help` w spisie globalnych flag. Recenzent **zakłada** że istnieją
jako konwencja CLI (każde sane CLI ma `--version`), ale spec.md
powinien zweryfikować empirycznie (jeden `codex --version` w
shell). Jeśli nie istnieje, alternatywą jest parsowanie outputu
`codex` interaktywnego TUI lub package metadata (npm/brew). To
**low risk**, ale formalnie nie potwierdzone w docs.

### 5. `codex features` subcommand — niewykorzystana surface

Reference wymienia `codex features` (*"List feature flags and
persistently enable or disable them"*). Żaden z 4 ADRów go nie
używa. Może być relevantne dla:

- ADR-5 H3 check (`[features].codex_hooks = true`) — może lepiej
  czytać przez `codex features list` niż TOML parsing? Bezpośrednie
  TOML parsing jest robust niezależnie, ale `codex features` to
  natywny surface który Sage może audit'ować. Niska priorytet, do
  spec.md jako rozważanie.

### 6. Slash command `/init` — natywny scaffold AGENTS.md

Codex ma natywny `/init` generujący AGENTS.md. Sage `bin/sage init`
robi to samo dla swojej części. Po raz kolejny kolizja nazewnicza
(slash command vs CLI subcommand) — nie blocker, ale spec.md
powinno udokumentować że Sage **nie nadpisuje** natywnego
`/init` flow Codex; wręcz przeciwnie — Sage `bin/sage init`
**dopełnia** AGENTS.md o Sage block (per ADR-5
append-below-markers).

---

## Summary recommendation

Wszystkie 4 ADRy są **technicznie wykonalne** na obecnym Codex
0.126 surface. Trzy (doctor-and-status, enforcement-profiles,
narrow-palette) są **GREEN** lub **GREEN with caveats** —
wszystkie używane mechanizmy istnieją i są udokumentowane.

Jeden ADR (public-workflows-internal-library) jest **YELLOW** ze
względu na pomieszanie pojęć skill/plugin i niespójność z
narrow-palette ADR (gdzie direct skille są w `.agents/skills`
z `allow_implicit_invocation: false`, vs ten ADR sugeruje "poza
hierarchią discovery"). Rekomendacja: spec.md musi rozstrzygnąć
tę niespójność jednoznacznie.

Główne ryzyka cross-cutting:
1. **Naming kolizja** `sage status` ↔ natywny `/status` (UX risk).
2. **Brak mapping** Sage profile labels ↔ natywne `[profiles.X]`.
3. **Plugin angle** całkowicie pominięty w research base.
4. **Empirical pilots** są niezbędne dla narrow-palette
   (precedence `description` vs `short_description`) i bug #14161
   (sub-agent override).

Pilot tests w narrow-palette ADR są **właściwym wzorcem** —
recenzent rekomenduje rozszerzyć ten wzorzec na enforcement-profiles
(empirical check że `[profiles.fast-trusted]` z `--yolo` faktycznie
zachowuje się jak ADR zakłada) i doctor-and-status (empirical
check że `codex --version` istnieje jako documented surface).
