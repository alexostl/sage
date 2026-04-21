import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";

const server = new McpServer({ name: "dummy-local", version: "0.0.1" });

server.registerTool(
  "echo",
  {
    description: "Echo a message back to the caller.",
    inputSchema: {
      message: z.string().describe("Message to echo"),
    },
  },
  async ({ message }) => ({
    content: [{ type: "text", text: `echo:${message}` }],
  })
);

server.registerTool(
  "repo_brief",
  {
    description: "Return a tiny repo brief for smoke testing.",
    inputSchema: {},
  },
  async () => ({
    content: [{ type: "text", text: "Repo brief: dummy repo with Sage E2E fixture." }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
