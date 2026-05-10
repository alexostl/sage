# Recon — Claude port bootstrap & constitution mechanics

## A. Bootstrap lifecycle

### A1. `bin/sage init` step-by-step

1. **Validate project state** (bin/sage:878-920) — sprawdza czy nie jest self-host framework, czy już zainicjalizowany, czy musi confirm
2. **Copy framework** (bin/sage:932, calls copy_framework:562-575) — `cp -a $SAGE_FRAMEWORK $target/sage &` z spinner, prune cache files
3. **Detect stack** (bin/sage:934, detect_stack:533-560) — skanuje `package.json`, `go.mod`, `Cargo.toml` etc.
4. **Select platform** (bin/sage:935, select_platform:465-531) — auto-detect z `.claude/`, `.agents/`, `AGENTS.md` headlinów; pytaj interaktywnie jeśli ambig
5. **Select preset** (bin/sage:936, select_preset:577-628) — czyta existing `.sage/constitution.md` `extends:` field; auto-detect lub interactive choice (base/startup/enterprise/opensource)
6. **Create .sage/ state** (bin/sage:937, create_sage_state:642-732) — tworzy `config.yaml`, `decisions.md`, `conventions.md`, copy gate scripts z `core/gates/scripts/`, copy `gate-modes.yaml`
7. **Constitution scaffold** (bin/sage:937, create_sage_state:711-723) — jeśli preset ≠ base/none, tworzy `.sage/constitution.md` z frontmatter `extends: $PRESET` + ## Project Additions stub
8. **Run platform generators** (bin/sage:938, run_generators:734-756) — bash `runtime/platforms/{antigravity,claude-code,codex}/setup/generate-*.sh`
9. **Wire hooks** (bin/sage:939, ensure_hooks_wired:217-278) — copy `.githooks/pre-commit` z framework, set `git config core.hooksPath .githooks`
10. **Print success banner** (bin/sage:940, print_success:758-818) — info o `/sage` commands, sage-memory setup hint

### A2. Atomicity

**NIE atomowe.** Init robi dwa stadia:
- Faza 1 (sage_init do run_generators): alokuje state w `.sage/`, kopiuje framework, calls generators
- Faza 2 (ensure_hooks_wired): wires git hooks (idempotent, ale separate)

**Nie ma osobnego `sage compile` / `sage deploy`** — wszystko dzieje się w `run_generators` (linie 740-756), który for each platform calls setup script synchronicznie.

### A3. core/ → .sage/ mechanism

**COPY (pełny, z pruning):**

1. Framework: `cp -a $SAGE_FRAMEWORK $target/sage` (bin/sage:568) → entire parent dir
2. Prune: `rm -rf $sage_dir/.git .github .tmp` + `rm -f .DS_Store` (bin/sage:354-358)
3. Gate scripts: `cp $SAGE_FRAMEWORK/core/gates/scripts/*.sh $sage_dir/gates/scripts/` (bin/sage:698-702)
4. Gate config: `cp $gate_config $sage_dir/gates/gate-modes.yaml` (bin/sage:705-708)

Constitution preset nie kopiuje z `core/constitution/presets/` do `.sage/` — zamiast tego **generator czyta preset z `core/` i merguje w locie** (generate-claude-code.sh:419-458):
- Odczytuje `.sage/constitution.md` `extends:` field
- Jeśli nie base/none: szuka `core/constitution/presets/${PRESET}.constitution.md`
- Ekstraktuje zasady z `## Additions` sekcji
- Merguje do `CONST_SECTION` variable
- Wstawiającego do CLAUDE.md template przejazdem `__CONSTITUTION_PLACEHOLDER__` (linia 306, 461-473)

### A4. core/ inventory

Katalogi które framework bootstrapuje:

