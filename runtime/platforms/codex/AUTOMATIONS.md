# Sage Automation Templates for Codex

These are examples only. Sage does not ship its own automation runner on
Codex; use Codex-native automations and adapt the prompts below to your repo.

## Pick the Right Automation Shape

- Use a thread automation when you want follow-up work to continue in the same
  thread, with the same running context and conversation history.
- Use a standalone automation when you want a clean recurring task that can
  run independently of the current thread.
- For Git repositories, prefer standalone automations with worktrees when the
  task may edit files, open diffs, or need clean isolation from your active
  workspace.
- For lightweight reminders, triage, and periodic check-ins on work already in
  progress, prefer a thread automation.

## Template: Repo Brief

Best fit:
- weekly or twice-weekly standalone automation
- or a thread automation for an active repo that already has a planning thread

Use when:
- you want a compact summary of repo state, active Sage work, and likely next
  moves

Suggested prompt:

```text
Read the current Sage project state from .sage/work/ and .sage/decisions.md,
inspect recent repository activity, and produce a concise repo brief. Include:
1. active initiatives
2. recent meaningful changes
3. notable risks or blockers
4. the most sensible next actions

If the repo is quiet, say what still appears active from Sage state instead of
inventing momentum.
```

## Template: CI Triage

Best fit:
- standalone automation for repositories with recurring build or test noise

Use when:
- you want a regular pass over recent failures, flaky checks, or open quality
  issues

Suggested prompt:

```text
Review the latest CI-relevant signals available in this workspace and triage
them into:
1. likely real failures
2. likely flaky or transient noise
3. follow-up items worth scheduling for engineering work

When possible, connect the failures back to current Sage initiatives in
.sage/work/. Keep the result short and action-oriented.
```

## Template: Review Follow-Up

Best fit:
- thread automation tied to an implementation or review thread

Use when:
- you want a scheduled second-pass review after fixes land or after a risky
  change has had time to settle

Suggested prompt:

```text
Revisit the work discussed in this thread and perform a follow-up review.
Check whether the previously noted risks were addressed, whether the current
diff introduces new regressions, and what still needs attention.

Use Codex-native review surfaces when useful, but keep the output focused on:
1. resolved findings
2. remaining risks
3. recommended next action
```

## Template: Reflect / Retro

Best fit:
- thread automation after a milestone, release, or intense debug cycle

Use when:
- you want to convert recent work into durable learnings without building a
  full retrospective process

Suggested prompt:

```text
Reflect on the recent work in this repository and summarize:
1. what changed
2. what worked well
3. what created friction
4. what should be repeated, avoided, or documented next time

Anchor the reflection in recent Sage state and repository activity rather than
generic advice.
```

## Practical Notes

- Keep automation prompts short and durable. The schedule and workspace belong
  in the automation settings, not in the prompt body.
- If a recurring task should create or edit code, use a standalone automation
  on a worktree-enabled Git repo rather than waking up your main working tree.
- If the automation is mainly checking progress, reviewing, or reminding you to
  continue the same stream of work, use a thread automation instead.
