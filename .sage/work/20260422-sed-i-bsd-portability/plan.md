---
title: "Fix Plan for BSD sed -i Portability"
status: "completed"
phase: "fix-plan"
created: "2026-04-22"
updated: "2026-04-23"
---

# Fix Plan: BSD sed -i Portability

**Mode:** fix
**Status:** completed
**Started:** 2026-04-22
**Last updated:** 2026-04-23
**Landed in:** 702e867 `fix: use BSD-compatible sed -i.bak`
**Upstream PR:** https://github.com/xoai/sage/pull/3 (open)

## Root Cause

Four executable call sites use GNU-style `sed -i` without a backup suffix.
BSD `sed` on macOS requires the suffix to be attached to `-i`, so those
commands fail instead of editing files in place.

## Files To Change

- `bin/sage`
  Replace the `apply_prefix_config()` in-place edit with the repo's portable
  `sed -i.bak ...` pattern and remove the generated backup file.
- `runtime/platforms/claude-code/setup/generate-claude-code.sh`
  Update both fallback `sed` edits to use `-i.bak`, keep the existing `-e`
  chain intact, and remove `CLAUDE.md.bak` after each edit.
- `runtime/platforms/antigravity/setup/generate-antigravity.sh`
  Update the fallback `sed` edit to use `-i.bak` and remove `GEMINI.md.bak`
  afterward.

## Tests

- Run a local macOS repro for bare `sed -i` versus `sed -i.bak`.
- Run `bash install.sh` from this checkout to refresh the local framework.
- Verify `sage init --prefix --preset base` in a fresh temp project.
- Verify `yes | sage update --prefix` flips `command_prefix` to `true`.
- Verify `yes | sage update` flips `command_prefix` back to `false`.
- Verify fresh `sage init` without `--prefix` keeps unprefixed commands and
  avoids `/sage:` rewrites.

## Risks

- The CLAUDE/GEMINI fallback replacements are only used when `python3` is not
  available, so they need direct coverage in addition to end-to-end CLI tests.
- The multi-`-e` `sed` invocation must preserve its existing substitution set.

## Rollback

Revert the four `sed` call-site changes and remove the new fix-plan artifact if
the portable pattern causes unexpected behavior.
