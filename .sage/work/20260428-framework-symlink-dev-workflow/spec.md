---
title: Symlink ~/.sage/framework jako dev workflow
status: completed
phase: spec
scope: Standard
cycle_id: 20260428-framework-symlink-dev-workflow
created: 2026-04-28
updated: 2026-04-28
owner: alexostl
review: APPROVE WITH MINOR FIXES (sub-agent), all fixes applied
branch_policy: pinned to selfhost, NO forward-merge to codex-port or upstream/main
handoff: |
  Key decisions:
    - Wariant A (symlink only) over B (symlink + install.sh hardening)
    - Rollback default = git clone z alexostl/sage origin (najczystszy)
    - Swap przez `mv → bak`, nie `rm -rf` (reversible)
    - sage upgrade na czarnej liście dopóki symlink aktywny
    - 4 follow-up cycles (install.sh, sage upgrade, prune, drift detector) — out of scope
    - Cykl pinowany do selfhost, nie forward-merge do codex-port
  Open questions: brak
  Risks: install.sh i sage upgrade nadpiszą/popsują symlink; mitygacja przez higienę operacyjną w runbooku
  Next agent should: napisać plan.md z 5 zadaniami (T1-T5 zarysowane na końcu spec)
---

# Spec — Framework symlink dev workflow

## WHAT

Zamienić obecny katalog `~/.sage/framework` (osobny pełen git clone
tego samego repo `alexostl/sage`) na symlink wskazujący na primary
dev checkout `~/Developer/sage-selfhost`.

Po zmianie:

```
~/.sage/framework  →  /Users/alexostl/Developer/sage-selfhost
```

Jeden git checkout zamiast dwóch.

## WHY

1. **Eliminacja driftu** — dziś dwa pełne checkouty wymagają ręcznej
   synchronizacji. Każdy `git pull` na jednym wymaga akcji na drugim.
   Z symlinkiem aktualizacje robi się raz.

2. **Krótszy cykl iteracyjny** — edycja w `sage-selfhost` jest
   natychmiast widoczna jako "nowa wersja frameworka" dla `sage update`
   w consumer repo. Bez kroku "skopiuj zmiany do `~/.sage/framework`".
   (Patrz RISK #3 — to samo jest też ryzykiem, wymaga pre-flight
   checklist przed `sage update` w consumerze.)

3. **Zgodność z user instruction** — "Claude jest source of truth dla
   konwencji portu". Jeden git checkout self-host = jeden source of
   truth, fizycznie.

## HOW

Trzy kroki, wszystkie reversible:

1. **Verify clean state** (powtórzyć tuż przed swap):
   - `~/.sage/framework` clean (`git status` → `nothing to commit`)
   - `~/.sage/framework` na branchu `selfhost`
   - `~/.sage/framework` HEAD identyczny z `sage-selfhost` HEAD
   - Jeśli którykolwiek warunek niespełniony → STOP, zapytaj usera.

2. **Swap z minimalną przerwą + safety backup**:
   ```
   mv ~/.sage/framework ~/.sage/framework.bak.YYYYMMDD-HHMMSS
   ln -s /Users/alexostl/Developer/sage-selfhost ~/.sage/framework
   ```
   `.bak` zostaje jako natychmiastowy lokalny rollback (do usunięcia
   po smoke test). Nie używamy `rm -rf` w tej fazie — wszystko
   reversible przez `mv` w drugą stronę.

3. **Smoke test** (wszystkie z CWD **poza** sage-selfhost, np.
   z `~`, żeby `resolve_framework` musiał skorzystać z `~/.sage/framework`,
   a nie z lokalnej gałęzi `parent_dir/core`):
   - `readlink ~/.sage/framework` → ścieżka docelowa
   - `cd ~ && sage --help` działa, wypisuje sekcję "Project commands"
   - `cd ~ && sage --version` zwraca wersję bez błędu
   - `[ -d ~/.sage/framework/core ]` true (bash `-d` przechodzi przez symlink)
   - W consumer projekcie (np. `~/Developer/safe-rent-v1`):
     `git status` przed → `sage update --dry-run` (jeśli istnieje) lub
     przeczytanie informacji o ścieżce frameworka w wyjściu sage
     bez wykonania update — sprawdzenie czy framework rozpoznany.

