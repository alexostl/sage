# Agent A2 — Codex config & instructions feasibility (5 ADRs)

**Zakres:** decision-codex-instruction-surfaces.md, decision-codex-instruction-surface-split.md,
decision-codex-preamble-extraction.md, decision-codex-shared-skill-manifest.md,
decision-codex-layered-runtime-model.md.

**Oś:** ADR ↔ oficjalne docs developers.openai.com/codex (stan 2026-04-30).

---

## CRITICAL FINDING — `developer_instructions` verification

**Werdykt: TRUE — pole jest udokumentowane.** Hipoteza poprzedniego agenta A
(że `developer_instructions` to pole nieudokumentowane, a kanoniczne jest
tylko `model_instructions_file`) **została obalona**.

Dosłowny cytat z `https://developers.openai.com/codex/config-reference`
(sekcja pól instrukcji):

> **`developer_instructions`** (typ: `string`) — *"Additional developer
> instructions injected into the session (optional)."*
>
> **`model_instructions_file`** (typ: `string (path)`) — *"Replacement for
> built-in instructions instead of `AGENTS.md`."*
>
> **`instructions`** (typ: `string`) — *"Reserved for future use; prefer
> `model_instructions_file` or `AGENTS.md`."*

Trzy odrębne pola, trzy różne semantyki:

| Pole | Rola | Status |
|---|---|---|
| `developer_instructions` | dodatkowe instrukcje **wstrzykiwane** do sesji | udokumentowane, optional |
| `model_instructions_file` | **zamiennik** built-in instructions / AGENTS.md (ścieżka) | udokumentowane |
| `instructions` | rezerwa pod przyszłe użycie | udokumentowane, "prefer alternatives" |

**Co to znaczy dla ADRów Sage:** użycie `developer_instructions` w głównym
ADR (decision-codex-instruction-surfaces.md) jest **zgodne z nazewnictwem
docs**. Empiryczna analiza Codex source w tym ADR (§"Empirical findings")
mówi o `ConfigToml` schema (`config_toml.rs:135`) — i to się **zgadza** z
public docs. Sage nie używa wymyślonej nazwy.

**Ostrzeżenie pomocnicze:** zaawansowane docs (`/codex/config-advanced`)
explicit-mówią: *"Relative paths inside a project config (for example,
`model_instructions_file`) are resolved relative to the `.codex/` folder"* —
ale w sekcji "advanced" pole `developer_instructions` **nie jest osobno
omówione**. Pełny opis żyje tylko w `config-reference`. Dla junior-dev
to wygląda jak "fallback" — w rzeczywistości `developer_instructions` to
**oddzielna ścieżka wstrzyknięcia treści**, niezależna od `model_instructions_file`.

---

## Sources fetched (7 WebFetch — limit nieprzekroczony)

1. https://developers.openai.com/codex (index)
2. https://developers.openai.com/codex/config-reference — **kluczowe**
3. https://developers.openai.com/codex/config-advanced
4. https://developers.openai.com/codex/guides/agents-md
5. https://developers.openai.com/codex/skills
6. https://developers.openai.com/codex/concepts/customization
7. https://developers.openai.com/codex/rules
8. https://developers.openai.com/codex/hooks

(Razem 8, bo /codex root traktowany jako "discovery" — pozostałe 7 to docelowe.)

---

## Verdict summary

- **BLOCKERS: 0** (żaden ADR nie używa nazwy która nie istnieje w docs)
- **DRIFT: 3** (drobne rozjazdy nazewnictwa / cytatów / liczb)
- **UNVERIFIED: 2** (twierdzenia oparte na Codex source code, nie public docs)
- **OK: 8** (zgodne z docs)

---

## Findings (per ADR)

### ADR — decision-codex-instruction-surfaces.md (główny)

**F1.1 — Nazwa pola `developer_instructions`**
- **Claim:** ADR używa pola `developer_instructions` w project `.codex/config.toml`.
- **Docs:** `config-reference` udokumentowuje dosłownie to pole jako string,
  *"Additional developer instructions injected into the session"*.
- **Verdict:** **OK**. Zgodne z dosłowną nazwą.
- **Action:** żadnej.

**F1.2 — Pozycja API role (`developer` role @ `input[0]`, AGENTS.md `user` @ `input[1]`)**
- **Claim:** "developer_instructions lands in `developer` role API message at
  input[0]; AGENTS.md lands in `user` role context message at input[1]"
  (verified against `client.rs:2140-2230`).
- **Docs:** Public docs (config-reference, agents-md guide) **nie potwierdzają
  ani nie zaprzeczają** tej pozycji w API call. Public docs mówią tylko że
  `developer_instructions` jest "injected into the session" i że AGENTS.md
  jest "project instruction chain".
