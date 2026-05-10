---
cycle_id: "20260508-selfhost-branch-name-cleanup"
title: "Rename self-host branch references to selfhost"
workflow: fix
phase: complete
status: completed
created: 2026-05-08
updated: 2026-05-08
owner: alexostl
---

# Plan: Rename self-host branch references to selfhost

## Root Cause

The repository branch model was simplified to `selfhost`, but documentation,
CI triggers, and Sage project history still contain operational references to
the old slash-style branch name.

## Scope

- Search the full repository, including hidden project documentation but
  excluding `.git`, for old self-host branch spellings.
- Update current operational references to `selfhost`.
- Preserve wording only where the old branch name is explicitly historical and
  changing it would make the record false.
- Verify no actionable old branch references remain.
- Run lightweight validation for touched CI/docs where applicable.
- Push `selfhost`, then delete the old GitHub self-host branch.

## Verification

- `rg` search for old branch spellings.
- `git status --short --branch`.
- `git diff --check`.
- YAML parse for touched GitHub workflow files if any.
