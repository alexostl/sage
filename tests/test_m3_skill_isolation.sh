#!/usr/bin/env bash
# M3 test suite — Direct skill behavioral isolation
#
# Covers:
#   - skill_tier (workflow vs direct vs missing)
#   - emit_skill_isolation_yaml (content + escape + idempotency)
#   - SSoT regression: yaml.short_description == SKILL.md description
#   - generator integration: alex-os-dev-shape fixture deploy
#   - _render_skills_section states
#   - name: invariant (no SKILL.md name field changes)
#
# Run from repo root:  bash tests/test_m3_skill_isolation.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SAGE_BIN="$REPO_ROOT/bin/sage"
GEN="$REPO_ROOT/runtime/platforms/codex/setup/generate-codex.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/alex-os-dev-shape"
PASS=0
FAIL=0

# Extract helpers from generator (skill_tier + emit_skill_isolation_yaml)
HELPERS=$(mktemp -t m3-helpers.XXXXXX)
trap 'rm -f "$HELPERS"' EXIT
{
  awk '/^skill_tier\(\) \{/,/^\}$/' "$GEN"
  awk '/^emit_skill_isolation_yaml\(\) \{/,/^\}$/' "$GEN"
} > "$HELPERS"

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $label  ($actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label  (got: $actual, expected: $expected)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label  (output missing: '$needle')"
    echo "        haystack: $(printf '%s' "$haystack" | head -c 300)"
    FAIL=$((FAIL + 1))
  fi
}

#####################################################################
# UNIT — skill_tier
#####################################################################
echo ""
echo "=== unit: skill_tier ==="

T=$(mktemp -d)
cat > "$T/direct.md" <<'MD'
---
name: simplify
description: Reduces code complexity.
tier: direct
---
MD
cat > "$T/workflow.md" <<'MD'
---
name: sage
description: Workflow orchestrator.
tier: workflow
---
MD
cat > "$T/missing.md" <<'MD'
---
name: foo
description: No tier field.
---
MD
cat > "$T/empty.md" <<'MD'
no frontmatter at all
MD

out=$(bash -c "source '$HELPERS'; skill_tier '$T/direct.md'")
assert_eq "$out" "direct" "tier: direct → direct"

out=$(bash -c "source '$HELPERS'; skill_tier '$T/workflow.md'")
assert_eq "$out" "workflow" "tier: workflow → workflow"

out=$(bash -c "source '$HELPERS'; skill_tier '$T/missing.md'")
assert_eq "$out" "direct" "tier missing → direct (default)"

out=$(bash -c "source '$HELPERS'; skill_tier '$T/empty.md'")
assert_eq "$out" "direct" "no frontmatter → direct"

out=$(bash -c "source '$HELPERS'; skill_tier '$T/nonexistent.md'")
assert_eq "$out" "direct" "missing file → direct"

# Quoted tier values
cat > "$T/quoted.md" <<'MD'
---
name: x
tier: "workflow"
---
MD
out=$(bash -c "source '$HELPERS'; skill_tier '$T/quoted.md'")
assert_eq "$out" "workflow" "tier: \"workflow\" (quoted) → workflow"

rm -rf "$T"

#####################################################################
# UNIT — emit_skill_isolation_yaml content
#####################################################################
echo ""
echo "=== unit: emit_skill_isolation_yaml ==="

T=$(mktemp -d)
cat > "$T/skill.md" <<'MD'
---
name: simplify
description: >
  Reduces complexity. Use for "uprość ten kod" or
  "make this simpler" prompts.
tier: direct
---
# body
MD

bash -c "source '$HELPERS'; emit_skill_isolation_yaml '$T/skill.md' '$T/agents'"
yaml=$(cat "$T/agents/openai.yaml")

assert_contains "$yaml" "allow_implicit_invocation: false" "yaml: allow_implicit_invocation false"
assert_contains "$yaml" "policy:" "yaml: policy block"
assert_contains "$yaml" "interface:" "yaml: interface block"
assert_contains "$yaml" "short_description:" "yaml: short_description"
assert_contains "$yaml" 'Reduces complexity' "yaml: description body present"
assert_contains "$yaml" 'uprość' "yaml: UTF-8 (Polish chars) preserved"
assert_contains "$yaml" '\"uprość ten kod\"' "yaml: inner quotes escaped"

