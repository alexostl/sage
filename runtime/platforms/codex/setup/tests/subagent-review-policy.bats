#!/usr/bin/env bats
# Source-level assertions for subagent review approval and recall policy.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    grep -Fq "$pattern" "$REPO_ROOT/$file"
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    ! grep -Fq "$pattern" "$REPO_ROOT/$file"
}

@test "subagent review checkpoints do not approve the next phase implicitly" {
    assert_not_contains "core/workflows/fix.workflow.md" "to verify diagnosis, then proceed"
    assert_not_contains "core/workflows/fix.workflow.md" "to review the fix plan, then implement"
    assert_not_contains "core/workflows/build.workflow.md" "to review the spec, then continue to plan"
    assert_not_contains "core/workflows/build.workflow.md" "to review the plan, then start building"
    assert_not_contains "core/workflows/architect.workflow.md" "to review ADRs/design, then continue to plan"
    assert_not_contains "core/workflows/architect.workflow.md" "to review the plan, then start milestone 1"
    assert_not_contains "core/capabilities/review/auto-review/SKILL.md" "[A] Review - sub-agent reviews, then proceed"
    assert_not_contains "core/capabilities/review/auto-review/SKILL.md" "[A] Review — sub-agent reviews, then proceed"
}

@test "subagent review checkpoints preserve separate approval and autonomy paths" {
    assert_contains "core/workflows/fix.workflow.md" "[A] Subagent review"
    assert_contains "core/workflows/fix.workflow.md" "[S] Skip review"

    assert_contains "core/workflows/build.workflow.md" "[A] Subagent review"
    assert_contains "core/workflows/build.workflow.md" "[S] Skip review"
    assert_contains "core/workflows/build.workflow.md" "[C] Checkpointed implementation"
    assert_contains "core/workflows/build.workflow.md" "[F] Full autonomous implementation"

    assert_contains "core/workflows/architect.workflow.md" "[A] Subagent review"
    assert_contains "core/workflows/architect.workflow.md" "[S] Skip review"

    assert_contains "core/capabilities/review/auto-review/SKILL.md" "[A] Review"
    assert_contains "core/capabilities/review/auto-review/SKILL.md" "[S] Skip review"
    assert_contains "core/capabilities/review/auto-review/SKILL.md" "user decides"
}

@test "auto-review prompts include targeted SageMemory recall contract" {
    local file="core/capabilities/review/auto-review/SKILL.md"

    assert_contains "$file" "Targeted Recall For Subagent Review"
    assert_contains "$file" "Do not preload memory for every task"
    assert_contains "$file" "sage_memory_set_project"
    assert_contains "$file" "filter_tags: [\"self-learning\"]"
    assert_contains "$file" ".sage-memory/self-learning.md"
    assert_contains "$file" "prevention rules"
    assert_contains "$file" "set/select the current project"
}

@test "auto-review and auto-QA verdicts are process evidence, not mandatory decisions" {
    assert_contains "core/capabilities/review/auto-review/SKILL.md" "process evidence"
    assert_contains "core/capabilities/review/auto-review/SKILL.md" 'Do not create a global `.sage/decisions.md` entry for every verdict'
    assert_not_contains "core/capabilities/review/auto-review/SKILL.md" 'After every auto-review (any verdict), prepend to `.sage/decisions.md`'

    assert_contains "core/capabilities/review/auto-qa/SKILL.md" "process evidence"
    assert_contains "core/capabilities/review/auto-qa/SKILL.md" 'Do not create a global `.sage/decisions.md` entry for every verdict'
    assert_not_contains "core/capabilities/review/auto-qa/SKILL.md" 'After every auto-QA (any verdict), prepend to `.sage/decisions.md`'
}
