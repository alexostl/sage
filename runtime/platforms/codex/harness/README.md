# Codex outcome harness — v1 seed

Lightweight measurement scaffold for the Codex port. Aggregates the
8 v2-promotion-trigger signals from spec §13.2 against a real
`codex exec --json` session.

**Plan contract:** [T2.7 in plan.md](../../../../.sage/work/20260429-codex-port-rewrite/plan.md).

## What it measures (8 signals)

Per spec §13.2 + plan T2.7 done-criteria:

| # | Signal | Status | What it answers |
|---|---|---|---|
| 1 | `workflow_entry` | wired | How often did agent invoke `/sage:*`? |
| 2 | `phase_jump` | wired | How often did Stop hook flag unauthorized status flip? |
| 3 | `bypass_mutation` | wired | How often did Stop hook detect unclaimed git diff? |
| 4 | `doctor_s1` | wired | S1 incidents after harness run |
| 5 | `bash_mutation_leaks` | **STUB** | Agent `bash` tool writes to managed paths (cost > 1 day in v1) |
| 6a | `predicate_loc` | wired | `pre-tool-validate.sh` LOC vs §6.0 80-line ceiling |
| 6b | `predicate_p95_latency` | **STUB** | Per-invocation duration_ms (hooks don't yet log timing) |
| 7 | `l1_bypass` | wired | Commits without `.session-mutations.log` entries |
| 8 | `decisions_missing` | wired | Cycle frontmatter flips without same-commit decisions.md update |

7-of-8 wired; 5 + 6b explicitly stubbed with TODO markers (plan
T2.7 anti-gap rule — declared, not silent).

## How to run

```bash
runtime/platforms/codex/harness/run-harness.sh
```

Optional: set `HARNESS_OUT=/some/path` to control output location.
Default is a `mktemp -d` under `$TMPDIR`.

The harness:
1. Creates a fresh `git init` target at `$OUT/target/`
2. Runs `bin/sage init --platform codex --preset base` on it
3. Executes 5 prompts via `codex exec --json` (see `prompts/`)
4. Captures one JSONL transcript per prompt at `$OUT/transcripts/`
5. Runs `lib/aggregate-signals.sh` to produce `$OUT/report.json`

End-to-end: ~3-5 minutes (5 prompts × ~30-60s each on Codex
0.126.0-alpha.15).

## Prompts

Five prompts cover the routing surface:

1. **01-build-en-clean** — clear English build trigger
2. **02-build-pl-typos** — Polish + typos (regex-classifier dead-end test)
3. **03-build-out-of-scope** — write outside any cycle scope (tests PreToolUse rejection)
4. **04-fix-trigger** — fix workflow trigger
5. **05-routing-edge** — read-only question (should NOT trigger build)

Add prompts to `prompts/` to extend coverage. The aggregator picks
up all `*.txt` files automatically.

## Pre-flight

- `codex` ≥ 0.126.0-alpha.15 on PATH
- `jq` and `git` on PATH
- Framework's `bin/sage` executable

## Output schema (`report.json`)

```json
{
  "ts": "2026-04-30T...",
  "codex_version": "...",
  "target": "/tmp/codex-harness.X/target",
  "signals": {
    "1_workflow_entry": { "count": N, "total": 5, "rate": ... },
    "2_phase_jump":     { "count": N },
    "3_bypass_mutation":{ "count": N },
    "4_doctor_s1":      { "count": N },
    "5_bash_mutation_leaks": { "status": "TODO", "note": "..." },
    "6a_predicate_loc": { "loc": N, "ceiling": 80, "over_ceiling": false },
    "6b_predicate_p95_latency_ms": { "status": "TODO", "note": "..." },
    "7_l1_bypass":      { "count": N, "total": M, "rate": ... },
    "8_decisions_missing": { "count": N, "total": M, "rate": ... }
  }
}
```

Each numeric signal is a count + (where meaningful) a total + rate.
TODO signals carry a `status` and `note` explaining why deferred.

## Scope

**Seed only.** This produces a baseline reading from a single run.
The full pilot (12-15 prompts × multiple seeds × statistical
analysis per spec C5) is v1.x or v2 work. Per plan T2.7, this seed
unblocks v2-promotion decisions by giving §13.2 thresholds
something to compare against.
