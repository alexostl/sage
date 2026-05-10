---
cycle_id: 20260428-framework-symlink-dev-workflow
title: Plan — Framework symlink dev workflow
phase: plan
status: completed
scope: Standard
created: 2026-04-28
updated: 2026-04-28
owner: alexostl
branch_policy: pinned to selfhost, NO forward-merge to codex-port
spec: spec.md (completed, double-reviewed)
review: APPROVE WITH MINOR FIXES (sub-agent), all 8 fixes applied
handoff: |
  Plan zatwierdzony po cold-read review (verdict APPROVE WITH MINOR FIXES,
  0 critical). Wszystkie 8 minor fix zaaplikowane: TS scope (compound
  bash), gitfile check (exit-coded), gitignore świadomość runbook'a,
  consumer fallback, 2 nowe ryzyka (concurrent + interrupted), paste
  discipline jawne (Rule 5), time estimate realistyczny (20-30 min wall
  clock), manifest pre-flight w T4.
  Następny krok: T1 pre-flight verify (5 + opcjonalna 6. kontrola perms).
---

# Plan — Framework symlink dev workflow

5 zadań, każde z jasnym DONE-criterion. Dwa inter-task checkpointy
([A]/[R]): po T2 (swap zrobiony, przed smoke test) i po T5 (cykl
zamknięty).

---

## T1 — Pre-flight: weryfikacja clean state

**Cel**: potwierdzić że `~/.sage/framework` jest bezpieczny do swap'u
(brak lokalnych zmian, ten sam HEAD co sage-selfhost).

**Kroki**:

1. `git -C ~/.sage/framework status` → musi zwrócić "nothing to commit,
   working tree clean".
2. `git -C ~/.sage/framework branch --show-current` → musi zwrócić
   `selfhost`.
3. `git -C ~/.sage/framework rev-parse HEAD` i porównać z
   `git -C ~/Developer/sage-selfhost rev-parse HEAD` — muszą być
   identyczne.
4. `ls -ld ~/.sage/framework` → pierwszy znak musi być `d` (katalog).
   Jeśli `l` (symlink) → ktoś już to zmienił, abort i sprawdź stan.
5. `[ -d ~/.sage/framework/.git ] && echo "OK: regular .git directory" || echo "WORKTREE/GITFILE detected — abort"`.
   Worktree miałyby `.git` jako plik tekstowy z `gitdir: ...`, nie
   katalog. Plan zakłada regular clone, nie worktree.

**DONE**: wszystkie 5 kontroli zielone. Wynik komend wklejony do
output sesji jako evidence.

**Jeśli któryś warunek niespełniony** → STOP, present do usera:
- "framework ma niezacommitowane: <files> — co zrobić? [stash / commit / abort]"
- "framework na branchu <X> ≠ `selfhost` — co zrobić? [checkout / abort]"
- "HEAD się różni — co zrobić? [pull / abort]"

**Files involved**: read-only operacje, brak edycji.

---

## T2 — Swap: katalog → symlink (z safety backup)

**Cel**: wykonać atomową(ish) zamianę z zachowaniem natychmiastowego
lokalnego rollbacku.

**Kroki** (wykonać jako **jeden compound bash command**, żeby `$TS`
przeżyło między mv i ln; potem zapisać `$TS` do manifestu T4):

1. Single compound:
   ```
   TS=$(date +%Y%m%d-%H%M%S) && \
   mv ~/.sage/framework ~/.sage/framework.bak.$TS && \
   ln -s /Users/alexostl/Developer/sage-selfhost ~/.sage/framework && \
   echo "TS=$TS" && \
   echo "BAK=$HOME/.sage/framework.bak.$TS"
   ```
   Output `TS=...` musi być wklejony do output sesji — używamy go
   w T4 (manifest log) i T5 (cleanup target).

2. Weryfikacja natychmiastowa (osobne komendy, każda exit-coded):
   - `[ -L ~/.sage/framework ]` → exit 0 (symlink istnieje)
   - `readlink ~/.sage/framework` → `/Users/alexostl/Developer/sage-selfhost`
   - `[ -d ~/.sage/framework/core ]` → exit 0 (test `-d` przez symlink)