4. **Cleanup** (po pomyślnym smoke test):
   - `rm -rf ~/.sage/framework.bak.*` (dopiero po manualnym confirm)

## DONE-WHEN

- `~/.sage/framework` jest symlinkiem do `~/Developer/sage-selfhost`
  (weryfikacja: `[ -L ~/.sage/framework ]` zwraca true,
  `readlink ~/.sage/framework` zwraca docelową ścieżkę)
- `cd ~ && sage --help` działa bez błędu
- **Symlink resolution potwierdzony**: w consumer projekcie (np.
  `~/Developer/safe-rent-v1`) komenda którakolwiek wypisująca
  `SAGE_FRAMEWORK_DIR` (np. zmienna eksportowana po `resolve_framework`,
  linia 738 `bin/sage`) zwraca `~/.sage/framework` lub równoważną
  ścieżkę przechodzącą przez symlink. Jeśli `bin/sage` nie ma
  jawnego "print path" — alternatywa: `cd ~ && bash -x $(which sage) --help 2>&1 | grep SAGE_FRAMEWORK | head -3` (trace) lub
  `python3 -c 'import os; print(os.path.realpath(os.path.expanduser("~/.sage/framework")))'`
  zwraca `/Users/alexostl/Developer/sage-selfhost`.
- Decyzja zapisana w `.sage/decisions.md` (prepended, najnowsza pierwsza)
- Plan rollback w **jednoznacznej** lokalizacji:
  `.sage/docs/runbooks/framework-rollback.md` (nowy plik)
- Manifest cyklu w `.sage/work/20260428-framework-symlink-dev-workflow/manifest.md`
  (frontmatter z `phase`, `status`, `updated`, `handoff`; sekcje:
  context summary, decisions, current state)
- `~/.sage/framework.bak.*` usunięty po smoke test

## SCOPE OUT (nie w tym cyklu — z konkretnymi follow-up cycles)

- **Hardening `install.sh`** (`install.sh:49,61,68,100,109`) żeby
  wykrywał symlink i odmawiał `rm -rf` bez jawnej flagi. Upstream-relevant
  (idzie do `xoai/sage` PR). Follow-up cycle: `sage-install-symlink-guard`.
- **Hardening `sage upgrade`** (`bin/sage:1183`) żeby wykrywał symlink
  i odmawiał `git pull --ff-only`. Upstream-relevant. Follow-up cycle:
  `sage-upgrade-symlink-guard`.
- **Rozszerzenie `prune_framework_copy`** (`bin/sage:354`) żeby
  filtrowało też `.sage/`, `.sage-memory/`, `.claude/`, `.codex/`,
  `install.sh` z framework copy w consumerze. To **niezależny bug-fix**
  (poprawia zachowanie dla wszystkich userów Sage, nie tylko self-host).
  Upstream-relevant. Follow-up cycle: `sage-update-prune-extended`.
- **Drift detector / pre-flight hook** — pre-flight check przed
  `sage update` ostrzegający że sage-selfhost ma WIP w `sage/core/...`.
  Upstream-relevant. Follow-up cycle: `sage-update-dirty-worktree-warning`.

**Uwaga**: `sage-update-prune-extended` i `sage-update-dirty-worktree-warning`
są **komplementarne, nie alternatywne**. Pierwszy filtruje co leci do
consumera (ochrona by-default), drugi ostrzega zanim filtruje (ochrona
przed surprise). Idealnie obie naraz, ale można robić sekwencyjnie —
prune najpierw (większa wartość), warning potem.
- **Edycja consumer repo** (`alex-os-dev`, `safe-rent-v1`) — nie tutaj
  (per memory `bd634e11` — cross-repo wymaga jawnej zgody).
