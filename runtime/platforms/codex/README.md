# Codex platform port (v1)

Codex-native deployment of Sage on top of the Codex CLI 0.126.0-alpha.15
hook surface (SessionStart / PreToolUse / PostToolUse / Stop).

## Authoritative spec

The complete v1 architecture, hook contracts, and MCP-vs-bash decisions
live in [.sage/work/20260429-codex-port-rewrite/spec.md](../../../.sage/work/20260429-codex-port-rewrite/spec.md).
Read the spec before changing anything in this tree — many design
choices are deliberate trade-offs documented in §6 (hook surface) and
§8 (v2 promotion triggers).

## What's here

```
runtime/platforms/codex/
├── audit/                      — read-only audit helpers (sage doctor S1-S4)
├── harness/                    — outcome harness (T2.7 seed; §13.2 signals)
│   ├── run-harness.sh          — orchestrator: target init → 5 prompts → report
│   ├── lib/aggregate-signals.sh — 8-signal collector (7 wired, 5+6b stub)
│   ├── prompts/                 — 5 routing-coverage prompts
│   └── README.md
├── hooks/                      — bash-native v1 hook implementations
│   ├── lib/                    — sourced helpers (json_log, active_init,
│   │                              path_normalize)
│   ├── pre-tool-validate.sh    — PreToolUse(apply_patch) gate
│   ├── post-tool-check.sh      — PostToolUse(apply_patch) audit
│   ├── session-init.sh         — SessionStart banner + cycle summary
│   ├── turn-audit.sh           — Stop event Sage-audit (partial ADR-7)
│   └── tests/                  — bats suite (223 tests)
└── setup/                      — bin/sage init pipeline (10 stages)
    └── tests/                  — bats setup pipeline (140+ tests)
```

## Quickstart (smoke test against a fresh target)

```bash
# Outcome harness — runs 5 codex sessions on a throwaway target,
# emits the §13.2 8-signal report.
runtime/platforms/codex/harness/run-harness.sh
```

For development on the framework itself, follow the cycle plan at
[.sage/work/20260429-codex-port-rewrite/plan.md](../../../.sage/work/20260429-codex-port-rewrite/plan.md).
Bats sweep:

```bash
bats runtime/platforms/codex/setup/tests/ runtime/platforms/codex/hooks/tests/
```

## Why `bash + jq + yq`, not MCP?

Spec §6 + §8: bash hooks are the v1 substrate because they are
debuggable, hot-reloadable, and require no daemon. MCP is the v2
upgrade path triggered when one of the v2-promotion signals fires
(predicate > ~200 LOC, p95 latency > 1s, approval-gate logic
returns, etc.). The outcome harness in `harness/` collects those
signals empirically — see `harness/README.md` for the 8-signal
table.
