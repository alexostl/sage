#!/usr/bin/env bash
# Tests for .githooks/pre-commit
#
# Each case spins up an isolated copy of the git_repo fixture, wires
# core.hooksPath at the repo level, then exercises the gate.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$HERE/.." && pwd)"
PROJECT_ROOT="$(cd "$HOOKS_DIR/../../../.." && pwd)"
PRE_COMMIT="$PROJECT_ROOT/.githooks/pre-commit"
FIXTURE_SRC="$HERE/tmp/git_repo"

if [ ! -d "$FIXTURE_SRC" ]; then
  bash "$HERE/fixtures/build_fixtures.sh" >/dev/null
fi

PASS=0
FAIL=0

# Fresh repo with hook wired and runtime/platforms/codex/hooks symlinked.
fresh_repo() {
  local dest="$1"
  rm -rf "$dest"
  cp -R "$FIXTURE_SRC" "$dest"
  mkdir -p "$dest/runtime/platforms/codex"
  ln -sfn "$PROJECT_ROOT/runtime/platforms/codex/hooks" \
          "$dest/runtime/platforms/codex/hooks"
  mkdir -p "$dest/.githooks"
  cp "$PRE_COMMIT" "$dest/.githooks/pre-commit"
  chmod +x "$dest/.githooks/pre-commit"
  git -C "$dest" config core.hooksPath .githooks
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

# ── 1. Negative: standard scope, missing verification.md → blocked ──
case_negative_missing_verification() {
  local repo
  repo="$(mktemp -d -t sage-pc-neg.XXXXXX)"
  fresh_repo "$repo"
  # Remove verification.md from fixture initiative.
  rm -f "$repo/.sage/work/sample-init/verification.md"
  # Stage spec.md edit + an implementation file.
  echo "edit" >> "$repo/.sage/work/sample-init/spec.md"
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add .sage/work/sample-init/spec.md src/feature.py
  set +e
  local out
  out=$(git -C "$repo" commit -m "should be blocked" 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  printf '%s' "$out" | grep -q "pre-commit blocked" || {
    echo "  expected 'pre-commit blocked' in output"
    printf '%s\n' "$out" >&2
    return 1
  }
  return 0
}

# ── 2. Positive: standard scope, valid verification.md → allowed ────
case_positive_valid_verification() {
  local repo
  repo="$(mktemp -d -t sage-pc-pos.XXXXXX)"
  fresh_repo "$repo"
  # Fixture already has valid verification.md — just stage an impl file.
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add src/feature.py
  if ! git -C "$repo" commit -m "should be allowed" >/dev/null 2>&1; then
    echo "  expected commit to succeed"
    return 1
  fi
  return 0
}

# ── 3. False-positive ceiling: spec-only commit → allowed ───────────
case_spec_only_commit() {
  local repo
  repo="$(mktemp -d -t sage-pc-spec.XXXXXX)"
  fresh_repo "$repo"
  rm -f "$repo/.sage/work/sample-init/verification.md"
  echo "edit" >> "$repo/.sage/work/sample-init/spec.md"
  git -C "$repo" add .sage/work/sample-init/spec.md
  if ! git -C "$repo" commit -m "spec edit only" >/dev/null 2>&1; then
    echo "  spec-only commit was blocked (should be allowed)"
    return 1
  fi
  return 0
}

# ── 4. Mixed-case: spec.md + impl in same commit → blocked when bad ─
case_mixed_blocked_when_invalid() {
  local repo
  repo="$(mktemp -d -t sage-pc-mix.XXXXXX)"
  fresh_repo "$repo"
  # Defective verification.md — missing required heading.
  cp "$HERE/tmp/verifications/missing_closeout_checklist.md" \
     "$repo/.sage/work/sample-init/verification.md"
  echo "edit" >> "$repo/.sage/work/sample-init/spec.md"
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add .sage/work/sample-init/spec.md \
                       .sage/work/sample-init/verification.md \
                       src/feature.py
  set +e
  local out
  out=$(git -C "$repo" commit -m "mixed" 2>&1)
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "  expected mixed commit to be blocked"; return 1; }
  return 0
}

# ── 5. Mixed-case allowed when verification valid ───────────────────
case_mixed_allowed_when_valid() {
  local repo
  repo="$(mktemp -d -t sage-pc-mixok.XXXXXX)"
  fresh_repo "$repo"
  echo "edit" >> "$repo/.sage/work/sample-init/spec.md"
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add .sage/work/sample-init/spec.md src/feature.py
  if ! git -C "$repo" commit -m "mixed valid" >/dev/null 2>&1; then
    echo "  expected mixed-valid to commit"
    return 1
  fi
  return 0
}

# ── 6. Lightweight scope → ungated ──────────────────────────────────
case_lightweight_ungated() {
  local repo
  repo="$(mktemp -d -t sage-pc-light.XXXXXX)"
  fresh_repo "$repo"
  # Replace fixture spec.md with a lightweight one.
  cat > "$repo/.sage/work/sample-init/spec.md" <<'EOF'
---
cycle_id: "sample-init"
type: spec
status: in-progress
scope: lightweight
---

# Light spec
EOF
  rm -f "$repo/.sage/work/sample-init/verification.md"
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add .sage/work/sample-init/spec.md src/feature.py
  if ! git -C "$repo" commit -m "lightweight" >/dev/null 2>&1; then
    echo "  lightweight commit was blocked"
    return 1
  fi
  return 0
}

# ── 7. Docs allowlist: only AGENTS.md / docs/* changes → allowed ────
case_docs_allowlist() {
  local repo
  repo="$(mktemp -d -t sage-pc-docs.XXXXXX)"
  fresh_repo "$repo"
  rm -f "$repo/.sage/work/sample-init/verification.md"
  echo "edit" >> "$repo/.sage/work/sample-init/spec.md"
  echo "agent" > "$repo/AGENTS.md"
  mkdir -p "$repo/docs"
  echo "doc" > "$repo/docs/intro.md"
  git -C "$repo" add .sage/work/sample-init/spec.md AGENTS.md docs/intro.md
  if ! git -C "$repo" commit -m "docs" >/dev/null 2>&1; then
    echo "  docs allowlist commit was blocked"
    return 1
  fi
  return 0
}

# ── 8. No initiative touched → ungated ──────────────────────────────
case_no_initiative_touched() {
  local repo
  repo="$(mktemp -d -t sage-pc-noinit.XXXXXX)"
  fresh_repo "$repo"
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/feature.py"
  git -C "$repo" add src/feature.py
  if ! git -C "$repo" commit -m "unrelated" >/dev/null 2>&1; then
    echo "  unrelated commit was blocked"
    return 1
  fi
  return 0
}

run_case "negative: missing verification blocks"     case_negative_missing_verification
run_case "positive: valid verification allows"       case_positive_valid_verification
run_case "spec-only commit allowed"                  case_spec_only_commit
run_case "mixed blocked when verification invalid"   case_mixed_blocked_when_invalid
run_case "mixed allowed when verification valid"     case_mixed_allowed_when_valid
run_case "lightweight scope ungated"                 case_lightweight_ungated
run_case "docs allowlist passes"                     case_docs_allowlist
run_case "no initiative touched ungated"             case_no_initiative_touched

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