- **Rebuild z `xoai/sage` upstream (vanilla)** — osobna decyzja jeśli
  kiedyś trzeba.

## BRANCH POLICY / upstream exclusion

**Ten cykl jest pinowany do gałęzi `selfhost`. NIE forward-merge
do `codex-port` ani do `upstream/main` (xoai/sage).**

Powody:
1. Symlink `~/.sage/framework -> ~/Developer/sage-selfhost` to **lokalny
   dev workflow** specyficzny dla setupu Aleksandra (jeden checkout,
   alex-os ekosystem). Codex-port i vanilla Sage zakładają standardową
   instalację (`install.sh` → kopia w `~/.sage/framework`).
2. Artefakty tego cyklu (`spec.md`, `plan.md`, `manifest.md`,
   `decisions.md` entries) żyją w `.sage/work/` i `.sage/docs/runbooks/`,
   które są **gitignored** w sage-selfhost (`!.sage/docs/` whitelist
   nie obejmuje `runbooks/`). Nie poleciałyby do gita w normalnym
   workflow, ale ten zapis jest jawnym przypomnieniem.
   **Nawet jeśli kiedyś ktoś świadomie doda runbook do whitelisty
   `.gitignore` (np. żeby zsynchronizować dev-environment między
   maszynami), to NIE forward-mergujemy go do codex-port — symlink
   to lokalny dev-setup, nie cecha frameworka Sage.**
3. Mitygacje #2-#4 z sekcji powyżej (hardening install.sh, sage upgrade,
   prune_framework_copy, drift detector) **mają być rozwijane jako
   upstream-friendly cycles** — z fresh worktree z `upstream/main`,
   żeby nie ciągnąć self-host kontekstu. Per pattern z decision
   "Narrow palette is now the global self-host default" (commit
   `5a0bfef` z explicit "DO NOT FORWARD-MERGE TO codex-port" warning).

**Kontrakt dla przyszłego agenta**: jeśli pracujesz w worktree z
`codex-port` lub `upstream/main` i widzisz `~/.sage/framework` jako
symlink — to nie znaczy że masz odtworzyć ten setup w innej gałęzi.
Symlink istnieje tylko w lokalnym filesystem userze, nie w żadnej gałęzi
gita. Pracuj jakby to był zwykły katalog (bin/sage tego nie odróżnia).

## RISKS i mitygacje

