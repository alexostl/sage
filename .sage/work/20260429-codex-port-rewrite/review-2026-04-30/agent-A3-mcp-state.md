# Agent A3 — Codex MCP & state feasibility (5 ADRs)

Niezależny review feasibility 5 ADRów dotyczących MCP, audytu i workflow
state względem oficjalnej dokumentacji Codex (developers.openai.com/codex).

## Sources fetched

1. https://developers.openai.com/codex — entry point, mapa docs (MCP,
   memories, approvals, sandbox, config, skills).
2. https://developers.openai.com/codex/mcp — konfiguracja MCP serverów
   (TOML, transport, timeouts, enabled/disabled tools, required).
3. https://developers.openai.com/codex/config-reference — pełen schemat
   `config.toml` (mcp_servers, sandbox_mode, approval_policy, hooks,
   memories, sqlite_home, history.persistence).
4. https://developers.openai.com/codex/agent-approvals-security —
   semantyka approval_policy: untrusted / on-request / never / granular.
5. https://developers.openai.com/codex/memories — system pamięci, format
   `~/.codex/memories/`, Chronicle, brak programmatic state API.
6. https://developers.openai.com/codex/concepts/sandboxing — granica
   sandbox, read-only / workspace-write / danger-full-access; **brak
   informacji o relacji sandbox ↔ MCP serwery**.
7. https://developers.openai.com/codex/skills — skille są
   instruction-based, **brak built-in state, verification, approval gates
   wewnątrz skilla**.

## Verdict summary

| Status | Liczba | ADRy |
|---|---|---|
| OK | 2 | outcome-driven-verification, outcome-harness (z 1 UNVERIFIED) |
| DRIFT | 1 | mcp-stack (D5 timeout 5s vs default 10s — zaostrzony, ale legalny) |
| UNVERIFIED | 2 | workflow-state-machine, approval-proof (Codex nie ma własnego pojęcia gate'u — to czysto Sage'owa konstrukcja) |
| BLOCKERS | 0 | — żaden ADR nie zakłada feature'ów których docs negują |

Suma: **0 BLOCKERS, 1 DRIFT (drobny), 2 UNVERIFIED, 2 OK**.

## Findings (per ADR)

### ADR — `decision-codex-mcp-stack.md` → DRIFT (drobny) + 2 UNVERIFIED

**Co ADR zakłada:**

- D1: Python + oficjalny `mcp` SDK.
- D2: instalator `uv → pipx → pip --user` + shim `~/.sage/bin/sage-mcp-server`.
- D5: `[mcp_servers.sage]` z `command`, `args`, `required = true`,
  `startup_timeout_sec = 5`, `tool_timeout_sec = 10`, `enabled_tools = [...]`.
- D6: założenie że `required = true` chroni tylko startup, mid-session
  crash → `Transport closed`, brak respawn (potwierdzone empirycznie PoC C1 T3).

**Zgodność z docs:**

- **OK** — TOML, lokalizacja `config.toml`. Cytat z `/codex/mcp`:
  *"Codex stores MCP configuration in `config.toml` alongside other
  Codex configuration settings."* Lokalizacja: `~/.codex/config.toml`
  globalnie LUB `.codex/config.toml` per-projekt (trusted only).
- **OK** — pola w `[mcp_servers.<id>]`: `command`, `args`, `env`,
  `enabled_tools`, `disabled_tools`, `startup_timeout_sec`,
  `tool_timeout_sec`, `required` — wszystkie zdokumentowane w
  config-reference. ADR nie wymyśla pól.
- **OK** — STDIO transport + `command` jest udokumentowany jako jeden
  z dwóch transportów (drugi to "Streamable HTTP servers"). Dla naszego
  use-case'u (lokalny shim) STDIO jest właściwy.
- **DRIFT (drobny)** — ADR D5 ustawia `startup_timeout_sec = 5`, ale
  docs cytują: *"Timeout (seconds) for the server to start. Default: 10"*.
  ADR daje sobie 2× mniejsze okno niż default. **Nie blocker** (override
  jest legalny, pole istnieje), ale junior dev / wolniejsza maszyna
  może oblać startup. Rekomendacja: zostawić default 10s lub
  uzasadnić w ADR czemu 5s jest bezpieczne (PoC C1 mierzył startup?).
