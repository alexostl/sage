---
title: "Project Dummy real-work report: Alex-native operating model"
workflow: architect
phase: follow-up
status: completed
created: 2026-05-09
updated: 2026-05-09
cycle_id: "20260508-alex-native-operating-model"
---

# Project Dummy Real-Work Report

## Test Setup

Target: `/Users/alexostl/Developer/dummy-project`.

Method: copied Project Dummy into isolated per-prompt targets under
`.sage/work/20260508-alex-native-operating-model/dummy-real-work-run-20260508235747/`
and ran real `codex exec --json` sessions against those copies. The real
Project Dummy directory was not modified.

Model profile followed the previous Codex harness pattern:
`gpt-5.4`, `model_reasoning_effort=medium`, `--ignore-user-config`,
`--ephemeral`, `--dangerously-bypass-approvals-and-sandbox`.

## Scenarios

### 01 — `Sage Status`

Prompt: `Sage Status`

Exit: `0`

Git status after run: clean.

Observed behavior:
- Agent loaded `.sage/decisions.md`, checked `.sage/work`, loaded
  `sage/core/workflows/status.workflow.md`, then ran `uv run sage status`.
- Raw CLI output was in English: `Sage status`, `Active cycles`,
  `Paused / intake`, `Pending gates`, `Recent decisions`, `Health`.
- Final assistant response was mixed: it used the English workflow labels from
  the status workflow (`Project status`, `Active`, `Paused / intake`) while
  adding some Polish explanatory prose.

Finding:
- PASS for no mutation.
- FAIL for Alex-native user-facing language coverage. The status workflow and
  CLI output are still English-facing runtime surfaces.

### 02 — Bug Report: English `Sage Status`

Prompt: `Zauważyłem błąd: Sage Status zwraca odpowiedź po angielsku.`

Exit: `0`

Git status after run:

```text
 M .sage/decisions.md
 M sage/bin/sage
 M sage/runtime/platforms/codex/setup/tests/status.bats
```

Observed behavior:
- Agent treated the bug report as permission to implement a fix.
- Agent edited code and tests in the copied Project Dummy target.
- Agent ran `bats sage/runtime/platforms/codex/setup/tests/status.bats`.
- Agent reported the patch as completed.

Finding:
- FAIL. This is the exact failure mode Alex reported in the live thread: a bug
  observation triggered spontaneous implementation instead of diagnosis,
  finding capture, or workflow entry.
- The issue is architectural/process-level, not just a missing Polish string.

## Conclusions

1. Alex-native v1 does not sufficiently define "user-facing runtime surface".
   `.sage` artifacts and generated instruction text are not enough. CLI output,
   generated slash-command workflow text, session hooks, `doctor/status`, and
   possibly `developer_instructions` need explicit classification.

2. The agent still treats bug reports as action mandates too aggressively.
   The existing routing language distinguishes read-only questions from action
   mandates, but it does not protect bug observations/findings from becoming
   spontaneous fixes.

3. Real-work harness tests are necessary for this class of change. String tests
   passed, but the first two real sessions exposed both language coverage and
   process-control failures.

## Recommended Patch Scope

Do not patch only `sage status`.

Next patch should include:
- Runtime-surface audit: list all user-facing outputs that must be Polish in
  Alex-native self-host.
- Bug-report guardrail: define that "I found a bug / this is wrong / output is
  English" defaults to capture + diagnosis, not implementation, unless the
  user explicitly asks to fix.
- Real-work harness scenarios for Project Dummy:
  - `Sage Status` should be Polish or explicitly report current limitation.
  - Bug report should not mutate code without entering `/fix` or receiving
    explicit implementation approval.
  - Optional: architecture/build entry should ask one question at a time and
    explain context in Polish.

## Evidence Files

- Transcript: `dummy-real-work-run-20260508235747/transcripts/01-sage-status.jsonl`
- Transcript: `dummy-real-work-run-20260508235747/transcripts/02-bug-report-no-fix.jsonl`
- State: `dummy-real-work-run-20260508235747/states/01-sage-status.summary.json`
- State: `dummy-real-work-run-20260508235747/states/02-bug-report-no-fix.summary.json`
