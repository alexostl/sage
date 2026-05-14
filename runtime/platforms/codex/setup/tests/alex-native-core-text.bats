#!/usr/bin/env bats
# Alex-native operating contract shared-source assertions.
#
# These tests intentionally read the canonical core files directly. The Codex
# and Claude generators mirror only compact always-loaded parts; the full
# behavior must live in shared Sage core.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$REPO_ROOT/$file"
}

assert_between_contains() {
    local file="$1"
    local start="$2"
    local end="$3"
    local pattern="$4"
    awk -v start="$start" -v end="$end" '
        $0 ~ start { in_range = 1 }
        in_range { print }
        $0 ~ end { exit }
    ' "$REPO_ROOT/$file" | grep -q "$pattern"
}

@test "alex-native core: constitution and navigator define the self-host contract" {
    assert_contains "core/constitution/sage-process.constitution.md" "Alex-native operating contract"
    assert_contains "core/constitution/sage-process.constitution.md" "Treść prozatorską nowych sekcji"
    assert_contains "core/constitution/sage-process.constitution.md" "starszego angielskiego pliku"
    assert_contains "core/constitution/sage-process.constitution.md" "plain technical prose"
    assert_contains "core/constitution/sage-process.constitution.md" "visible impact and cause"
    assert_contains "core/constitution/sage-process.constitution.md" "technical mechanism"
    assert_contains "core/constitution/sage-process.constitution.md" "next action"
    assert_contains "core/constitution/sage-process.constitution.md" "Full autonomous implementation"
    assert_contains "core/constitution/sage-process.constitution.md" "jedno pytanie naraz"
    assert_contains "core/constitution/sage-process.constitution.md" "1-3 klikalne linki"

    assert_contains "core/capabilities/orchestration/sage-navigator/SKILL.md" "Alex-native operating contract"
    assert_contains "core/capabilities/orchestration/sage-navigator/SKILL.md" "jedno pytanie naraz"
    assert_contains "core/capabilities/orchestration/sage-navigator/SKILL.md" "Junior Dev Vibecoder"
}

@test "alex-native core: workflows cover Polish artifacts and autonomy checkpoints" {
    assert_contains "core/workflows/build.workflow.md" "Autonomiczna kontynuacja"
    assert_contains "core/workflows/build.workflow.md" "po spec"
    assert_contains "core/workflows/build.workflow.md" "po plan"
    assert_contains "core/workflows/build.workflow.md" "zatrzymaj sie przed implementation"

    assert_contains "core/workflows/architect.workflow.md" "jedno pytanie naraz"
    assert_contains "core/workflows/architect.workflow.md" "1-3 klikalne linki"
    assert_contains "core/workflows/architect.workflow.md" "po polsku"

    assert_contains "core/workflows/design.workflow.md" "1-3 klikalne linki"
    assert_contains "core/workflows/design.workflow.md" "po polsku"

    assert_contains "core/workflows/analyze.workflow.md" "jedno pytanie naraz"
    assert_contains "core/workflows/analyze.workflow.md" "po polsku"

    assert_contains "core/workflows/fix.workflow.md" "root cause"
    assert_contains "core/workflows/fix.workflow.md" "linki do dowodow"
}

@test "alex-native core: elicitation and planning capabilities use junior-friendly conversation" {
    assert_contains "core/capabilities/elicitation/deep-elicit/SKILL.md" "jedno pytanie naraz"
    assert_contains "core/capabilities/elicitation/deep-elicit/SKILL.md" "sprawdz repo"

    assert_contains "core/capabilities/elicitation/quick-elicit/SKILL.md" "jedno pytanie naraz"
    assert_contains "core/capabilities/elicitation/quick-elicit/SKILL.md" "sprawdz repo"

    assert_contains "core/capabilities/planning/specify/SKILL.md" "Treść prozatorską nowych sekcji"
    assert_contains "core/capabilities/planning/specify/SKILL.md" "Sage terms"

    assert_contains "core/capabilities/planning/plan/SKILL.md" "Treść prozatorską nowych sekcji"
    assert_contains "core/capabilities/planning/plan/SKILL.md" "Sage terms"

    assert_contains "core/capabilities/orchestration/build-loop/SKILL.md" "Autonomiczna kontynuacja"
    assert_contains "core/capabilities/orchestration/build-loop/SKILL.md" "Full autonomous implementation"
}

@test "alex-native core: templates preserve framework terms while preferring Polish prose" {
    assert_contains "develop/templates/manifest-template.md" "Alex-native self-host"
    assert_contains "develop/templates/manifest-template.md" "po polsku"
    assert_contains "develop/templates/spec/full.spec-template.md" "Alex-native self-host"
    assert_contains "develop/templates/spec/minimal.spec-template.md" "Alex-native self-host"
    assert_contains "develop/templates/plan/standard.plan-template.md" "Alex-native self-host"
    assert_contains "develop/templates/architecture/decision-template.md" "Alex-native self-host"
    assert_contains "develop/templates/qa-report-template.md" "Alex-native self-host"
    assert_contains "develop/templates/qa-report-template.md" "project language contract"
    assert_contains "develop/templates/qa-report-template.md" "Preserve"
    assert_contains "develop/templates/design-review-template.md" "Alex-native self-host"
    assert_contains "develop/templates/design-review-template.md" "project language contract"
    assert_contains "develop/templates/design-review-template.md" "Preserve"
}

@test "alex-native core: report workflows apply project language at template use" {
    assert_between_contains \
        "core/workflows/qa.workflow.md" \
        "Use the report template" \
        "QA REPORT CHECKPOINT" \
        "template provides structure"
    assert_between_contains \
        "core/workflows/qa.workflow.md" \
        "Use the report template" \
        "QA REPORT CHECKPOINT" \
        "project language contract"
    assert_between_contains \
        "core/workflows/qa.workflow.md" \
        "Use the report template" \
        "QA REPORT CHECKPOINT" \
        "raw evidence"

    assert_between_contains \
        "core/workflows/design-review.workflow.md" \
        "Use template from" \
        "DESIGN REVIEW CHECKPOINT" \
        "template provides structure"
    assert_between_contains \
        "core/workflows/design-review.workflow.md" \
        "Use template from" \
        "DESIGN REVIEW CHECKPOINT" \
        "project language contract"
    assert_between_contains \
        "core/workflows/design-review.workflow.md" \
        "Use template from" \
        "DESIGN REVIEW CHECKPOINT" \
        "raw evidence"
}
