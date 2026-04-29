#!/usr/bin/env bash
# M2 test suite — Githooks policy + --force-githooks override
#
# Covers:
#   - detect_existing_hooks_framework (6 fixtures: husky-dir, husky-node, lefthook,
#     pre-commit, simple-git-hooks, custom-scripts, none)
#   - force_githooks_override flag flow (abort, override, fall-through)
#   - _render_l5_section states (ACTIVE / DORMANT custom / NOT INITIALIZED / NOT A REPO)
#
# Run from repo root:  bash tests/test_m2_githooks.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SAGE_BIN="$REPO_ROOT/bin/sage"
PASS=0
FAIL=0

# Extract internals (same shim pattern as M1 test).
SAGE_INTERNALS_FILE=$(mktemp -t sage-internals-m2.XXXXXX)
trap 'rm -f "$SAGE_INTERNALS_FILE"' EXIT
{
  cat <<'STUBS'
step_ok_notimed() { echo "  ok: $*" >&2; }
step_warn()       { echo "  warn: $*" >&2; }
step_fail()       { echo "  fail: $*" >&2; }
RED=""; GREEN=""; YELLOW=""; DIM=""; BOLD=""; RESET=""
STUBS
  awk '/^# ── Portable realpath/,/^# ── ensure_hooks_wired ──/' "$SAGE_BIN" \
    | grep -vE '^(resolve_framework|resolve_profile)$'
  # Also pull in render-stub block + l5 renderer (stop BEFORE sage_status to avoid open brace)
  awk '/^_render_framework_root\(\)/,/^sage_status\(\) \{/ { if ($0 ~ /^sage_status\(\) \{/) exit; print }' "$SAGE_BIN"
} > "$SAGE_INTERNALS_FILE"
SAGE_INTERNALS="source '$SAGE_INTERNALS_FILE'"

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
    echo "        haystack: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

detect_in() {
  local dir="$1"
  bash -c "$SAGE_INTERNALS
detect_existing_hooks_framework '$dir'"
}

#####################################################################
# UNIT — detect_existing_hooks_framework
#####################################################################
echo ""
echo "=== unit: detect_existing_hooks_framework ==="

# 1. husky via .husky/ directory
T=$(mktemp -d); mkdir -p "$T/.husky"; touch "$T/.husky/pre-commit"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "husky" "husky (.husky/ dir)"
rm -rf "$T"

# 2. husky via node_modules
T=$(mktemp -d); mkdir -p "$T/node_modules/husky"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "husky" "husky (node_modules/husky)"
rm -rf "$T"

# 3. lefthook .yml
T=$(mktemp -d); echo "pre-commit:" > "$T/lefthook.yml"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "lefthook" "lefthook (.yml)"
rm -rf "$T"

# 4. lefthook .yaml
T=$(mktemp -d); echo "pre-commit:" > "$T/lefthook.yaml"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "lefthook" "lefthook (.yaml)"
rm -rf "$T"

# 5. pre-commit
T=$(mktemp -d); echo "repos: []" > "$T/.pre-commit-config.yaml"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "pre-commit" "pre-commit (.pre-commit-config.yaml)"
rm -rf "$T"

# 6. simple-git-hooks
T=$(mktemp -d); cat > "$T/package.json" <<'JSON'
{"name":"x","devDependencies":{"simple-git-hooks":"^2.0.0"}}
JSON
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "simple-git-hooks" "simple-git-hooks (package.json)"
rm -rf "$T"

# 7. custom-scripts in .git/hooks
T=$(mktemp -d); mkdir -p "$T/.git/hooks"
cat > "$T/.git/hooks/pre-commit" <<'SH'
#!/usr/bin/env bash
echo custom
SH
chmod +x "$T/.git/hooks/pre-commit"
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "custom-scripts" "custom-scripts (executable in .git/hooks)"
rm -rf "$T"

# 8. none
T=$(mktemp -d)
out=$(detect_in "$T" | cut -f1)
assert_eq "$out" "none" "none (empty project)"
rm -rf "$T"

# 9. custom hooks path is reported correctly
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath my-hooks)
mkdir -p "$T/my-hooks"
echo '#!/bin/sh' > "$T/my-hooks/pre-commit"
chmod +x "$T/my-hooks/pre-commit"
path=$(detect_in "$T" | cut -f2)
assert_eq "$path" "my-hooks" "custom hooks path returned"
rm -rf "$T"

#####################################################################
# UNIT — force_githooks_override flow
#####################################################################
echo ""
echo "=== unit: force_githooks_override flow ==="

