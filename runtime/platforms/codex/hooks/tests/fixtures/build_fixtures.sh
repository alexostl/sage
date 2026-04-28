#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Sage hook test fixtures builder
#
# Idempotent. Run as:
#   bash runtime/platforms/codex/hooks/tests/fixtures/build_fixtures.sh
#
# Produces every fixture tree under
#   runtime/platforms/codex/hooks/tests/tmp/
# which is gitignored. Re-run is a no-op (rm -rf + rebuild).
#
# Consumers (see fixtures/README.md):
#   T2 verification_check tests       — verifications/*
#   T4 active_state tests             — sage_*
#   T4 pre-prompt sticky test         — sage_*
#   T5 sage-close tests               — git_repo + sage_verification_*
#   T6 pre-commit hook tests          — git_repo + sage_*
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$(cd "$HERE/.." && pwd)"
TMP="$TESTS_DIR/tmp"

# Clean & recreate
rm -rf "$TMP"
mkdir -p "$TMP"

# ───────────────────────────────────────────────────────────────
# Helper: write a file with deterministic content
# ───────────────────────────────────────────────────────────────
write() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# ───────────────────────────────────────────────────────────────
# Fixture 1: sage_no_active
#   No work directory at all. Tests "no active initiative" path.
# ───────────────────────────────────────────────────────────────
mkdir -p "$TMP/sage_no_active/.sage/work"

# ───────────────────────────────────────────────────────────────
# Fixture 2: sage_brief_only
#   Brief exists, status: in-progress. Phase precedence test.
# ───────────────────────────────────────────────────────────────
write "$TMP/sage_brief_only/.sage/work/brief-init/brief.md" \
  '---' \
  'cycle_id: "brief-init"' \
  'type: brief' \
  'status: in-progress' \
  'scope: standard' \
  'updated: 2026-04-24' \
  '---' \
  '' \
  '# Brief: brief-init' \
  '' \
  'Smallest viable brief for testing.'

# ───────────────────────────────────────────────────────────────
# Fixture 3: sage_spec_only
#   Spec exists, brief absent, status: in-progress.
# ───────────────────────────────────────────────────────────────
write "$TMP/sage_spec_only/.sage/work/spec-init/spec.md" \
  '---' \
  'cycle_id: "spec-init"' \
  'type: spec' \
  'status: in-progress' \
  'scope: standard' \
  'updated: 2026-04-24' \
  '---' \
  '' \
  '# Spec: spec-init'

# ───────────────────────────────────────────────────────────────
# Fixture 4: sage_plan_only
#   Spec completed + plan in-progress. Phase precedence: plan wins.
# ───────────────────────────────────────────────────────────────
write "$TMP/sage_plan_only/.sage/work/plan-init/spec.md" \
  '---' \
  'cycle_id: "plan-init"' \
  'type: spec' \
  'status: completed' \
  'scope: standard' \
  'updated: 2026-04-23' \
  '---' \
  '' \
  '# Spec: plan-init'

write "$TMP/sage_plan_only/.sage/work/plan-init/plan.md" \
  '---' \
  'cycle_id: "plan-init"' \
  'type: plan' \
  'status: in-progress' \
  'scope: standard' \
  'updated: 2026-04-24' \
  '---' \
  '' \
  '# Plan: plan-init'

# ───────────────────────────────────────────────────────────────
# Fixture 5: sage_verification_pending
#   Full set including verification.md with closed: false.
#   "Ready to close" sticky line should fire here.
# ───────────────────────────────────────────────────────────────
write "$TMP/sage_verification_pending/.sage/work/verify-init/spec.md" \
  '---' \
  'cycle_id: "verify-init"' \
  'type: spec' \
  'status: completed' \
  'scope: standard' \
  'updated: 2026-04-23' \
  '---' \
  '' \
  '# Spec'

write "$TMP/sage_verification_pending/.sage/work/verify-init/plan.md" \
  '---' \
  'cycle_id: "verify-init"' \
  'type: plan' \
  'status: completed' \
  'scope: standard' \
  'updated: 2026-04-23' \
  '---' \
  '' \
  '# Plan'

