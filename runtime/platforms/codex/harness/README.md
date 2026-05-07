# Codex outcome harness — v1 seed

Lightweight measurement scaffold for the Codex port. Aggregates the
8 v2-promotion-trigger signals from spec §13.2 against a real
`codex exec --json` session.

## What it measures (8 signals)

The harness tracks these eight v2-promotion-trigger signals:

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

7-of-8 wired; 5 + 6b are explicitly stubbed with TODO markers, so deferred measurement is declared rather than silent.

## How to run

```bash
runtime/platforms/codex/harness/run-harness.sh
```

Optional: set `HARNESS_OUT=/some/path` to control output location.
Default is a `mktemp -d` under `$TMPDIR`.

The harness:
1. Creates a fresh `git init` target at `$OUT/target/`
2. Runs `bin/sage init --platform codex --preset base` on it
3. Executes every prompt in `prompts/` via `codex exec --json`
4. Captures one JSONL transcript per prompt at `$OUT/transcripts/`
5. Runs `lib/aggregate-signals.sh` to produce `$OUT/report.json`

End-to-end depends on prompt count (~30-60s each on Codex
0.126.0-alpha.15).

## Prompts

Prompts cover the routing surface:

1. **01-build-en-clean** — clear English build trigger
2. **02-build-pl-typos** — Polish + typos (regex-classifier dead-end test)
3. **03-build-out-of-scope** — write outside any cycle scope (tests PreToolUse rejection)
4. **04-fix-trigger** — fix workflow trigger
5. **05-routing-edge** — read-only question (should NOT trigger build)
6. **06-action-creates-or-resumes-manifest** — action prompt creates/resumes state
7. **07-capture-router-minimal-intake** — unrelated finding becomes intake
8. **08-safe-autofix-metadata** — reversible metadata repair keeps work moving
9. **09-memory-correction-reuse** — `.sage-memory` correction is reused
10. **10-cross-repo-target-state** — target repo owns workflow state

Add prompts to `prompts/` to extend coverage. The aggregator picks
up all `*.txt` files automatically.

## v1.1 Verification Policy

Deterministic Bats tests are required for framework outputs: generated
instructions, hook predicates, `status`/`doctor` text, artifact routing text,
and audit log schemas.

Real Codex harness evidence is required for claims about agent/runtime
behavior: workflow routing, recovery behavior, Capture Router behavior,
memory reuse across sessions, and cross-repo state ownership. These scenarios
are declared in `v11-scenarios.json`.

Harness failures block release claims when the changed behavior depends on
Codex following the operating model. Harness failures are advisory for
unrelated text-only changes that do not alter agent/runtime behavior, provided
the deterministic tests for the touched surface pass and the limitation is
called out in the checkpoint.

`report.json` includes `signals.v11_release_blocker_harness`. v1.1 cannot be
marked complete unless deterministic tests pass and every release-blocker
scenario has a real Codex transcript from the current harness run with
`codex exec` exit code `0`.

## Pre-flight

- `codex` ≥ 0.126.0-alpha.15 on PATH
- `jq` and `git` on PATH
- Framework's `bin/sage` executable
- Harness runs `codex exec --ignore-user-config` so user-level settings such
  as an unsupported `service_tier` do not invalidate release evidence.

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
    "8_decisions_missing": { "count": N, "total": M, "rate": ... },
    "v11_release_blocker_harness": {
      "total": 7,
      "present": 7,
      "missing": [],
      "complete": true
    }
  }
}
```

Each numeric signal is a count + (where meaningful) a total + rate.
TODO signals carry a `status` and `note` explaining why deferred.

## Scope

**Seed only.** This produces a baseline reading from a single run.
The full pilot (12-15 prompts × multiple seeds × statistical
analysis per spec C5) is v1.x or v2 work. This seed unblocks v2-promotion decisions by giving future thresholds something to compare against.
