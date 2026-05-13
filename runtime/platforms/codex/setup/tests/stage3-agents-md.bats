#!/usr/bin/env bats
# T1.11 — Stage 3 AGENTS.md composition contract.
#
# Plan contract (T1.11):
#   - Prefix-managed pattern with `<!-- SAGE-MANAGED-END -->` marker
#   - 3-layer constitution merge (base → preset overlay → user overlay)
#   - Rule 1A Sage Memory discovery before filesystem fallback
#   - T1.9 preset sentinel-bypass: PRESET ∈ {base, none, "", unset}
#   - Re-run preserves user territory below marker; missing marker → backup
#
# v1 spec ref: §4 Stage 3, §5 Tier A.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage3_agents.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage3() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset "${PRESET:-base}" --stage 3 "$@"
}

@test "stage3: creates AGENTS.md at target" {
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    [ -s "$TARGET/AGENTS.md" ]
}

@test "stage3: AGENTS.md has 'Sage — Project Instructions' header" {
    PRESET=base run_stage3
    grep -q '^# Sage — Project Instructions' "$TARGET/AGENTS.md"
}

@test "stage3: AGENTS.md contains compact operating kernel" {
    PRESET=base run_stage3
    grep -q '^## Operating Kernel' "$TARGET/AGENTS.md"
}

