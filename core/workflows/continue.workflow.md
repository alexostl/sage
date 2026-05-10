---
name: continue
version: "1.0.0"
mode: continue
produces: ["Session resumption with context"]
checkpoints: 0
scope: "Instant — routes to another workflow"
user-role: "Confirm which cycle to resume"
---

# Continue Workflow

## Artifact Language Contract

When this workflow writes or updates `.sage` artifacts, natural-language prose
follows the target project language contract. Keep artifact filenames,
frontmatter keys and values, workflow/status/phase names, command names, paths,
code identifiers, quoted evidence, and raw tool/test output canonical or
verbatim.

Resume any active cycle with full context. The user doesn't need
to remember which workflow or initiative was in progress.

## Step 1: Scan for Active Cycles

Scan `.sage/work/*/manifest.md` for cycles where
`status: in-progress`, `status: paused`, or `status: intake`.

Treat `in-progress` as implementation-active, including active approval
checkpoints where the next move is to review/approve/revise the current gate.
Do not "resume" an in-progress checkpoint by changing it to paused first. Treat
`paused` and `intake` as parked/resumable but not mutation-active until the user
confirms continuation.

### One cycle found (Zone 2: Approval)

```
Sage: Resuming [{title}] — {workflow}, phase: {phase}.
{context summary, verbatim from manifest}
Next step: {next step from manifest}

[C] Continue — pick up where we left off
[S] Status — show me full cycle state before continuing
[X] Different — I want to work on something else

Pick C/S/X, or tell me what you need.
```

On [C]: Load manifest context. Route to the workflow's Auto-Pickup
with manifest as primary context source. The resuming agent follows
the handoff guidance and does NOT re-ask questions already resolved.

On [S]: Show full manifest contents (State, Context summary,
Decisions, Open questions, Handoff guidance). Then offer [C]/[X].

On [X]: "Describe what you want to work on, or type / to see commands."

If there is one single clear resumable candidate and no conflicting active
cycle, `/continue` may select it as a safe auto-fix of state navigation: report
the detected state, why the choice was unambiguous, the selected cycle, and the
next legal move. If there are multiple equivalent cycles, conflicting statuses,
or ambiguous repo ownership, hard-stop and ask the user to choose.

Cross-repo rule: `/continue` reads the target repository's `.sage/work/`
manifests from the current working directory. The framework repository does not stand in
for the target repo's state, memory, scope, gates, or recovery.

### Multiple cycles found (Zone 1: Choice)

```
Sage: Found {N} resumable cycles:

[1] {title A} — {workflow}, phase: {phase}, status: {status} (updated: {date})
[2] {title B} — {workflow}, phase: {phase}, status: {status} (updated: {date})
[3] Start something new

Pick 1-{N+1}, type / for commands, or describe what you need.
```

On selection: load that cycle's manifest, route to its workflow.

### No cycles found (Zone 4: Open)

```
Sage: No active cycles found.

Describe what you want to work on, or type / to see commands.
```

## Step 2: Load Context and Resume

1. Read the selected manifest.md
2. Read the relevant artifacts (spec, plan, brief)
3. Read decisions.md entries for this cycle
4. Resume at the phase indicated by the manifest

The resuming agent behaves as if it has the context described
in the manifest's context summary. It follows the handoff
guidance. It does NOT re-ask questions the previous agent
already resolved — those decisions are in the manifest and
decisions.md.

## Routing

/continue reads the `workflow` field in the manifest and activates
the corresponding workflow's Auto-Pickup:

| workflow field | Routes to |
|---------------|-----------|
| build | /build Auto-Pickup |
| architect | /architect Auto-Pickup |
| fix | /fix Auto-Pickup |
| research | /research Auto-Pickup |
| design | /design Auto-Pickup |
| analyze | /analyze Auto-Pickup |
| reflect | /reflect Auto-Pickup |

## What /continue Does NOT Do

- Does not manage parallel execution
- Does not replace decisions.md (manifest decisions are a subset)
- Does not replace handoff fields in artifact frontmatter
- Does not auto-save on crash (manifest may be stale if session
  died unexpectedly — fallback to artifact-scanning still works)

## Rules

- /continue reads the manifest as PRIMARY context source
- Do NOT ignore the manifest and re-scan artifacts from scratch
- The manifest's phase routing and context summary take precedence
- Agent MAY additionally read artifacts for detail
- If manifest doesn't exist but artifacts do, route to the
  workflow's Auto-Pickup which will use file-scan fallback