# Valid verification.md (matches T3 template shape)
write "$TMP/sage_verification_pending/.sage/work/verify-init/verification.md" \
  '---' \
  'cycle_id: "verify-init"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: false' \
  '---' \
  '' \
  '# Verification: verify-init' \
  '' \
  '## Pre-fix reproducer' \
  '' \
  'Pre-existing failing condition described here.' \
  '' \
  '## Implementation summary' \
  '' \
  'What changed.' \
  '' \
  '## Test command + pasted output' \
  '' \
  '```' \
  'python3 -m unittest discover' \
  '..............' \
  'Ran 14 tests in 0.123s' \
  '' \
  'OK' \
  '```' \
  '' \
  '## Close-out checklist' \
  '' \
  '- [x] Tests pass' \
  '- [x] Decisions recorded'

# ───────────────────────────────────────────────────────────────
# Fixture 6: sage_multi_active
#   Three active initiatives — exercises the tie-breaker.
#   Most-recently-modified manifest wins; here init-c.
# ───────────────────────────────────────────────────────────────
for name in init-a init-b init-c; do
  write "$TMP/sage_multi_active/.sage/work/$name/spec.md" \
    '---' \
    "cycle_id: \"$name\"" \
    'type: spec' \
    'status: in-progress' \
    'scope: standard' \
    "updated: 2026-04-24" \
    '---' \
    '' \
    "# Spec: $name"
  write "$TMP/sage_multi_active/.sage/work/$name/manifest.md" \
    '---' \
    "cycle_id: \"$name\"" \
    'type: manifest' \
    'status: in-progress' \
    "updated: 2026-04-24" \
    '---' \
    '' \
    "# Manifest: $name"
done
# Bump init-c manifest mtime so the tie-breaker has a winner.
sleep 1
touch "$TMP/sage_multi_active/.sage/work/init-c/manifest.md"

# ───────────────────────────────────────────────────────────────
# Fixture 7: verifications/  — for verification_check.py tests
# ───────────────────────────────────────────────────────────────
VERIF="$TMP/verifications"
mkdir -p "$VERIF"

# Valid (passes validator)
write "$VERIF/valid.md" \
  '---' \
  'cycle_id: "x"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: false' \
  '---' \
  '' \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  '' \
  'A. Repro steps.' \
  '' \
  '## Implementation summary' \
  '' \
  'B. Summary.' \
  '' \
  '## Test command + pasted output' \
  '' \
  '```' \
  'python3 -m unittest discover' \
  'Ran 1 test in 0.001s' \
  'OK' \
  '```' \
  '' \
  '## Close-out checklist' \
  '' \
  '- [x] All checks'

# Missing each required heading
for missing in "Pre-fix reproducer" "Implementation summary" "Test command + pasted output" "Close-out checklist"; do
  slug="$(printf '%s' "$missing" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd 'a-z_+')"
  # Build a verification with one heading replaced by a sentinel
  python3 - "$VERIF/missing_${slug}.md" "$missing" <<'PY'
import sys, pathlib
out = pathlib.Path(sys.argv[1])
omit = sys.argv[2]
sections = [
    ("Pre-fix reproducer", "Repro."),
    ("Implementation summary", "Summary."),
    ("Test command + pasted output", "```\npython3 -m unittest discover\nRan 1 test in 0.001s\nOK\n```"),
    ("Close-out checklist", "- [x] done"),
]
parts = ['---', 'cycle_id: "x"', 'verified_at: 2026-04-24', 'scope: standard',
         'closed: false', '---', '', '# Verification', '']
for h, body in sections:
    if h == omit:
        continue
    parts.append('## ' + h)
    parts.append('')
    parts.append(body)
    parts.append('')
out.write_text("\n".join(parts) + "\n")
PY
done

# No frontmatter at all
write "$VERIF/no_frontmatter.md" \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  'A.' \
  '' \
  '## Implementation summary' \
  'B.' \
  '' \
  '## Test command + pasted output' \
  '```' \
  'cmd' \
  'output line' \
  '```' \
  '' \
  '## Close-out checklist' \
  '- [x] x'

