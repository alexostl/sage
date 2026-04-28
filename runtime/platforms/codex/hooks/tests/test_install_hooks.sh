#!/usr/bin/env bash
# Tests for bin/sage-install-hooks.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../../../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/bin/sage-install-hooks"

PASS=0
FAIL=0

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

# NOTE: Since the hybrid-levers fix cycle, bin/sage-install-hooks is a
# thin wrapper around `bin/sage install-hooks`, which calls
# ensure_hooks_wired(). New contract:
#   - Missing .githooks/ dir → script CREATES it (no longer aborts).
#   - Pre-existing identical hook → idempotent (no-op).
#   - Pre-existing user-edited hook → preserved + .sage-new sidecar.
#   - Outside git repo → exits non-zero.
# These cases reflect the new contract.

# ── 1. First run on bare git repo: copies framework hook + wires ────
case_first_run() {
  local repo
  repo="$(mktemp -d -t sage-ih-first.XXXXXX)"
  ( cd "$repo" && git init --quiet )
  if ! (cd "$repo" && env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SCRIPT" >/dev/null 2>&1); then
    echo "  install failed"
    return 1
  fi
  [ -f "$repo/.githooks/pre-commit" ] || { echo "  hook not copied"; return 1; }
  local val
  val="$(git -C "$repo" config --get core.hooksPath || true)"
  [ "$val" = ".githooks" ] || { echo "  expected .githooks, got '$val'"; return 1; }
  return 0
}

# ── 2. Re-run with framework hook present: idempotent (no warnings) ─
case_idempotent() {
  local repo
  repo="$(mktemp -d -t sage-ih-idem.XXXXXX)"
  ( cd "$repo" && git init --quiet )
  (cd "$repo" && env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SCRIPT" >/dev/null 2>&1)
  local hash_before
  hash_before=$(shasum -a 256 "$repo/.githooks/pre-commit" | cut -d" " -f1)
  local out
  out=$(cd "$repo" && env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SCRIPT" 2>&1)
  local rc=$?
  [ "$rc" -eq 0 ] || { echo "  rerun exit=$rc"; return 1; }
  # No "auto-wired" reported, no "differs from framework" warning.
  printf '%s' "$out" | grep -q "auto-wired" && {
    echo "  unexpected re-wire on idempotent run"
    return 1
  }
  printf '%s' "$out" | grep -q "differs from framework" && {
    echo "  unexpected diff warning on idempotent run"
    return 1
  }
  local hash_after
  hash_after=$(shasum -a 256 "$repo/.githooks/pre-commit" | cut -d" " -f1)
  [ "$hash_before" = "$hash_after" ] || { echo "  hook changed on idempotent run"; return 1; }
  return 0
}

# ── 3. Missing .githooks/ dir → script creates it (new contract) ────
case_creates_missing_dir() {
  local repo
  repo="$(mktemp -d -t sage-ih-mkdir.XXXXXX)"
  ( cd "$repo" && git init --quiet )
  # No .githooks/ in fixture; expect script to create + populate.
  if ! (cd "$repo" && env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SCRIPT" >/dev/null 2>&1); then
    echo "  install failed"
    return 1
  fi
  [ -d "$repo/.githooks" ] || { echo "  .githooks/ not created"; return 1; }
  [ -f "$repo/.githooks/pre-commit" ] || { echo "  pre-commit not copied"; return 1; }
  return 0
}

# ── 4. Outside a git repo: clean error ──────────────────────────────
case_outside_repo() {
  local dir
  dir="$(mktemp -d -t sage-ih-nogit.XXXXXX)"
  set +e
  local out
  out=$(cd "$dir" && env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SCRIPT" 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  # Match case-insensitively because the new dispatcher prints
  # "Not inside a git repository." (capitalized).
  printf '%s' "$out" | grep -qi "not inside a git repository" || {
    echo "  expected git-repo error"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

run_case "first run copies + wires"          case_first_run
run_case "re-run is idempotent (no warns)"   case_idempotent
run_case "missing .githooks/ → created"      case_creates_missing_dir
run_case "outside git repo aborts"           case_outside_repo

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
