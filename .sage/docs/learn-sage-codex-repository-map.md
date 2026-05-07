# Learn: `sage-codex` Repository Map

## Purpose

This file is the working-entry map for future sessions inside `sage-codex`.
Start here when you need to understand what the repository owns, where the
canonical deep references live, and which paths are operationally relevant for
ongoing work in Sage.

The rule of thumb is:

- start in `.sage/` for current working context
- use this map to jump to deeper canonical repo docs
- treat `to-rewrite-in-sage/` as legacy input, not as normal operating surface

## What This Repository Is

`sage-codex` is the Sage framework repository running in a self-hosted Codex
setup. It contains:

- framework philosophy and public documentation
- core workflow/capability sources
- platform adapters, including Codex
- development contracts, validators, and templates
- shared project state in `.sage/` for work on the framework itself

This repository is not just an app using Sage. It is Sage working on Sage.

## Major Top-Level Directories

| Path | Owns | Use it for |
| --- | --- | --- |
| `.sage/` | Working state for this repo | Current initiative state, decisions, and operational repo knowledge |
| `.agents/` | Codex skill surface | Workflow and direct skills used in Codex sessions |
| `.codex/` | Codex project config | Project-scoped Codex config and MCP setup |
| `core/` | Platform-agnostic engine | Capabilities, workflows, constitutions, references |
| `docs/` | Public/reference framework docs | Philosophy, ecosystem docs, user-facing documentation map |
| `runtime/` | Platform/runtime adapters | Codex adapter, platform generators, MCP/runtime support |
| `develop/` | Contributor/developer support | Contracts, guides, templates, validators |
| `skills/` | Installed/built-in direct skills | Domain and framework skills outside workflow shells |
| `tools/` | Supporting tools | Auxiliary tooling for repo operations |
| `to-rewrite-in-sage/` | Legacy rewrite input | Historical docs used to seed `.sage` parity; non-canonical for normal work |

## Canonical Source Map

### Working state and current initiative context

Primary source:

- `.sage/work/`
- `.sage/decisions.md`
- `.sage/docs/`

Use when:

- resuming active work
- checking current decisions
- finding repo-operational guidance rewritten for Sage methodology

### Framework philosophy and rationale

Primary source:

- `docs/README.md`
- `docs/philosophy/design-philosophy.md`
- `docs/philosophy/project-state-convention.md`

Use when:

- you need the "why" behind Sage architecture
- you need naming/structure rationale
- you are validating whether a repo-level doc matches framework intent

### Core workflow and capability behavior

Primary source:

- `core/workflows/`
- `core/capabilities/`
- `core/constitution/`

Use when:

- a task depends on exact workflow behavior
- a skill references a capability path
- you need the platform-agnostic source, not an adapter summary

### Codex adapter behavior

Primary source:

- `runtime/platforms/codex/README.md`
- `runtime/platforms/codex/setup/`
- `runtime/platforms/codex/hooks/`
- `runtime/platforms/codex/harness/`

Use when:

- the task touches Codex-specific surfaces
- you need adapter posture, limits, or setup details
- you are checking whether a Codex-facing statement is still true

### Development and contribution mechanics

Primary source:

- `develop/contracts/`
- `develop/guides/`
- `develop/templates/`
- `develop/validators/`

Use when:

- contributing a skill, bundle, or capability
- validating repo structure/contracts
- generating or checking project artifacts/templates

### Legacy rewrite inputs

Legacy input only:

- `to-rewrite-in-sage/README.md`
- `to-rewrite-in-sage/CONTRIBUTING.md`
- `to-rewrite-in-sage/SELF_HOSTING.md`
- `to-rewrite-in-sage/runtime/platforms/codex/*`

Use when:

- checking parity during the documentation rewrite
- confirming whether an older operational note has been migrated into `.sage`

Do not use these files as first-stop guidance for normal project work.

## Recommended Reading Order For A New Agent

1. `.sage/decisions.md`
2. `.sage/docs/learn-sage-codex-working-model.md`
3. `.sage/docs/learn-sage-codex-repository-map.md`
4. `.sage/docs/learn-sage-codex-codex-platform-context.md` only if the task touches Codex/self-hosting surfaces
5. Deep canonical repo docs from `docs/`, `runtime/`, `core/`, or `develop/` as pointed to by the `.sage/docs/` files

## Operational Rule

If a future session needs a repo-operational fact repeatedly to do work, the
first home for that fact should be `.sage/docs/` or `.sage/decisions.md`, not a
new ad hoc note elsewhere in the repo.

## Legacy Status of `to-rewrite-in-sage/`

`to-rewrite-in-sage/` is a legacy staging folder from the documentation rewrite.
Its purpose is parity checking while `.sage` is being populated. Once the
working knowledge required for normal project execution is available through
`.sage/` plus the canonical paths referenced here, the folder is eligible for
deletion.
