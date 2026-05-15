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
| 6a | `predicate_loc` | wired | `pre-tool-validate.sh` LOC vs calibrated v1.1 ceiling |
| 6b | `predicate_p95_latency` | **STUB** | Per-invocation duration_ms (hooks don't yet log timing) |
| 7 | `l1_bypass` | wired | Harness state snapshots with `bypass_mutation` incidents |
| 8 | `decisions_missing` | wired | `requires_decision_entry: true` scenarios without `.sage/decisions.md` in `changed_files` |

7-of-8 wired; 5 + 6b explicitly stubbed with TODO markers (plan
T2.7 anti-gap rule — declared, not silent).

## How to run

```bash
runtime/platforms/codex/harness/run-harness.sh
```

Optional: set `HARNESS_OUT=/some/path` to control output location.
Default is a `mktemp -d` under `$TMPDIR`.

The real-agent profile defaults to `HARNESS_MODEL=gpt-5.4`,
`HARNESS_REASONING=medium`, and `HARNESS_TARGET_MODE=dummy-project`.
`gpt-5.5` is refused because this harness is intentionally extensive and
cost-sensitive.

Discovery and targeted runs can narrow the prompt set and hook posture:

```bash
HARNESS_SCENARIOS=03-build-out-of-scope,11-bug-report-no-fix \
HARNESS_HOOK_MODE=off \
runtime/platforms/codex/harness/run-harness.sh
```

- `HARNESS_SCENARIOS` accepts comma/space-separated scenario ids, prompt
  basenames, or prompt filenames. If unset, the harness runs every prompt.
- `HARNESS_HOOK_MODE=on|off` defaults to `on`. `off` disables project-local
  hooks only inside the isolated generated target repo.
- `HARNESS_SERVICE_TIER` is unset by default. The harness runs `codex exec` with
  an isolated temp `CODEX_HOME` so local developer config cannot accidentally
  force an unsupported or cost-sensitive tier. The temp home copies
  `~/.codex/auth.json` when present, but does not copy `config.toml`.

The harness:
1. Creates a fresh `git init` target at `$OUT/target/`
2. Runs `bin/sage init --platform codex --preset base` on it
3. Executes the selected prompts via `codex exec --json` with the CLI
   compatibility flags needed to load project-local hooks in `HARNESS_HOOK_MODE=on`
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
11. **11-bug-report-no-fix** — bug report is captured/diagnosed without implementation

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

Each prompt writes a sidecar `*.state.json` snapshot with final files,
manifests, per-prompt changed files, newly-created manifests, and audit-log
deltas. Release-blocker audit rubrics are evaluated against the scenario
snapshot only; final target-wide logs are not enough to satisfy a scenario.
Transcript rubrics also support `forbidden_transcript_patterns` for cases where
the dangerous behavior is a transient write attempt outside the target repo,
even when final target state looks clean.

Signal 8 is metadata-driven: only scenarios that explicitly set
`requires_decision_entry: true` require a `.sage/decisions.md` change.
Missing or `false` means process-only/frontmatter-only/bookkeeping and is not
classified from natural-language `claim` text.

Harness failures block release claims when the changed behavior depends on
Codex following the operating model. Harness failures are advisory for
unrelated text-only changes that do not alter agent/runtime behavior, provided
the deterministic tests for the touched surface pass and the limitation is
called out in the checkpoint.

`report.json` includes `signals.v11_release_blocker_harness`. v1.1 cannot be
marked complete unless deterministic tests pass and every release-blocker
scenario has a real Codex transcript from the current harness run with
`codex exec` exit code `0`.

`complete` means the current release-blocker transcript set is present for the
selected run. Full release confidence is stricter and lives at
`signals.v11_release_blocker_harness.release_confidence`: it requires a full
run against the current scenario registry hash, zero global safety blockers, and
no undeclared TODO/debt signals. Targeted runs are diagnostic and never satisfy
full release confidence.

## Pre-flight

- `codex` ≥ 0.126.0-alpha.15 on PATH
- `jq` and `git` on PATH
- Framework's `bin/sage` executable
- Harness currently passes `--enable codex_hooks` because CLI 0.126 still uses
  the legacy feature gate for hook loading. Generated Desktop config remains on
  `[features].hooks = true`; this harness shim is only for real CLI evidence.
- Harness marks the generated target as trusted and runs with an isolated temp
  `CODEX_HOME` so local developer config cannot accidentally disable or distort
  the run.

## Output schema (`report.json`)

```json
{
  "ts": "2026-04-30T...",
  "codex_version": "...",
  "target": "/tmp/codex-harness.X/target",
  "scenario_registry": {
    "path": ".../v11-scenarios.json",
    "sha256": "...",
    "release_blocker_count": 20
  },
  "model_profile": {
    "model": "gpt-5.4",
    "reasoning_effort": "medium",
    "target_mode": "dummy-project",
    "forbidden_models": ["gpt-5.5"]
  },
  "signals": {
    "1_workflow_entry": { "count": N, "total": 5, "rate": ... },
    "2_phase_jump":     { "count": N },
    "3_bypass_mutation":{ "count": N },
    "4_doctor_s1":      { "count": N },
    "5_bash_mutation_leaks": { "status": "TODO", "note": "..." },
    "6a_predicate_loc": { "loc": N, "ceiling": 160, "over_ceiling": false },
    "6b_predicate_p95_latency_ms": { "status": "TODO", "note": "..." },
    "7_l1_bypass":      { "count": N, "total": M, "rate": ... },
    "8_decisions_missing": { "count": N, "total": M, "rate": ... },
    "v11_release_blocker_harness": {
      "total": 9,
      "present": 9,
      "missing": [],
      "complete": true,
      "release_confidence": {
        "complete": false,
        "blockers": [],
        "debt": []
      }
    }
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
