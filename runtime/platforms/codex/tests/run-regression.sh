#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TMP_PARENT="$REPO_ROOT/.tmp"
mkdir -p "$TMP_PARENT"
TMP_ROOT="$(mktemp -d "$TMP_PARENT/codex-adapter-regression.XXXXXX")"
PROJECT="$TMP_ROOT/project"
LOG_DIR="$TMP_ROOT/logs"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

step() {
  printf "\n== %s ==\n" "$1"
}

assert_file() {
  [ -f "$1" ] || fail "Expected file: $1"
}

assert_dir() {
  [ -d "$1" ] || fail "Expected directory: $1"
}

assert_executable() {
  [ -x "$1" ] || fail "Expected executable file: $1"
}

assert_contains() {
  local file="$1"
  local text="$2"
  rg -Fq -- "$text" "$file" || fail "Expected '$text' in $file"
}

assert_same_file() {
  cmp -s "$1" "$2" || fail "Expected files to match: $1 == $2"
}

run_in_project() {
  local log_name="$1"
  shift
  (
    cd "$PROJECT"
    "$@"
  ) >"$LOG_DIR/$log_name" 2>&1 || {
    cat "$LOG_DIR/$log_name" >&2
    fail "Command failed: $*"
  }
}

mkdir -p "$PROJECT/src" "$PROJECT/.claude" "$LOG_DIR"

cat >"$PROJECT/package.json" <<'JSON'
{
  "name": "codex-adapter-regression",
  "private": true,
  "version": "0.0.0"
}
JSON

cat >"$PROJECT/src/index.js" <<'JS'
export function add(a, b) {
  return a + b;
}
JS

step "sage init --platform codex"
run_in_project init.log "$REPO_ROOT/bin/sage" init --platform codex --preset base

assert_dir "$PROJECT/.sage"
assert_file "$PROJECT/AGENTS.md"
assert_dir "$PROJECT/.agents/skills"
assert_dir "$PROJECT/.codex"
assert_file "$PROJECT/.codex/config.toml"
assert_dir "$PROJECT/sage"
assert_file "$PROJECT/sage/.sage-framework-source"
assert_executable "$PROJECT/sage/bin/sage"
grep -Fxq "$REPO_ROOT" "$PROJECT/sage/.sage-framework-source" || fail "Expected framework marker to point at repo root"

step "prepare merge fixture"
cat >"$PROJECT/.claude/mcp.json" <<'JSON'
{
  "mcpServers": {
    "legacy-local": {
      "command": "node",
      "args": ["-e", "process.exit(0)"]
    }
  }
}
JSON

cat >"$PROJECT/.codex/config.toml.tmp" <<'TOML'
model = "gpt-5.4"
project_doc_fallback_filenames = ["AGENTS.md", "CLAUDE.md"]

[features]
codex_hooks = true

[mcp_servers.native_keep]
command = "native-test"
args = ["--keep"]

TOML
cat "$PROJECT/.codex/config.toml" >>"$PROJECT/.codex/config.toml.tmp"
mv "$PROJECT/.codex/config.toml.tmp" "$PROJECT/.codex/config.toml"

assert_file "$PROJECT/.agents/skills/api/SKILL.md"
printf "\nMUTATED BY REGRESSION TEST\n" >>"$PROJECT/.agents/skills/api/SKILL.md"

step "project-local sage update"
run_in_project update.log ./sage/bin/sage update

assert_dir "$PROJECT/sage"
assert_executable "$PROJECT/sage/bin/sage"
assert_contains "$PROJECT/.codex/config.toml" 'model = "gpt-5.4"'
assert_contains "$PROJECT/.codex/config.toml" 'project_doc_fallback_filenames = ["AGENTS.md", "CLAUDE.md"]'
assert_contains "$PROJECT/.codex/config.toml" '[features]'
assert_contains "$PROJECT/.codex/config.toml" 'codex_hooks = true'
assert_contains "$PROJECT/.codex/config.toml" '[mcp_servers.native_keep]'
assert_contains "$PROJECT/.codex/config.toml" '# >>> SAGE MANAGED BLOCK START'
assert_contains "$PROJECT/.codex/config.toml" '[mcp_servers.legacy-local]'
assert_same_file "$PROJECT/.agents/skills/api/SKILL.md" "$PROJECT/sage/skills/api/SKILL.md"

step "summary"
echo "PASS: Codex adapter regression checks"
echo "  Project fixture: $PROJECT"
echo "  Logs: $LOG_DIR"