- **core/constitution/** — base.constitution.md + presets/ (startup/enterprise/opensource)
- **core/gates/scripts/** — gate implementation scripts (spec-compliance.sh itp) — `cp`'d do `.sage/gates/scripts/`
- **core/gates/_config/gate-modes.yaml** — activation config — `cp`'d do `.sage/gates/gate-modes.yaml`
- **core/workflows/*.workflow.md** — durable process workflows (build/fix/architect/learn itp) — nie kopiujemy, czytamy z `sage/core/` w generator
- **core/capabilities/** — orchestration, execution, discovery agents i skills (sage-navigator, coding-principles, personas itp) — referencja z CLAUDE.md/AGENTS.md, nie copy
- **core/agents/*.persona.md** — developer/debugger/architect personas — referencja z generator preamble (linie 544, 557, 587 etc w generate-codex.sh)

Katalogi które **NIE** trafiają do `.sage/`:
- **.git, .github, .tmp** (pruned: bin/sage:354-358)
- **core/references/** — durable docs, czytane z `sage/core/` in situ
- **skills/** — read from `sage/skills/`, never copied to `.sage/`

### A5. `sage update` semantics

Idempotent (bin/sage:946-1161):

1. **Detect active platforms** (linie 967-982) — z frontmatter w CLAUDE.md/AGENTS.md oraz katalogi `.claude/`, `.agents/`
2. **Backup community skills** (1040-1047) — `cp -a` custom skills to temp dir (preserve across framework rm -rf)
3. **Update sage/ framework** (1050-1067) — `rm -rf $target/sage`, `cp -a $update_source`
4. **Restore community skills** (1069-1093) — `cp -a` z backup, update skills.json metadata
5. **Regenerate platform files** (1101-1103) — `SAGE_UPDATE_MODE=true run_generators` (flag dostępny dla generatorów)
6. **Migrate legacy artifacts** (1105-1151) — clean stale pattern frontmatter (tasks-total/done removal), migrate journal.md → decisions.md
7. **.sage/ preserved** — config.yaml, decisions.md, conventions.md, gates, docs nie są dotykane

**User mods w .sage/ survival:** config i decisions są hand-edited, nie nadpisywane. Gates scripts mogą być custom — generator nie replace'uje jeśli diffs dotykane.

### A6. Dev mode vs production

**Dev mode: framework-symlink-dev-workflow** (.sage/work/20260428-framework-symlink-dev-workflow/plan.md):

Nie zmienia mechaniki bootstrap — jest post-init workflow. Zamiast `~/.sage/framework` being a copy/clone, tworzy symlink do `~/Developer/sage-selfhost` (self-host scenario). Generatory czytają z symlinku samo jak z kopii (sys level transparently).

Implikacje:
- `sage update` pulls z sage-selfhost repo zamiast z remote (bin/sage:1051, resolve_update_source:307-348 checks `.sage/.sage-framework-source` marker)
- Self-host init flag (bin/sage:888) skips copy, uses local framework in situ

---

## B. Constitution merge

### B1. Constitution definition

Constitution to **durable rulebook** dla agenta. Living document zawierający:
- **Base principles** (5 universal: tests-first, no-silent-failures, secrets-never-in-code, dependencies-explicit, changes-reversible) — zawsze obowiązkowe
- **Preset additions** (6-9: startup/enterprise itp) — inherit base, add velocity/compliance/docs rules
- **Project additions** — site-specific principles zespół wpisuje w `.sage/constitution.md` sekcja `## Project Additions`

FRONTMATTER (YAML zwischen `---` delimiters):
```yaml
name: "$project_name"
extends: $PRESET  # base|startup|enterprise|opensource — default base
```

Czyta się z `.sage/constitution.md` (bin/sage:598-606, create_sage_state; generate-claude-code.sh:420-421).

### B2. Preset inventory

Istnieją 4 presets (core/constitution/presets/):

1. **base** — core/constitution/base.constitution.md — domyślnie; never override
2. **startup** — startup.constitution.md — velocity + monolith-first (principles 6-9)
3. **enterprise** — enterprise.constitution.md — compliance + audit (principles 6-9)
4. **opensource** — opensource.constitution.md — docs-mirror-code + semver contract (principles 6-9)

Każdy preset `extends: base` — addytywnie, nie subtraktywnie.

### B3. Preset selection mechanism

**Explicit options (interactive, bin/sage:608-627):**
- CLI flag: `sage init --preset startup`
- Interactive prompt: ask_choice 5 opcji
- Default: base (linia 625)

**Auto-detect (bin/sage:597-606):**
- Jeśli `.sage/constitution.md` już istnieje, czyta `extends:` field (sed parse frontmatter)
- Preservuje preset na re-init (zapobiega reset'owi)

**Flow:** jeśli --preset flag set → use it; else jeśli exists constitution.md → read extends; else interactive; else base

### B4. Preset → project merge mechanism

**Dla Claude Code (generate-claude-code.sh:406-473):**

Preset **nie** kopiowany do projektu. Zamiast tego:
1. Generator czyta `.sage/constitution.md` `extends:` field (linia 420-421)
2. Jeśli preset ≠ base/none: otwiera `core/constitution/presets/${PRESET}.constitution.md`
3. Ekstraktuje linie zaczynające się `[0-9]` w sekcji `## Additions` (linia 426)
4. Renumeruje sekwencyjnie (merging z base) w `$CONST_SECTION` variable (linie 428-440)
5. **Wstawia do CLAUDE.md** jako string-replace `__CONSTITUTION_PLACEHOLDER__` via Python (linie 462-473)

**Dla Codex:**
Analogicznie (generate-codex.sh ma ten sam merge pattern).

**User additions preservation:**
- Project może dodać custom rules w `.sage/constitution.md` sekcja `## Project Additions`
- Generator ekstraktuje je (generate-claude-code.sh:445-457) i merges
- Każdy subsequent update re-czytuje `.sage/constitution.md`, respektując user edits

### B5. User-additions protection

`.sage/constitution.md` struktura (linie 712-721):
```markdown
---
name: "$project_name"
extends: $SELECTED_PRESET
---

## Project Additions

(Add project-specific principles here)
```

**Protection mechanism:**
- Generator nigdy nie nadpisuje `.sage/constitution.md` (bin/sage:711: `if [ ! -f "$sage_dir/constitution.md" ]`)
- Jeśli plik istnieje, czyta go bez modyfikacji (generate-claude-code.sh:420)
- User może edytować `## Project Additions` sekcję; generator będzie czytał updated content na następnym update

Symlink do innego pliku (linia 3 z CLAUDE.md: `@.sage/docs/comm-style.md`) pokazuje że generator wspiera `@` syntax dla include'ów (mechanizm Claude Code), ale constitution merge nie używa symlinków — pure string merge.

### B6. Constitution → agent runtime injection path

**Dla Claude Code:**

1. Generator wstawia `CONST_SECTION` do CLAUDE.md templatu w sekcji `## Engineering Principles` (linia 307, 461-473)
2. CLAUDE.md jest **global context** — Claude Code czyta go entire na session start
3. Agent widzi merged principles w `.md` as part of process constitution rules
4. Nie ma dynamicznego include; constitution jest frozen w moment generation

**Dla Codex:**

AGENTS.md analogiczną strukturę (line 145+), ale **brak jawnego constitution-merge section**. Zamiast tego:
- Workflow preambles (generator:533-688) zawierają RULES hardcoded
- Constitution sprawdza się intuitively z rules + AGENTS.md principles (linie 158-162 "Process Constitution (non-negotiable)")
- Nie ma `__CONSTITUTION_PLACEHOLDER__` mechaniki jak u Claude Code

**Injektowanie do uruchomionego agenta:**
- Sage nie uses runtime injection (no MCP dla constitution, no env vars)
- Agent odczytuje pliki na startup (CLAUDE.md, AGENTS.md statycznie)
- Memory layer (sage-memory MCP) przechowuje learnings z constitution aplikacji, ale samo constitution text nie persists; każda sesja ponownie czyta z pliku

---

## C. Implications for Codex port

Platform-agnostic (identyczne dla Codex):
1. Bootstrap flow: detect-platform → select-preset → copy framework → create .sage/ → run generators (sekwencja idempotent)
2. Constitution merge: read .sage/constitution.md, extract preset + project additions, string-replace w output
3. Gate scripts architecture: copy z core/gates/scripts/, manage w .sage/gates/scripts/
4. State preservation: config.yaml, decisions.md, conventions.md, user edits survive update
5. Dev workflow: framework symlink option works transparently (Codex generator would use same symlink as Claude Code)

Platform-specific (wymaga portu):
1. **Generator entry point:** runtime/platforms/codex/setup/generate-codex.sh musi być analogiczny do claude-code version (tworzy AGENTS.md, .agents/skills/, .codex/config.toml)
2. **Workflow file mapping:** core/workflows/*.workflow.md czytane przez codex generator, konwertowane do Codex skill format (linia 1-50 z generate-codex.sh to Python rewriting pola skill name + prefix)
3. **Command prefix parity:** `-e "s|/design-review|/${PREFIX}design-review|g"` pattern (bin/sage:479-496) musi działać dla Codex also (skillcmd references w AGENTS.md)
4. **Constitution injection:** AGENTS.md musi mieć analogiczny `__CONSTITUTION_PLACEHOLDER__` lub jawny merge section (codex generator to nie robi jeszcze jawnie — kto czyta AGENTS.md policy?)
5. **MCP reference style:** Claude Code uses `@.sage/docs/` syntax (linia 3 CLAUDE.md); Codex używa `$skill` reference system (linia 179 AGENTS.md) — muszą być aligned jeśli constitution chce cross-referencji

Port priorities:
1. Ensure generate-codex.sh existuje i robi full AGENTS.md generation (istniejące)
2. Add explicit constitution merge to AGENTS.md (brakuje)
3. Test platform detection logic (cli-flag, auto-detect, interactive) dla Codex (działające, ale verify w sage update flow)
4. Symlink dev workflow transparency (już działa — żaden kod platform-specific)
