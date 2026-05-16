---
name: status
version: "1.1.0"
mode: status
produces: ["Project state summary computed from artifacts"]
checkpoints: 0
scope: "Instant"
user-role: "Read and decide next step"
---

# Status Workflow

## Artifact Language Contract

When this workflow writes or updates `.sage` artifacts, natural-language prose
follows the target project language contract. Keep artifact filenames,
frontmatter keys and values, workflow/status/phase names, command names, paths,
code identifiers, quoted evidence, and raw tool/test output canonical or
verbatim.

Show current Sage project state. Computed from artifacts — always current.

## Process

Scan and display:

1. `.sage/work/` — read manifest frontmatter for lifecycle state
2. `.sage/docs/` — list project-level artifacts
3. `.sage/decisions.md` — last 3-5 entries for recent context
4. `.sage/gates/gate-modes.yaml` — current gate activation config

Present concisely:

**Sage:** Project status for [name]

Active:
  [initiative-name] [status, phase]
    brief ✓  spec ✓  plan (in-progress)
    .sage/work/YYYYMMDD-slug/

Paused / intake:
  [initiative-name] [paused, phase] — resumable, not mutation-active
  [initiative-name] [intake] — parked actionable work, no implementation started

History:
  closed/shipped/folded/rejected counts only; details are search-first when needed

Docs: [N] files in .sage/docs/
Recent decisions: [last 2-3 decision titles]
Gates: [mode config summary]

[1] Continue [initiative] — type /build
[2] Start something new

## Rules

- Report what actually exists, not what should exist.
- Compute from artifacts — never read progress.md.
- If `.sage/work/` is empty, say so. Don't fabricate state.
- Always suggest the next slash command.
- `in-progress` is active workflow state, including gated checkpoints where
  `phase` is `root-cause-gate`, `fix-scope-gate`, `plan-gate`, or another
  approval gate. Hooks may still block implementation until artifacts/scope are
  approved, but the cycle is not parked.
- `paused` and `intake` are visible and resumable, but not
  implementation-active for hooks.
- Closed cycle manifests use `status: closed` and `phase: closed`; the close
  outcome is stored in `resolution: shipped | superseded | folded_into |
  rejected`. Legacy `status: completed` is read as closed during migration.
- `work_index` is derived from manifest frontmatter only. It is the lightweight
  lifecycle layer for status JSON; do not read manifest bodies, raw evidence,
  transcripts, or archive decisions for ordinary status.
- Closed/folded/rejected history is count-only in default status. When
  details are needed, search targeted artifacts with `rg` and read only the
  matching fragment.
- `recent_decisions` and `health` are context/diagnostic layers. They do not
  replace manifest frontmatter as lifecycle source-of-truth.
- `status` surfaces current active/resumable work and brief next actions.
  `doctor` diagnoses structural inconsistencies such as actionable work placed
  in `.sage/docs/`.
- If recovery-first behavior applied a safe auto-fix, status may summarize the
  resulting current state, but durable details live in `.sage/.auto-fixes.log`
  and `doctor` surfaces the audit trail. A safe auto-fix is only reversible
  metadata/state hygiene; anything that changes scope, product behavior, risk,
  or ownership is a stop-and-ask condition.
- Status is computed from the target repository's `.sage/` state. In
  cross-repo work, the edited/current working repository owns workflow state,
  memory, scope, gates, and recovery; framework repository state is not a
  substitute.
