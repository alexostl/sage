---
cycle_id: "20260423-copy-framework-exclusions"
workflow: fix
phase: deliver
status: complete
created: 2026-04-23
updated: 2026-04-23 14:58
---

# Cycle: Copy Framework Exclusions

## State

**Current phase:** complete — framework copy/update paths now prune copied
repo metadata and transient artifacts after `cp -a`.
**Next step:** open a PR against `xoai/sage` with the verified manual results
and call out that legacy nested `sage/.git` disappears on the next
`sage update`.
**Artifacts:**
- plan.md: exists
- implementation: complete
- quality-gates: manual init/update/new verification passed

## Context Summary

`cp -a` currently copies the entire framework checkout into project-local
`sage/`, which leaks nested repo metadata (`.git`, `.github`) and transient
artifacts (`.tmp`, `.DS_Store`) into consumer projects. Repo grep found no code
that depends on project-local `sage/.git`, and direct GitHub issue/PR searches
in `xoai/sage` found no prior discussion or feature claim for nested repo state.
Docs do say the framework source is intentionally copied into each project, so
the chosen fix keeps full framework copy semantics and only prunes clearly
non-runtime metadata after copy.

## Decisions So Far

- Route as `/fix` Moderate, not `/architect`.
- Use `cp -a` plus post-copy pruning instead of introducing an `rsync`
  dependency.
- Treat removal of legacy nested `sage/.git` on `sage update` as a bug fix,
  not a breaking change.

## Open Questions

- Whether upstream wants a follow-up issue for pruning additional dead-weight
  top-level files beyond the four excluded entries.

## Provenance

| Key | Value |
|-----|-------|
| Repo | `https://github.com/alexostl/sage.git` |
| Branch | `fix/copy-framework-exclusions` |
| Base | `codex-port` |

## Handoff Guidance

If this work is revisited, keep the main CLI and plugin script copy/update
paths aligned and treat the excluded set as a focused bugfix unless upstream
explicitly asks for a broader whitelist/packaging change.
