# Agent A1 — Codex hooks feasibility (5 ADRs)

Recenzent: niezależny subagent feasibility (oś ADR ↔ Codex docs)
Data: 2026-04-30
Zakres: 5 ADRów dotyczących hooków + integracji.
Wersja docs sprawdzana: developers.openai.com/codex (snapshot 2026-04-30).

## Sources fetched

1. https://developers.openai.com/codex
   — index nawigacyjny; potwierdza istnienie `/codex/hooks`,
   `/codex/config-reference`, `/codex/config-advanced`,
   `/codex/concepts/customization`, `/codex/plugins`, `/codex/mcp`.
2. https://developers.openai.com/codex/hooks
   — pełna referencja 6 eventów (SessionStart, PreToolUse,
   PermissionRequest, PostToolUse, UserPromptSubmit, Stop), payload
   schema, exit codes, ścieżki konfiguracji.
3. https://developers.openai.com/codex/config-reference
   — klucze `[features].codex_hooks`, `[hooks]` inline,
   `mcp_servers.<id>.*`, scope global vs project (`~/.codex/config.toml`
   vs `<repo>/.codex/config.toml`).
4. https://developers.openai.com/codex/config-advanced
   — multiple hooks per event (array `[[hooks.PreToolUse]]`); admin
   `requirements.toml` `[hooks].managed_dir`; flaga "experimental".
5. https://developers.openai.com/codex/concepts/customization
   — konceptualnie wymienia AGENTS.md, Skills, MCP, Subagents,
   Memories. Hooks tylko w nawigacji, brak detali.

Nie podążyłem za URL-em git-pre-commit / PreCommit — Codex docs **nie
opisują** dedykowanego eventu pre-commit. To NIE jest event Codex,
tylko klasyczny git hook.

## Verdict summary

- BLOCKERS: 0
- DRIFT: 4
- UNVERIFIED: 3
- OK: 7

Zliczone per ADR: każdy ADR ma kilka claimów; verdict per claim, nie per ADR.

---

## Findings

### ADR: decision-codex-hook-activation.md

#### Claim A — `[features].codex_hooks = true` jest sygnałem aktywacji
**Docs says:** Potwierdzone w `/codex/config-reference`:
> `features.codex_hooks` — "Enable lifecycle hooks loaded from
> `hooks.json` or inline `[hooks]` config"

Nazwa klucza i znaczenie zgadzają się dosłownie z ADR.
**Verdict:** OK
**Suggested action:** brak; spec może bezpiecznie cytować ten klucz.

#### Claim B — Hooks konfigurowane w `.codex/hooks.json`
**Docs says:** Potwierdzone w `/codex/hooks`:
> Locations: `~/.codex/hooks.json`, `~/.codex/config.toml`,
> `<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml`

Jest też alternatywa inline `[hooks]` w `config.toml`
(`/codex/config-reference` mówi "inline `[hooks]` config").
ADR przyjmuje tylko wariant `hooks.json` — to jest świadomy wybór, nie
konflikt z docs, ale spec powinien wzmiankować że inline-wariant
istnieje i Sage go nie używa.
**Verdict:** OK (z drobną notą)
**Suggested action:** w spec.md dodać jedno zdanie "Sage używa
`hooks.json`, nie inline `[hooks]`, dla determinizmu mergowania —
inline-wariant istnieje per docs, ale nie jest używany."