**DONE**: wszystkie 3 weryfikacje zielone. Wynik wklejony jako pełen
output (Sage Rule 5 — paste actual output, NIE summary).

**Rollback przy niepowodzeniu** (`$TS` z kroku 1):
```
unlink ~/.sage/framework
mv ~/.sage/framework.bak.<wklejony-TS> ~/.sage/framework
```
Jeśli `$TS` zgubiony z sesji → `ls -1 ~/.sage/framework.bak.* | tail -1`
zwróci najnowszy `.bak`.

**Files involved**: filesystem only (nie edycja repo). Działanie
ograniczone do `~/.sage/`.

🔒 **CHECKPOINT po T2 (przed smoke test):**

Sage: Swap wykonany. `~/.sage/framework` jest symlinkiem.
`.bak.$TS` zachowany jako safety net.

[A] Approve — przechodzę do smoke test (T3)
[R] Revise — coś nie tak, opisz co
[B] Rollback — odwróć swap (`unlink + mv`), wrócimy do dwóch checkoutów

Wybierz A/R/B.

---

## T3 — Smoke test (z CWD poza sage-selfhost)

**Cel**: potwierdzić że `bin/sage` faktycznie chodzi przez symlink,
nie przez lokalny `parent_dir/core` z którego mogłaby być wywołana.

**Kroki** (wszystkie z `cd ~`, żeby `resolve_framework` musiał wpaść
w gałąź `$HOME/.sage/framework`):

1. `cd ~ && which sage` → `/Users/alexostl/.local/bin/sage` lub
   `/Users/alexostl/.sage/framework/bin/sage` (zależnie od PATH).
2. `cd ~ && sage --help` → wypisuje sekcję "Project commands"
   bez błędu.
3. `cd ~ && python3 -c 'import os; print(os.path.realpath(os.path.expanduser("~/.sage/framework")))'`
   → `/Users/alexostl/Developer/sage-selfhost`. Potwierdza że
   `realpath` resolve'uje przez symlink do oczekiwanego targetu.
4. `cd ~ && ls -la ~/.sage/framework/bin/sage` → plik istnieje,
   wykonalny.
5. **Consumer-side test** (read-only, bez `sage update`, **opcjonalny**
   — kroki 1-4 są wystarczające dla DONE):
   - Wybrać consumer z `.sage/`: `~/Developer/safe-rent-v1` lub
     `~/Developer/alex-os-dev` lub jakikolwiek inny dev project.
   - Jeśli żaden nie istnieje → pominąć krok 5 (nie blokuje DONE).
   - `cd <consumer> && cat .sage/.sage-framework-source 2>/dev/null` —
     pokaże skąd framework był ostatnio kopiowany; informacyjnie.
   - **NIE odpalać `sage update`** w tym kroku — to byłaby zmiana
     consumer state (per memory `bd634e11` cross-repo writes wymaga
     osobnej zgody). Tylko weryfikacja że `sage --help` z consumer
     directory działa: `sage --help`.

**DONE**: kroki 1-4 zielone z **pełnym pasted output** (Sage Rule 5 —
paste actual output, NIE streszczenie). Krok 5 opcjonalny.

**Jeśli któryś krok zawiedzie**:
- `sage --help` failuje → sprawdzić `bin/sage` resolve_framework
  output (uruchomić z `set -x`); prawdopodobnie potrzebny rollback (T2 przeciwnie).
- `realpath` nie zwraca expected → symlink wskazuje gdzie indziej,
  sprawdzić `readlink` i poprawić.

**Files involved**: read-only operacje, brak edycji.

---

## T4 — Dokumentacja: runbook + decisions

**Cel**: zostawić ślad operacyjny dla przyszłej obsługi (rollback,
black-list komend, pre-flight checklist dla `sage update`).

**Kroki**:

1. **Pre-flight manifest check**: `head -10 ~/Developer/sage-selfhost/.sage/work/20260428-framework-symlink-dev-workflow/manifest.md`
   żeby potwierdzić current `phase:` i `status:` przed update. Manifest
   istnieje od fazy spec — nie nadpisujemy, tylko aktualizujemy frontmatter.
2. Stworzyć katalog `~/Developer/sage-selfhost/.sage/docs/runbooks/`
   jeśli nie istnieje.

   **Świadoma decyzja**: `.sage/docs/runbooks/` jest **gitignored** w
   tym repo (`.sage/docs/*` ignored, `runbooks/` brak whitelisty per
   `.gitignore`). To **feature, nie bug** — runbook to lokalny
   dev-setup artefakt, nie cecha Sage. Nie próbujemy go whitelistować.
   Per BRANCH POLICY w spec.md.
3. Napisać `framework-rollback.md` z sekcjami:
   - **Co to za setup** — jednoznacznie: `~/.sage/framework` to symlink
     do `~/Developer/sage-selfhost`. Implikacje (jeden checkout, brak
     niezależnego clone'u).
   - **Czarna lista komend pod symlinkiem**:
     - `sage upgrade` (`bin/sage:1183` — `git pull --ff-only` na sage-selfhost)
     - `install.sh` (`rm -rf` w 5 miejscach — zniszczy symlink)
     - dowolny `git -C ~/.sage/framework <op>` zakładający osobne repo
   - **Pre-flight checklist przed `sage update` w consumerze**:
     ```
     cd ~/Developer/sage-selfhost
     git status              # clean? jeśli nie: stash lub commit
     git branch --show-current  # selfhost? (lub świadomy feature branch)
     git rev-parse HEAD       # zapisz, do porównania potem
     ```
   - **Rollback (4 warianty z spec'a)** — skopiować dokładnie z spec.md
     sekcja ROLLBACK.
   - **Jak weryfikować że symlink dalej żyje**:
     `[ -L ~/.sage/framework ] && readlink ~/.sage/framework`
4. Update `.sage/decisions.md` — prepend wpis "2026-04-28 — Symlink
   dev workflow aktywny" z fingerprintem swap'u (timestamp `$TS`
   z T2, sha sage-selfhost HEAD przed/po, ścieżka `.bak.$TS`).
5. Update manifest.md — `phase: plan → complete`, `status: completed`,
   `updated: 2026-04-28`, dopełnić handoff field z konkretnymi
   wartościami `$TS` i `BAK` z T2.

**DONE**:
- `.sage/docs/runbooks/framework-rollback.md` istnieje, ma 5 sekcji
  wymienionych wyżej, każda nienpusta.
- `.sage/decisions.md` ma nowy wpis na górze (po `# Decisions`
  header).
- `manifest.md` updated.

**Files involved**:
- `.sage/docs/runbooks/framework-rollback.md` (nowy)
- `.sage/decisions.md` (prepend)
- `.sage/work/20260428-framework-symlink-dev-workflow/manifest.md` (update)

---

## T5 — Cleanup `.bak` (po manualnym confirm)

**Cel**: usunąć backup gdy mamy pewność że symlink działa.

**Kroki**:

1. Sage prezentuje: "Symlink żyje, smoke test zielony, runbook zapisany.
   Usunąć `.bak.$TS`? [Y/n]". User decyduje.
2. Jeśli `Y`: `rm -rf ~/.sage/framework.bak.$TS`.
3. Jeśli `n`: zostaw `.bak.$TS` z notatką w manifest.md o jego
   istnieniu i lokalizacji (do późniejszego ręcznego cleanup).

**DONE**: user świadomie zdecydował o losie `.bak`.

**Files involved**: filesystem `~/.sage/framework.bak.*` (rm) i
manifest.md (jeśli zostawiamy).

🔒 **CHECKPOINT po T5 (cykl zamknięty):**

Sage: Build complete. Symlink aktywny, runbook w
`.sage/docs/runbooks/framework-rollback.md`, decyzja w decisions.md.
4 follow-up cycles do rozważenia w przyszłości (SCOPE OUT spec'a).

[A] Approve — merge/ship (zaktualizuj plan status: completed,
   prepend zamknięcie do decisions.md)
[R] Revise — coś jeszcze do zrobienia
[V] Verify — `/sage:review` dla independent code review

Wybierz A/R/V.

---

## Quality gates (Sage standard)

Per `.sage/gates/gate-modes.yaml` build mode = wszystkie 5 mandatory:

| Gate | Co testuje | Jak weryfikujemy |
|---|---|---|
| 1 spec-compliance | implementacja zgodna ze spec | manualne przejście DONE-WHEN po każdym tasku, output wklejony |
| 2 constitution-compliance | branch policy, scope discipline | nie ruszamy consumerów; pinning selfhost; brak `rm -rf` w T2 |
| 3 code-quality | nie ma kodu — wszystko bash one-liners | review komend w plan.md przed wykonaniem |
| 4 hallucination-check | nie ma importów; ścieżki realne | `bin/sage:354,568,1061,1183` zweryfikowane przez sub-agent w spec review |
| 5 verification | smoke test w T3 z pasted output | T3 paste'uje **PEŁNY output** wszystkich komend (Sage Rule 5 — paste actual output, NIE summary) |

Gate 8 (auto-QA) — N/A, brak browser-testowalnej UI.

## Risks during execution

- **Risk**: T2 może zostawić niespójny stan jeśli skrypt umrze między
  `mv` a `ln -s`. **Mitigacja**: compound bash `&&` — jeśli `mv`
  failuje, `ln -s` się nie odpali. Jeśli `mv` poszedł a `ln -s`
  failuje → manualnie `mv ~/.sage/framework.bak.$TS ~/.sage/framework`
  (rollback w drugą stronę).
- **Risk**: T3 może false-positive jeśli `bin/sage` resolve_framework
  trafi w gałąź "script's own directory" zamiast `~/.sage/framework`.
  **Mitigacja**: krok 3 z `realpath` jest weryfikacją niezależną od
  `bin/sage` (czysty Python `os.path.realpath`).
- **Risk**: T4 może być pominięty pod presją czasu. **Mitigacja**:
  T4 jest wymaganiem DONE-WHEN spec'a — bez niego cykl nie jest
  completed.
- **Risk (concurrent access)**: Inna sesja terminala robi `git pull`
  / commit w sage-selfhost między T1 a T3. T1 verify mógł być clean,
  ale T3 smoke test już testuje inny stan. **Mitigacja**: zamknąć
  inne sesje terminala dotykające sage-selfhost na czas T1-T3.
  Jeśli niepewne → ponowić T1 verify tuż przed T2.
- **Risk (interrupted session)**: User zamyka sesję między T2 a T3.
  Symlink żyje, `.bak.$TS` zostaje, ale stan nieudokumentowany.
  **Recovery**: następna sesja sprawdzi
  `[ -L ~/.sage/framework ] && readlink ~/.sage/framework && ls -1d ~/.sage/framework.bak.* 2>/dev/null`
  — jeśli symlink żyje + `.bak.*` istnieje → kontynuuj od T3 (smoke
  test). Wpisać tę procedurę do runbooka w T4.
- **Risk (permission)**: `mv` w T2 failuje bo `~/.sage/` ma write
  perms ale `~/.sage/framework/` zawiera plik z innym ownerem (mało
  prawdopodobne na single-user macOS, ale). **Mitigacja**: pre-flight
  `[ -w ~/.sage ]` w T1 jako szósta kontrola (opcjonalna).

## Time estimate

- T1: 30 sekund (agent execution)
- T2: 30 sekund (agent)
- Post-T2 checkpoint: 1-3 minuty (review przez usera)
- T3: 1-2 minuty (agent)
- T4: 5-10 minut (agent — pisanie runbooka)
- T5: 30 sekund (agent) + manualny confirm
- Final checkpoint: 1-3 minuty (review)

Łącznie: ~10-15 min agent execution + 5-10 min user review checkpointów.
Realistycznie 20-30 min total wall clock.