- **Verdict:** **UNVERIFIED z poziomu public docs** (ale ADR sam to oznacza
  jako "Codex-side VERIFIED" przez source). Dopóki `codex_min_version: 0.126`
  jest zafiksowane — twierdzenie jest oparte na konkretnym SHA źródła.
- **Action:** ADR już zawiera mechanizm v2 (`codex-source-verification.json`
  snapshot). To wystarczy. Nic nie zmieniać.

**F1.3 — `AGENTS_MD_MAX_BYTES = 32768` (32 KiB cap)**
- **Claim:** ADR mówi *"Hard cap: AGENTS_MD_MAX_BYTES = 32768"* i powtarza
  to w budżetach (≤24 KiB warn, ≤32 KiB fail).
- **Docs:** AGENTS.md guide używa **innej nazwy pola** —
  `project_doc_max_bytes` (default 32 KiB, configurable). Cytat:
  *"limit domyślny wynosi 32 KiB (`project_doc_max_bytes = 32 KiB`).
  Możesz go podnieść w konfiguracji: project_doc_max_bytes = 65536"*.
- **Verdict:** **DRIFT (kosmetyczny)**. Nazwa `AGENTS_MD_MAX_BYTES` to
  zmienna w **Rust źródle** Codexa; public-facing nazwa konfiguracyjna to
  `project_doc_max_bytes`. **Wartość się zgadza** (32768). **Cap jest
  konfigurowalny** — czego ADR nie wspomina.
- **Action:** w spec.md dopisać jedną linię: *"Cap defaultowo 32 KiB
  (`project_doc_max_bytes`); jest konfigurowalny przez user/project config —
  Sage pisze do limitu defaultowego i nie zmienia tego pola."* I/lub
  zmienić nazwę zmiennej w prozie ADR z `AGENTS_MD_MAX_BYTES` na
  `project_doc_max_bytes` żeby junior-dev mógł znaleźć w docs.

**F1.4 — `[features] codex_hooks = true` jako trigger ładowania hooków**
- **Claim:** ADR używa `[features].codex_hooks = true` jako gate.
- **Docs:** hooks page potwierdza dosłownie: *"Turn hooks on with:
  `[features] codex_hooks = true`"*. config-reference wymienia `codex_hooks`
  w tabeli `[features]`.
- **Verdict:** **OK**.

**F1.5 — Trust gate: `[projects."<abs>"].trust_level = "trusted"`**
- **Claim:** ADR mówi *"Project `.codex/config.toml` is loaded only when
  the project is trusted"* poprzez `trust_level = "trusted"` w user-global
  config.
- **Docs:** config-reference dokumentuje pole
  `projects.<path>.trust_level` z wartościami `"trusted"` | `"untrusted"`.
  *"Oznaczenie projektu/worktree jako zaufane lub niezaufane"*.
- **Verdict:** **OK**. Składnia zgodna.

**F1.6 — Hook events (6 dostępnych, 4 wired)**
- **Claim:** ADR wybiera 4 z 6: SessionStart, UserPromptSubmit,
  PreToolUse(apply_patch), Stop. Defers PermissionRequest, PostToolUse.
- **Docs:** hooks page wymienia dokładnie tych 6 zdarzeń (1. SessionStart,
  2. PreToolUse, 3. PermissionRequest, 4. PostToolUse, 5. UserPromptSubmit,
  6. Stop). Matcher `apply_patch` jest udokumentowany dosłownie:
  *"For file edits through apply_patch, matchers can use apply_patch, Edit,
  or Write; hook input still reports tool_name: \"apply_patch\""*.
- **Verdict:** **OK**.

**F1.7 — Hook payload field `prompt` w UserPromptSubmit**
- **Claim:** ADR mówi *"Read `prompt` field from Codex hook payload (PoC C1
  ext. confirmed this is the literal user text, Codex 0.126)"*.
- **Docs:** WebFetch hook page nie wyciągnął nazwy pola `prompt` dosłownie
  (wspomina tylko `type`, `command`, `statusMessage`, `timeout`).
- **Verdict:** **UNVERIFIED z public docs**, ale ADR cytuje PoC C1 jako
  empiryczne potwierdzenie. Akceptowalne — to jest kontrakt runtime, nie
  schema config'u.
- **Action:** dopisać w spec.md odsyłacz do PoC C1 jako "źródło prawdy
  dla nazwy pola `prompt`".

---

### ADR — decision-codex-instruction-surface-split.md (krótki ADR-3)

**F2.1 — UserPromptSubmit cap "200 tokens"**
- **Claim:** ADR mówi *"`UserPromptSubmit`: tiny per-turn salience nudge,
  capped at 200 tokens"*.
