#!/usr/bin/env bash
# E2E test for `sage install-hooks` dispatcher case.
# Drives bin/sage install-hooks against a throwaway git repo and
# asserts that the hook lands + core.hooksPath is set.
#
# Note: full `sage init` flow is exercised by manual smoke at Step 7
# (cp -a of the framework is too slow for the test suite).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../../../../.." && pwd)"
SAGE_BIN="$PROJECT_ROOT/bin/sage"

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

# ── 1. sage install-hooks wires a fresh project ─────────────────────
case_install_hooks_wires() {
  local target
  target="$(mktemp -d -t sage-ih-cmd.XXXXXX)"
  ( cd "$target" && git init --quiet )
  set +e
  local out
  out=$(cd "$target" && env SAGE_FRAMEWORK="$PROJECT_ROOT" \
        "$SAGE_BIN" install-hooks 2>&1)
  local rc=$?
  set -e
  [ "$rc" -eq 0 ] || { echo "  exit=$rc"; printf '%s\n' "$out" >&2; return 1; }
  [ -f "$target/.githooks/pre-commit" ] || { echo "  hook not copied"; return 1; }
  local val
  val=$(git -C "$target" config --get core.hooksPath || true)
  [ "$val" = ".githooks" ] || { echo "  core.hooksPath=$val"; return 1; }
  return 0
}

# ── 2. sage install-hooks outside a git repo: clean error ───────────
case_install_hooks_no_git() {
  local target
  target="$(mktemp -d -t sage-ih-nogit.XXXXXX)"
  set +e
  local out
  out=$(cd "$target" && env SAGE_FRAMEWORK="$PROJECT_ROOT" \
        "$SAGE_BIN" install-hooks 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  printf '%s' "$out" | grep -q "git repository" || {
    echo "  expected 'git repository' in error"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

# ── 3. Re-running install-hooks is idempotent ───────────────────────
case_install_hooks_idempotent() {
  local target
  target="$(mktemp -d -t sage-ih-rerun.XXXXXX)"
  ( cd "$target" && git init --quiet )
  cd "$target"
  env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SAGE_BIN" install-hooks >/dev/null
  local hash_before
  hash_before=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  local out
  out=$(env SAGE_FRAMEWORK="$PROJECT_ROOT" "$SAGE_BIN" install-hooks 2>&1)
  local rc=$?
  [ "$rc" -eq 0 ] || { echo "  re-run exit=$rc"; return 1; }
  # Must NOT report new copy or re-wire on second run.
  printf '%s' "$out" | grep -q "auto-wired" && {
    echo "  unexpected re-wire in idempotent run"
    return 1
  }
  local hash_after
  hash_after=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  [ "$hash_before" = "$hash_after" ] || { echo "  hook content changed"; return 1; }
  return 0
}

run_case "install-hooks wires fresh project"     case_install_hooks_wires
run_case "install-hooks outside git: clean fail" case_install_hooks_no_git
run_case "install-hooks idempotent on re-run"    case_install_hooks_idempotent

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
