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

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    ! grep -q "$pattern" "$REPO_ROOT/$file"
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
    assert_contains "core/constitution/sage-process.constitution.md" "(Recommended)"
    assert_contains "core/constitution/sage-process.constitution.md" "Rekomenduję \\[A\\], bo"
    assert_contains "core/constitution/sage-process.constitution.md" "maksymalnie trzy zdania"
    assert_contains "core/constitution/sage-process.constitution.md" "rekomendacja nie jest approvalem"
    assert_contains "core/constitution/sage-process.constitution.md" "mandatory steps"

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

@test "alex-native core: decisions.md is decision log, not process log" {
    assert_contains "core/constitution/sage-process.constitution.md" "decision log, not a process log"
    assert_contains "core/constitution/sage-process.constitution.md" "Only decision-worthy events"
    assert_contains "core/constitution/sage-process.constitution.md" "Auto-review and Auto-QA verdicts are process evidence"
    assert_contains "core/constitution/sage-process.constitution.md" "Process-only frontmatter"
    assert_contains "core/constitution/sage-process.constitution.md" "50 newest decisions"
    assert_contains "core/constitution/sage-process.constitution.md" ".sage/decisions-archive.md"
    assert_contains "core/constitution/sage-process.constitution.md" "search-first"

    assert_contains "core/workflows/build.workflow.md" "decision-worthy"
    assert_contains "core/workflows/fix.workflow.md" "decision-worthy"
    assert_contains "core/workflows/architect.workflow.md" "decision-worthy"
    assert_contains "core/workflows/analyze.workflow.md" "decision-worthy"
    assert_contains "core/capabilities/review/auto-review/SKILL.md" "process evidence"
    assert_contains "core/capabilities/review/auto-qa/SKILL.md" "process evidence"
    assert_contains "core/capabilities/orchestration/sage-navigator/SKILL.md" "decision log, not a process log"

    assert_not_contains "core/workflows/build.workflow.md" "Prepend review verdict to decisions.md"
    assert_not_contains "core/workflows/architect.workflow.md" "Prepend review verdict to decisions.md"
    assert_not_contains "core/capabilities/review/auto-review/SKILL.md" "After every auto-review (any verdict), prepend"
    assert_not_contains "core/capabilities/review/auto-qa/SKILL.md" "After every auto-QA (any verdict), prepend"
}

@test "alex-native core: completed-cycle reconciliation is manifest-only and narrow" {
    assert_contains "core/constitution/sage-process.constitution.md" "completed-cycle artifacts are immutable"
    assert_contains "core/constitution/sage-process.constitution.md" "completed manifest-only reconciliation"
    assert_contains "core/constitution/sage-process.constitution.md" "not decision-worthy"

    assert_contains "core/workflows/build.workflow.md" "manifest.status: completed"
    assert_contains "core/workflows/build.workflow.md" "completed manifest-only reconciliation"
    assert_contains "core/workflows/build.workflow.md" "same active conversation"
    assert_contains "core/workflows/build.workflow.md" "not the default for ordinary non-milestone builds"
    assert_contains "core/workflows/build.workflow.md" "lifecycle artifacts complete"

    assert_contains "core/workflows/fix.workflow.md" "manifest.status: completed"
    assert_contains "core/workflows/fix.workflow.md" "completed manifest-only reconciliation"
    assert_contains "core/workflows/fix.workflow.md" "same active conversation"
    assert_contains "core/workflows/fix.workflow.md" "not the default for ordinary non-milestone fixes"

    assert_contains "core/workflows/architect.workflow.md" "completed manifest-only reconciliation"
    assert_contains "core/workflows/architect.workflow.md" "follow-up cycle"
    assert_contains "core/workflows/architect.workflow.md" "Standalone closeout artifacts are appropriate for architecture, umbrella"
    assert_contains "core/constitution/sage-process.constitution.md" "is exceptional"
}

@test "alex-native core: fix workflow has implementation readiness preflight" {
    assert_contains "core/workflows/fix.workflow.md" "implementation readiness preflight"
    assert_contains "core/workflows/fix.workflow.md" "manifest-only readiness patch"
    assert_contains "core/workflows/fix.workflow.md" 'canonical `plan.md`'
    assert_contains "core/workflows/fix.workflow.md" "same-turn boundary"
    assert_contains "core/workflows/fix.workflow.md" '\[C\] Checkpointed implementation'
    assert_contains "core/workflows/fix.workflow.md" '\[F\] Full autonomous implementation'
}

@test "alex-native core: status work_index is lightweight and frontmatter-derived" {
    assert_contains "core/workflows/status.workflow.md" "work_index"
    assert_contains "core/workflows/status.workflow.md" "manifest frontmatter only"
    assert_contains "core/workflows/status.workflow.md" "count-only in default status"
    assert_contains "core/workflows/status.workflow.md" "search-first"
    assert_contains "core/workflows/status.workflow.md" "recent_decisions"
    assert_contains "core/workflows/status.workflow.md" "health"
    assert_contains "core/workflows/status.workflow.md" "lifecycle source-of-truth"
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
