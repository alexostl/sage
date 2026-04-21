#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMP_PARENT="$REPO_ROOT/.tmp"
mkdir -p "$TMP_PARENT"
TMP_ROOT="$(mktemp -d "$TMP_PARENT/codex-mcp-regression.XXXXXX")"
PROJECT="$TMP_ROOT/project"
LOG_DIR="$TMP_ROOT/logs"
SERVER_SCRIPT="$SCRIPT_DIR/dummy-server.mjs"

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

assert_contains() {
  local file="$1"
  local text="$2"
  rg -Fq -- "$text" "$file" || fail "Expected '$text' in $file"
}

assert_json_check() {
  local file="$1"
  local expr="$2"
  python3 - "$file" "$expr" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expr = sys.argv[2]
data = json.loads(path.read_text())
if not eval(expr, {"__builtins__": {"len": len}}, {"data": data}):
    raise SystemExit(f"JSON assertion failed: {expr}")
PY
}

mkdir -p "$PROJECT/.codex" "$LOG_DIR"

cat >"$PROJECT/.codex/config.toml" <<TOML
model = "gpt-5.4"

[mcp_servers.dummy-local]
command = "node"
args = ["$SERVER_SCRIPT"]

[mcp_servers.broken-local]
command = "nonexistent-mcp-binary"
args = []
TOML

step "run-client list-tools reports partial failure"
set +e
(
  cd "$PROJECT"
  bash "$REPO_ROOT/runtime/mcp/run-client.sh" list-tools
) >"$LOG_DIR/list-tools.stdout" 2>"$LOG_DIR/list-tools.stderr"
LIST_STATUS=$?
set -e
[ "$LIST_STATUS" -ne 0 ] || fail "Expected non-zero exit when one MCP server is broken"

assert_json_check "$LOG_DIR/list-tools.stdout" 'data["_meta"]["hasFailures"] is True'
assert_json_check "$LOG_DIR/list-tools.stdout" 'data["_meta"]["servers"]["dummy-local"]["status"] == "ok"'
assert_json_check "$LOG_DIR/list-tools.stdout" 'data["_meta"]["servers"]["broken-local"]["status"] == "error"'
assert_json_check "$LOG_DIR/list-tools.stdout" 'len(data["dummy-local"]) == 2'

step "run-client call-tool succeeds for healthy server"
(
  cd "$PROJECT"
  bash "$REPO_ROOT/runtime/mcp/run-client.sh" call-tool dummy-local echo --params '{"message":"smoke"}'
) >"$LOG_DIR/call-tool.stdout" 2>"$LOG_DIR/call-tool.stderr" || {
  cat "$LOG_DIR/call-tool.stderr" >&2
  fail "Expected dummy-local echo tool to succeed"
}

assert_contains "$LOG_DIR/call-tool.stdout" 'echo:smoke'

step "discover.sh preserves healthy tools and records failures"
(
  cd "$PROJECT"
  bash "$REPO_ROOT/runtime/mcp/discover.sh" .
) >"$LOG_DIR/discover.stdout" 2>"$LOG_DIR/discover.stderr" || {
  cat "$LOG_DIR/discover.stderr" >&2
  fail "Expected discover.sh to complete with partial results"
}

assert_contains "$LOG_DIR/discover.stdout" 'dummy-local: ✅ 2 tools'
assert_contains "$LOG_DIR/discover.stdout" 'broken-local: ❌ failed'
assert_file "$PROJECT/.sage/mcp-manifest.json"
assert_file "$PROJECT/.sage/mcp-snippet.md"
assert_json_check "$PROJECT/.sage/mcp-manifest.json" 'len(data["servers"]["dummy-local"]) == 2'
assert_json_check "$PROJECT/.sage/mcp-manifest.json" 'data["failures"]["broken-local"]["status"] == "error"'
assert_contains "$PROJECT/.sage/mcp-snippet.md" 'dummy-local: echo, repo_brief'
assert_contains "$PROJECT/.sage/mcp-snippet.md" 'broken-local: unavailable'

step "summary"
echo "PASS: MCP regression checks"
echo "  Project fixture: $PROJECT"
echo "  Logs: $LOG_DIR"
