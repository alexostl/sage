#!/usr/bin/env bash
# M1 test suite — Codex hook activation pipeline
#
# Covers:
#   - codex_hooks_enabled (5 fixtures)
#   - codex_hook_known_hash (3 fixtures)
#   - resolve_profile (3 fixtures)
#   - ensure_codex_hooks_wired against alex-os-dev-shape (full pipeline)
#   - idempotency: 2x sage update → 0 diff
#
# Run from repo root:  bash tests/test_m1_codex_hooks.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SAGE_BIN="$REPO_ROOT/bin/sage"
FIXTURE="$REPO_ROOT/tests/fixtures/alex-os-dev-shape"
PASS=0
FAIL=0

# Source bin/sage for unit access to internal functions. We bypass the
# auto-run dispatch by setting COMMAND="" before sourcing wouldn't work
# (set -euo at top + exit 1 unknown). Instead we use a shim: write a
# wrapper that sources the relevant chunk by line range. Simpler: extract
# functions via subshell `bash -c`.
# Extract function defs only — strip the bare top-level calls that
# auto-run at source time (resolve_framework / resolve_profile) so each
# unit test starts from a clean state. Write to a temp file so tests
# can `source` it without process-substitution edge cases (sourcing
# via `<(awk ...)` breaks heredocs inside the extracted text).
SAGE_INTERNALS_FILE=$(mktemp -t sage-internals.XXXXXX)
trap 'rm -f "$SAGE_INTERNALS_FILE"' EXIT
{
  # Output helper stubs — bin/sage defines step_ok_notimed / step_warn /
  # step_fail before the range we extract; provide minimal shims so the
  # extracted code can call them in unit context.
  cat <<'STUBS'
step_ok_notimed() { echo "  ok: $*" >&2; }
step_warn()       { echo "  warn: $*" >&2; }
step_fail()       { echo "  fail: $*" >&2; }
STUBS
  awk '/^# ── Portable realpath/,/^# ── ensure_hooks_wired ──/' "$SAGE_BIN" \
    | grep -vE '^(resolve_framework|resolve_profile)$'
} > "$SAGE_INTERNALS_FILE"
SAGE_INTERNALS="source '$SAGE_INTERNALS_FILE'"