| # | Ryzyko | Mitygacja |
|---|---|---|
| 1 | `install.sh` `rm -rf` zniszczy symlink | Operacyjna higiena: nie odpalać `install.sh` w dev. Hardening = osobny cycle. Rollback = trywialny re-clone. |
| 2 | `sage upgrade` (`bin/sage:1183`) zrobi `git pull --ff-only` na sage-selfhost zamiast osobnego checkoutu — może wciągnąć niechciane zmiany albo zepsuć WIP / inny branch | **Nie odpalać `sage upgrade`** dopóki `~/.sage/framework` jest symlinkiem. Aktualizować framework przez normalny git workflow w `sage-selfhost` (`git pull` ręcznie na właściwym branchu). Udokumentować w runbooku. |
| 3 | Niezacommitowane edycje w `sage/core/...` w sage-selfhost natychmiast widoczne dla `sage update` w consumerze. **Kluczowy fakt**: `sage update` woła `cp -a "$SAGE_FRAMEWORK" "$target/sage"` (`bin/sage:568,1061`), a `prune_framework_copy` (`bin/sage:354`) filtruje **tylko** `.git/`, `.github/`, `.tmp/`, `.DS_Store`. Niezacommitowane pliki, `.sage/`, `.sage-memory/`, `.claude/`, `install.sh` — wszystko leci do `target/sage/`. | **Pre-flight checklist** w runbooku przed każdym `sage update` w consumerze: `cd ~/Developer/sage-selfhost && git status` (clean? jeśli nie → stash lub commit) + `git branch --show-current` (oczekiwany branch?). Memory `fd94a21b` — user świadomie zaakceptował że bezpiecznikiem jest jawne, ręczne odpalenie update. Mitigacje strukturalne (rozszerzenie `prune_framework_copy`, drift detector) → SCOPE OUT, follow-up cycles. |
| 4 | Inny branch w sage-selfhost (np. feature) leaky do consumera | **Pre-flight przed `sage update`**: `cd sage-selfhost && git branch --show-current` — sprawdź czy stoisz tam gdzie chcesz. Cecha dla iteracji feature-branch, nie bug. |
| 5 | `sage_init` w sage-selfhost (przez symlink) nieoczekiwane zachowanie | `is_framework_repo` guard (`bin/sage:884`) już istnieje — odmawia init w frameworku bez `SELF_HOST_FLAG`. Bezpieczne. |
| 6 | `git -C ~/.sage/framework <op>` operuje teraz na sage-selfhost | Udokumentować w runbooku jako alias, nie osobne repo. Tylko jedna realna komenda Sage używa tego: `sage upgrade` (patrz #2). |
| 7 | `bin/sage` `[ -d ~/.sage/framework/core ]` test nie przejdzie przez symlink | Sprawdzone: bash `-d` przechodzi przez symlinki. `resolve_framework()` (linie 144-145) zadziała bez zmian. |

## ROLLBACK

Trzy warianty od **najczystszego**:

1. **Świeży clone z `alexostl/sage` origin** (DEFAULT — najczystszy):
   ```
   unlink ~/.sage/framework
   git clone https://github.com/alexostl/sage.git ~/.sage/framework
   git -C ~/.sage/framework checkout selfhost
   ```
   Nie ciągnie gitignored content z sage-selfhost (`.sage/work/`,
   `.sage-memory/` itp.). Wraca do stanu "dwa niezależne checkouty
   selfhost".

2. **Lokalny `.bak`** (jeśli jeszcze istnieje, fastest):
   ```
   unlink ~/.sage/framework
   mv ~/.sage/framework.bak.YYYYMMDD-HHMMSS ~/.sage/framework
   ```
   Tylko jeśli swap się odbył niedawno i `.bak` nie został wyczyszczony
   przez krok 4.

3. **`install.sh` z lokalnego sage-selfhost** (NIE czysty):
   ```
   unlink ~/.sage/framework
   bash ~/Developer/sage-selfhost/install.sh
   ```
   `cp -a` skopiuje też gitignored content (`.sage/work/`, lokalne
   notatki). Działa, ale `~/.sage/framework` zostanie z bagażem
   admin-state. Używać tylko gdy nie ma sieci na `git clone`.

4. **Vanilla Sage z `xoai/sage` upstream**:
   ```
   curl -fsSL https://raw.githubusercontent.com/xoai/sage/main/install.sh | bash
   ```
   Wraca do oryginalnego Sage, **traci self-host fork** — używać
   tylko świadomie.

Domyślny rollback = wariant 1 (`git clone` z origin).

## handoff

Key decisions:
- Wariant A (symlink only) zatwierdzony nad wariantem B (symlink +
  install.sh hardening). Hardening = osobny cycle później.
- Rollback domyślny = `git clone` z `alexostl/sage` origin
  (wariant 1, najczystszy bez gitignored bagażu).
- Swap nie używa `rm -rf` — robimy `mv` na `.bak`, czyszczone dopiero
  po smoke test.
- `sage upgrade` zostaje **na czarnej liście** dopóki symlink jest
  aktywny — git pull tylko ręcznie w sage-selfhost.

Open questions: brak.

Risks: install.sh i sage upgrade nadpiszą/popsują symlink — bez
hardeningu w tym cyklu, tylko higiena operacyjna.

Next agent should: napisać plan.md z 4-5 zadaniami:
  T1. Pre-flight verify clean (powtórka w runtime)
  T2. Swap (mv → bak, ln -s)
  T3. Smoke test z CWD poza sage-selfhost
  T4. Dokumentacja: runbook rollback w `.sage/docs/runbooks/`,
      decisions.md prepend, manifest.md
  T5. Cleanup `.bak` po manualnym confirm