# Empty fenced block (only command line, no output beyond it)
write "$VERIF/empty_test_block.md" \
  '---' \
  'cycle_id: "x"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: false' \
  '---' \
  '' \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  'A.' \
  '' \
  '## Implementation summary' \
  'B.' \
  '' \
  '## Test command + pasted output' \
  '```' \
  'python3 -m unittest discover' \
  '```' \
  '' \
  '## Close-out checklist' \
  '- [x] x'

# No fenced block at all in test section
write "$VERIF/no_fenced_block.md" \
  '---' \
  'cycle_id: "x"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: false' \
  '---' \
  '' \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  'A.' \
  '' \
  '## Implementation summary' \
  'B.' \
  '' \
  '## Test command + pasted output' \
  '' \
  'python3 -m unittest discover (no fence)' \
  'Ran 1 test in 0.001s' \
  'OK' \
  '' \
  '## Close-out checklist' \
  '- [x] x'

# Wrong order (Test before Implementation)
write "$VERIF/wrong_order.md" \
  '---' \
  'cycle_id: "x"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: false' \
  '---' \
  '' \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  'A.' \
  '' \
  '## Test command + pasted output' \
  '```' \
  'cmd' \
  'output' \
  '```' \
  '' \
  '## Implementation summary' \
  'B.' \
  '' \
  '## Close-out checklist' \
  '- [x] x'

# Closed: true variant (used by sage-close idempotence tests)
write "$VERIF/valid_closed.md" \
  '---' \
  'cycle_id: "x"' \
  'verified_at: 2026-04-24' \
  'scope: standard' \
  'closed: true' \
  '---' \
  '' \
  '# Verification' \
  '' \
  '## Pre-fix reproducer' \
  'A.' \
  '' \
  '## Implementation summary' \
  'B.' \
  '' \
  '## Test command + pasted output' \
  '```' \
  'cmd' \
  'output' \
  '```' \
  '' \
  '## Close-out checklist' \
  '- [x] x'

# ───────────────────────────────────────────────────────────────
# Fixture 8: git_repo  — for L4/L5 tests
#   Branches: self-host/main (inner), codex-port (integration)
#   Initial commit on both.
# ───────────────────────────────────────────────────────────────
GIT="$TMP/git_repo"
mkdir -p "$GIT"
(
  cd "$GIT"
  git init --quiet --initial-branch=self-host/main
  git config user.email "fixture@sage.local"
  git config user.name "Fixture User"
  git config commit.gpgsign false
  echo "fixture" > README.md
  mkdir -p .sage/work/sample-init .sage/docs
  cat > .sage/decisions.md <<'EOF'
# Decisions

EOF
  cat > .sage/work/sample-init/spec.md <<'EOF'
---
cycle_id: "sample-init"
type: spec
status: completed
scope: standard
---

# Spec
EOF
  cat > .sage/work/sample-init/plan.md <<'EOF'
---
cycle_id: "sample-init"
type: plan
status: completed
scope: standard
---

# Plan
EOF
  cp "$VERIF/valid.md" .sage/work/sample-init/verification.md
  # Replace cycle_id in copied file so it matches the slug
  python3 - <<'PY'
import pathlib, re
p = pathlib.Path(".sage/work/sample-init/verification.md")
text = p.read_text()
text = re.sub(r'cycle_id:\s*"[^"]*"', 'cycle_id: "sample-init"', text)
p.write_text(text)
PY
  git add -A
  git commit --quiet -m "fixture: initial state"
  git branch codex-port
)

# ───────────────────────────────────────────────────────────────
# Fixture 9: sage_lightweight  — for L5 false-positive ceiling
#   Standard scope NOT declared → hook must not gate.
# ───────────────────────────────────────────────────────────────
write "$TMP/sage_lightweight/.sage/work/light-init/spec.md" \
  '---' \
  'cycle_id: "light-init"' \
  'type: spec' \
  'status: in-progress' \
  'scope: lightweight' \
  '---' \
  '' \
  '# Spec'

echo "Sage: fixtures rebuilt under $TMP"
ls -1 "$TMP" | sed 's/^/  - /'