- **OK** — `tool_timeout_sec = 10` jest 6× ostrzejsze niż default 60s,
  ale dla lokalnych predykatów to rozsądne; pole istnieje, override jest
  legalny.
- **UNVERIFIED** — D6 zakłada że Codex **nie respawnuje** dead MCP
  mid-session. Docs nie mówią o respawnie wprost; ADR potwierdza to
  empirycznie PoC C1 T3 (T3 confirmed mid-session crash, "Transport
  closed", "does NOT respawn the server"). Empiryka > docs, ale wpis
  do "co docs nie potwierdza wprost" — jeżeli OpenAI doda respawn w
  0.127, D6 stanie się przestarzałe. **Akcja:** spec.md powinien
  oznaczyć D6 jako empirically-anchored i dodać kontrolę version pin.
- **UNVERIFIED** — relacja MCP ↔ sandbox. Strona `/codex/concepts/sandboxing`
  cytuje sandbox tylko dla "spawned commands" i nie wypowiada się o
  procesach MCP. Nie wiemy z docs czy MCP server uruchomiony przez
  `command = ".../sage-mcp-server"` dziedziczy sandbox czy nie. ADR-3
  nie potrzebuje tego rozstrzygnąć (Sage MCP czyta tylko `.sage/` i
  pisze do tego samego workspace), ale **spec.md powinien dodać
  sanity check w `sage doctor`**: czy MCP może czytać/pisać do
  `.sage/`. Jeżeli przyszły Codex zaostrzy sandbox dla MCP procesów,
  D2/D5 mogą wymagać `writable_roots`.

**Co ADR zakłada NIEzgodnego z docs:** nic. Cała powierzchnia
konfiguracji jest w schemacie `config-reference`.

### ADR — `decision-codex-outcome-driven-verification.md` → OK

**Co ADR zakłada:**

- Każdy enforcement milestone v1 wymaga empirycznego pilota (12–15
  promptów) zanim uznamy go za ukończony.
- Mechaniczne testy (78/78 z poprzedniego cyklu) nie były
  predyktywne; trzeba behavioral outcome.

**Zgodność z docs:**

- **OK** — to jest decyzja **procesowa** Sage, niezależna od Codex.
  Docs nie mają pojęcia "outcome verification" jako platformy
  (`/codex/agent-approvals-security` cytuje: *"The material provides
  no explicit discussion of outcome verification, completion proof,
  or post-approval confirmation mechanisms"*). To znaczy że **Sage
  buduje warstwę której Codex sam nie ma** — zgodne z brief C5,
  niezagrożone przez konflikt z platformą.
- ADR nie zakłada żadnego API / surface'u Codex; tylko mówi
  "test the loop". Nie ma czego falsyfikować w docs.

**Wniosek:** ADR jest czystą decyzją Sage i nie konfliktuje z Codex.

### ADR — `decision-codex-outcome-harness.md` → OK (z 1 UNVERIFIED)

**Co ADR zakłada:**

- D3: harness wywołuje `codex exec --json --prompt-file <tmpfile>`
  i czyta event stream JSON.
- D3: opcjonalna flaga `--seed <stable-int>` jeśli Codex 0.126 ją wspiera.
- D2: regeneracja `<repo>/.codex/config.toml` per-arm (per-projekt
  config TOML).
- D4: structural evaluator czyta `tool_call` events typu `apply_patch`,
  hook block events (exit 2 z hook scriptu).

**Zgodność z docs:**

- **OK** — per-projekt `.codex/config.toml` jest zdokumentowane
  ("`.codex/config.toml` for project-scoped settings, trusted projects
  only"). ADR jawnie regeneruje plik per-arm — to jest legalna
  ścieżka.
- **OK** — Hooks są w schemacie config-reference: *"Event types
  include: `PreToolUse`, `PostToolUse`, `PermissionRequest`,
  `SessionStart`, `UserPromptSubmit`, `Stop`"*. Evaluator zakłada
  PreToolUse exit 2 = block; spójne z dokumentacją hooks.
- **UNVERIFIED** — `codex exec --json` schema. ADR sam to nazywa
  (FM-8.1: *"`codex exec --json` schema changes between Codex versions"*)
  i pinuje `codex_min_version: 0.126`. Docs entry-point nie
  publikował specyfikacji event-streamu w pobieranych URL-ach;
  potwierdzenie istnieje tylko w research base §5 row 13. **Akcja:**
  spec.md musi zalockować schema w `evaluator.py` z explicit
  walidacją (ADR sam to obiecuje w FM-8.1: "harness runner asserts
  schema on first invocation").
- **UNVERIFIED** — `--seed` flag. Sam ADR cytuje: *"Codex 0.126
  `--seed` flag uncertainty. Research base does not confirm `--seed`
  exists in 0.126."* To jawne UNVERIFIED i ADR ma fallback (3
  uruchomienia per prompt). **OK** — ryzyko zaadresowane.

**Wniosek:** ADR nie zakłada nic czego docs negują; pinuje wersję
0.126 i ma fallbacki. Ryzyko = schema drift przy bumpie Codex; to
jest udokumentowany failure mode.

### ADR — `decision-codex-workflow-state-machine.md` → UNVERIFIED

**Co ADR zakłada:**

- Codex potrzebuje **zewnętrznego** state machine'a (Sage'owego),
  bo sama platforma nie utrzymuje workflow gate state.
- State pochodzi z artefaktów `.sage/` (frontmatter, decisions.md);
  validator dzieli logikę między hooks, `sage status` i generator.
- Decyzje "what gate is open / what's allowed next / response shape"
  rezydują w warstwie Sage, nie w Codex.

**Zgodność z docs:**

- **OK koncepcyjnie** — docs (`/codex/skills`) cytują:
  *"There is no mention of enforcing sequential steps or requiring
  completion of prerequisites... no built-in state tracking, outcome
  enforcement, or workflow validation within the skill definition
  format itself."* To **potwierdza** rationale ADR: jeśli Codex sam
  tego nie ma, Sage musi to dostarczyć.
- **OK** — Codex memories (`/codex/memories`) są dla kontekstu między
  sesjami ("stable preferences, recurring workflows, tech stacks"),
  **nie** dla per-turn workflow state. Chronicle ratuje kontekst z
  ekranu, nie tracking gate'ów. ADR słusznie nie buduje na memories.
- **UNVERIFIED** — ADR zakłada że state można **w pełni** wyprowadzić
  z `.sage/` artefaktów (frontmatter + decisions.md). Docs nie
  oferują programmatic API ("The documentation doesn't mention a
  dedicated API for state management"). To **wzmacnia** wybór:
  Sage musi sam czytać pliki, bo Codex nic nie udostępnia. Ryzyko
  jednak: jeśli agent zmieni stan ale nie zapisze artefaktu, state
  machine jest ślepy. ADR-3 (D6) i ADR-7 łączą to przez
  `pre-tool-validate.sh` + Stop hook. **Akcja:** spec.md musi
  jednoznacznie zdefiniować "co jest source-of-truth state'u" —
  ADR zostawia to jako "shared by hooks, status, and generated
  context", ale nie wskazuje pliku-królika.
- **UNVERIFIED** — założenie że validator jest jednym wspólnym
  modułem dla hooks + status + generator nie jest weryfikowalne
  z docs (to architektura Sage). Z perspektywy Codex: dopóki
  validator jest wywoływany jako MCP tool (ADR-3 v1 surface) lub
  hook script, platforma to akceptuje.

**Wniosek:** ADR nie zakłada żadnej konstrukcji Codex której docs
nie wspierają. Cała wartość jest po stronie Sage; Codex po prostu
udostępnia hooks i MCP, a Sage używa ich do enforce'u state'u.
**Rekomendacja:** spec.md doprecyzuje source-of-truth state'u
(jeden plik? union frontmatter+decisions.md? tylko `.sage/work/`?).

### ADR — `decision-codex-approval-proof.md` → UNVERIFIED

**Co ADR zakłada:**

- Approval proof = frontmatter (`approved_at`, `approved_by`,
  `approval_source`, `approval_gate`) + matching wpis w `decisions.md`.
- Validator traktuje approval jako missing jeśli nie da się go
  wyprowadzić z artefaktu + decision log.
- Semantyka `[A]` / `[S]` / `[R]` jest Sage'owa, nie Codex'owa.

**Zgodność z docs:**

- **OK koncepcyjnie** — Codex ma własne `approval_policy`
  (untrusted / on-request / never / granular) ale to jest
  **per-tool-call gate** (czy Codex może wykonać działanie w
  sandboxie / poza nim), **nie** per-workflow-checkpoint approval.
  Cytat z `/codex/agent-approvals-security`: approval_policy
  *"determines when Codex must ask you before it executes an action
  (for example, leaving the sandbox, using the network, or running
  commands outside a trusted set)."* To jest **inny rodzaj approval'u**
  niż Sage'owy `[A]/[R]/[S]` na deliverable.
- **UNVERIFIED + zalecane wyjaśnienie** — ADR nie wprowadza
  niezgodności, ale ryzyko **terminologicznego konfliktu**: w docs
  Codex słowo "approval" oznacza sandbox-level prompt; w Sage
  oznacza checkpoint na briefie/spec/planie. **Akcja:** spec.md
  powinien jawnie odróżnić "Codex approval (platform)" od "Sage
  approval (workflow)" — inaczej junior dev pomyli. Rekomenduję
  wprowadzenie nazwy `sage_approval_proof` lub `workflow_approval`
  do schemy frontmatter (ADR używa neutralnego "approval", co
  działa, ale w połączeniu z Codex `approval_policy` może mylić).
- **OK** — ADR zakłada że approval proof jest **plikowy**, nie
  zapamiętany przez model. To zgadza się z docs cytatem
  `/codex/memories`: *"Memories may not update right away when a
  thread ends. Codex waits until a thread has been idle long
  enough."* → memories są zbyt opóźnione i nieprogramowalne, żeby
  służyć za approval store. ADR słusznie wybiera frontmatter +
  decisions.md.
- **UNVERIFIED** — założenie że validator może z 100% pewności
  wyprowadzić approval z artefaktu + decisions.md. Edge case:
  user pisze `[A]` w czacie ale agent nie zapisał frontmattera
  (np. crash przed save). ADR-3 D6 + ADR-7 incident log zamykają
  to, ale spec.md powinien skoordynować: "approval bez frontmattera
  = no approval, niezależnie od chat history".

**Wniosek:** ADR nie konfliktuje z Codex; ryzyko jest
terminologiczne i edge-case'owe. **Rekomendacja:** spec.md doda
glossary section odróżniającą "Codex approval" (sandbox) od
"Sage approval proof" (workflow checkpoint).

## Cross-cutting

### 1. Codex docs nie mają pojęcia "outcome / verification / proof"

Cytaty zebrane z trzech stron docs:

- `/codex/agent-approvals-security`: *"The material provides no
  explicit discussion of outcome verification, completion proof, or
  post-approval confirmation mechanisms."*
- `/codex/skills`: *"The documentation does not describe any built-in
  verification or validation of skill outcomes."*
- `/codex/memories`: *"The documentation doesn't mention a dedicated
  API for state management."*

**Konsekwencja:** wszystkie 5 ADRów buduje warstwę **której Codex
sam nie ma**. To **nie jest blocker** — to legitnie wybrane miejsce
do wartości Sage. Ale junior dev / przyszły reviewer powinien to
rozumieć: **Codex jest substrate'em, Sage jest workflow engine'em.
Nie zakładamy że Codex enforce'uje cokolwiek workflow-wise.**

### 2. Source-of-truth dla workflow state — niedoprecyzowany w ADRach

ADR-workflow-state-machine i ADR-approval-proof oba mówią o
"frontmatter + decisions.md", ale nie ma jednej kanonicznej
definicji "co jest stan". Trzy potencjalne źródła:

1. `.sage/work/<initiative>/*.md` frontmatter (status, phase).
2. `.sage/decisions.md` (kronologiczne).
3. `.sage/` flag files (`.approval-pending`, `.session-mutations.log`).

**Akcja dla spec.md:** jednoznaczna hierarchia precedensu. Sugestia:
frontmatter = primary, decisions.md = uzupełnienie (rationale),
flag files = transient (per-session).

### 3. Sandbox ↔ MCP relacja — luka w docs

`/codex/concepts/sandboxing` mówi o sandboxie tylko dla "spawned
commands"; nie wyjaśnia czy proces MCP server (uruchomiony przez
`command = ...`) podlega tym samym zasadom. ADR-3 zakłada że MCP
może czytać `.sage/` i pisać do niego — w sandbox-mode
`workspace-write` to powinno działać, ale w `read-only` byłoby
zablokowane jeśli MCP też podlega.

**Akcja dla spec.md:** dodać do `bin/sage doctor` self-test
"can MCP write to `.sage/`?" — jeden plik tymczasowy, write+delete,
zgłasza failure jeśli sandbox blokuje. Pokrywa to FM nie nazwany w
ADR-3.

### 4. Wersje / version pinning

ADR-3 i ADR-8 pinują `codex_min_version: 0.126`. To jest dobre,
ale docs nie publikują versioned schema dla `codex exec --json` ani
dla schema mcp_servers. **Konsekwencja:** każdy bump Codex wymaga
re-walidacji harness (FM-8.1 to nazywa). **Rekomendacja dla
spec.md:** dodać `bin/sage doctor` step "Codex version detected:
X; supported: 0.126.*; warn jeśli wyższe".

### 5. Co nie jest blockerem ale wymaga wzmianki

- `enabled_tools` jako allowlist — ADR-3 D5 słusznie używa, ale
  docs cytują *"`disabled_tools` (denylist applied after
  allowlist)"* — kolejność jest "allow then deny". ADR jest spójny
  z tą kolejnością.
- `experimental_environment = "remote"` (z `/codex/mcp` STDIO
  options) — NIE używane w ADR-3, i słusznie (production stack
  lokalny). Wpis informacyjny.

### 6. Pojęcie "approval" — kolizja terminologiczna

Codex docs używają "approval" dla sandbox-level prompts (untrusted
/ on-request / never / granular). Sage używa "approval" dla
workflow checkpoint ([A]/[R]/[S]). Spec.md MUSI rozróżnić.

Sugerowane nazewnictwo w spec.md:
- "Codex platform approval" / "approval_policy" — sandbox-level.
- "Sage workflow approval" / "approval_proof" — checkpoint-level.

To jest soft-blocker dla docs przyjazności junior devom.

## Podsumowanie dla spec.md

**Akcje wymagane (z tego review):**

1. ADR-3 D5: rozważyć `startup_timeout_sec = 10` (default) zamiast 5,
   lub uzasadnić 5s pomiarem PoC.
2. ADR-3: dodać do `bin/sage doctor` self-test "MCP może pisać do
   `.sage/`?" (krycie luki sandbox ↔ MCP w docs).
3. ADR-workflow-state-machine: doprecyzować hierarchię source-of-truth
   (frontmatter primary > decisions.md > flag files).
4. ADR-approval-proof: dodać glossary odróżniający Codex approval
   (sandbox) od Sage approval proof (workflow checkpoint).
5. ADR-8: ujednolicić w `evaluator.py` runtime walidację schema
   `codex exec --json` (już obiecane w FM-8.1).
6. Cross: udokumentować że "Codex jest substrate, Sage jest workflow
   engine; brak workflow enforcement po stronie platformy".

**Brak BLOCKERS.** Wszystkie ADRy są feasible w obrębie 0.126 docs;
ryzyka są terminologiczne, schema-stability, i empiryczne (D6
respawn behavior). Wszystkie ryzyka są nazwane w ADRach lub
zaadresowane przez ADR-9 (sage doctor).