#### Claim C — Mapowanie eventów: UPS → pre-prompt.sh, PreToolUse(Bash) → pre-bash.sh, PostToolUse(Bash) → post-bash.sh, SessionStart → session-start.sh
**Docs says:** Wszystkie cztery nazwy eventów istnieją dosłownie w
`/codex/hooks`: `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`SessionStart`. PreToolUse i PostToolUse mają matcher na `tool_name` —
matcher to **regex string** (`/codex/hooks` cytuje
`matcher = "^Bash$"`).

ADR mówi „PreToolUse (Bash)" / „PostToolUse (Bash)" jakby `Bash` był
częścią event-name. W rzeczywistości to event = `PreToolUse`, matcher
= `Bash`. Drobna nieścisłość notacyjna, ale ADR-1
(`decision-codex-validate-mutation-predicate.md`) mówi że anchor jest
`PreToolUse(apply_patch)` — co jest spójne z docs (apply_patch jest
wymienionym tool_name w docs).
**Verdict:** DRIFT (kosmetyczny, nie blocker)
**Suggested action:** w spec.md doprecyzować: event = `PreToolUse`,
matcher = `^Bash$` (regex). To jedna linia w tabeli mapowania.

#### Claim D — Merge logic do `hooks.json` (array entries per event)
**Docs says:** `/codex/config-advanced` potwierdza że eventy mają
array entries (`[[hooks.PreToolUse]]` w TOML, czyli też array w JSON).
Zatem dodanie kolejnego elementu do array jest mechanicznie możliwe.
**ALE:** docs explicit mówi: *"the documentation does not explicitly
clarify whether all matching hooks execute or only the first one fires
when multiple hooks match the same event."*

ADR zakłada że wszystkie odpalą się ("dodawane jako kolejny element w
array"). To jest **niesprawdzone empirycznie z docs**. PoC C1 ADR-1
walidował tylko jeden hook na event.
**Verdict:** VERIFIED (PoC A1 U3, 2026-04-30) — see [poc-A1-uncertainties.md](poc-A1-uncertainties.md). All array entries fire (PASS_ALL_FIRE_UNORDERED), order is non-deterministic. Order-independence is now an ADR-1 design constraint (Amendment 2026-04-30).
**Suggested action:** dodać do spec.md test E2E "dwa entries dla
PreToolUse — czy oba się odpalają?" przed cutoverem v1. Jeśli tylko
pierwszy odpala — merge logic musi to zaadresować (np. wrapper script
który chainuje).

#### Claim E — Identity rule: framework entry ma `command` zaczynający się od `.codex/hooks/`
**Docs says:** `/codex/hooks` cytuje pole `command` (string – full
path to executable). Pole istnieje, ADR używa go zgodnie ze schematem.
Brak w docs wymogu absolutnej ścieżki — relatywna `.codex/hooks/...`
powinna być honorowana z worktree root.
**Verdict:** UNVERIFIED (docs nie potwierdza explicit że relatywne
ścieżki działają z `cwd` worktree)
**Suggested action:** PoC sprawdzający czy `.codex/hooks/pre-prompt.sh`
(relatywna) działa, czy trzeba `${CODEX_PROJECT_DIR}/.codex/hooks/...`
albo absolutna ścieżka.

#### Claim F — `[features].codex_hooks = false` lub brak → nic nie aktywne
**Docs says:** Nie powiedziane wprost, ale wynika z definicji feature
flagi w `/codex/config-reference` ("Enable lifecycle hooks loaded
from..."). Default value flagi nie jest podany w wyciągu.
**Verdict:** OK (rozsądna interpretacja)
**Suggested action:** brak.

---

### ADR: decision-codex-stop-hook-scope.md

#### Claim A — Stop hook payload: `session_id`, `transcript_path`, `cwd`, `stop_hook_active`
**Docs says:** `/codex/hooks` Stop event:
> Common fields plus: `turn_id`, `stop_hook_active` (boolean),
> `last_assistant_message` (string or null)

Common fields: `session_id`, `transcript_path`, `cwd`,
`hook_event_name`, `model`.

Zatem ADR cytuje cztery pola które rzeczywiście są w payloadzie. **ALE
pomija** `turn_id`, `last_assistant_message`, `hook_event_name`,
`model`. Dla audit logiki `turn_id` może być przydatne (D3 ADR-7
używa pola `turn_id` w `.mcp-incidents.log` — skąd je bierze? Z payload
Stop? Wtedy zgodne).
**Verdict:** DRIFT (niekompletna lista pól, ale bez konfliktu)
**Suggested action:** w spec.md uzupełnić Stop payload o pełny zestaw
pól (`turn_id`, `last_assistant_message`, `hook_event_name`,
`model`); pokazać jak D3 mapuje `turn_id`.

#### Claim B — Stop hook może zwrócić `"continue": true | false`
**Docs says:** `/codex/hooks` Stop output:
> Continue: `{"decision": "block", "reason": "Run one more pass..."}`
> (counter-intuitive naming; "block" = continue)
> `continue: false` → halt turn

Tu jest **istotny drift**. Codex używa `decision: "block"` jako
"kontynuuj" (counter-intuitive). ADR mówi `"continue": true` zawsze. Z
docs wygląda że pole `continue` istnieje, ale podstawowy mechanizm
"hard-blokowanie next turn" to `decision: "block"`, nie
`continue: false`. ADR D5 mówi "v1 zawsze `continue: true`" — to
prawdopodobnie znaczy "nigdy nie zwracaj `decision: block` ani
`continue: false`", ale terminologia ADR jest niezgodna z docs.
**Verdict:** DRIFT
**Suggested action:** Przepisać D1 i D5 z dosłowną semantyką Codex:
v1 zawsze zwraca **brak** pola `decision: "block"` i **brak**
`continue: false` (czyli pusty JSON output albo `{}`). Cytować
counter-intuitive naming docs explicit żeby przyszli readerzy nie
zinterpretowali tego jako "block = blokuj".

#### Claim C — Exit 0 zawsze; exit non-zero "prints to user but does not block"
**Docs says:** `/codex/hooks` Stop:
> Exit code `2` with reason on stderr → continues with that reason as
> new prompt

ADR mówi "non-zero exit prints to user but does not block". Docs mówi
inaczej: exit 2 → STDERR jest **wstrzykiwany jako nowy prompt** do
agenta. Czyli to jest forma soft-bloku (modyfikuje stan turn'a).
**Verdict:** DRIFT (istotny)
**Suggested action:** Zmienić formułowanie w D5 i C6: exit 2 nie jest
"benign print", to wstrzyknięcie promptu. v1 powinno explicit `exit 0`
nawet w error path C6, lub explicit zaakceptować że błąd transportu
zostanie wstrzyknięty jako prompt (co jest UX-owo niepożądane —
user dostaje surowy "Transport closed" w turn).

#### Claim D — Stop nie ma matchera
**Docs says:** `/codex/hooks` Stop: "Matcher: No – unsupported for
this event". Zgodne.
**Verdict:** OK
**Suggested action:** brak.

#### Claim E — Stop fires "end of every turn"
**Docs says:** Docs nie mówi explicit "end of every turn"; mówi
"halt turn" / "Run one more pass". Rozsądna interpretacja, ale `Stop`
prawdopodobnie fires gdy agent **chce** zakończyć turn (signal "I'm
done"), a hook może to zawetować. ADR formułowanie "end of every turn"
jest skrótem.
**Verdict:** OK (interpretacyjnie spójne z `stop_hook_active`
semantyką)
**Suggested action:** brak; ewentualnie w spec.md doprecyzować:
"Stop fires when the agent signals end-of-turn; hook może wymusić
kolejny pass via `decision: block`".

---

### ADR: decision-codex-mutation-guardrail-stack.md

#### Claim A — Layered stack używa SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop
**Docs says:** Wszystkie pięć eventów istnieje w `/codex/hooks`.
Nazwy zgodne dosłownie.
**Verdict:** OK
**Suggested action:** brak.

#### Claim B — PreToolUse może interceptować `apply_patch`, `Edit`, `Write`, Bash, MCP tools
**Docs says:** `/codex/hooks` PreToolUse:
> Supported tools: `"Bash"`, `"apply_patch"` (aliases: `"Edit"`,
> `"Write"`), MCP tools (e.g., `"mcp__filesystem__read_file"`)

Zgodne dosłownie.
**Verdict:** OK
**Suggested action:** brak; spec może cytować dosłownie.

#### Claim C — Codex docs nazywa PreToolUse "guardrail rather than complete enforcement boundary"
**Docs says:** Wyciąg z `/codex/config-advanced` mówi że hooks są
"experimental and may change or be removed in future releases".
Konkretnego cytatu "guardrail not enforcement boundary" w pobranych
fragmentach **nie ma**.
**Verdict:** UNVERIFIED
**Suggested action:** ADR cytuje docs parafrazując; w spec.md albo
znaleźć dosłowny cytat (sprawdzić `/codex/hooks` w pełnym tekście)
albo przeformułować jako "własna interpretacja docs" zamiast cytatu.

#### Claim D — `.githooks/pre-commit` jako "last repository backstop"
**Docs says:** Codex docs **milczy** o git hooks. To nie jest
mechanizm Codex — to klasyczny mechanizm git, niezależny od Codex.
ADR poprawnie pozycjonuje go jako "repo backstop" (nie Codex hook).
**Verdict:** OK (ale formalnie poza zakresem Codex docs)
**Suggested action:** brak; oddzielić w spec.md sekcję "Codex hooks"
od "git hooks" żeby reader nie mylił.

---

### ADR: decision-codex-validate-mutation-predicate.md

#### Claim A — `PreToolUse(apply_patch)` fires before mutation, payload ma `tool_name: "apply_patch"`
**Docs says:** `/codex/hooks` PreToolUse:
> Common fields plus: `turn_id`, `tool_name` (e.g., `"Bash"`,
> `"apply_patch"`, or MCP name), `tool_use_id`, `tool_input` (JSON)

Zgodne dosłownie. Pole `tool_name` istnieje, wartość `"apply_patch"`
jest udokumentowana.
**Verdict:** OK
**Suggested action:** brak.

#### Claim B — `exit 2` z hooka deterministycznie blokuje mutację
**Docs says:** `/codex/hooks` PreToolUse:
> Exit code `2` with reason on stderr → blocks command

Zgodne dosłownie. STDERR jako reason — docs potwierdza "surfaces
back into the agent context" w sensie że błąd jest widoczny.
**Verdict:** OK
**Suggested action:** brak.

#### Claim C — Codex 0.117 lacked custom-tool hook support, wymaga ≥ 0.126
**Docs says:** Docs nie wspomina wersji 0.117/0.126. Stwierdzenie ADR
opiera się na PoC C1 (empirycznie sprawdzone), nie na docs.
**Verdict:** UNVERIFIED z docs (ale ADR powołuje się na PoC, nie na
docs — co jest legitymne).
**Suggested action:** brak; spec.md powinien explicit oznaczyć
"empirical anchor" vs "docs anchor".

#### Claim D — `required = true` na MCP server hard-fails session creation
**Docs says:** `/codex/config-reference` wymienia
`mcp_servers.<id>.startup_timeout_sec` i `enabled`. Pole `required`
**nie jest wymienione** w pobranym wyciągu.
**Verdict:** UNVERIFIED
**Suggested action:** Sprawdzić bezpośrednio `/codex/mcp` lub pełne
config-reference czy `required` jest legitymny klucz. Jeśli nie —
mechanism PoC C1 T2 może używać innego klucza (np. `enabled`?).
Krytyczne dla "deny-fail-closed by construction" claim.

#### Claim E — `Transport closed` po crash mid-session (Codex nie respawns)
**Docs says:** Docs nie potwierdza explicit. PoC C1 T3 to weryfikował
empirycznie.
**Verdict:** UNVERIFIED z docs (ale empirycznie spójne)
**Suggested action:** brak; pozostaje jako empiryczny anchor.

---

### ADR: decision-codex-approval-proof-schema.md (tylko fragmenty hookowe)

#### Claim A — `UserPromptSubmit` payload zawiera `prompt` field
**Docs says:** `/codex/hooks` UserPromptSubmit:
> Common fields plus: `turn_id`, `prompt` (string – user's message)

Zgodne dosłownie. Pole `prompt` istnieje.
**Verdict:** OK
**Suggested action:** brak.

#### Claim B — UserPromptSubmit nie ma matchera
**Docs says:** `/codex/hooks` UPS:
> Matcher: No – `matcher` field ignored (no matcher support)

Zgodne. ADR nie zakłada matchera — OK.
**Verdict:** OK
**Suggested action:** brak.

#### Claim C — Hook script `ups-approval.sh` może odczytać prompt z STDIN i zapisać token na disk
**Docs says:** UPS hook input = JSON na stdin, output = plain text na
stdout (added as developer context) lub JSON. Hook może mieć dowolne
side-effects (filesystem). Zgodne.
**Verdict:** OK
**Suggested action:** brak.

#### Claim D — Hook może zaobserwować literal user input (vs agent-fabricated)
**Docs says:** Docs **milczy** explicitly o tym czy UPS fires też dla
agent-injected promptów (np. sub-agent calls, hook injection via
`additionalContext`). Z architektury wygląda że UPS fires tylko na
**user-typed** message — bo to jest rola eventu — ale brak jawnego
gwarantu.
**Verdict:** VERIFIED (PoC A1 U1, 2026-04-30) — UPS does NOT re-fire when Stop hook injects stderr via exit 2. Residual D-class risks (subagent UPS, hook `additionalContext`) documented in ADR-2 §"Empirical anchor + residual risks".
**Suggested action:** **Krytyczne** dla forge-resistance claim ADR-2.
Jeśli agent może wywołać UPS via "self-talk" lub
`additionalContext` injection — cały mechanizm tokenu pada.
Empiryczny PoC: czy UPS fires gdy:
  (a) agent wyśle subagent task z fake user message?
  (b) Stop hook wstrzyknie nowy prompt via exit 2?
  (c) hook zwróci `additionalContext`?
Jeśli któreś z tych ścieżek wywołuje UPS — token może być sforgowany
bez user input. To jest blocker do zwalidowania przed v1 cutover.

#### Claim E — Stop hook audit (ADR-7) flags non-hook write to `.approval-pending`
**Docs says:** Stop hook może wykryć diff w plikach (filesystem). To
nie wymaga support ze strony Codex docs — jest pure-disk check.
**Verdict:** OK
**Suggested action:** brak.

---

## Cross-cutting (only this block)

Wzorce widoczne w 2+ ADRach z tego bloku:

### CC-1 — Terminologia "block" vs "continue" jest niezgodna z docs Codex

ADRy 7 (Stop) i pomocniczo 1, 3 używają `continue: true` jako
"pozwól iść dalej". Codex używa odwrotnej (counter-intuitive)
semantyki:
- `decision: "block"` = "kontynuuj turn jeszcze raz" (docs cytuje
  to wprost: "block" = continue).
- `continue: false` = "zatrzymaj turn".

To dotyczy 2 ADRów (Stop, mutation-stack pośrednio). Spec.md MUSI
ujednolicić terminologię na semantykę docs Codex i dodać callout
"counter-intuitive naming — see /codex/hooks" żeby kolejne ADRy się
nie myliły.

### CC-2 — Multiple hooks per event: niepewna semantyka wykonania

ADR hook-activation zakłada że dodanie kolejnego entry do array
spowoduje wykonanie obu (framework + user). Docs **explicit zaznacza
że nie definiuje tej semantyki**. To dotyczy ADR hook-activation
bezpośrednio; pośrednio wpływa na ADR-7 (Stop) jeśli user też ma
custom Stop hook (nie miałby framework Stop hooka — ALE merge mówi
że framework dodaje swój).

Mitygacja zamknięta: PoC A1 U3 (2026-04-30) potwierdził
PASS_ALL_FIRE_UNORDERED. Wszystkie entries odpalają, ordering
nondeterministyczny — ADR-1 dodał constraint "order-independent".
Chain-script wrapper niepotrzebny.

### CC-3 — Mieszanie semantyki Codex vs git pre-commit

ADR mutation-guardrail-stack wymienia `.githooks/pre-commit` razem z
Codex hookami. To dwa różne systemy (Codex hook = lifecycle event;
git hook = VCS event). Lekko myli reading. Cross-cutting tylko o
tyle, że ADR-7 C5 też używa `.precommit.log` jako artefakt L5 —
i Codex Stop hook czyta go. Te dwie warstwy współpracują, ale to
NIE jest jedna kategoria mechanizmu. Spec.md powinien je rozdzielić
fizycznie w prezentacji.

### CC-4 — UNVERIFIED claims oparte na PoC zamiast docs

Trzy claimy są "empirycznie zwalidowane na 0.126" ale docs ich nie
potwierdza:
- `required = true` na MCP server (ADR-1, klucz nie wymieniony w
  config-reference snapshot)
- `Transport closed` semantyka po crash (ADR-1)
- UPS fires tylko na real user input (ADR-2, krytyczne dla forge
  resistance)

Wzorzec: ADRy traktują PoC jako wystarczający anchor. To OK dla
empirycznych zachowań Codex, ale spec.md powinien explicit oznaczać
każdy taki claim jako "PoC-anchored, not docs-anchored" — gdy Codex
zmieni implementację (docs mówi "experimental"), te claimy pierwsze
się posypią. Lista takich claimów do tabeli ryzyka w spec.md.

### CC-5 — Brak dokumentowanego klucza `required` na MCP server (potencjalny blocker)

Drobna nuta ale ważna: claim "session hard-fails when MCP server
required is true" jest jedna z fundamentów "deny-fail-closed by
construction" w ADR-1. Jeśli klucz `required` nie istnieje (lub się
nazywa inaczej, np. `enabled` z dodatkową semantyką, `startup_timeout_sec
= 0` etc.), cały argument fail-closed jest zbudowany na empirycznym
zachowaniu które może się zmienić. Pre-spec.md TODO: bezpośrednia
weryfikacja w `/codex/mcp` lub pełnym `/codex/config-reference`
jakim kluczem osiąga się "session must not start without this MCP up".

---

## Summary recommendation

Żaden z 5 ADRów nie ma BLOCKER drift — wszystkie mechanizmy hookowe
których ADRy używają **istnieją w docs Codex** pod cytowanymi nazwami.
Główne ryzyka są:

1. **Terminologia Stop output** (CC-1) — wymaga przepisania D1/D5
   ADR-7 zanim spec.md zacznie cytować dosłownie.
2. **Multi-hook execution semantics** (CC-2) — PoC E2E przed
   v1 cutoverem; merge logic może wymagać chain-wrappera.
3. **UPS fires tylko na real user input** (Claim D ADR-2) — krytyczne
   dla forge-resistance; bez empirycznego potwierdzenia (że agent
   nie może triggerować UPS) cały approval-token mechanism jest
   spekulatywny. Wymaga PoC.
4. **Klucz `required` na MCP server** (CC-5) — sprawdzić w pełnym
   docs przed spec.md.

Sugerowana kolejność dla spec.md: zaadresować 1+4 w treści ADRów
(reword), 2+3 w sekcji "open PoCs przed cutoverem" w spec.md.
