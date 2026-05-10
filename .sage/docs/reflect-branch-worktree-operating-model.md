# Reflection: Branch and Worktree Operating Model

> **Note (2026-04-28):** Project was renamed `sage-codex` → `sage-selfhost`.
> References below preserved verbatim from when this document was written.

## Topic

Branch/worktree reorganization, upstream sync discipline, and isolated upstream
PR preparation for `sage-codex`.

## Cycle Review

Artifacts reviewed:

- `.sage/work/20260423-branch-worktree-operating-model/brief.md`
- `.sage/work/20260423-branch-worktree-operating-model/spec.md`
- `.sage/work/20260423-branch-worktree-operating-model/plan.md`
- `.sage/work/20260423-branch-worktree-operating-model/manifest.md`
- `.sage/decisions.md`

Concrete outcomes:

- `main` was re-established as a manual fast-forward mirror of `upstream/main`
- `codex-port` was merged forward from refreshed `main`
- active self-host work moved onto `selfhost`
- long-lived worktrees were separated and auxiliary ones moved under
  `~/.codex/worktrees/sage-codex/`
- upstream issue fixes were rebuilt from fresh `upstream/main`
- clean upstream PRs were opened as `xoai/sage#3` and `xoai/sage#4`

## User Feedback Captured

Direct signals from the session:

> mam wrazenie, ze ta zmiana plikow wprowadzilismy ogromny chaos

> cap/ ... powinna byc source of truth dla projektu tutaj

> worktress w codex powinny byc koniecznie tworzone we wskazanym przez codex katalogu

Interpretation:

- the previous branch model was not legible enough for a new or returning agent
- self-host work needed an explicit, stable home distinct from integration work
- the location of auxiliary worktrees is part of the operating contract, not an
  incidental implementation detail

## Learnings

### Reinforce

1. WHEN a repository has multiple long-lived lines of work, CHECK that each line
   has a named branch role and a dedicated worktree, BECAUSE switching a single
   checkout across roles hides the source of truth and creates operator
   confusion.
2. WHEN upstreaming a small shared fix from a divergent fork, CHECK that the fix
   is recreated from fresh `upstream/main`, BECAUSE issue-scoped PRs become much
   easier to review and do not drag repository-local artifacts upstream.

### Prevent

1. WHEN proposing a branch name under `main/...`, CHECK whether a real `main`
   branch already exists, BECAUSE Git ref namespaces make `main` and `main/...`
   mutually incompatible.
2. WHEN creating Codex-facing auxiliary worktrees, CHECK that they live under
   `~/.codex/worktrees/sage-codex/` unless a config override exists, BECAUSE
   off-pattern worktree locations make the repo topology harder to discover and
   trust.
3. WHEN treating local `main` as an upstream mirror, CHECK that it has just been
   fast-forwarded to `upstream/main`, BECAUSE a stale mirror gives false
   confidence and contaminates later integration decisions.

### Improve

1. WHEN an architect cycle establishes a durable repo-operation rule, CHECK that
   the rule was promoted into `.sage/docs`, `.sage/conventions.md`, and
   `.sage-memory/`, BECAUSE cycle-local artifacts alone are too easy for future
   agents to miss.
2. WHEN a new repo-operational rule becomes mandatory, CHECK that `AGENTS.md`
   points agents to the relevant `.sage/docs` note, BECAUSE startup routing is
   where strict adherence begins.

## Seeds For Future Sessions

- Before future Git-heavy work, read
  `.sage/docs/learn-sage-codex-branch-worktree-model.md` first.
- If Codex later exposes a formal worktree-root config, update the branch
  worktree note to replace the current convention-based path rule.
- If the branch/worktree model survives several more sessions unchanged, promote
  it from a session reflection into a broader repo-operation guide.