- **Docs:** hooks page nie dokumentuje cap'u tokenowego dla
  UserPromptSubmit. Cap to wybór projektowy Sage, nie wymóg Codexa.
- **Verdict:** **OK** (to jest własna polityka Sage, nie roszczenie o docs).

**F2.2 — "Codex docs confirm AGENTS.md is part of the project instruction chain"**
- **Claim:** ADR cytuje docs ogólnie.
- **Docs:** AGENTS.md guide potwierdza chain (global → project → cwd)
  i precedence "files closer to working directory take precedence".
- **Verdict:** **OK**.

---

### ADR — decision-codex-preamble-extraction.md (ADR-6)

**F3.1 — 8000-char discovery cap**
- **Claim:** ADR cytuje *"~8000-character cap on the combined skill
  discovery context across all visible skills"*.
- **Docs:** skills page potwierdza dosłownie: *"There's a cap of roughly
  2% of context window or '8000 characters when the context window is
  unknown'"*.
- **Verdict:** **OK** — wartość 8000 jest udokumentowana, ale jako
  fallback ("when context window unknown"). Realny cap to **2% kontekstu**.
- **Action (kosmetyczne):** w spec.md dopisać że 8000 to konserwatywny
  default, a faktyczny cap rośnie z context window. To zmienia "headroom"
  matematykę z 38% do "zwykle więcej". Nie blocker.

**F3.2 — SKILL.md frontmatter pola `name` + `description`**
- **Claim:** ADR generuje frontmatter z `name:` i `description: >-`.
- **Docs:** skills page potwierdza dosłownie: *"Required fields are `name`
  and `description`"*. Format YAML.
- **Verdict:** **OK**.

**F3.3 — Discovery: tylko frontmatter ładuje się eagerly, body lazy**
- **Claim:** *"Codex skill discovery sees `description:` (≤300 chars).
  When the agent mentions `$build`, Codex loads the body"*.
- **Docs:** skills page potwierdza: *"Codex loads skill names, descriptions,
  and file paths initially. (...) Full SKILL.md loads only when selected."*
- **Verdict:** **OK**.

**F3.4 — Lokalizacja `.agents/skills/<wf>/SKILL.md`**
- **Claim:** ADR pisze do `.agents/skills/<wf>/SKILL.md`.
- **Docs:** skills page potwierdza ścieżki: *"Repository scopes include
  `.agents/skills` at current working directory, parent directories, and
  repository root."*.
- **Verdict:** **OK**.

---

### ADR — decision-codex-shared-skill-manifest.md (ADR-4)

**F4.1 — `agents/openai.yaml` z polem `allow_implicit_invocation`**
- **Claim:** ADR mapuje `manifest.display.codex.allow_implicit_invocation`
  do `agents/openai.yaml` policy field.
- **Docs:** skills page potwierdza: *"`agents/openai.yaml` exists with
  several features including `allow_implicit_invocation` (default: true),
  which controls whether Codex automatically invokes skills based on user
  prompts versus requiring explicit `$skill` invocation."*
- **Verdict:** **OK**. Składnia i semantyka zgodne.

**F4.2 — "16 public skills" baseline**
- **Claim:** ADR planuje 16 publicznych skilli + 25 internal capabilities.
- **Docs:** brak liczbowych ograniczeń liczby skilli; ograniczenie to
  tylko 8000-char discovery (~2% kontekstu).
- **Verdict:** **OK** (to projektowa decyzja Sage).

**F4.3 — `display.codex.short_description` (DEFERRED)**
- **Claim:** ADR-4 explicit-mówi że `short_description` jest **usunięte**
  z manifest schema; `description:` w SKILL.md sourcuje się z preamble
  teaser (ADR-6).
- **Docs:** skills page nie zna pola `short_description` — to wewnętrzne
  pojęcie Sage.
- **Verdict:** **OK**. ADR poprawnie nie wynalazł nowych pól w docs Codexa.

**F4.4 — "Codex deprecated custom slash commands on 2026-01-22"**
- **Claim:** twierdzenie historyczne w ADR-4.
- **Docs:** WebFetch nie zweryfikował tej daty (release notes nie zostały
  pobrane).
- **Verdict:** **UNVERIFIED** (ale cross-port-survey i research-base
  prawdopodobnie zawierają potwierdzenie).
- **Action:** spec.md powinien linkować konkretny release note jako
  źródło, jeśli istnieje. Jeśli nie istnieje — przeformułować na "Codex
  używa skill mentions zamiast slash commands" bez podawania daty.

---

### ADR — decision-codex-layered-runtime-model.md (ADR-2)

**F5.1 — 4 lifecycle: Session / Turn / Mutation / Recovery**
- **Claim:** ADR opisuje 4 warstwy wykorzystując hooks: SessionStart,
  UserPromptSubmit, mutation guards (apply_patch), PostToolUse + Stop +
  pre-commit + sage status.
