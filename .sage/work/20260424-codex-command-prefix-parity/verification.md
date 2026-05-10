---
title: "Verification for Codex Command Prefix Parity"
status: "completed"
phase: "verification"
created: "2026-04-24"
updated: "2026-04-24"
---

# Verification: Codex Command Prefix Parity

## Command

```bash
runtime/platforms/codex/tests/run-regression.sh
```

## Output

```text
== summary ==
PASS: Codex adapter regression checks
  Project fixture: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.t5TY0s/project
  Prefix fixture: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.t5TY0s/project-prefix-true
  Absent fixture: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.t5TY0s/project-prefix-absent
  Logs: /Users/alexostl/Developer/sage-codex/.tmp/codex-adapter-regression.t5TY0s/logs
```

## Covered scenarios

- Default / `command_prefix: false` path keeps unprefixed Codex output.
- `command_prefix: true` path prefixes Codex workflow/direct-skill surfaces,
  keeps `sage` unprefixed, keeps native `/review` native, and avoids known
  prose-corruption cases.
- Missing `command_prefix` line before `sage update` regenerates unprefixed
  Codex output.
