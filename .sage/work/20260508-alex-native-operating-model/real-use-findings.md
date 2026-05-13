---
title: "Real-use findings: Alex-native operating model"
workflow: architect
phase: follow-up
status: completed
created: 2026-05-08
updated: 2026-05-09
cycle_id: "20260508-alex-native-operating-model"
---

# Real-use findings: Alex-native operating model

## Finding 1 — First real command stayed English

**Severity:** Major

**Observation:** In a fresh agent/session in `sage-selfhost`, the first simple
command (`sage status`) returned user-facing output in English.

**Additional evidence:** On 2026-05-09, Alex reported the same issue again in
another Codex thread: `codex://threads/019e0c34-ac40-7740-999e-5e00d9a54c05`.
The status output surfaced in English again after the Alex-native rollout and
after the Project Dummy validation runs.

**Why this matters:** This shows the Alex-native change did not cover real
agent/CLI interaction surfaces. The implementation focused on `.sage`
artifacts, core prompts, templates, and compact generated instruction surfaces,
but did not verify the visible output of basic commands in real work.

**Architectural implication:** The problem is not only `sage status`. It is a
coverage gap in the operating model: user-visible runtime surfaces need to be
classified and tested separately from documentation/template surfaces.

## Finding 2 — Agent treated bug report as permission to patch

**Severity:** Critical process finding

**Observation:** After Alex reported the English `sage status` output, the
agent immediately started editing code and tests instead of entering a fix
workflow, diagnosing scope, and asking for approval.

**Why this matters:** The request was informational: "I found a bug." It was
not an implementation mandate. The agent violated the desired workflow by
treating a report as implicit authorization to modify code.

**Architectural implication:** The operating model needs a stronger guardrail:
bug reports, findings, and observations should default to capture/diagnosis,
not spontaneous fixes. A fix should start only after explicit user mandate or
after the relevant workflow gate approves implementation.

## Finding 3 — Real-work tests are missing from the Alex-native patch

**Severity:** Major

**Observation:** The previous implementation passed string/generator tests but
did not run a realistic new-agent workflow test in a separate project.

**Why this matters:** The first real-use check immediately exposed a mismatch
between intended behavior and actual user experience. String tests proved that
the contract exists in files; they did not prove that an agent behaves correctly
or that CLI-facing output is localized.

**Next direction:** Reuse the real-work/harness testing pattern from the
previous Codex operating-model patches and run an analogous test in
`/Users/alexostl/Developer/dummy-project`.

## Finding 4 — Hook softening may have introduced enforcement leakage

**Severity:** Critical process finding

**Observation:** Alex reported a regression in another Codex thread:
`codex://threads/019e0c28-b19f-74f0-85ac-be37e18e4437`. According to the
report, after the previous large patch before the Polish/Alex-native patch,
Sage softened hook behavior, but the hooks started leaking too much. The agent
also appeared to ignore `AGENTS.md` and Developer Instructions in practice.

**Why this matters:** This suggests the problem is deeper than localization or
one command surface. If hooks are softened without a strong enough replacement
contract in always-loaded instructions, agents can slip past Sage workflow
gates even when `AGENTS.md` and Developer Instructions describe the correct
behavior. That weakens the exact guardrails needed for no-spontaneous-fix,
scope protection, and checkpoint discipline.

**Architectural implication:** The follow-up patch should inspect the boundary
between Codex hooks, generated `AGENTS.md`, `.codex/config.toml`
`developer_instructions`, and recovery UX. It may need stronger wording in
both `AGENTS.md` and Developer Instructions, but should not rely on prose alone
if hook behavior can enforce or audit the condition deterministically.

**Evidence status:** This is captured from Alex's report, not independently
verified in this session. The thread should be reviewed before implementation.

## Open Questions For Next Patch

- Which surfaces count as user-facing runtime output and must be Polish in
  Alex-native self-host?
- Should `.codex/config.toml` `developer_instructions` carry the compact
  Alex-native contract?
- What hook or process guard should prevent spontaneous code edits after a bug
  report that has not entered `/fix` or another approved workflow?
- Did the previous hook-softening patch create leakage that lets agents ignore
  `AGENTS.md` and Developer Instructions, and can this be strengthened in both
  hook enforcement and generated instruction surfaces?
- Which real-work test scenarios best represent first-run agent behavior:
  `sage status`, `sage continue`, entering `architect`, entering `build`, or
  a combined smoke script?

## Recommended Next Step

Do not patch the `sage status` symptom directly. First run real-work tests in
Project Dummy, observe failures, then design a follow-up patch that covers the
missing runtime surfaces and the no-spontaneous-fix guardrail together.

## Project Dummy Real-Work Evidence

Report: `.sage/work/20260508-alex-native-operating-model/dummy-project-real-work-report.md`.

Result:
- `Sage Status` real-agent scenario did not mutate files, but surfaced English
  CLI/workflow labels.
- Bug-report scenario mutated code and tests in the copied target without
  explicit implementation approval.

This confirms the next patch should be architecture/process scoped, not a
single-command localization fix.

## Project Dummy Brief-Based Matrix Evidence

Test plan: `.sage/work/20260508-alex-native-operating-model/dummy-project-brief-test-plan.md`.
Report: `.sage/work/20260508-alex-native-operating-model/dummy-project-brief-test-report.md`.
Run root: `.sage/work/20260508-alex-native-operating-model/dummy-brief-matrix-20260509000640`.

Result:
- `build`, `fix`, and `architect` start-of-work behavior improved: agents used
  Polish, inspected repo context first, and asked one question at a time.
- `analyze` created a Polish `.sage/docs` artifact, but over-escalated into
  browser/Playwright attempts for a simple UX analysis.
- `bug-report-only` reproduced the critical failure: a plain bug report caused
  the agent to patch `sage/bin/sage` and `status.bats` in the copied target
  without explicit implementation approval.
- Full `spec`/`plan` checkpoint behavior remains unverified because the tested
  scenarios stopped before those gates.

Implication: the follow-up patch must cover runtime localization inventory,
no-spontaneous-fix guardrails, port parity, and a multi-turn checkpoint test.

## Project Dummy Artifact Documentation Evidence

Report: `.sage/work/20260508-alex-native-operating-model/dummy-project-artifact-docs-report.md`.
Run root: `.sage/work/20260508-alex-native-operating-model/dummy-artifact-matrix-20260509002336`.

Result:
- `build` created `manifest.md`, `spec.md`, and `plan.md`.
- `architect` created `brief.md` and `spec.md`.
- `fix` created `manifest.md` and `plan.md`.
- Most body prose is Polish, but template headings, `handoff` labels, and some
  `title` values remain English (`State`, `Context summary`, `Tasks`, `Tests`,
  `Risks`, `Key decisions`, `Next agent should`, `Spec for...`, `Fix Plan
  for...`).

Implication: artifact language needs snapshot-style regression tests for actual
generated `brief/spec/plan/manifest/decision` files, not only prompt text.