# Idempotency: re-emit, hash unchanged
h1=$(shasum -a 256 "$T/agents/openai.yaml" | cut -d" " -f1)
bash -c "source '$HELPERS'; emit_skill_isolation_yaml '$T/skill.md' '$T/agents'"
h2=$(shasum -a 256 "$T/agents/openai.yaml" | cut -d" " -f1)
assert_eq "$h1" "$h2" "idempotent: 2× emit → same hash"

# No frontmatter → skip (no yaml created)
mkdir -p "$T/empty-agents"
cat > "$T/no-fm.md" <<'MD'
just text
MD
bash -c "source '$HELPERS'; emit_skill_isolation_yaml '$T/no-fm.md' '$T/empty-agents'" >/dev/null
[ ! -f "$T/empty-agents/openai.yaml" ] && {
  echo "  PASS  no frontmatter → skipped emission"
  PASS=$((PASS + 1))
} || {
  echo "  FAIL  no frontmatter should skip emission"
  FAIL=$((FAIL + 1))
}

rm -rf "$T"

#####################################################################
# UNIT — SSoT regression: short_description == SKILL.md description
#####################################################################
echo ""
echo "=== unit: SSoT (short_description == SKILL.md description) ==="

T=$(mktemp -d)
cat > "$T/skill.md" <<'MD'
---
name: x
description: One-line direct description.
tier: direct
---
MD
bash -c "source '$HELPERS'; emit_skill_isolation_yaml '$T/skill.md' '$T/agents'"
out=$(grep "short_description:" "$T/agents/openai.yaml" | sed 's/^.*short_description: //; s/^"//; s/"$//')
assert_eq "$out" "One-line direct description." "SSoT: inline desc copied verbatim"

# Folded scalar: lines joined with single space.
cat > "$T/folded.md" <<'MD'
---
name: y
description: >
  Line one continues
  to line two and
  line three.
tier: direct
---
MD
bash -c "source '$HELPERS'; emit_skill_isolation_yaml '$T/folded.md' '$T/agents-folded'"
out=$(grep "short_description:" "$T/agents-folded/openai.yaml" | sed 's/^.*short_description: //; s/^"//; s/"$//')
assert_eq "$out" "Line one continues to line two and line three." "SSoT: folded scalar joined w/ spaces"

rm -rf "$T"

#####################################################################
# INTEGRATION — generator deploys yaml for direct skills only
#####################################################################
echo ""
echo "=== integration: generator emits yaml for direct skills only ==="

T=$(mktemp -d)
cp -R "$FIXTURE"/. "$T"/
mkdir -p "$T/.sage"
echo "deploy_direct_skills: true" > "$T/.sage/config.yaml"

# Make sage/core/workflows so workflow-skip path doesn't fire spuriously
mkdir -p "$T/sage/core/workflows"

# Run generator
out=$(SAGE_FRAMEWORK_DIR="$T/sage" bash "$GEN" "$T" 2>&1)
rc=$?
assert_eq "$rc" "0" "generator exits 0"

# Direct skills → yaml deployed
for s in simplify specify evaluate; do
  if [ -f "$T/.agents/skills/$s/agents/openai.yaml" ]; then
    echo "  PASS  $s (direct) has agents/openai.yaml"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $s (direct) missing agents/openai.yaml"
    FAIL=$((FAIL + 1))
  fi
done

# Workflow skill → yaml NOT deployed
if [ -f "$T/.agents/skills/sage/agents/openai.yaml" ]; then
  echo "  FAIL  sage (workflow) should NOT have agents/openai.yaml"
  FAIL=$((FAIL + 1))
else
  echo "  PASS  sage (workflow) correctly has no agents/openai.yaml"
  PASS=$((PASS + 1))
fi

