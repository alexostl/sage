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

# ── 1. First run sets core.hooksPath ────────────────────────────────
case_first_run() {
  local repo
  repo="$(mktemp -d -t sage-ih-first.XXXXXX)"
  (
    cd "$repo"
    git init --quiet
    mkdir -p .githooks
    printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit
    chmod +x .githooks/pre-commit
  )
  if ! (cd "$repo" && "$SCRIPT" >/dev/null 2>&1); then
    echo "  install failed"
    return 1
  fi
  local val
  val="$(git -C "$repo" config --get core.hooksPath || true)"
  [ "$val" = ".githooks" ] || { echo "  expected .githooks, got '$val'"; return 1; }
  return 0
}

# ── 2. Re-run is idempotent ─────────────────────────────────────────
case_idempotent() {
  local repo
  repo="$(mktemp -d -t sage-ih-idem.XXXXXX)"
  (
    cd "$repo"
    git init --quiet
    mkdir -p .githooks
    printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit
    chmod +x .githooks/pre-commit
  )
  (cd "$repo" && "$SCRIPT" >/dev/null 2>&1)
  local out
  out=$(cd "$repo" && "$SCRIPT" 2>&1)
  local rc=$?
  [ "$rc" -eq 0 ] || { echo "  rerun exit=$rc"; return 1; }
  printf '%s' "$out" | grep -q "already wired" || {
    echo "  expected 'already wired' on re-run"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

# ── 3. Missing .githooks dir aborts ─────────────────────────────────
case_missing_dir() {
  local repo
  repo="$(mktemp -d -t sage-ih-miss.XXXXXX)"
  (
    cd "$repo"
    git init --quiet
  )
  set +e
  local out
  out=$(cd "$repo" && "$SCRIPT" 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  printf '%s' "$out" | grep -q "hooks directory missing" || {
    echo "  expected error about missing dir"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

# ── 4. Outside a git repo aborts ────────────────────────────────────
case_outside_repo() {
  local dir
  dir="$(mktemp -d -t sage-ih-nogit.XXXXXX)"
  set +e
  local out
  out=$(cd "$dir" && "$SCRIPT" 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  printf '%s' "$out" | grep -q "not inside a git repository" || {
    echo "  expected git-repo error"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

run_case "first run sets hooksPath"     case_first_run
run_case "re-run is idempotent"         case_idempotent
run_case "missing .githooks aborts"     case_missing_dir
run_case "outside git repo aborts"      case_outside_repo

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
