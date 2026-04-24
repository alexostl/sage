#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TMP_PARENT="$REPO_ROOT/.tmp"
mkdir -p "$TMP_PARENT"
TMP_ROOT="$(mktemp -d "$TMP_PARENT/codex-adapter-regression.XXXXXX")"
PROJECT="$TMP_ROOT/project"
PROJECT_PREFIX_TRUE="$TMP_ROOT/project-prefix-true"
PROJECT_PREFIX_ABSENT="$TMP_ROOT/project-prefix-absent"
PROJECT_TOGGLE="$TMP_ROOT/project-toggle"
PROJECT_TOGGLE_PREFIX="$TMP_ROOT/project-toggle-prefix"
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

assert_not_dir() {
  [ ! -d "$1" ] || fail "Did not expect directory: $1"
}

assert_executable() {
  [ -x "$1" ] || fail "Expected executable file: $1"
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "Expected '$text' in $file"
}

assert_not_contains() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    fail "Did not expect '$text' in $file"
  fi
}

assert_same_file() {
  cmp -s "$1" "$2" || fail "Expected files to match: $1 == $2"
}

run_in_dir() {
  local log_name="$1"
  local dir="$2"
  shift 2
  (
    cd "$dir"
    "$@"
  ) >"$LOG_DIR/$log_name" 2>&1 || {
    cat "$LOG_DIR/$log_name" >&2
    fail "Command failed: $*"
  }
}

run_in_project() {
  local log_name="$1"
  shift
  run_in_dir "$log_name" "$PROJECT" "$@"
}

create_project_fixture() {
  local dir="$1"
  mkdir -p "$dir/src" "$dir/.claude"

  cat >"$dir/package.json" <<'JSON'
{
  "name": "codex-adapter-regression",
  "private": true,
  "version": "0.0.0"
}
JSON

  cat >"$dir/src/index.js" <<'JS'
export function add(a, b) {
  return a + b;
}
JS
}

mkdir -p "$LOG_DIR"
create_project_fixture "$PROJECT"
create_project_fixture "$PROJECT_PREFIX_TRUE"
create_project_fixture "$PROJECT_PREFIX_ABSENT"
create_project_fixture "$PROJECT_TOGGLE"
create_project_fixture "$PROJECT_TOGGLE_PREFIX"

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
assert_file "$PROJECT/.agents/skills/build/SKILL.md"
assert_contains "$PROJECT/.agents/skills/build/SKILL.md" 'name: build'
assert_file "$PROJECT/.agents/skills/api/SKILL.md"
assert_contains "$PROJECT/.agents/skills/api/SKILL.md" 'name: "api"'
assert_contains "$PROJECT/AGENTS.md" '$build'
assert_contains "$PROJECT/AGENTS.md" '$fix'
assert_contains "$PROJECT/AGENTS.md" '$sage'
assert_not_contains "$PROJECT/AGENTS.md" '$sage:build'

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

step "prefixed init"
run_in_dir prefix-true-init.log "$PROJECT_PREFIX_TRUE" "$REPO_ROOT/bin/sage" init --platform codex --preset base --prefix

assert_file "$PROJECT_PREFIX_TRUE/.agents/skills/sage:build/SKILL.md"
assert_contains "$PROJECT_PREFIX_TRUE/.agents/skills/sage:build/SKILL.md" 'name: sage:build'
assert_file "$PROJECT_PREFIX_TRUE/.agents/skills/sage:review/SKILL.md"
assert_contains "$PROJECT_PREFIX_TRUE/.agents/skills/sage:review/SKILL.md" 'name: sage:review'
assert_file "$PROJECT_PREFIX_TRUE/.agents/skills/sage:api/SKILL.md"
assert_contains "$PROJECT_PREFIX_TRUE/.agents/skills/sage:api/SKILL.md" 'name: sage:api'
assert_file "$PROJECT_PREFIX_TRUE/.agents/skills/sage-navigator/SKILL.md"
assert_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '$sage:build'
assert_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '$sage:fix'
assert_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '$sage:review'
assert_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '$sage'
assert_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '/review'
assert_not_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '$sage:sage'
assert_not_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" '/sage:review'
assert_not_contains "$PROJECT_PREFIX_TRUE/AGENTS.md" 'understand/sage:research'
assert_contains "$PROJECT_PREFIX_TRUE/.agents/skills/sage-navigator/SKILL.md" '/sage:build'
assert_contains "$PROJECT_PREFIX_TRUE/.agents/skills/sage:fix/SKILL.md" 'type /sage:build or /sage:architect instead'

