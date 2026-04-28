#!/usr/bin/env bash
# Smoke test: pre-prompt.sh emits a sticky `additionalContext` block on
# every meaningful turn (passthrough, hint, and block paths). Exits 0
# on pass, non-zero with diagnostics on fail.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$HERE/.." && pwd)"
HOOK="$HOOKS_DIR/pre-prompt.sh"
TMP="$HERE/tmp"

# Ensure fixtures exist.
if [ ! -d "$TMP/sage_no_active" ]; then
  bash "$HERE/fixtures/build_fixtures.sh" >/dev/null
fi

PASS=0
FAIL=0

run_case() {
  local label="$1"
  local fixture="$2"
  local prompt="$3"
  local expect_in_context="$4"

  local fixture_root="$TMP/$fixture"
  if [ ! -d "$fixture_root" ]; then
    echo "FAIL [$label]: fixture $fixture missing" >&2
    FAIL=$((FAIL + 1))
    return
  fi

  local stdin_payload
  stdin_payload=$(printf '{"prompt": %s}' "$(printf '%s' "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")

  # Note: in `VAR=v cmd1 | cmd2`, VAR scopes to cmd1 only. We need the
  # env on cmd2 (bash $HOOK), so use `env` explicitly.
  local out
  out=$(printf '%s' "$stdin_payload" \
        | env SAGE_PROJECT_ROOT="$fixture_root" SAGE_HOOK_DIR="$HOOKS_DIR" \
              bash "$HOOK" 2>&1 || true)

  if [ -z "$out" ]; then
    # Empty stdout means silent passthrough — only OK for parse-fail /
    # empty-prompt branches. None of our cases use those, so flag it.
    echo "FAIL [$label]: empty stdout" >&2
    FAIL=$((FAIL + 1))
    return
  fi

  # Extract additionalContext via python (no jq dependency).
  local context
  context=$(printf '%s' "$out" | python3 -c '
import json, sys
try:
    j = json.loads(sys.stdin.read())
except Exception as e:
    print("__PARSE_ERROR__", e)
    sys.exit(0)
hso = j.get("hookSpecificOutput") or {}
print(hso.get("additionalContext", ""))
') || true

  if [ -z "$context" ]; then
    echo "FAIL [$label]: no additionalContext in output" >&2
    echo "  raw: $out" >&2
    FAIL=$((FAIL + 1))
    return
  fi

  if ! printf '%s' "$context" | grep -q "$expect_in_context"; then
    echo "FAIL [$label]: expected '$expect_in_context' in context" >&2
    echo "  context: $context" >&2
    FAIL=$((FAIL + 1))
    return
  fi

  # Sticky block must always be present (its first marker line is
  # "Sage state — " regardless of fixture state).
  if ! printf '%s' "$context" | grep -q "Sage state —"; then
    echo "FAIL [$label]: sticky context missing 'Sage state —'" >&2
    echo "  context: $context" >&2
    FAIL=$((FAIL + 1))
    return
  fi

  echo "PASS [$label]"
  PASS=$((PASS + 1))
}

# 1. Passthrough — explicit skill invocation, must emit sticky.
run_case "explicit-skill" "sage_spec_only" '$build add a feature' "Sage state —"

# 2. Tiny / question — must emit sticky.
run_case "tiny-question" "sage_brief_only" "what does this do" "Sage state —"

# 3. Tier 1 fix hint — must emit hint AND sticky.
run_case "tier1-fix" "sage_spec_only" "fix the typo in README" "Tier 1 fix detected"

# 4. Tier 1 build hint — must emit hint AND sticky.
run_case "tier1-build" "sage_spec_only" "add tests for the utils module" "Tier 1 build detected"

# 5. Fix keyword (non-Tier-1) — must block AND emit sticky.
run_case "fix-block" "sage_no_active" "the checkout endpoint is broken" "Sage workflow gate — fix"

# 6. Build keyword without active spec/plan — must block AND emit sticky.
run_case "build-block" "sage_no_active" "implement a new payment service" "Sage workflow gate — build"

# 7. Build keyword with active spec/plan in same initiative — passthrough
#    with sticky. (sage_plan_only has spec+plan in plan-init.)
run_case "build-pass" "sage_plan_only" "implement a new analytics module" "Sage state —"

# 8. Default passthrough on a generic statement — sticky still emitted.
run_case "generic" "sage_brief_only" "let me know when ready" "Sage state —"

# 9. Verification-pending fixture: sticky must include 'ready to close'.
run_case "ready-to-close" "sage_verification_pending" "what is the next step" "ready to close: bin/sage-close verify-init"

# 10. No-active sticky line.
run_case "no-active-sticky" "sage_no_active" "ok let's get started" "no active initiative"

echo
echo "Results: $PASS passed, $FAIL failed."
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