@test "stage3: AGENTS.md ends with SAGE-MANAGED-END marker (prefix-managed)" {
    PRESET=base run_stage3
    grep -q '<!-- SAGE-MANAGED-END' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=base → all 5 base principles present" {
    PRESET=base run_stage3
    grep -qi 'Tests before code'    "$TARGET/AGENTS.md"
    grep -qi 'No silent failures'   "$TARGET/AGENTS.md"
    grep -qi 'Secrets never in code' "$TARGET/AGENTS.md"
    grep -qi 'Dependencies explicit' "$TARGET/AGENTS.md"
    grep -qi 'Changes reversible'   "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=base → no preset-overlay warning emitted (sentinel)" {
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qi 'Preset overlay missing'
    ! echo "$output" | grep -qi 'falling back to base'
}

@test "stage3: PRESET=none → sentinel bypass, base only, no warning" {
    PRESET=none run run_stage3
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qi 'Preset overlay missing'
    grep -qi 'Tests before code' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=startup → includes 'Ship smallest' (preset overlay merged)" {
    PRESET=startup run_stage3
    grep -qi 'Ship smallest viable' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=enterprise → includes 'All endpoints require authentication'" {
    PRESET=enterprise run_stage3
    grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=foo (missing) → warning to stderr + base fallback" {
    PRESET=foo run run_stage3
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'Preset overlay missing'
    grep -qi 'Tests before code' "$TARGET/AGENTS.md"
    # Should NOT contain startup/enterprise principles since fallback is base.
    ! grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: .sage/constitution.md extends override → user preset wins" {
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
---
extends: enterprise
---
EOF
    PRESET=base run_stage3
    # User extends: enterprise overrides PRESET=base on the command line.
    grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: user additions under '## Project Additions' merge into AGENTS.md (B3)" {
    # Plan T2.6 done-when: generated AGENTS.md must include the user's
    # extra rule alongside the preset overlay. Closes the contract gap
    # T2.6 surfaced (stub heading vs merger heading mismatch).
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
---
extends: enterprise
---

## Project Additions

Every PR must reference a JIRA ticket. UNIQUE-MARKER-T26-MERGE.
EOF
    PRESET=base run_stage3
    grep -q 'UNIQUE-MARKER-T26-MERGE' "$TARGET/AGENTS.md"
    grep -qi 'JIRA ticket' "$TARGET/AGENTS.md"
}

@test "stage3: user additions section absent → only base+preset rules render" {
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
---
extends: enterprise
---
EOF
    PRESET=base run_stage3
    # No user additions section, no extra principles beyond preset.
    ! grep -qi 'JIRA ticket' "$TARGET/AGENTS.md"
    ! grep -q 'UNIQUE-MARKER-T26-MERGE' "$TARGET/AGENTS.md"
}

@test "stage3: Rule 1A discovers Sage Memory before filesystem fallback" {
    # No .codex/config.toml at all still tells Codex to try deferred discovery first.
    PRESET=base run_stage3
    grep -q 'Discover available Sage Memory tools' "$TARGET/AGENTS.md"
    grep -q 'available Codex' "$TARGET/AGENTS.md"
    grep -q 'tool-discovery surface' "$TARGET/AGENTS.md"
    grep -q 'Fall back to `.sage-memory/` files only when MCP tools are unavailable' "$TARGET/AGENTS.md"
    grep -q 'Codex built-in Memories are a' "$TARGET/AGENTS.md"
}

@test "stage3: Rule 1A keeps MCP-first behavior when [[mcp_servers]] present" {
    mkdir -p "$TARGET/.codex"
    cat > "$TARGET/.codex/config.toml" <<'EOF'
[[mcp_servers]]
name = "sage-memory"
command = "node"
EOF
    PRESET=base run_stage3
    grep -q 'Discover available Sage Memory tools' "$TARGET/AGENTS.md"
    grep -q 'Fall back to `.sage-memory/` files only when MCP tools are unavailable' "$TARGET/AGENTS.md"
}

# Shared-source routing contract assertions. These are intentionally
# separate from generated AGENTS.md assertions below.

@test "shared routing: old eager question fallback is absent" {
    ! grep -R -n 'Question / evaluation / "why".*UNDERSTAND' \
        "$REPO_ROOT/core/constitution/sage-process.constitution.md" \
        "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    ! grep -R -n 'why".*UNDERSTAND.*analyze' \
        "$REPO_ROOT/core/constitution/sage-process.constitution.md" \
        "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
}

@test "shared routing: conversational questions can be answered without workflow" {
    grep -q 'conversational/read-only question' "$REPO_ROOT/core/constitution/sage-process.constitution.md"
    grep -q 'without announcing or starting a workflow' "$REPO_ROOT/core/constitution/sage-process.constitution.md"
    grep -q 'Conversational/read-only question' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'Answer conversationally by default' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
}

@test "shared routing: active work does not force read-only questions into implementation" {
    grep -q 'active work exists' "$REPO_ROOT/core/constitution/sage-process.constitution.md"
    grep -q 'unrelated read-only questions' "$REPO_ROOT/core/constitution/sage-process.constitution.md"
    grep -q 'If active work exists' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'offer to resume afterward' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
}

@test "shared routing: polite question-form mandates are action mandates" {
    grep -q 'polite question-form mandates' "$REPO_ROOT/core/constitution/sage-process.constitution.md"
    grep -q 'Can you fix this' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'Could you implement this' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'Would you run a smoke test' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
}

# Generated Codex AGENTS.md routing contract assertions.

@test "stage3: generated AGENTS.md says conversational questions do not start workflow by default" {
    PRESET=base run_stage3
    grep -q 'Route Work, Preserve Conversation' "$TARGET/AGENTS.md"
    grep -q 'conversational/read-only questions can be answered' "$TARGET/AGENTS.md"
    grep -q 'without workflow by default' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md distinguishes workflow commands, action mandates, and ambiguous prompts" {
    PRESET=base run_stage3
    grep -q 'explicit workflow command' "$TARGET/AGENTS.md"
    grep -q 'action mandate' "$TARGET/AGENTS.md"
    grep -q 'ambiguous/borderline prompt' "$TARGET/AGENTS.md"
    grep -q 'soft confirmation' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md covers polite question-form mandates" {
    PRESET=base run_stage3
    grep -q 'Can you fix' "$TARGET/AGENTS.md"
    grep -q 'Could you implement' "$TARGET/AGENTS.md"
    grep -q 'Would you run a smoke test' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves post-entry Codex enforcement language" {
    PRESET=base run_stage3
    grep -q 'After workflow entry, Codex-native enforcement still applies' "$TARGET/AGENTS.md"
    grep -q 'spec/plan gates' "$TARGET/AGENTS.md"
    grep -q 'manifest scope protection' "$TARGET/AGENTS.md"
    grep -q 'verification-before-done' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md requires Moderate+ fix artifacts before code" {
    PRESET=base run_stage3
    grep -q 'Moderate+ fixes must update plan.md and manifest.md before code changes' "$TARGET/AGENTS.md"
    grep -q 'Writing plan.md or manifest.md after code does not cure the violation' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md defines state transition boundary without overlogging lightweight work" {
    PRESET=base run_stage3
    grep -q 'Lightweight/Surgical work may finish with code plus conversation summary' "$TARGET/AGENTS.md"
    grep -q 'Standard+/Moderate+ entry or resume must create/update the manifest' "$TARGET/AGENTS.md"
    grep -q 'After changing `status` or `phase`, say what changed' "$TARGET/AGENTS.md"
    grep -q 'identify workflow/cycle' "$TARGET/AGENTS.md"
    grep -q 'update `manifest.md` first' "$TARGET/AGENTS.md"
    grep -q 'announce the completed state change' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves fix-trigger guardrail for instruction files" {
    PRESET=base run_stage3
    grep -q 'Fix-trigger prompts in instruction' "$TARGET/AGENTS.md"
    grep -q 'require `/fix` diagnosis and scope' "$TARGET/AGENTS.md"
    grep -q 'before mutation, even for typos' "$TARGET/AGENTS.md"
    grep -q 'outside instruction/process surfaces' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md treats hook blocks as recovery guidance" {
    PRESET=base run_stage3
    grep -q 'recoverable hook block is correction guidance' "$TARGET/AGENTS.md"
    grep -q 'retry via legal path' "$TARGET/AGENTS.md"
    grep -q 'user decision' "$TARGET/AGENTS.md"
    grep -q 'scope amputation' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md contains laconic mutation preflight contract" {
    PRESET=base run_stage3
    grep -q 'Mutation preflight before write' "$TARGET/AGENTS.md"
    grep -q 'active cycle/scope/count' "$TARGET/AGENTS.md"
    grep -q 'threshold/closeout/' "$TARGET/AGENTS.md"
    grep -q 'tool path' "$TARGET/AGENTS.md"
    grep -q 'Text edits use `apply_patch`' "$TARGET/AGENTS.md"
    grep -q 'binary assets need' "$TARGET/AGENTS.md"
    grep -q 'explicit binary path' "$TARGET/AGENTS.md"
    ! grep -q 'How mutation preflight works' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md contains laconic closeout handoff contract" {
    PRESET=base run_stage3
    grep -q 'Closeout order' "$TARGET/AGENTS.md"
    grep -q 'manifest.status completed last' "$TARGET/AGENTS.md"
    grep -q 'stage/commit' "$TARGET/AGENTS.md"
    grep -q 'no default push' "$TARGET/AGENTS.md"
    grep -q 'no post-closeout .sage epilogue' "$TARGET/AGENTS.md"
    ! grep -q 'How closeout handoff works' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md says active work does not force read-only implementation" {
    PRESET=base run_stage3
    grep -q 'When active work exists' "$TARGET/AGENTS.md"
    grep -q 'unrelated' "$TARGET/AGENTS.md"
    grep -q 'read-only questions' "$TARGET/AGENTS.md"
    grep -q 'without resuming' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md carries compact Alex-native contract" {
    PRESET=base run_stage3
    grep -q 'Alex-native operating contract' "$TARGET/AGENTS.md"
    grep -q 'Treść prozatorską nowych sekcji w `.sage` pisz po' "$TARGET/AGENTS.md"
    grep -q 'starszego angielskiego pliku' "$TARGET/AGENTS.md"
    grep -q 'explain bugs/findings first as impact and cause' "$TARGET/AGENTS.md"
    grep -q 'technical mechanism' "$TARGET/AGENTS.md"
    grep -q 'jedno pytanie naraz' "$TARGET/AGENTS.md"
    grep -q '1-3 klikalne linki' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves no-spontaneous-fix guardrail" {
    PRESET=base run_stage3
    grep -q 'bug report/finding/observation' "$TARGET/AGENTS.md"
    grep -q 'do not edit code' "$TARGET/AGENTS.md"
    grep -q 'workflow gate approves implementation' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves Codex plan/progress visibility contract" {
    PRESET=base run_stage3
    grep -q 'For Standard+ Codex work' "$TARGET/AGENTS.md"
    grep -q 'native plan/progress view' "$TARGET/AGENTS.md"
    grep -q 'visibility layer' "$TARGET/AGENTS.md"
    grep -q 'never replaces Sage artifacts' "$TARGET/AGENTS.md"
    grep -q 'lightweight' "$TARGET/AGENTS.md"
    grep -q 'read-only conversation' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves post-plan implementation mode choice" {
    PRESET=base run_stage3
    grep -q '\[C\] Checkpointed implementation' "$TARGET/AGENTS.md"
    grep -q '\[F\] Full autonomous implementation' "$TARGET/AGENTS.md"
    grep -q 'approved plan without intermediate' "$TARGET/AGENTS.md"
    grep -q 'scoped autonomy, not general autonomy' "$TARGET/AGENTS.md"
    grep -q 'approved plan and manifest scope' "$TARGET/AGENTS.md"
    grep -q 'scope expansion cancels the grant' "$TARGET/AGENTS.md"
    grep -q 'key assumption' "$TARGET/AGENTS.md"
    grep -q 'material risk changes the plan' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md covers subagent scope inheritance" {
    PRESET=base run_stage3
    grep -q 'subagents/reviewer agents' "$TARGET/AGENTS.md"
    grep -q 'project instructions' "$TARGET/AGENTS.md"
    grep -q 'Subagent edits are not exempt' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md requires explicit Codex subagent authorization" {
    PRESET=base run_stage3
    grep -q 'Codex subagent authorization must be literal' "$TARGET/AGENTS.md"
    grep -q 'Only call spawn_agent after the' "$TARGET/AGENTS.md"
    grep -q '\[A\] Subagent review' "$TARGET/AGENTS.md"
    grep -q 'review please' "$TARGET/AGENTS.md"
    grep -q 'ask for subagent review vs self-review' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md explains paused/intake visibility vs implementation-active state" {
    PRESET=base run_stage3
    grep -q 'status: in-progress' "$TARGET/AGENTS.md"
    grep -q 'implementation-active' "$TARGET/AGENTS.md"
    grep -q 'active_session_id' "$TARGET/AGENTS.md"
    grep -q 'handoff/parking' "$TARGET/AGENTS.md"
    grep -q 'status: paused' "$TARGET/AGENTS.md"
    grep -q 'status: intake' "$TARGET/AGENTS.md"
    grep -q 'parked,' "$TARGET/AGENTS.md"
    grep -q 'resumable work' "$TARGET/AGENTS.md"
    grep -q 'manifest-only' "$TARGET/AGENTS.md"
    grep -q 'sage status' "$TARGET/AGENTS.md"
    grep -q 'sage doctor' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md defines deterministic artifact router" {
    PRESET=base run_stage3
    grep -q 'Artifact Router' "$TARGET/AGENTS.md"
    grep -q '\.sage/docs/' "$TARGET/AGENTS.md"
    grep -q '\.sage/work/<cycle>/' "$TARGET/AGENTS.md"
    grep -q '\.sage/work/<cycle>/research/' "$TARGET/AGENTS.md"
    grep -q '\.sage/decisions.md' "$TARGET/AGENTS.md"
    grep -q '\.sage-memory/' "$TARGET/AGENTS.md"
    grep -q 'minimal intake' "$TARGET/AGENTS.md"
    grep -q 'needs-triage' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md defines recovery-first safe auto-fix boundaries" {
    PRESET=base run_stage3
    grep -q 'Recovery-First' "$TARGET/AGENTS.md"
    grep -q 'safe auto-fix' "$TARGET/AGENTS.md"
    grep -q 'minimal intake manifest' "$TARGET/AGENTS.md"
    grep -q 'inferable frontmatter' "$TARGET/AGENTS.md"
    grep -q 'same-cycle documentation scope' "$TARGET/AGENTS.md"
    grep -q 'Hard stop' "$TARGET/AGENTS.md"
    grep -q 'destructive actions' "$TARGET/AGENTS.md"
    grep -q 'ambiguous repo ownership' "$TARGET/AGENTS.md"
    grep -q '.sage/.auto-fixes.log' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md defines target-repo ownership" {
    PRESET=base run_stage3
    grep -q 'Target Repo Ownership' "$TARGET/AGENTS.md"
    grep -q 'current working directory' "$TARGET/AGENTS.md"
    grep -q 'edited repository owns workflow state' "$TARGET/AGENTS.md"
    grep -q 'state, memory, scope, gates, and recovery' "$TARGET/AGENTS.md"
    grep -q 'framework repository must not impersonate' "$TARGET/AGENTS.md"
    grep -q 'ambiguous repo ownership' "$TARGET/AGENTS.md"
    grep -q 'Do not write `.sage/\*\*` outside the target repo' "$TARGET/AGENTS.md"
    grep -q 'Source/runtime/test/' "$TARGET/AGENTS.md"
    grep -q 'instruction behavior changes require the proper Sage workflow' "$TARGET/AGENTS.md"
    grep -q 'single-file config-only' "$TARGET/AGENTS.md"
    grep -q 'multi-file/security/hooks/instruction/generated' "$TARGET/AGENTS.md"
    grep -qi 'same-turn self-created artifacts are not approval' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md preserves explicit subagent review and skip-review checkpoint paths" {
    PRESET=base run_stage3
    grep -q '\[A\] Subagent review' "$TARGET/AGENTS.md"
    grep -q '\[S\] Skip review' "$TARGET/AGENTS.md"
    grep -q 'Do not collapse them into' "$TARGET/AGENTS.md"
    grep -q 'generic approval' "$TARGET/AGENTS.md"
    grep -q 'read-only subagent' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md stays compact and points to skills/workflows" {
    PRESET=base run_stage3
    bytes="$(wc -c < "$TARGET/AGENTS.md" | tr -d ' ')"
    [ "$bytes" -lt 12000 ] || {
        echo "AGENTS.md too large: $bytes bytes"
        return 1
    }
    grep -q '\.agents/skills/' "$TARGET/AGENTS.md"
    grep -q 'core/workflows/' "$TARGET/AGENTS.md"
}

@test "shared guidance: review and navigator use Capture Router instead of decisions backlog" {
    grep -q 'Capture Router' "$REPO_ROOT/core/workflows/review.workflow.md"
    grep -q 'current-cycle follow-up' "$REPO_ROOT/core/workflows/review.workflow.md"
    grep -q 'minimal intake' "$REPO_ROOT/core/workflows/review.workflow.md"
    ! grep -q '^Prepend review findings to `.sage/decisions.md`\\.' "$REPO_ROOT/core/workflows/review.workflow.md"
    grep -q 'Project-level knowledge' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'Initiative-specific research' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'Actionable TODO' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
    grep -q 'needs-triage' "$REPO_ROOT/core/capabilities/orchestration/sage-navigator/SKILL.md"
}

@test "shared guidance: status and continue describe recovery next legal moves" {
    grep -q 'safe auto-fix' "$REPO_ROOT/core/workflows/status.workflow.md"
    grep -q '.sage/.auto-fixes.log' "$REPO_ROOT/core/workflows/status.workflow.md"
    grep -q 'single clear resumable candidate' "$REPO_ROOT/core/workflows/continue.workflow.md"
    grep -q 'multiple equivalent cycles' "$REPO_ROOT/core/workflows/continue.workflow.md"
    grep -q 'hard-stop' "$REPO_ROOT/core/workflows/continue.workflow.md"
}

@test "shared guidance: status and continue use target repository state" {
    grep -q 'target repository' "$REPO_ROOT/core/workflows/status.workflow.md"
    grep -q 'edited/current working repository owns workflow state' "$REPO_ROOT/core/workflows/status.workflow.md"
    grep -q 'Cross-repo rule' "$REPO_ROOT/core/workflows/continue.workflow.md"
    grep -q 'target repository' "$REPO_ROOT/core/workflows/continue.workflow.md"
    grep -q 'framework repository does not stand in' "$REPO_ROOT/core/workflows/continue.workflow.md"
}


@test "stage3: re-run preserves user content below marker" {
    PRESET=base run_stage3
    # Append user content below marker.
    cat >> "$TARGET/AGENTS.md" <<'EOF'

## My Custom Section

This is user territory — preserve me on update.
EOF
    PRESET=base run_stage3
    grep -q 'My Custom Section' "$TARGET/AGENTS.md"
    grep -q 'preserve me on update' "$TARGET/AGENTS.md"
}

@test "stage3: re-run is idempotent despite explanatory marker mention" {
    PRESET=base run_stage3
    PRESET=base run_stage3

    local constitution_count marker_line_count mention_count
    constitution_count="$(grep -c '^## Operating Kernel$' "$TARGET/AGENTS.md" || true)"
    marker_line_count="$(grep -c '^<!-- SAGE-MANAGED-END' "$TARGET/AGENTS.md" || true)"
    mention_count="$(grep -c 'SAGE-MANAGED-END' "$TARGET/AGENTS.md" || true)"

    [ "$constitution_count" = "1" ] || {
        echo "Operating Kernel count: $constitution_count"
        return 1
    }
    [ "$marker_line_count" = "1" ] || {
        echo "marker line count: $marker_line_count"
        return 1
    }
    [ "$mention_count" = "2" ] || {
        echo "marker mention count: $mention_count"
        return 1
    }
}

@test "stage3: re-run with no marker → backup + regenerate (with marker)" {
    cat > "$TARGET/AGENTS.md" <<'EOF'
# User-only AGENTS.md without Sage marker.

Important user content here.
EOF
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    # Backup should exist with user-backup-<ts> suffix.
    ls "$TARGET"/AGENTS.md.user-backup-* >/dev/null 2>&1
    # Regenerated AGENTS.md has the marker now.
    grep -q '<!-- SAGE-MANAGED-END' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md says checkpoints keep cycles in-progress" {
    PRESET=base run_stage3
    grep -q 'active' "$TARGET/AGENTS.md"
    grep -q 'approval checkpoints' "$TARGET/AGENTS.md"
    grep -q 'root-cause-gate' "$TARGET/AGENTS.md"
    grep -q 'Checkpoints update `phase`' "$TARGET/AGENTS.md"
    grep -q 'not pause the cycle' "$TARGET/AGENTS.md"
}

@test "stage3: generated AGENTS.md supports cross-cycle capture-only routing" {
    PRESET=base run_stage3
    grep -q 'belongs' "$TARGET/AGENTS.md"
    grep -q 'another existing cycle' "$TARGET/AGENTS.md"
    grep -q 'capture-only update' "$TARGET/AGENTS.md"
    grep -q 'Cross-cycle capture must stay capture-only' "$TARGET/AGENTS.md"
    grep -q 'runtime/code/test implementation' "$TARGET/AGENTS.md"
}