# Setup: husky-style repo with override declined.
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath .husky)
mkdir -p "$T/.husky"; echo '#!/bin/sh' > "$T/.husky/pre-commit"
chmod +x "$T/.husky/pre-commit"
mkdir -p "$T/.githooks"
echo '#!/bin/sh' > "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"

out=$(printf 'n\n' | bash -c "$SAGE_INTERNALS
force_githooks_override '$T'" 2>&1)
rc=$?
assert_eq "$rc" "1" "decline: returns 1"
assert_contains "$out" "Aborted" "decline: 'Aborted' message"
hp=$(git -C "$T" config --get core.hooksPath)
assert_eq "$hp" ".husky" "decline: core.hooksPath unchanged (.husky)"
rm -rf "$T"

# Husky + accept
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath .husky)
mkdir -p "$T/.husky"; echo '#!/bin/sh' > "$T/.husky/pre-commit"
chmod +x "$T/.husky/pre-commit"
mkdir -p "$T/.githooks"
echo '#!/bin/sh' > "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"

out=$(printf 'y\n' | bash -c "$SAGE_INTERNALS
force_githooks_override '$T'" 2>&1)
rc=$?
assert_eq "$rc" "0" "accept: returns 0"
hp=$(git -C "$T" config --get core.hooksPath)
assert_eq "$hp" ".githooks" "accept: core.hooksPath swapped to .githooks"
[ -x "$T/.githooks/pre-commit" ] && {
  echo "  PASS  accept: .githooks/pre-commit still executable"
  PASS=$((PASS + 1))
} || {
  echo "  FAIL  accept: .githooks/pre-commit missing/non-exec"
  FAIL=$((FAIL + 1))
}
[ -x "$T/.husky/pre-commit" ] && {
  echo "  PASS  accept: previous .husky/pre-commit left in place (no longer fires)"
  PASS=$((PASS + 1))
} || {
  echo "  FAIL  accept: .husky/pre-commit was deleted (should be left)"
  FAIL=$((FAIL + 1))
}
rm -rf "$T"

# No-conflict fall-through: empty hooksPath → delegates to ensure_hooks_wired
T=$(mktemp -d) && (cd "$T" && git init -q)
mkdir -p "$T/.githooks"
echo '#!/bin/sh' > "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"
# stub ensure_hooks_wired so we don't depend on framework state
out=$(bash -c "$SAGE_INTERNALS
ensure_hooks_wired() { echo 'STUB:ensure_hooks_wired called'; return 0; }
force_githooks_override '$T'" 2>&1)
rc=$?
assert_eq "$rc" "0" "fall-through: returns 0"
assert_contains "$out" "STUB:ensure_hooks_wired called" "fall-through: delegates to ensure_hooks_wired"
rm -rf "$T"

#####################################################################
# UNIT — _render_l5_section states
#####################################################################
echo ""
echo "=== unit: _render_l5_section states ==="

render_l5() {
  local target="$1"
  bash -c "$SAGE_INTERNALS
SAGE_STATUS_TARGET='$target'
_render_l5_section"
}

# State 1: no .git → NOT A REPO
T=$(mktemp -d)
out=$(render_l5 "$T")
assert_contains "$out" "NOT A REPO" "L5: no .git → NOT A REPO"
rm -rf "$T"

# State 2: git repo, no hooksPath → NOT INITIALIZED
T=$(mktemp -d) && (cd "$T" && git init -q)
out=$(render_l5 "$T")
assert_contains "$out" "NOT INITIALIZED" "L5: fresh repo → NOT INITIALIZED"
rm -rf "$T"

# State 3: .githooks active
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath .githooks)
mkdir -p "$T/.githooks"
echo '#!/bin/sh' > "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"
out=$(render_l5 "$T")
assert_contains "$out" "ACTIVE" "L5: .githooks + script → ACTIVE"
rm -rf "$T"

# State 4: .githooks set but pre-commit missing → DORMANT
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath .githooks)
mkdir -p "$T/.githooks"
out=$(render_l5 "$T")
assert_contains "$out" "DORMANT" "L5: .githooks + missing script → DORMANT"
rm -rf "$T"

# State 5: husky → DORMANT (custom)
T=$(mktemp -d) && (cd "$T" && git init -q && git config core.hooksPath .husky)
mkdir -p "$T/.husky"; touch "$T/.husky/pre-commit"
out=$(render_l5 "$T")
assert_contains "$out" "DORMANT" "L5: husky → DORMANT (custom)"
assert_contains "$out" "force-githooks" "L5: husky → hint mentions --force-githooks"
rm -rf "$T"

#####################################################################
# SUMMARY
#####################################################################
echo ""
echo "================================================================="
echo "  M2 test summary:  $PASS passed, $FAIL failed"
echo "================================================================="
[ "$FAIL" -eq 0 ]
