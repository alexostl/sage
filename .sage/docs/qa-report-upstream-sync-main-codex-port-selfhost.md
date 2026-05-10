# QA Report: `main` -> `codex-port` -> `selfhost`

> **Note (2026-04-28):** Project was renamed `sage-codex` → `sage-selfhost`.
> References below preserved verbatim from when this document was written.

## Scope

Standalone QA after retrospective analysis of the upstream sync chain:

1. `main` fast-forwarded to `upstream/main`
2. `codex-port` merged refreshed `main`
3. `selfhost` merged refreshed `codex-port`

Browser testing was not available, so this report is code-and-command QA only.

## Test Scope

Surfaces verified:

- `codex-port` Codex adapter regression flow
- `codex-port` MCP regression flow
- `selfhost` framework-repo self-host init/update smoke flow

Not tested:

- browser-rendered routes or UI flows
- non-Codex platform end-to-end behavior beyond the self-host smoke
- broader manual exploratory testing across all CLI commands

## Test Execution

### 1. Codex adapter regression on `codex-port`

Command:

```bash
bash runtime/platforms/codex/tests/run-regression.sh
```

Result: PASS

Evidence:

- summary reported `PASS: Codex adapter regression checks`
- fixture path:
  `/Users/alexostl/.codex/worktrees/sage-codex/codex-port/.tmp/codex-adapter-regression.xpt4dI/project`

### 2. MCP regression on `codex-port`

Command:

```bash
bash runtime/mcp/tests/run-regression.sh
```

Result: PASS

Evidence:

- summary reported `PASS: MCP regression checks`
- fixture path:
  `/Users/alexostl/.codex/worktrees/sage-codex/codex-port/.tmp/codex-mcp-regression.RO9rNd/project`

### 3. Self-host smoke on `selfhost`

Method:

- created an isolated detached worktree from `selfhost`
- verified that plain `sage init` inside the framework repo fails with the
  expected framework-directory guard
- reran with `sage init --self-host --platform claude-code,codex --preset base`
  and accepted the reinstall prompt caused by existing tracked `.sage/`
- verified generated platform files and absence of nested `sage/`
- ran `sage update` and verified nested `sage/` was still absent

Result: PASS

Evidence:

- guard path returned exit status `1` and emitted
  `You're inside the Sage framework directory`
- self-host init emitted `Self-host mode enabled (reusing local framework checkout)`
- reinstall path was expected and emitted `Sage is already initialized in this project`
- `AGENTS.md`, `.agents/skills/`, and `.codex/config.toml` were present after init
- nested `sage/` stayed absent after both init and update
- final summary:
  `SELFHOST_QA noflag_status=1 noflag_msg=1 reinstall_msg=1 selfhost_msg=1 nested_sage=absent update_nested_sage=absent`

## Results Summary

- Tested command groups: 3
- Pass: 3
- Fail: 0
- Warning: 1
- Verdict: PASS WITH WARNINGS

## Warnings

1. Browser testing was not available, so no route-level or UI-level validation
   was performed.

## Bugs Found

- Critical: 0
- Major: 0
- Minor: 0

## Conclusion

The refreshed branch chain is validated for the targeted non-browser surfaces
that carry the highest immediate integration risk:

- Codex adapter regression paths on `codex-port`
- MCP regression paths on `codex-port`
- self-host framework-repo init/update behavior on `selfhost`

This QA does not prove universal compatibility, but it removes the strongest
post-sync uncertainty identified by the retrospective analysis.