# Idempotency: regen × 2 = 0 diff in yaml content
h1=$(find "$T/.agents/skills" -name openai.yaml -exec shasum -a 256 {} \; | sort | shasum -a 256 | cut -d" " -f1)
SAGE_FRAMEWORK_DIR="$T/sage" bash "$GEN" "$T" >/dev/null 2>&1
h2=$(find "$T/.agents/skills" -name openai.yaml -exec shasum -a 256 {} \; | sort | shasum -a 256 | cut -d" " -f1)
assert_eq "$h1" "$h2" "idempotent: 2× generator → same yaml hashes"

# SKILL.md `name:` field invariant — never altered by generator
for s in simplify specify evaluate sage; do
  src=$(grep "^name:" "$FIXTURE/sage/skills/$s/SKILL.md" | head -1)
  dst=$(grep "^name:" "$T/.agents/skills/$s/SKILL.md" 2>/dev/null | head -1 || echo "MISSING")
  assert_eq "$dst" "$src" "$s SKILL.md name: unchanged by generator"
done

rm -rf "$T"

#####################################################################
# UNIT — _render_skills_section states
#####################################################################
echo ""
echo "=== unit: _render_skills_section states ==="

# Extract bin/sage internals (M2 pattern)
SAGE_INT=$(mktemp -t sage-int-m3.XXXXXX)
{
  cat <<'STUBS'
RED=""; GREEN=""; YELLOW=""; DIM=""; BOLD=""; RESET=""
STUBS
  awk '/^_render_framework_root\(\)/,/^sage_status\(\) \{/ { if ($0 ~ /^sage_status\(\) \{/) exit; print }' "$SAGE_BIN"
} > "$SAGE_INT"

render_skills() {
  local target="$1"
  bash -c "source '$SAGE_INT'
SAGE_STATUS_TARGET='$target'
_render_skills_section"
}

# State 1: no .agents/skills → N/A
T=$(mktemp -d)
out=$(render_skills "$T")
assert_contains "$out" "N/A" "no .agents/skills → N/A"
rm -rf "$T"

# State 2: only workflow skill → WORKFLOW-ONLY
T=$(mktemp -d); mkdir -p "$T/.agents/skills/sage"
cat > "$T/.agents/skills/sage/SKILL.md" <<'MD'
---
name: sage
tier: workflow
---
MD
out=$(render_skills "$T")
assert_contains "$out" "WORKFLOW-ONLY" "only workflow skill → WORKFLOW-ONLY"
rm -rf "$T"

# State 3: direct skills, no yaml → DORMANT
T=$(mktemp -d); mkdir -p "$T/.agents/skills/simplify"
cat > "$T/.agents/skills/simplify/SKILL.md" <<'MD'
---
name: simplify
tier: direct
---
MD
out=$(render_skills "$T")
assert_contains "$out" "DORMANT" "direct skill no yaml → DORMANT"
rm -rf "$T"

# State 4: direct skills + matching yaml → ACTIVE
T=$(mktemp -d); mkdir -p "$T/.agents/skills/simplify/agents"
cat > "$T/.agents/skills/simplify/SKILL.md" <<'MD'
---
name: simplify
tier: direct
---
MD
echo "policy: {allow_implicit_invocation: false}" > "$T/.agents/skills/simplify/agents/openai.yaml"
out=$(render_skills "$T")
assert_contains "$out" "ACTIVE" "direct skill + yaml → ACTIVE"
rm -rf "$T"

# State 5: partial coverage → PARTIAL
T=$(mktemp -d)
mkdir -p "$T/.agents/skills/a/agents" "$T/.agents/skills/b"
cat > "$T/.agents/skills/a/SKILL.md" <<'MD'
---
name: a
tier: direct
---
MD
cat > "$T/.agents/skills/b/SKILL.md" <<'MD'
---
name: b
tier: direct
---
MD
echo "policy: {allow_implicit_invocation: false}" > "$T/.agents/skills/a/agents/openai.yaml"
out=$(render_skills "$T")
assert_contains "$out" "PARTIAL" "1 of 2 direct skills isolated → PARTIAL"
rm -rf "$T"

rm -f "$SAGE_INT"

#####################################################################
# SUMMARY
#####################################################################
echo ""
echo "================================================================="
echo "  M3 test summary:  $PASS passed, $FAIL failed"
echo "================================================================="
[ "$FAIL" -eq 0 ]
