# Codex Port Implementation Handoff

Updated: 2026-04-21
Primary branch: `codex-port`
Coordinator: main thread

## Goal

Bring Sage's Codex adapter to a release-candidate state that is both:

- honest about current Codex capabilities
- compatible with current official Codex docs
- backward-compatible with existing Sage projects where reasonable

This is not a ground-up redesign. Prefer the smallest change set that fixes
real blockers and closes the highest-value compatibility gaps.

## Source of Truth

This file is the single operational source of truth for Codex port status,
remaining follow-up, and implementation handoff. Older ad hoc status notes
should be removed rather than kept in parallel.

Implementation should stay aligned with:

- `runtime/platforms/codex/platform.yaml`
- `runtime/platforms/codex/README.md`
- `runtime/platforms/codex/INSTALL.md`
- `runtime/platforms/README.md`
- `runtime/platforms/codex/setup/generate-codex.sh`
- `runtime/mcp/json_to_toml.py`
- `runtime/mcp/load_config.py`
- `runtime/mcp/discover.sh`
- `runtime/mcp/mcp-client.ts`
- `runtime/cli/src/cli.mjs`
- `runtime/cli/package.json`

Official reference set:

- `app/worktrees`
- `app/features#built-in-git-tools`
- `guides/agents-md`
- `config-reference#configtoml`
- `hooks`
- `app/automations#managing-tasks`
- `learn/best-practices#use-automations-for-repeated-work`
- `skills`
- `enterprise/admin-setup#step-4-standardize-local-configuration-with-team-config`
- `app-server#detect-and-import-external-agent-config`

## Working Model

Recommended execution model:

- one coordinator thread owns planning, review, and integration
- one worker per disjoint write scope
- workers do not edit the same files
- workers do not revert unrelated changes

Branching strategy:

- if humans are doing the work manually: use one topic branch per workstream
- if Codex subagents are doing the work: prefer each worker's isolated forked
  workspace instead of manual `git worktree` management

Why:

- subagents already get isolated execution context
- manual worktrees add operational overhead without much extra safety here
- the real safety mechanism is disjoint file ownership plus coordinator review

## Merge Policy

Each workstream is `mergeable` only if all of the following are true:

1. The change stays within the assigned write scope.
2. The change is backward-compatible or the compatibility trade-off is
   explicitly documented.
3. Docs match actual behavior.
4. Required verification commands pass.
5. The coordinator review finds no new release blocker.

If any of the above fails, mark the stream `no-merge` until fixed.

## Current Release Status

The original rollout blockers were addressed. A later deep E2E simulation
surfaced a short repair list, and those repairs have also been completed in
this branch:

1. project-local `sage/bin/sage update`
2. false-green MCP discovery for broken servers
3. direct-skill refresh on `sage update`
4. non-executable `bin/sage` in source checkouts

At this point the original conservative-port goals are implemented in this
branch:

1. workflow-entry UX pack through `$sage`, `$build`, `$fix`, `$architect`,
   `$continue`, `$status`, and `$review`
2. Codex-native automation templates/examples
3. optional experimental hooks starter pack
4. lightweight manual regression checks for Codex init/update/MCP paths

Remaining work is optional follow-up rather than a known release blocker.

## Open Follow-Up Backlog

Optional follow-up remains:

1. Deepen hook enforcement beyond the conservative Bash-focused starter pack.
2. Evaluate whether `.codex/skills/` dual-support becomes safe once Codex docs
   and runtime behavior settle.
3. Wire the shipped regression scripts into CI or a repeatable release gate.
4. Revisit whether Codex should eventually get a more opinionated workflow
   entry UX beyond the current skill-first posture, if the platform exposes a
   stable native surface for it.

## Workstreams

### Stream A: Adapter metadata and docs

Goal:

- align capability claims and user guidance with current Codex reality

Write scope:

- `runtime/platforms/codex/platform.yaml`
- `runtime/platforms/codex/README.md`
- `runtime/platforms/codex/INSTALL.md`
- `runtime/platforms/README.md`
- optional new docs/examples under `runtime/platforms/codex/`

