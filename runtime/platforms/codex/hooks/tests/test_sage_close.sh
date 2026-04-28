#!/usr/bin/env bash
# Tests for bin/sage-close.
#
# Each test runs against an isolated copy of the git_repo fixture so
# state never leaks between cases. Captures git tip + decisions.md
# length before/after to prove idempotence (DONE-WHEN #5 / plan-reviewer).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$HERE/.." && pwd)"
PROJECT_ROOT="$(cd "$HOOKS_DIR/../../../.." && pwd)"
SAGE_CLOSE="$PROJECT_ROOT/bin/sage-close"
FIXTURE_SRC="$HERE/tmp/git_repo"

if [ ! -d "$FIXTURE_SRC" ]; then
  bash "$HERE/fixtures/build_fixtures.sh" >/dev/null
fi

PASS=0
FAIL=0

# Make sure the fresh fixture exists for each case by copying.
fresh_repo() {
  local dest="$1"
  rm -rf "$dest"
  cp -R "$FIXTURE_SRC" "$dest"
  # Symlink the runtime/platforms/codex/hooks tree from the project so
  # sage-close can import lib.verification_check from inside the fixture.
  mkdir -p "$dest/runtime/platforms/codex"
  ln -sfn "$PROJECT_ROOT/runtime/platforms/codex/hooks" \
          "$dest/runtime/platforms/codex/hooks"
}

run_case() {
  local label="$1"; shift
  if "$@"; then
    echo "PASS [$label]"
    PASS=$((PASS + 1))
  else
    echo "FAIL [$label]" >&2
    FAIL=$((FAIL + 1))
  fi
}

# ── 1. DRY run prints planned phases without touching git ───────────
case_dry_run() {
  local repo
  repo="$(mktemp -d -t sage-close-dry.XXXXXX)"
  fresh_repo "$repo"
  local before_inner before_integration before_lines
  before_inner=$(git -C "$repo" rev-parse self-host/main)
  before_integration=$(git -C "$repo" rev-parse codex-port)
  before_lines=$(wc -l < "$repo/.sage/decisions.md")

  local out
  out=$(cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_DRY=1 \
        SAGE_CLOSE_NO_PUSH=1 \
        "$SAGE_CLOSE" sample-init 2>&1)
  local rc=$?
  [ "$rc" -eq 0 ] || { echo "  dry-run exit=$rc"; return 1; }

  printf '%s' "$out" | grep -q "phase 1/7 preflight" || { echo "  no preflight phase"; return 1; }
  printf '%s' "$out" | grep -q "phase 2/7 verify" || { echo "  no verify phase"; return 1; }

  local after_inner after_integration after_lines
  after_inner=$(git -C "$repo" rev-parse self-host/main)
  after_integration=$(git -C "$repo" rev-parse codex-port)
  after_lines=$(wc -l < "$repo/.sage/decisions.md")

  [ "$before_inner" = "$after_inner" ] || { echo "  inner branch tip changed"; return 1; }
  [ "$before_integration" = "$after_integration" ] || { echo "  integration branch tip changed"; return 1; }
  [ "$before_lines" = "$after_lines" ] || { echo "  decisions.md grew under DRY"; return 1; }
  return 0
}

# ── 2. Real run: 1 inner commit + 1 integration merge + decisions entry ─
case_real_run() {
  local repo
  repo="$(mktemp -d -t sage-close-real.XXXXXX)"
  fresh_repo "$repo"
  local before_inner_count before_int_count
  before_inner_count=$(git -C "$repo" rev-list --count self-host/main)
  before_int_count=$(git -C "$repo" rev-list --count codex-port)

  if ! (cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_NO_PUSH=1 \
        "$SAGE_CLOSE" sample-init >/tmp/sage-close-real.log 2>&1); then
    echo "  real run exited non-zero"
    cat /tmp/sage-close-real.log >&2
    return 1
  fi

  local after_inner_count after_int_count
  after_inner_count=$(git -C "$repo" rev-list --count self-host/main)
  after_int_count=$(git -C "$repo" rev-list --count codex-port)
  [ "$after_inner_count" = "$((before_inner_count + 1))" ] || {
    echo "  inner branch did not gain exactly 1 commit ($before_inner_count → $after_inner_count)"
    return 1
  }
  # Integration gains: +1 merge commit AT LEAST + the merged commit.
  # Conservative check: must be greater than before.
  [ "$after_int_count" -gt "$before_int_count" ] || {
    echo "  integration branch did not advance"
    return 1
  }
  # Must contain a merge commit mentioning the slug.
  git -C "$repo" log codex-port --merges --grep=sample-init -n1 \
    --format="%s" | grep -q sample-init || {
    echo "  no merge commit referencing sample-init on codex-port"
    return 1
  }
  # decisions.md must carry close entry.
  head -n 30 "$repo/.sage/decisions.md" | grep -q "close sample-init" || {
    echo "  decisions.md missing close entry"
    return 1
  }
  # verification.md frontmatter flipped to closed: true.
  grep -q "^closed: true" "$repo/.sage/work/sample-init/verification.md" || {
    echo "  verification.md not marked closed: true"
    return 1
  }
  return 0
}

