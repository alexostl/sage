## Summary

<!-- 1-3 bullet points: what changed and why. -->

## Branch policy

<!-- Required for any PR touching template defaults / generator output. -->

- [ ] Source branch: <!-- self-host/main | codex-port | main -->
- [ ] Target branch: <!-- same as source unless promoting -->
- [ ] If touching template defaults (`generate-codex.sh`, `bin/sage`,
      `runtime/platforms/codex/setup/`), I checked the
      [self-host vs upstream defaults table](../.sage/docs/decision-self-host-aggressive-defaults.md)
      and confirmed `.sage/profile` guard is intact.

## Codex hook changes

<!-- Skip this section if no files in runtime/platforms/codex/hooks/*.sh changed. -->

- [ ] If I modified any `runtime/platforms/codex/hooks/*.sh`, I appended
      a new sha256 line to `runtime/platforms/codex/hooks/.versions.txt`
      in this same PR. (Append-only — never edit existing lines. See
      [ADR-1](../.sage/docs/decision-codex-hook-activation.md).)

## Test plan

- [ ] <!-- bullets describing how this was tested -->

🤖 Generated with [Claude Code](https://claude.com/claude-code)