run_unit() {
  local name="$1" assertion="$2"
  local out rc
  out=$(SAGE_FRAMEWORK="$REPO_ROOT" bash -c "$SAGE_INTERNALS
$assertion" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    echo "        $out"
    FAIL=$((FAIL + 1))
  fi
}

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

#####################################################################
# UNIT — codex_hooks_enabled
#####################################################################
echo ""
echo "=== unit: codex_hooks_enabled ==="

T=$(mktemp -d)
mkdir "$T/.codex"
echo "[features]" > "$T/.codex/config.toml"
echo "codex_hooks = true" >> "$T/.codex/config.toml"
run_unit "codex_hooks=true (active)" \
  "codex_hooks_enabled '$T' && exit 0 || exit 1"
rm -rf "$T"

T=$(mktemp -d)
mkdir "$T/.codex"
echo "[features]" > "$T/.codex/config.toml"
echo "codex_hooks = false" >> "$T/.codex/config.toml"
run_unit "codex_hooks=false (disabled)" \
  "codex_hooks_enabled '$T' && exit 1 || exit 0"
rm -rf "$T"

T=$(mktemp -d)
mkdir "$T/.codex"
echo "# (no features section)" > "$T/.codex/config.toml"
run_unit "no [features] section" \
  "codex_hooks_enabled '$T' && exit 1 || exit 0"
rm -rf "$T"

T=$(mktemp -d)
run_unit "no .codex/config.toml" \
  "codex_hooks_enabled '$T' && exit 1 || exit 0"
rm -rf "$T"

T=$(mktemp -d)
mkdir "$T/.codex"
echo '[features]' > "$T/.codex/config.toml"
echo 'codex_hooks="true"' >> "$T/.codex/config.toml"
run_unit "codex_hooks=\"true\" (quoted)" \
  "codex_hooks_enabled '$T' && exit 0 || exit 1"
rm -rf "$T"

#####################################################################
# UNIT — codex_hook_known_hash
#####################################################################
echo ""
echo "=== unit: codex_hook_known_hash ==="

current_hash=$(shasum -a 256 "$REPO_ROOT/runtime/platforms/codex/hooks/post-bash.sh" | cut -d" " -f1)
run_unit "current hash recognized" \
  "codex_hook_known_hash '$current_hash' && exit 0 || exit 1"

run_unit "unknown hash rejected" \
  "codex_hook_known_hash '0000000000000000000000000000000000000000000000000000000000000000' && exit 1 || exit 0"

run_unit "empty hash rejected" \
  "codex_hook_known_hash '' && exit 1 || exit 0"

#####################################################################
# UNIT — resolve_profile
#####################################################################
echo ""
echo "=== unit: resolve_profile ==="

# Real framework, profile present (this repo)
out=$(SAGE_FRAMEWORK="$REPO_ROOT" bash -c "$SAGE_INTERNALS
resolve_profile
echo \"\$SAGE_PROFILE\"")
assert_eq "$out" "self-host" "self-host profile detected (this repo)"

# Fake framework root with profile: upstream
F=$(mktemp -d)
mkdir -p "$F/core" "$F/skills" "$F/.sage"
echo "profile: upstream" > "$F/.sage/profile"
out=$(SAGE_FRAMEWORK="$F" bash -c "$SAGE_INTERNALS
resolve_profile
echo \"\$SAGE_PROFILE\"")
assert_eq "$out" "upstream" "explicit profile: upstream"
rm -rf "$F"

# Fake framework root, no profile file → default upstream
F=$(mktemp -d)
mkdir -p "$F/core" "$F/skills"
out=$(SAGE_FRAMEWORK="$F" bash -c "$SAGE_INTERNALS
resolve_profile
echo \"\$SAGE_PROFILE\"")
assert_eq "$out" "upstream" "no profile file → upstream"
rm -rf "$F"

# Invalid framework layout (no core/skills) → upstream fallback even if marker says self-host
F=$(mktemp -d)
mkdir -p "$F/.sage"
echo "profile: self-host" > "$F/.sage/profile"
out=$(SAGE_FRAMEWORK="$F" bash -c "$SAGE_INTERNALS
resolve_profile
echo \"\$SAGE_PROFILE\"")
assert_eq "$out" "upstream" "invalid framework layout → upstream fallback"
rm -rf "$F"

#####################################################################
# INTEGRATION — full ensure_codex_hooks_wired against fixture
#####################################################################
echo ""
echo "=== integration: ensure_codex_hooks_wired (alex-os-dev-shape) ==="

T=$(mktemp -d)
cp -R "$FIXTURE"/. "$T"/
[ -d "$T/.codex" ] || { echo "  FAIL  fixture copy missing .codex"; FAIL=$((FAIL+1)); }

# Pre-state: only custom SessionStart user entry, no framework script files.
PRE_HOOKS=$(cat "$T/.codex/hooks.json")

# Run the pipeline.
"$SAGE_BIN" --help >/dev/null 2>&1  # smoke
out=$(cd "$T" && SAGE_HOOKS_QUIET=1 bash -c "
  source '$SAGE_INTERNALS_FILE'
  SAGE_FRAMEWORK='$REPO_ROOT'
  ensure_codex_hooks_wired '$T' 2>&1
  echo '---rc='\$?
")
echo "$out"

# Verify .sh files copied
for f in pre-prompt.sh pre-bash.sh post-bash.sh session-start.sh; do
  if [ -x "$T/.codex/hooks/$f" ]; then
    echo "  PASS  $f copied + executable"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $f missing or not executable"
    FAIL=$((FAIL + 1))
  fi
done

# Verify hooks.json now contains framework entries AND preserves user entry
if command -v python3 >/dev/null 2>&1; then
  python3 - "$T/.codex/hooks.json" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
session = data.get("hooks", {}).get("SessionStart") or []
fw = [g for g in session if any(".codex/hooks/session-start.sh" in (h.get("command","") or "") for h in g.get("hooks") or [])]
user = [g for g in session if any("verify-wiring.sh" in str(h) or "verify-wiring.sh" in (h.get("command","") or "") for h in g.get("hooks") or [])]
# user entry was NOT in hooks[*] structure (it's a flat dict in the fixture). Verify by string search.
raw = open(sys.argv[1]).read()
ok_fw = len(fw) >= 1
ok_user = "verify-wiring.sh" in raw
print(f"FW_ENTRIES={len(fw)}")
print(f"USER_PRESERVED={'yes' if ok_user else 'no'}")
sys.exit(0 if (ok_fw and ok_user) else 1)
PYEOF
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "  PASS  hooks.json: framework entries added + user entry preserved"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  hooks.json post-merge state wrong"
    FAIL=$((FAIL + 1))
  fi
fi

# Backup file present
if ls "$T/.codex"/hooks.json.sage-bak.* >/dev/null 2>&1; then
  echo "  PASS  atomic backup created"
  PASS=$((PASS + 1))
else
  echo "  FAIL  atomic backup missing"
  FAIL=$((FAIL + 1))
fi

# Idempotency: re-run, hooks.json should be unchanged after sorting
HASH_BEFORE=$(shasum -a 256 "$T/.codex/hooks.json" | cut -d" " -f1)
out2=$(cd "$T" && bash -c "
  source '$SAGE_INTERNALS_FILE'
  SAGE_FRAMEWORK='$REPO_ROOT'
  ensure_codex_hooks_wired '$T' 2>&1
")
HASH_AFTER=$(shasum -a 256 "$T/.codex/hooks.json" | cut -d" " -f1)
assert_eq "$HASH_BEFORE" "$HASH_AFTER" "idempotency: 2x ensure → 0 hooks.json diff"

#####################################################################
# INTEGRATION — shadow file detection
#####################################################################
echo ""
echo "=== integration: shadow file detection ==="

T2=$(mktemp -d)
cp -R "$FIXTURE"/. "$T2"/
mkdir -p "$T2/.codex/hooks"
echo "#!/usr/bin/env bash" > "$T2/.codex/hooks/post-bash.sh"
echo "echo SHADOW" >> "$T2/.codex/hooks/post-bash.sh"
chmod +x "$T2/.codex/hooks/post-bash.sh"

out=$(cd "$T2" && bash -c "
  source '$SAGE_INTERNALS_FILE'
  SAGE_FRAMEWORK='$REPO_ROOT'
  ensure_codex_hooks_wired '$T2' 2>&1
  echo \"---rc=\$?\"
")
assert_contains "$out" "SHADOW" "shadow file detected and surfaced"
assert_contains "$out" "MISCONFIGURED" "MISCONFIGURED message printed"
assert_contains "$out" "rc=2" "non-zero return code"

rm -rf "$T" "$T2"

#####################################################################
# SUMMARY
#####################################################################
echo ""
echo "================================================================="
echo "  M1 test summary:  $PASS passed, $FAIL failed"
echo "================================================================="
[ "$FAIL" -eq 0 ]