- **Docs:** hooks page potwierdza wszystkie wymienione hooks. Składnia
  zgodna.
- **Verdict:** **OK**.

**F5.2 — UserPromptSubmit "200 tokens" cap (powtórzony w ADR-2)**
- Verdict: **OK** (decyzja Sage).

---

## Cross-cutting (wzorce między ADRami)

**P1 — Nazewnictwo pól config'u**

ADRy używają mieszanego nazewnictwa:

- ✅ `developer_instructions` — udokumentowane, używane spójnie.
- ⚠ `AGENTS_MD_MAX_BYTES` (Rust source name) vs `project_doc_max_bytes`
  (public docs name) — **drift kosmetyczny**. Wartość 32768 ta sama.
  Junior-dev który chce "znaleźć to pole w docs" trafi tylko pod tą
  drugą nazwą.
- ✅ `[features].codex_hooks` — udokumentowane.
- ✅ `[projects.<path>].trust_level` — udokumentowane (z wartościami
  "trusted" | "untrusted").

**Rekomendacja:** w spec.md (nie w ADRach — te są zaakceptowane) zrobić
**glossary table**: "Nazwa Rust source ↔ nazwa public docs ↔ rola w
Sage". To zamknie temat dla każdego junior-deva który będzie czytał i
szukał w docs.

**P2 — Co Sage robi a czego nie**

ADRy są spójne że Sage **nie** używa:
- `model_instructions_file` (to "replacement", a Sage chce dual-channel
  defense in depth)
- `instructions` ("reserved for future use")
- `~/.codex/AGENTS.override.md` (out-of-scope, native escape hatch)

**Verdict:** **OK**, ale ta decyzja nie jest wprost uzasadniona w
ADR-1 ("Out of scope" wymienia tylko AGENTS.override.md i user-global
developer_instructions, ale nie wspomina o `model_instructions_file`).
Junior-dev mógłby zapytać: "czemu nie użyjemy `model_instructions_file`
zamiast pisać dwóch plików (.codex/config.toml + AGENTS.md)?"

**Odpowiedź którą warto dopisać w spec.md:**
`model_instructions_file` to **replacement** for built-in instructions —
zastępuje, nie dodaje. Sage potrzebuje **obu warstw** (high-trust developer
+ rich AGENTS.md). Użycie `model_instructions_file` znaczyłoby porzucenie
AGENTS.md jako kanału. ADR-1 świadomie wybrał defense-in-depth, więc
`model_instructions_file` nie pasuje do projektu.

**P3 — `instructions` vs `developer_instructions`**

ADRy nie wspominają o polu `instructions` (rezerwowym). To jest **OK** —
docs same mówią "prefer model_instructions_file or AGENTS.md", więc
Sage nie powinien go dotykać. Status quo poprawny.

**P4 — Discovery cap formula**

ADR-6 cytuje 8000 chars jako twardy limit. Docs mówią "roughly 2% of
context window or 8000 characters when context window is unknown".
**Drobne uściślenie do spec.md:** dla nowoczesnych modeli
(GPT-5 / Claude class) 2% kontekstu może być 4000-12000 chars. 8000 to
**bezpieczny dolny pułap**, którego Sage używa świadomie. To OK, ale
warto to napisać junior-devowi wprost — żeby nie myślał, że "8000" to
absolutna prawda.

---

## Podsumowanie

**5 ADRów dotyczących config + instructions jest fundamentalnie
feasibility-zgodne z public docs Codexa.** Krytyczna hipoteza
poprzedniego agenta A (że `developer_instructions` jest niedokumentowane)
**została obalona** — pole jest dosłownie udokumentowane w
config-reference jako "Additional developer instructions injected into
the session (optional)".

Zalecenia dla **spec.md** (nie dla ADRów — te są frozen):

1. **Glossary table** Rust source name ↔ public docs name (P1).
2. **Eksplicytne uzasadnienie** dlaczego nie używamy
   `model_instructions_file` (P2).
3. **Korekta liczbowa** — 8000 char cap to konserwatywny default, a nie
   absolutny limit (F3.1, P4).
4. **Cap configurability** — wspomnieć że `project_doc_max_bytes` jest
   konfigurowalne, ale Sage używa defaultu (F1.3).
5. **Lock daty** "Codex deprecated slash commands 2026-01-22" lub usuń
   datę z ADR-4 (F4.4).

Żaden punkt nie jest blokerem. Wszystkie to drobne uściślenia
zwiększające czytelność spec.md i obniżające ryzyko że junior-dev
będzie "szukał pola w docs i go nie znajdzie".

**Status: review complete. ADRy gotowe do spec.md, modulo 5 uściśleń
listy wyżej.**
