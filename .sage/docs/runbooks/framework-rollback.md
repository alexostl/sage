---
title: Runbook — Framework symlink rollback i operacyjna higiena
created: 2026-04-28
updated: 2026-04-28
status: active
scope: local-dev-only
gitignored: true
related_cycle: .sage/work/20260428-framework-symlink-dev-workflow/
swap_timestamp: 20260428-230110
swap_head: 443a7c8187264fcb9591d27c1d097dfdfdb4a212
---

# Runbook — Framework symlink rollback

> **Świadomie gitignored**. Ten runbook żyje w `.sage/docs/runbooks/`,
> które jest filtrowane przez `.gitignore` (`.sage/docs/*` ignored,
> `runbooks/` brak whitelisty). To **feature, nie bug** — runbook to
> lokalny dev-setup artefakt, nie cecha frameworka Sage. NIE
> whitelistować i NIE forward-merge do codex-port ani upstream.
> Per BRANCH POLICY w `spec.md` cyklu związanego.

## 1. Co to za setup

`~/.sage/framework` jest **symlinkiem** do `~/Developer/sage-selfhost`:

```
$ ls -ld ~/.sage/framework
lrwxr-xr-x@ ...  /Users/alexostl/.sage/framework -> /Users/alexostl/Developer/sage-selfhost
```

Implikacje:

- **Jeden git checkout**, nie dwa. `~/Developer/sage-selfhost` jest
  source of truth dla self-host konwencji portu (per user instruction
  "Claude jest source of truth").
- **Każda operacja `cd ~/.sage/framework`** trafia do sage-selfhost.
- **`bin/sage` rezolwuje framework** przez `~/.sage/framework`
  (linie 144-145 w `bin/sage`) i przechodzi przez symlink (bash `-d`
  test przez symlink działa).
- **Edycje w sage-selfhost** stają się natychmiast widoczne jako
  source frameworka. Bezpiecznikiem **nie jest sam symlink** —
  bezpiecznikiem jest **jawny, ręczny `sage update` w consumerze**.

Swap został wykonany 2026-04-28 (timestamp `20260428-230110`,
HEAD `443a7c8187264fcb9591d27c1d097dfdfdb4a212`).

## 2. Czarna lista komend pod symlinkiem

**NIE odpalać** dopóki `~/.sage/framework` jest symlinkiem:

| Komenda | Dlaczego |
|---|---|
| `sage upgrade` | `bin/sage:1183` robi `git pull --ff-only` na frameworku → po swap to byłby pull na primary dev checkoucie. Surprise commits, możliwy konflikt z WIP. |
| `bash install.sh` (z dowolnego miejsca) | `install.sh:49,61,68,100,109` wykonuje `rm -rf "$SAGE_FRAMEWORK"` w 5 miejscach → zniszczy symlink i postawi kopię. |
| `git -C ~/.sage/framework <op>` | Operuje teraz na sage-selfhost. Bez świadomości tego, każda komenda git jest dwukrotnie liczona. |
| `git -C ~/.sage/framework reset/checkout/clean` | Cokolwiek niszczącego — robi to na primary dev checkoucie. |

**Bezpieczne alternatywy**:

- Aktualizacja frameworka → `cd ~/Developer/sage-selfhost && git fetch && git pull --ff-only` (świadomie, na właściwym branchu).
- Reinstalacja → patrz sekcja 4 (rollback) → opcja 1 (świeży clone).

## 3. Pre-flight checklist przed `sage update` w consumerze

Przed każdym `sage update` w consumer projekcie (np. `alex-os-dev`,
`safe-rent-v1`):

```bash
cd ~/Developer/sage-selfhost

# 1. Czy są niezacommitowane zmiany w sage/core/...?
git status

# Jeśli dirty → STOP. Decyduj:
#   - git stash       (jeśli to WIP którego nie chcesz dystrybuować)
#   - git commit      (jeśli to zaplanowana zmiana frameworka)
#   - git checkout -- (jeśli śmieciowe zmiany)

# 2. Czy stoję na właściwym branchu?
git branch --show-current

# Oczekiwane: selfhost (lub świadomy feature branch).
# Jeśli inny → git checkout selfhost.

# 3. (Opcjonalnie) Zapisz HEAD przed update — do porównania potem.
git rev-parse HEAD
```

Dopiero teraz `cd <consumer> && sage update`.

**Dlaczego**: `sage update` woła `cp -a "$SAGE_FRAMEWORK" "$target/sage"`
(`bin/sage:568,1061`), `prune_framework_copy` (`bin/sage:354`) filtruje
**tylko** `.git/`, `.github/`, `.tmp/`, `.DS_Store`. Wszystko inne — w
tym niezacommitowane edycje — leci do consumera.

## 4. Rollback (4 warianty od najczystszego)

