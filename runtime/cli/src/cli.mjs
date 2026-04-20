#!/usr/bin/env node

/**
 * Sage CLI bridge.
 *
 * The shell CLI in `bin/sage` is the canonical installer/update path. This
 * wrapper keeps the npm entrypoint honest by forwarding supported commands to
 * the same implementation instead of maintaining a second platform installer.
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync, readdirSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '..', '..', '..');
const SHELL_CLI = join(REPO_ROOT, 'bin', 'sage');

const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
};

function banner() {
  console.log(`
${c.bold}${c.cyan}  ╔═══════════════════════════════════════════════════╗
  ║                                                   ║
  ║   Sage CLI                                        ║
  ║   npm bridge for the canonical shell installer    ║
  ║                                                   ║
  ╚═══════════════════════════════════════════════════╝${c.reset}
`);
}

function parseArgs(argv) {
  const command = argv[0] ?? 'help';
  const passthrough = argv.slice(1);
  return { command, passthrough };
}

function runShellCli(command, passthrough) {
  if (!existsSync(SHELL_CLI)) {
    console.error(`${c.red}Error: missing shell CLI at ${SHELL_CLI}${c.reset}`);
    process.exit(1);
  }

  const result = spawnSync('bash', [SHELL_CLI, command, ...passthrough], {
    stdio: 'inherit',
    cwd: process.cwd(),
    env: process.env,
  });

  if (result.error) {
    console.error(`${c.red}Error: ${result.error.message}${c.reset}`);
    process.exit(1);
  }

  process.exit(result.status ?? 1);
}

function readValue(text, pattern, fallback = 'unknown') {
  return text.match(pattern)?.[1] ?? fallback;
}

function detectPlatformFromFilesystem(projectDir) {
  const detected = [];
  if (existsSync(join(projectDir, 'CLAUDE.md')) || existsSync(join(projectDir, '.claude'))) {
    detected.push('claude-code');
  }
  if (existsSync(join(projectDir, 'GEMINI.md')) || existsSync(join(projectDir, '.agent'))) {
    detected.push('antigravity');
  }
  if (existsSync(join(projectDir, 'AGENTS.md')) || existsSync(join(projectDir, '.codex')) || existsSync(join(projectDir, '.agents'))) {
    detected.push('codex');
  }
  return detected.length > 0 ? detected.join(',') : 'unknown';
}

function countSkillFiles(dir) {
  try {
    return readdirSync(dir, { recursive: true })
      .filter((entry) => entry.toString().endsWith('SKILL.md')).length;
  } catch {
    return 0;
  }
}

function commandStatus() {
  const sageDir = join(process.cwd(), '.sage');
  if (!existsSync(sageDir)) {
    console.log(`${c.yellow}Sage not initialized in this directory.${c.reset}`);
    console.log(`Run: ${c.cyan}sage init${c.reset}`);
    process.exit(1);
  }

  console.log(`${c.bold}Sage Status${c.reset}\n`);

  const configPath = join(sageDir, 'config.yaml');
  if (existsSync(configPath)) {
    const config = readFileSync(configPath, 'utf-8');
    const platform = readValue(config, /^platform:\s*"?([^\n"]+)"?$/m, detectPlatformFromFilesystem(process.cwd()));
    const constitution =
      readValue(config, /^constitution:\s*"?([^\n"]+)"?$/m, readValue(config, /^extends:\s*(\S+)/m, 'base'));
    console.log(`  Platform:      ${platform}`);
    console.log(`  Constitution:  ${constitution}`);
  }

  const progressPath = join(sageDir, 'progress.md');
  if (existsSync(progressPath)) {
    const progress = readFileSync(progressPath, 'utf-8');
    console.log(`  Mode:          ${readValue(progress, /^Mode:\s*(.+)$/m, 'none')}`);
    console.log(`  Feature:       ${readValue(progress, /^Feature:\s*(.+)$/m, 'none')}`);
    const next = readValue(progress, /^Next action:\s*(.+)$/m, '');
    if (next) {
      console.log(`  Next action:   ${next}`);
    }
  }

  const skillsDir = join(sageDir, 'skills');
  if (existsSync(skillsDir)) {
    console.log(`  Skills:        ${countSkillFiles(skillsDir)}`);
  }

  console.log('');
}

function commandHelp() {
  banner();
  console.log(`${c.bold}Usage:${c.reset}

  ${c.cyan}npx sage-kit init${c.reset}                         Initialize current directory
  ${c.cyan}npx sage-kit init --platform codex${c.reset}       Initialize with the Codex adapter
  ${c.cyan}npx sage-kit new my-app --platform codex${c.reset} Create a new Sage project
  ${c.cyan}npx sage-kit update${c.reset}                       Regenerate platform files
  ${c.cyan}npx sage-kit status${c.reset}                       Show project Sage state
  ${c.cyan}npx sage-kit help${c.reset}                         This help

${c.bold}Notes:${c.reset}

  This npm entrypoint forwards install/update commands to ${c.cyan}bin/sage${c.reset},
  which is the canonical multi-platform implementation for Claude Code,
  Antigravity, and Codex.

${c.bold}Examples:${c.reset}

  npx sage-kit init --platform codex --preset startup
  npx sage-kit init --platform claude-code,codex --prefix
  npx sage-kit update
`);
}

const { command, passthrough } = parseArgs(process.argv.slice(2));

if (command === 'status') {
  commandStatus();
} else if (command === 'help' || command === '--help' || command === '-h') {
  commandHelp();
} else if (
  ['init', 'new', 'update', 'upgrade', 'learn', 'setup', 'find', 'add', 'remove', 'skills'].includes(command)
) {
  runShellCli(command, passthrough);
} else {
  console.log(`${c.red}Unknown command: ${command}${c.reset}`);
  commandHelp();
  process.exit(1);
}