step "command_prefix absent update"
run_in_dir prefix-absent-init.log "$PROJECT_PREFIX_ABSENT" "$REPO_ROOT/bin/sage" init --platform codex --preset base
sed -i.bak '/^command_prefix:/d' "$PROJECT_PREFIX_ABSENT/.sage/config.yaml"
rm -f "$PROJECT_PREFIX_ABSENT/.sage/config.yaml.bak"
run_in_dir prefix-absent-update.log "$PROJECT_PREFIX_ABSENT" ./sage/bin/sage update --platform codex

assert_file "$PROJECT_PREFIX_ABSENT/.agents/skills/build/SKILL.md"
assert_contains "$PROJECT_PREFIX_ABSENT/.agents/skills/build/SKILL.md" 'name: build'
assert_file "$PROJECT_PREFIX_ABSENT/.agents/skills/api/SKILL.md"
assert_contains "$PROJECT_PREFIX_ABSENT/.agents/skills/api/SKILL.md" 'name: "api"'
assert_contains "$PROJECT_PREFIX_ABSENT/AGENTS.md" '$build'
assert_contains "$PROJECT_PREFIX_ABSENT/AGENTS.md" '$fix'
assert_contains "$PROJECT_PREFIX_ABSENT/AGENTS.md" '$sage'
assert_not_contains "$PROJECT_PREFIX_ABSENT/AGENTS.md" '$sage:build'

step "toggle prefix off -> on in same project"
run_in_dir toggle-init.log "$PROJECT_TOGGLE" "$REPO_ROOT/bin/sage" init --platform codex --preset base
sed -i.bak 's/^command_prefix: false$/command_prefix: true/' "$PROJECT_TOGGLE/.sage/config.yaml"
rm -f "$PROJECT_TOGGLE/.sage/config.yaml.bak"
run_in_dir toggle-prefix-on.log "$PROJECT_TOGGLE" ./sage/bin/sage update --platform codex

assert_file "$PROJECT_TOGGLE/.agents/skills/sage:build/SKILL.md"
assert_file "$PROJECT_TOGGLE/.agents/skills/sage:api/SKILL.md"
assert_not_dir "$PROJECT_TOGGLE/.agents/skills/build"
assert_not_dir "$PROJECT_TOGGLE/.agents/skills/api"
assert_not_dir "$PROJECT_TOGGLE/.agents/skills/review"
assert_not_dir "$PROJECT_TOGGLE/.agents/skills/status"

step "toggle prefix on -> off in same project"
run_in_dir toggle-prefix-init.log "$PROJECT_TOGGLE_PREFIX" "$REPO_ROOT/bin/sage" init --platform codex --preset base --prefix
sed -i.bak 's/^command_prefix: true$/command_prefix: false/' "$PROJECT_TOGGLE_PREFIX/.sage/config.yaml"
rm -f "$PROJECT_TOGGLE_PREFIX/.sage/config.yaml.bak"
run_in_dir toggle-prefix-off.log "$PROJECT_TOGGLE_PREFIX" ./sage/bin/sage update --platform codex

assert_file "$PROJECT_TOGGLE_PREFIX/.agents/skills/build/SKILL.md"
assert_file "$PROJECT_TOGGLE_PREFIX/.agents/skills/api/SKILL.md"
assert_not_dir "$PROJECT_TOGGLE_PREFIX/.agents/skills/sage:build"
assert_not_dir "$PROJECT_TOGGLE_PREFIX/.agents/skills/sage:api"
assert_not_dir "$PROJECT_TOGGLE_PREFIX/.agents/skills/sage:review"
assert_not_dir "$PROJECT_TOGGLE_PREFIX/.agents/skills/sage:status"

step "summary"
echo "PASS: Codex adapter regression checks"
echo "  Project fixture: $PROJECT"
echo "  Prefix fixture: $PROJECT_PREFIX_TRUE"
echo "  Absent fixture: $PROJECT_PREFIX_ABSENT"
echo "  Toggle fixture: $PROJECT_TOGGLE"
echo "  Toggle prefix fixture: $PROJECT_TOGGLE_PREFIX"
echo "  Logs: $LOG_DIR"
