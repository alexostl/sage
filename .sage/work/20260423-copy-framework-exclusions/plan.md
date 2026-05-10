---
title: "Fix Plan for Copy Framework Exclusions"
status: "completed"
phase: "fix-plan"
created: "2026-04-23"
updated: "2026-04-23"
---

# Fix Plan: Copy Framework Exclusions

**Mode:** fix
**Status:** completed
**Started:** 2026-04-23
**Last updated:** 2026-04-23

## Root Cause

Framework copy/update paths use `cp -a` on the full source checkout, so
consumer projects inherit repository metadata and transient artifacts that the
runtime does not read.

## Files To Change

- `bin/sage`
  Add a small helper that removes `.git`, `.github`, `.tmp`, and `.DS_Store`
  from copied framework trees; call it after both init-time and update-time
  framework copies.
- `tools/sage-claude-plugin/scripts/sage`
  Mirror the same exclusion behavior in the plugin script's init/update paths
  so both entrypoints stay aligned.
- `CHANGELOG.md`
  Document the bug fix and note that legacy nested `sage/.git` disappears on
  the next `sage update`.

## Tests

- Fresh init from local checkout does not create `sage/.git`, `sage/.github`,
  or `sage/.tmp`.
- `sage update` still completes after init and preserves a working project.
- Updating a legacy-style project removes accidental nested `sage/.git`.
- `sage new` still scaffolds a runnable project without nested `sage/.git`.

## Risks

- The plugin script can drift from the main CLI if only one path is patched.
- `sage update` now removes accidental nested repo metadata from legacy
  projects; that is intended but should be called out clearly in changelog/PR.

## Rollback

Revert the pruning helper and its call sites in both scripts, plus the
changelog entry, if the exclusions break a real consumer workflow that depends
on copied metadata.
