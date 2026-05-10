---
cycle_id: 20260428-framework-symlink-dev-workflow
title: Symlink ~/.sage/framework jako dev workflow
phase: complete
status: completed
scope: Standard
created: 2026-04-28
updated: 2026-04-28
owner: alexostl
branch_policy: pinned to selfhost, NO forward-merge to codex-port
swap_timestamp: 20260428-230110
swap_head_before: 443a7c8187264fcb9591d27c1d097dfdfdb4a212
swap_head_after: 443a7c8187264fcb9591d27c1d097dfdfdb4a212
swap_bak_path: /Users/alexostl/.sage/framework.bak.20260428-230110
artifacts:
  - spec.md (status: completed, double-reviewed)
  - plan.md (status: completed, reviewed APPROVE-WITH-MINOR-FIXES, 8/8 fixed)
  - manifest.md (this file)
  - .sage/docs/runbooks/framework-rollback.md (gitignored, local-dev-only)
handoff: |
  Cykl zamknięty 2026-04-28. Wszystkie T1-T5 wykonane, final checkpoint
  approved [A].

  Stan końcowy:
    ~/.sage/framework → symlink → /Users/alexostl/Developer/sage-selfhost
    .bak.20260428-230110 wyczyszczony (T5 user-confirm Y).
    HEAD przed = HEAD po = 443a7c8187264fcb9591d27c1d097dfdfdb4a212.

  Operacyjna higiena:
    NIE odpalać sage upgrade, bash install.sh, git -C ~/.sage/framework
    pod symlinkiem. Pełna czarna lista + 4 warianty rollbacku w
    .sage/docs/runbooks/framework-rollback.md (gitignored, local-dev-only).

  Branch policy:
    Pinned to selfhost. NIE forward-mergować do codex-port ani
    upstream — to lokalny dev artefakt, nie cecha frameworka Sage.

  4 follow-up cycles (upstream-relevant, fresh worktree z upstream/main):
    - sage-install-symlink-guard
    - sage-upgrade-symlink-guard
    - sage-update-prune-extended
    - sage-update-dirty-worktree-warning
---

# Manifest — Framework symlink dev workflow

## Context summary (judgment, nie kopia spec)

Repo `~/Developer/sage-selfhost` ma dziś **drugi pełen git clone** w
`~/.sage/framework`. Dwa checkouty tej samej gałęzi (`selfhost`),
identyczny HEAD, identyczne remoty. Drift dziś = 0, ale każdy `git pull`
wymaga akcji na obu. Setup ten jest **artefaktem standardowej instalacji
Sage** (`install.sh` zawsze tworzy fresh clone w `~/.sage/framework/`),
nie świadomą decyzją.

User chce zamienić to na symlink żeby:
- skrócić cykl iteracji (edycja w sage-selfhost natychmiast widoczna jako
  source dla `sage update` w consumerach)
- mieć jeden source of truth zgodnie z user instruction "Claude jest
  source of truth dla konwencji portu"

Bezpiecznikiem **nie jest sam symlink** — jest **jawny, ręczny `sage
update` w consumerze**. User świadomie to akceptuje (memory `fd94a21b`).

## Kluczowe decyzje (judgment-loaded, nie facts)

1. **Symlink nad fresh clone** — drift między dwoma checkoutami był
   niewykrywalny dopóki ktoś nie odpalił `git status` w obu. Symlink
   eliminuje klasę problemu, ale wprowadza inną klasę (WIP visibility).
   Trade-off świadomy.

2. **Wariant A nad B** (sam symlink, bez hardeningu install.sh / sage
   upgrade) — hardening to **upstream-relevant change**. Mieszanie tego
   z lokalną zmianą setupu komplikowałoby branch policy. Rozdzielamy:
   - Wariant A → self-host-only, pinowany do main
   - Hardening → osobne cycles, fresh worktree z upstream/main
     żeby nie ciągnąć self-host kontekstu

3. **Rollback default = git clone, nie install.sh** — install.sh w
   trybie "Local install" robi `cp -a` z **całym worktree**, włącznie
   z gitignored content (`.sage/work/` 39KB decisions, `.sage-memory/`
   itp.). Świeży clone z origin nie ciągnie tego bagażu, jest
   higieniczny. install.sh zostaje jako fallback gdy nie ma sieci.

4. **Branch policy explicit, nie incidental** — `.sage/work/` jest
   gitignored, więc artefakty tego cyklu nie poleciałyby do gita
   "sam z siebie". Ale spec ma jawną sekcję BRANCH POLICY na wypadek
   gdyby ktoś kiedyś dodał runbook do whitelisty albo gdyby ktoś
   próbował upstreamować mitygacje #2-#4 razem z tym cyklem. Pattern
   skopiowany z commit `5a0bfef` ("narrow palette default" pin).

## Current state

- Spec: completed, dwa cold-read review (REVISE → APPROVE WITH MINOR FIXES → fixed).
- Plan: not started (następny krok).
- Decisions.md: prepended z decyzją 2026-04-28.
- Manifest.md: this file.

## Next agent guidance

Jeśli przejmujesz ten cykl:

1. **Przeczytaj spec.md w całości** — zwłaszcza RISKS table (7 wpisów
   z konkretnymi liniami `bin/sage`) i ROLLBACK (4 warianty od
   najczystszego).
2. **Branch state matter**: sprawdź gdzie aktualnie stoi sage-selfhost
   (`git branch --show-current`). Po swap wszystko `cd ~/.sage/framework`
   trafia na ten branch.
3. **Nie odpalaj `sage upgrade`** dopóki testujesz symlink — git pull
   na primary dev checkoucie to surprise.
4. **`install.sh` `rm -rf`** — nie odpalaj install.sh w dev workflow.
   Update przez normalny git.
5. **Plan ma 5 zadań** zarysowanych w spec handoff (T1 verify, T2 swap,
   T3 smoke, T4 docs, T5 cleanup). Każde z [A]/[R] checkpointem.
