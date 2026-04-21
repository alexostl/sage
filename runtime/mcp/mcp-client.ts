#!/usr/bin/env tsx
/**
 * Sage MCP Client — Layer 2 Proxy
 *
 * Connects to MCP servers and calls tools without polluting the
 * main agent's context window. Returns extracted results only.
 *
 * Usage:
 *   bash runtime/mcp/run-client.sh list-tools [--server <name>]
 *   bash runtime/mcp/run-client.sh call-tool <server> <tool> [--params '{"key":"value"}']
 *   bash runtime/mcp/run-client.sh call-tool <server> <tool> --params-arg key1=value1 key2=value2
 *
 * Configuration:
 *   Reads from .codex/config.toml or legacy Sage MCP JSON config
 *   Install dependencies once with runtime/mcp/run-client.sh on a clean checkout
 *
 * Output:
 *   JSON to stdout. Errors to stderr. Exit code 0 on success, 1 on failure.
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { existsSync } from "fs";
import { resolve } from "path";
import { execFileSync } from "child_process";
import { fileURLToPath } from "url";

// ── Types ──
interface MCPServerConfig {
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  env_vars?: string[];
  cwd?: string;
  url?: string;
  http_headers?: Record<string, string>;
  env_http_headers?: Record<string, string>;
  bearer_token_env_var?: string;
  enabled?: boolean;
}

interface MCPConfig {
  mcpServers: Record<string, MCPServerConfig>;
}

interface ToolInfo {
  name: string;
  description: string;
  inputSchema?: Record<string, unknown>;
}

interface CallResult {
  server: string;
  tool: string;
  success: boolean;
  content: string;
  contentType: "text" | "json" | "error";
}

interface MCPConnection {
  client: Client;
  transport: {
    terminateSession?: () => Promise<void>;
  };
}

// ── Config Loading ──
function findConfig(startDir: string = process.cwd()): MCPConfig | null {
  const loaderPath = fileURLToPath(new URL("./load_config.py", import.meta.url));
  if (!existsSync(loaderPath)) return null;

  try {
    const output = execFileSync("python3", [loaderPath, resolve(startDir)], { encoding: "utf-8" });
    const parsed = JSON.parse(output) as { mcpServers?: Record<string, MCPServerConfig> };
    if (parsed.mcpServers) {
      return { mcpServers: parsed.mcpServers };
    }
  } catch (e) {
    console.error(`Error reading MCP config: ${(e as Error).message}`);
  }
  return null;
}

// ── Server Connection ──
function buildEnv(config: MCPServerConfig): Record<string, string> {
  const env = { ...process.env, ...(config.env || {}) } as Record<string, string>;

  for (const variable of config.env_vars || []) {
    const value = process.env[variable];
    if (typeof value === "string") {
      env[variable] = value;
    }
  }

  return env;
}

function buildHttpHeaders(config: MCPServerConfig): Record<string, string> {
  const headers: Record<string, string> = { ...(config.http_headers || {}) };

  for (const [headerName, envVarName] of Object.entries(config.env_http_headers || {})) {
    const value = process.env[envVarName];
    if (typeof value === "string" && value.length > 0) {
      headers[headerName] = value;
    }
  }

  if (config.bearer_token_env_var) {
    const token = process.env[config.bearer_token_env_var];
    if (typeof token === "string" && token.length > 0) {
      headers.Authorization = `Bearer ${token}`;
    }
  }

  return headers;
}

async function connectToServer(
  name: string,
  config: MCPServerConfig,
  timeoutMs: number = 15000
): Promise<MCPConnection> {
  const client = new Client(
    { name: `sage-mcp-${name}`, version: "1.0.0" },
    { capabilities: {} }
  );

  let transport;
  if (config.url) {
    const headers = buildHttpHeaders(config);
    transport = new StreamableHTTPClientTransport(new URL(config.url), {
      requestInit: Object.keys(headers).length > 0 ? { headers } : undefined,
    });
  } else if (config.command) {
    transport = new StdioClientTransport({
      command: config.command,
      args: config.args || [],
      env: buildEnv(config),
      cwd: config.cwd,
    });
  } else {
    throw new Error(`MCP server '${name}' must define either url or command`);
  }

  // Connect with timeout
  const connectPromise = client.connect(transport);
  const timeoutPromise = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error(`Connection to ${name} timed out after ${timeoutMs}ms`)), timeoutMs)
  );

  await Promise.race([connectPromise, timeoutPromise]);
  return { client, transport };
}

async function closeConnection(connection: MCPConnection): Promise<void> {
  try {
    if (typeof connection.transport.terminateSession === "function") {
      await connection.transport.terminateSession();
    }
  } catch {
    // Best-effort only; closing the client is still required.
  }
  await connection.client.close();
}

// ── List Tools ──
async function listTools(
  config: MCPConfig,
  serverFilter?: string
): Promise<Record<string, ToolInfo[]>> {
  const results: Record<string, ToolInfo[]> = {};
  const servers = serverFilter
    ? { [serverFilter]: config.mcpServers[serverFilter] }
    : config.mcpServers;

  for (const [name, serverConfig] of Object.entries(servers)) {
    if (!serverConfig) {
      console.error(`Server '${name}' not found in config`);
      continue;
    }
    if (serverConfig.enabled === false) {
      results[name] = [];
      continue;
    }

    try {
      const connection = await connectToServer(name, serverConfig);
      const response = await connection.client.listTools();

      results[name] = (response.tools || []).map((t) => ({
        name: t.name,
        description: t.description || "",
        inputSchema: t.inputSchema as Record<string, unknown> | undefined,
      }));

      await closeConnection(connection);
    } catch (e) {
      console.error(`Failed to list tools from ${name}: ${(e as Error).message}`);
      results[name] = [];
    }
  }

  return results;
}

// ── Call Tool ──
async function callTool(
  config: MCPConfig,
  serverName: string,
  toolName: string,
  params: Record<string, unknown>
): Promise<CallResult> {
  const serverConfig = config.mcpServers[serverName];
  if (!serverConfig) {
    return {
      server: serverName,
      tool: toolName,
      success: false,
      content: `Server '${serverName}' not found in MCP configuration`,
      contentType: "error",
    };
  }
  if (serverConfig.enabled === false) {
    return {
      server: serverName,
      tool: toolName,
      success: false,
      content: `Server '${serverName}' is disabled in MCP configuration`,
      contentType: "error",
    };
  }

  try {
    const connection = await connectToServer(serverName, serverConfig);

    const response = await connection.client.callTool({
      name: toolName,
      arguments: params,
    });

    await closeConnection(connection);

    // Extract text content from response
    const contentParts = (response.content as Array<{ type: string; text?: string }>) || [];
    const textContent = contentParts
      .filter((c) => c.type === "text" && c.text)
      .map((c) => c.text!)
      .join("\n");

    // Try to detect if content is JSON
    let contentType: "text" | "json" = "text";
    if (textContent.startsWith("{") || textContent.startsWith("[")) {
      try {
        JSON.parse(textContent);
        contentType = "json";
      } catch {
        // Not JSON, keep as text
      }
    }

    return {
      server: serverName,
      tool: toolName,
      success: !response.isError,
      content: textContent,
      contentType,
    };
  } catch (e) {
    return {
      server: serverName,
      tool: toolName,
      success: false,
      content: (e as Error).message,
      contentType: "error",
    };
  }
}

// ── CLI ──
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === "--help" || command === "-h") {
    console.log(`Sage MCP Client — Layer 2 Proxy

Usage:
  bash runtime/mcp/run-client.sh list-tools [--server <name>]
  bash runtime/mcp/run-client.sh call-tool <server> <tool> [--params '{"key":"val"}']
  bash runtime/mcp/run-client.sh call-tool <server> <tool> --params-arg key=val key2=val2

Examples:
  bash runtime/mcp/run-client.sh list-tools
  bash runtime/mcp/run-client.sh list-tools --server context7
  bash runtime/mcp/run-client.sh call-tool context7 resolve-library-id --params '{"libraryName":"next.js"}'
  bash runtime/mcp/run-client.sh call-tool context7 query-docs --params-arg libraryId=/nextjs/nextjs topic=caching`);
    process.exit(0);
  }

  const config = findConfig();
  if (!config) {
    console.error("No MCP configuration found.");
    console.error("Expected: .codex/config.toml, .claude/mcp.json, or .sage/mcp.json");
    console.error("See: runtime/mcp/sage-mcp-config.example.json");
    process.exit(1);
  }

  if (command === "list-tools") {
    const serverIdx = args.indexOf("--server");
    const serverFilter = serverIdx >= 0 ? args[serverIdx + 1] : undefined;

    const tools = await listTools(config, serverFilter);
    console.log(JSON.stringify(tools, null, 2));
    process.exit(0);
  }

  if (command === "call-tool") {
    const serverName = args[1];
    const toolName = args[2];

    if (!serverName || !toolName) {
      console.error("Usage: call-tool <server> <tool> [--params '{...}']");
      process.exit(1);
    }

    // Parse params from either --params JSON or --params-arg key=value pairs
    let params: Record<string, unknown> = {};

    const paramsIdx = args.indexOf("--params");
    const paramsArgIdx = args.indexOf("--params-arg");

    if (paramsIdx >= 0 && args[paramsIdx + 1]) {
      try {
        params = JSON.parse(args[paramsIdx + 1]);
      } catch {
        console.error("Invalid JSON in --params");
        process.exit(1);
      }
    } else if (paramsArgIdx >= 0) {
      // Parse key=value pairs
      for (let i = paramsArgIdx + 1; i < args.length; i++) {
        if (args[i].startsWith("--")) break;
        const eq = args[i].indexOf("=");
        if (eq > 0) {
          params[args[i].slice(0, eq)] = args[i].slice(eq + 1);
        }
      }
    }

    const result = await callTool(config, serverName, toolName, params);

    if (result.success) {
      // Output extracted content directly — not wrapped in JSON
      // This is what the agent sees in its context
      console.log(result.content);
      process.exit(0);
    } else {
      console.error(`MCP call failed: ${result.content}`);
      process.exit(1);
    }
  }

  console.error(`Unknown command: ${command}`);
  process.exit(1);
}

main().catch((e) => {
  console.error(`Fatal: ${e.message}`);
  process.exit(1);
});