### Wariant 1 — Świeży clone z `alexostl/sage` origin (DEFAULT)

Najczystszy, bez gitignored bagażu z worktree:

```bash
unlink ~/.sage/framework
git clone https://github.com/alexostl/sage.git ~/.sage/framework
git -C ~/.sage/framework checkout selfhost
```

Wraca do stanu sprzed swap (dwa niezależne checkouty `selfhost`).
Symlink usunięty, normalny katalog z fresh clone.

### Wariant 2 — Lokalny `.bak` (najszybszy, jeśli istnieje)

Jeśli `~/.sage/framework.bak.*` jeszcze istnieje (T5 cyklu nie był
wykonany lub user wstrzymał cleanup):

```bash
unlink ~/.sage/framework
ls -1d ~/.sage/framework.bak.*    # zobacz dostępne backupy
mv ~/.sage/framework.bak.<timestamp> ~/.sage/framework
```

Najszybszy rollback. Działa tylko gdy `.bak` żyje.

### Wariant 3 — `install.sh` z lokalnego sage-selfhost (NIE czysty)

Działa, ale `cp -a` skopiuje **też gitignored content** z worktree
(`.sage/work/`, `.sage-memory/`, lokalne notatki). `~/.sage/framework`
zostanie z bagażem admin-state.

```bash
unlink ~/.sage/framework
bash ~/Developer/sage-selfhost/install.sh
```

Używać tylko gdy nie ma sieci na `git clone`.

### Wariant 4 — Vanilla Sage z `xoai/sage` upstream

Wraca do oryginalnego Sage, **traci self-host fork**:

```bash
curl -fsSL https://raw.githubusercontent.com/xoai/sage/main/install.sh | bash
```

Używać tylko świadomie (np. test czy bug istnieje w vanilla).

## 5. Jak weryfikować że symlink dalej żyje

```bash
# Czy to dalej symlink?
[ -L ~/.sage/framework ] && echo "ŻYJE" || echo "ZNISZCZONY"

# Jeśli żyje — gdzie wskazuje?
readlink ~/.sage/framework
# Oczekiwane: /Users/alexostl/Developer/sage-selfhost

# Sanity check przez symlink
[ -d ~/.sage/framework/core ] && echo "core/ dostępny" || echo "broken"

# Realpath — ostateczna weryfikacja
python3 -c 'import os; print(os.path.realpath(os.path.expanduser("~/.sage/framework")))'
# Oczekiwane: /Users/alexostl/Developer/sage-selfhost
```

Jeśli któraś z tych komend zwróci nieoczekiwany wynik:
1. Sprawdź `ls -ld ~/.sage/framework` — pierwszy znak (`l`=symlink,
   `d`=katalog, brak=usunięty).
2. Sprawdź `ls -1d ~/.sage/framework.bak.*` — czy backup żyje.
3. Wybierz wariant rollbacku z sekcji 4.

## 6. Recovery dla przerwanej sesji

Jeśli sesja swap'u została przerwana między T2 (swap) a T3 (smoke test):

```bash
# Stan po T2 zakończonym:
[ -L ~/.sage/framework ] && \
  readlink ~/.sage/framework && \
  ls -1d ~/.sage/framework.bak.* 2>/dev/null

# Jeśli wszystkie 3 zwracają OK → kontynuuj od T3 (smoke test).
# Jeśli symlink istnieje ale .bak zniknął → swap zakończony,
#   .bak był wyczyszczony w T5; wszystko w porządku.
# Jeśli symlinka brak ale .bak istnieje → T2 nie skończony,
#   ręcznie: ln -s /Users/alexostl/Developer/sage-selfhost ~/.sage/framework.
# Jeśli ani symlinka ani .bak → katastrofa: rollback wariant 1
#   (świeży clone).
```

## 7. Powiązane artefakty

- Spec cyklu: `.sage/work/20260428-framework-symlink-dev-workflow/spec.md`
- Plan cyklu: `.sage/work/20260428-framework-symlink-dev-workflow/plan.md`
- Manifest cyklu: `.sage/work/20260428-framework-symlink-dev-workflow/manifest.md`
- Decisions log: `.sage/decisions.md` (wpisy 2026-04-28)
- 4 follow-up cycles (out of scope tego cyklu, upstream-relevant):
  - `sage-install-symlink-guard` — install.sh wykrywa symlink
  - `sage-upgrade-symlink-guard` — sage upgrade wykrywa symlink
  - `sage-update-prune-extended` — `prune_framework_copy` filtruje
    `.sage/`, `.sage-memory/`, `.claude/`, `.codex/`, `install.sh`
  - `sage-update-dirty-worktree-warning` — pre-flight ostrzeżenie
    przed `sage update` jeśli source ma WIP
