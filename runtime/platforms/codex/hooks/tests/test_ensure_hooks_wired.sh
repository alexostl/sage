#!/usr/bin/env bash
# Tests for ensure_hooks_wired() in bin/sage.
#
# Exercises the function directly (not through `sage init`) so we can
# isolate copy + wire behavior without driving the full setup flow.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../../../../.." && pwd)"
SAGE_BIN="$PROJECT_ROOT/bin/sage"
HOOK_SRC="$PROJECT_ROOT/.githooks/pre-commit"

PASS=0
FAIL=0

# Source ensure_hooks_wired() from bin/sage by extracting the function.
# We cannot just `source bin/sage` because it would dispatch a command.
# Instead, run a subshell that defines step_* helpers + sources the
# function, then calls it.
run_ensure() {
  local target="$1"
  env SAGE_FRAMEWORK="$PROJECT_ROOT" \
      bash -c "
    # Stub the step_* helpers so the function does not error.
    step_ok_notimed() { echo \"OK: \$*\"; }
    step_warn()       { echo \"WARN: \$*\"; }
    step_info()       { echo \"INFO: \$*\"; }
    # Extract the function body and source it.
    eval \"\$(awk '/^ensure_hooks_wired\\(\\) \\{/,/^\\}\\$/' '$SAGE_BIN')\"
    ensure_hooks_wired '$target'
  "
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

# ── 1. Fresh git project: copy + wire ───────────────────────────────
case_fresh_project() {
  local target
  target="$(mktemp -d -t sage-ehw-fresh.XXXXXX)"
  ( cd "$target" && git init --quiet )
  local out
  out=$(run_ensure "$target" 2>&1)
  [ -f "$target/.githooks/pre-commit" ] || { echo "  hook not copied"; printf '%s\n' "$out" >&2; return 1; }
  [ -x "$target/.githooks/pre-commit" ] || { echo "  hook not executable"; return 1; }
  local val
  val=$(git -C "$target" config --get core.hooksPath || true)
  [ "$val" = ".githooks" ] || { echo "  core.hooksPath=$val (expected .githooks)"; return 1; }
  return 0
}

# ── 2. Already wired: idempotent ────────────────────────────────────
case_idempotent() {
  local target
  target="$(mktemp -d -t sage-ehw-idem.XXXXXX)"
  ( cd "$target" && git init --quiet )
  run_ensure "$target" >/dev/null
  local hash_before
  hash_before=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  local out
  out=$(run_ensure "$target" 2>&1)
  # No "OK: hooks: pre-commit copied" on second run.
  printf '%s' "$out" | grep -q "pre-commit copied" && {
    echo "  unexpected re-copy on second run"
    printf '%s\n' "$out" >&2
    return 1
  }
  printf '%s' "$out" | grep -q "auto-wired" && {
    echo "  unexpected re-wire on second run"
    printf '%s\n' "$out" >&2
    return 1
  }
  local hash_after
  hash_after=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  [ "$hash_before" = "$hash_after" ] || { echo "  hook content changed on idempotent run"; return 1; }
  # Catch the bug where ALWAYS writing a sidecar would slip past the
  # hash assertion (sidecar would still be present, original unchanged).
  [ ! -f "$target/.githooks/pre-commit.sage-new" ] || {
    echo "  unexpected .sage-new sidecar on idempotent run"
    return 1
  }
  return 0
}

# ── 3. Custom core.hooksPath: preserved ─────────────────────────────
case_custom_hookspath_preserved() {
  local target
  target="$(mktemp -d -t sage-ehw-custom.XXXXXX)"
  ( cd "$target" && git init --quiet && git config core.hooksPath .my-hooks )
  local out
  out=$(run_ensure "$target" 2>&1)
  local val
  val=$(git -C "$target" config --get core.hooksPath)
  [ "$val" = ".my-hooks" ] || { echo "  custom hooksPath was clobbered: $val"; return 1; }
  printf '%s' "$out" | grep -q "custom" || { echo "  no notice about custom value"; printf '%s\n' "$out" >&2; return 1; }
  return 0
}

# ── 4. User-edited hook: preserved + .sage-new sidecar ──────────────
case_user_edited_hook_preserved() {
  local target
  target="$(mktemp -d -t sage-ehw-edit.XXXXXX)"
  ( cd "$target" && git init --quiet )
  mkdir -p "$target/.githooks"
  echo "#!/bin/sh" > "$target/.githooks/pre-commit"
  echo "# my custom hook" >> "$target/.githooks/pre-commit"
  chmod +x "$target/.githooks/pre-commit"
  local out
  out=$(run_ensure "$target" 2>&1)
  # Original hook content preserved
  grep -q "my custom hook" "$target/.githooks/pre-commit" || { echo "  user hook was clobbered"; return 1; }
  # Sidecar created with framework version
  [ -f "$target/.githooks/pre-commit.sage-new" ] || { echo "  no .sage-new sidecar created"; return 1; }
  printf '%s' "$out" | grep -q "differs from framework" || { echo "  no warning about diff"; printf '%s\n' "$out" >&2; return 1; }
  return 0
}

# ── 5. Non-git directory: silent skip on wire ───────────────────────
case_non_git_dir_safe() {
  local target
  target="$(mktemp -d -t sage-ehw-nogit.XXXXXX)"
  local out
  out=$(run_ensure "$target" 2>&1)
  # Hook still copied (no git check on copy step), but no wire attempted.
  [ -f "$target/.githooks/pre-commit" ] || { echo "  hook should still be copied"; return 1; }
  printf '%s' "$out" | grep -q "auto-wired" && { echo "  wire was attempted in non-git dir"; printf '%s\n' "$out" >&2; return 1; }
  return 0
}

# ── 6. Self-host (target == SAGE_FRAMEWORK): skip copy, do wire ─────
case_self_host_no_copy() {
  local target
  target="$(mktemp -d -t sage-ehw-selfhost.XXXXXX)"
  # Build a minimal "framework" layout in target, then point
  # SAGE_FRAMEWORK at target so hook_src == hook_dest.
  ( cd "$target" && git init --quiet )
  mkdir -p "$target/.githooks"
  cp "$HOOK_SRC" "$target/.githooks/pre-commit"
  chmod +x "$target/.githooks/pre-commit"
  local hash_before
  hash_before=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  # Override SAGE_FRAMEWORK to target itself.
  local out
  out=$(env SAGE_FRAMEWORK="$target" bash -c "
    step_ok_notimed() { echo \"OK: \$*\"; }
    step_warn()       { echo \"WARN: \$*\"; }
    step_info()       { echo \"INFO: \$*\"; }
    eval \"\$(awk '/^ensure_hooks_wired\\(\\) \\{/,/^\\}\\$/' '$SAGE_BIN')\"
    ensure_hooks_wired '$target'
  " 2>&1)
  local hash_after
  hash_after=$(shasum -a 256 "$target/.githooks/pre-commit" | cut -d" " -f1)
  [ "$hash_before" = "$hash_after" ] || { echo "  hook content changed (should not in self-host)"; return 1; }
  printf '%s' "$out" | grep -q "auto-wired" || { echo "  expected wire to happen"; printf '%s\n' "$out" >&2; return 1; }
  return 0
}

run_case "fresh project: copy + wire"           case_fresh_project
run_case "idempotent: second run no-op"         case_idempotent
run_case "custom core.hooksPath preserved"      case_custom_hookspath_preserved
run_case "user-edited hook preserved + sidecar" case_user_edited_hook_preserved
run_case "non-git dir: copy ok, no wire"        case_non_git_dir_safe
run_case "self-host: skip copy, do wire"        case_self_host_no_copy

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
