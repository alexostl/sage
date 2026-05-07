# Codex platform port (v1)

Codex-native deployment of Sage on top of the Codex CLI 0.126.0-alpha.15
hook surface (SessionStart / PreToolUse / PostToolUse / Stop).

## Design contract

The v1 architecture is encoded in this tree and its Bats suites:
`setup/` owns generation, `hooks/` owns runtime guardrails, and
`harness/` owns outcome measurement. Read those files and tests before
changing behavior; many decisions are deliberate trade-offs between
bash-native hooks today and possible MCP promotion later.

## What's here

```
runtime/platforms/codex/
├── audit/                      — read-only audit helpers (sage doctor S1-S4)
├── harness/                    — outcome harness (T2.7 seed; §13.2 signals)
│   ├── run-harness.sh          — orchestrator: target init → prompts → report
│   ├── lib/aggregate-signals.sh — 8-signal + v1.1 release-blocker collector
│   ├── prompts/                 — routing/recovery/capture coverage prompts
│   ├── v11-scenarios.json       — v1.1 real-harness release contract
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
# Outcome harness — runs prompt sessions on a throwaway target,
# emits the §13.2 8-signal report plus v1.1 release-blocker evidence.
runtime/platforms/codex/harness/run-harness.sh
```

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
signals empirically — see `harness/README.md` for the 8-signal table
and v1.1 release-blocker harness policy.
