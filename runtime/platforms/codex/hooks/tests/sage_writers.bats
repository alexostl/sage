#!/usr/bin/env bats
# T1.3 — audit/sage-writers.yaml: writers manifest per spec §6.7.
#
# Plan contract (T1.3): yq parses cleanly; values match spec §6.7
# verbatim (`.approval-pending` is v1 developer override state;
# `.ups-hook.log` remains v2/deferred).

setup() {
    MANIFEST="$BATS_TEST_DIRNAME/../../audit/sage-writers.yaml"
    [ -f "$MANIFEST" ] || skip "sage-writers.yaml not found at $MANIFEST"
}

@test "sage-writers.yaml: yq parses cleanly" {
    yq eval '.' "$MANIFEST" >/dev/null
}

@test "sage-writers.yaml: .approval-pending writers = [pre-tool-validate, user-prompt-submit]" {
    result=$(yq eval '.[".sage/.approval-pending"].writers | join(",")' "$MANIFEST")
    [ "$result" = "pre-tool-validate.sh,user-prompt-submit.sh" ]
}

@test "sage-writers.yaml: .ups-hook.log writers is empty (v2 deferred)" {
    result=$(yq eval '.[".sage/.ups-hook.log"].writers | length' "$MANIFEST")
    [ "$result" = "0" ]
}

@test "sage-writers.yaml: .mcp-incidents.log writers = [post-tool-check, turn-audit]" {
    result=$(yq eval '.[".sage/.mcp-incidents.log"].writers | join(",")' "$MANIFEST")
    [ "$result" = "post-tool-check.sh,turn-audit.sh" ]
}

@test "sage-writers.yaml: .session-mutations.log writers = [pre-tool-validate]" {
    result=$(yq eval '.[".sage/.session-mutations.log"].writers | join(",")' "$MANIFEST")
    [ "$result" = "pre-tool-validate.sh" ]
}

@test "sage-writers.yaml: .session-baseline.log writers = [session-init]" {
    result=$(yq eval '.[".sage/.session-baseline.log"].writers | join(",")' "$MANIFEST")
    [ "$result" = "session-init.sh" ]
}

@test "sage-writers.yaml: .skipped-checks.log writers = [active_init, post-tool-check]" {
    result=$(yq eval '.[".sage/.skipped-checks.log"].writers | join(",")' "$MANIFEST")
    [ "$result" = "active_init.sh,post-tool-check.sh" ]
}

@test "sage-writers.yaml: .auto-fixes.log writers = [pre-tool-validate]" {
    result=$(yq eval '.[".sage/.auto-fixes.log"].writers | join(",")' "$MANIFEST")
    [ "$result" = "pre-tool-validate.sh" ]
}

@test "sage-writers.yaml: decisions.md writer = agent_via_apply_patch_when_P2_2" {
    result=$(yq eval '.[".sage/decisions.md"].writers | join(",")' "$MANIFEST")
    [ "$result" = "agent_via_apply_patch_when_P2_2" ]
}

@test "sage-writers.yaml: .sage/work/** + .sage/docs/** writers = agent only" {
    work=$(yq eval '.[".sage/work/**"].writers | join(",")' "$MANIFEST")
    docs=$(yq eval '.[".sage/docs/**"].writers | join(",")' "$MANIFEST")
    [ "$work" = "agent_via_apply_patch_when_P2_2" ]
    [ "$docs" = "agent_via_apply_patch_when_P2_2" ]
}

@test "sage-writers.yaml: total entries = 10 (v1 contract)" {
    result=$(yq eval 'keys | length' "$MANIFEST")
    [ "$result" = "10" ]
}
