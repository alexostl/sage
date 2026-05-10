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
│   ├── run-harness.sh          — orchestrator: target init → prompts → report
│   ├── lib/aggregate-signals.sh — 8-signal + v1.1 release-blocker collector
│   ├── prompts/                 — routing/recovery/capture coverage prompts
│   ├── v11-scenarios.json       — v1.1 real-harness release contract
│   └── README.md
├── hooks/                      — bash-native v1 hook implementations
│   ├── lib/                    — sourced helpers (json_log, active_init,
│   │                              path_normalize)
│   ├── pre-tool-validate.sh    — PreToolUse(apply_patch/Edit/Write) gate
│   ├── post-tool-check.sh      — PostToolUse(apply_patch/Edit/Write) audit
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

For development on the framework itself, follow the cycle plan at
[.sage/work/20260429-codex-port-rewrite/plan.md](../../../.sage/work/20260429-codex-port-rewrite/plan.md).
Bats sweep:

```bash
bats runtime/platforms/codex/setup/tests/ runtime/platforms/codex/hooks/tests/
```

## Hook activation and coverage

Generated Codex config enables the current Desktop hook flag with
`[features].hooks = true` and deploys `.codex/hooks.json`. The registry
matches `apply_patch|Edit|Write` for file-edit hooks plus `Stop` for turn-end
audit. The real-agent harness also passes `--enable codex_hooks` because CLI
0.126 still requires the legacy feature gate to load project-local hooks;
Desktop config should stay on `[features].hooks = true`.

PreToolUse enforces both patch-style edits and `file_change` payloads when the
runtime surfaces them. Stop/audit remains the fallback evidence layer for any
mutation path that a runtime does not expose before write-time.

## Why `bash + jq + yq`, not MCP?

Spec §6 + §8: bash hooks are the v1 substrate because they are
debuggable, hot-reloadable, and require no daemon. MCP is the v2
upgrade path triggered when one of the v2-promotion signals fires
(predicate > ~200 LOC, p95 latency > 1s, approval-gate logic
returns, etc.). The outcome harness in `harness/` collects those
signals empirically — see `harness/README.md` for the 8-signal table
and v1.1 release-blocker harness policy.