# ── 3. Idempotence: re-run is a no-op ───────────────────────────────
case_idempotent_rerun() {
  local repo
  repo="$(mktemp -d -t sage-close-idem.XXXXXX)"
  fresh_repo "$repo"
  # First run.
  (cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_NO_PUSH=1 \
    "$SAGE_CLOSE" sample-init >/dev/null 2>&1) || {
    echo "  initial run failed"
    return 1
  }
  local before_inner before_int before_lines
  before_inner=$(git -C "$repo" rev-parse self-host/main)
  before_int=$(git -C "$repo" rev-parse codex-port)
  before_lines=$(wc -l < "$repo/.sage/decisions.md")

  # Re-run.
  local out
  out=$(cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_NO_PUSH=1 \
        "$SAGE_CLOSE" sample-init 2>&1)
  local rc=$?
  [ "$rc" -eq 0 ] || { echo "  re-run exit=$rc"; printf '%s\n' "$out" >&2; return 1; }
  printf '%s' "$out" | grep -q "already done" || {
    echo "  no 'already done' line in re-run output"
    printf '%s\n' "$out" >&2
    return 1
  }
  # All three before/after measures unchanged.
  local after_inner after_int after_lines
  after_inner=$(git -C "$repo" rev-parse self-host/main)
  after_int=$(git -C "$repo" rev-parse codex-port)
  after_lines=$(wc -l < "$repo/.sage/decisions.md")
  [ "$before_inner" = "$after_inner" ] || { echo "  inner tip moved on re-run"; return 1; }
  [ "$before_int" = "$after_int" ] || { echo "  integration tip moved on re-run"; return 1; }
  [ "$before_lines" = "$after_lines" ] || { echo "  decisions.md grew on re-run"; return 1; }
  return 0
}

# ── 4. Validator failure blocks at phase 2; no commits ──────────────
case_validator_blocks() {
  local repo
  repo="$(mktemp -d -t sage-close-bad.XXXXXX)"
  fresh_repo "$repo"
  # Replace verification.md with a defective fixture.
  cp "$HERE/tmp/verifications/missing_closeout_checklist.md" \
     "$repo/.sage/work/sample-init/verification.md"
  local before_inner_count
  before_inner_count=$(git -C "$repo" rev-list --count self-host/main)

  set +e
  local out
  out=$(cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_NO_PUSH=1 \
        "$SAGE_CLOSE" sample-init 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit on validator failure"; return 1; }
  printf '%s' "$out" | grep -q "FAILED shape check" || {
    echo "  expected FAILED shape check in output"
    printf '%s\n' "$out" >&2
    return 1
  }
  local after_inner_count
  after_inner_count=$(git -C "$repo" rev-list --count self-host/main)
  [ "$after_inner_count" = "$before_inner_count" ] || {
    echo "  inner branch advanced despite validator failure"
    return 1
  }
  return 0
}

# ── 5. Slug-not-found exits cleanly ─────────────────────────────────
case_unknown_slug() {
  local repo
  repo="$(mktemp -d -t sage-close-noslug.XXXXXX)"
  fresh_repo "$repo"
  set +e
  local out
  out=$(cd "$repo" && env SAGE_PROJECT_ROOT="$repo" SAGE_CLOSE_NO_PUSH=1 \
        "$SAGE_CLOSE" not-a-real-slug 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  printf '%s' "$out" | grep -q "initiative directory not found" || {
    echo "  expected 'initiative directory not found' in stderr"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

run_case "dry-run no mutation"        case_dry_run
run_case "real run produces close"    case_real_run
run_case "re-run is idempotent"       case_idempotent_rerun
run_case "validator blocks bad shape" case_validator_blocks
run_case "unknown slug exits clean"   case_unknown_slug

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