Required changes:

- update capability model for `worktrees` and `hooks`
- describe hooks as experimental, not absent
- document built-in Git flows and automations honestly
- clarify current `.agents/skills` posture versus newer Team Config docs
- avoid claiming full Claude parity where it does not exist

Definition of done:

- capability table and narrative match current official docs
- docs describe limitations precisely
- docs are consistent with actual generator/runtime behavior

Verification:

- read-through consistency check across all edited docs
- spot-check against current generated surfaces and config behavior

### Stream B: Config generation and instruction compatibility

Goal:

- modernize generated `.codex/config.toml` without forcing opinionated defaults
- preserve user-owned Codex config during regeneration
- improve instruction-discovery compatibility with current Codex docs

Write scope:

- `runtime/mcp/json_to_toml.py`
- `runtime/mcp/load_config.py`
- `runtime/platforms/codex/setup/generate-codex.sh`

Required changes:

- keep legacy MCP JSON translation working
- add conservative support for modern config keys where appropriate
- prefer commented options/templates when hard defaults would be too opinionated
- preserve user-owned config outside Sage-managed sections
- account for `AGENTS.override.md` and fallback instruction filenames without
  redesigning the whole instruction system
- make TOML handling robust enough for normal hand-edited Codex config

Candidate config keys to evaluate:

- `project_doc_fallback_filenames`
- `project_doc_max_bytes`
- `review_model`
- `model_reasoning_effort`
- `model_verbosity`
- `web_search`
- `sandbox_workspace_write.network_access`
- `skills.config` only if the resulting behavior is clearly safe

Definition of done:

- `sage update` no longer clobbers unrelated user Codex settings
- generator output is minimal but current
- parser/loader round-trips realistic hand-edited TOML cases

Verification:

- syntax check:
  - `python3 -m py_compile runtime/mcp/json_to_toml.py runtime/mcp/load_config.py`
  - `bash -n runtime/platforms/codex/setup/generate-codex.sh`
- smoke tests on example inputs:
  - empty project
  - project with legacy `.claude/mcp.json`
  - project with existing `.codex/config.toml` plus user-owned keys/comments

### Stream C: Distribution and runtime blockers

Goal:

- make the npm bridge and MCP runtime bootable on a clean checkout or install

Write scope:

- `runtime/cli/src/cli.mjs`
- `runtime/cli/package.json`
- `runtime/mcp/mcp-client.ts`
- `runtime/mcp/discover.sh`
- optional new manifest/helper files under `runtime/cli/` or `runtime/mcp/`

Required changes:

- fix the npm bridge so `npx sage-kit init/update/...` does not rely on a file
  outside the published package root
- make MCP discovery runnable from a clean checkout by declaring or packaging
  required runtime dependencies
- keep the fix low-risk and easy to understand

Definition of done:

- npm package smoke check no longer points to a missing shell entrypoint
- MCP client/discovery can start without undeclared dependencies
- updated docs or inline comments explain the runtime expectations

Verification:

- `node --check runtime/cli/src/cli.mjs`
- `npm pack --dry-run` from `runtime/cli`
- clean-run smoke test for MCP tooling from repo state

## Out of Scope

- replacing Sage memory with Codex memories
- redesigning the port around browser/computer-use/image generation
- forcing migration from `.agents/skills` to `.codex/skills`
- building a full automation runner inside Sage
- large refactors that are not needed for compatibility or release-readiness

## Coordinator Review Checklist

For each stream:

1. Read the diff for scope creep.
2. Check docs vs runtime consistency.
3. Run the stream's verification commands.
4. Decide:
   - `merge`
   - `merge with follow-up`
   - `no-merge`

## Expected Final Outcome

When all mergeable streams are integrated, the Codex port should be:

- honest about current Codex capabilities
- safe to regenerate in existing projects
- able to boot its MCP tooling from a clean environment
- materially closer to current Codex config and instruction behavior
- still conservative where official Codex behavior remains experimental
