#!/usr/bin/env node
/**
 * Minimal stdio client for the godot-mcp server.
 *
 * The MCP server is registered in .mcp.json and Claude Code picks it up at session
 * start. This script talks to the same server directly, which is useful for one-off
 * calls, for scripting, and inside a session that started before the server existed.
 *
 *   node tools/godot_mcp_call.mjs list_tools
 *   node tools/godot_mcp_call.mjs get_godot_version
 *   node tools/godot_mcp_call.mjs get_project_info '{"projectPath":"godot"}'
 *
 * run_project keeps its child process inside the server, so a one-shot call would
 * lose it as soon as this client exits. Use --seq to run several tools against one
 * server session, with `sleep:<ms>` steps in between:
 *
 *   node tools/godot_mcp_call.mjs --seq \
 *     'run_project {"projectPath":"godot"}' sleep:20000 get_debug_output stop_project
 */

import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sequenceMode = process.argv[2] === '--seq';
const steps = [];

if (sequenceMode) {
  for (const raw of process.argv.slice(3)) {
    if (raw.startsWith('sleep:')) {
      steps.push({ sleep: Number(raw.slice(6)) });
      continue;
    }
    const split = raw.indexOf(' ');
    const name = split === -1 ? raw : raw.slice(0, split);
    const argText = split === -1 ? '{}' : raw.slice(split + 1);
    steps.push({ name, args: JSON.parse(argText) });
  }
} else {
  const toolName = process.argv[2];
  if (!toolName) {
    console.error('usage: node tools/godot_mcp_call.mjs <tool> [jsonArgs]');
    console.error('       node tools/godot_mcp_call.mjs --seq \'<tool> <json>\' sleep:<ms> ...');
    process.exit(2);
  }
  try {
    steps.push({ name: toolName, args: JSON.parse(process.argv[3] ?? '{}') });
  } catch (err) {
    console.error(`invalid JSON arguments: ${err.message}`);
    process.exit(2);
  }
}

// Reuse the server definition Claude Code uses so there is one source of truth.
const mcpConfig = JSON.parse(readFileSync(resolve(repoRoot, '.mcp.json'), 'utf8'));
const serverConfig = mcpConfig.mcpServers?.godot;
if (!serverConfig) {
  console.error('no "godot" server in .mcp.json');
  process.exit(2);
}

const child = spawn(serverConfig.command, serverConfig.args ?? [], {
  cwd: repoRoot,
  env: { ...process.env, ...(serverConfig.env ?? {}) },
  stdio: ['pipe', 'pipe', 'pipe'],
  shell: process.platform === 'win32',
});

const pending = new Map();
let nextId = 1;
let stdoutBuffer = '';

child.stdout.on('data', (chunk) => {
  stdoutBuffer += chunk.toString();
  let newline;
  while ((newline = stdoutBuffer.indexOf('\n')) !== -1) {
    const line = stdoutBuffer.slice(0, newline).trim();
    stdoutBuffer = stdoutBuffer.slice(newline + 1);
    if (!line.startsWith('{')) continue; // server banner lines
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      continue;
    }
    const resolver = pending.get(message.id);
    if (resolver) {
      pending.delete(message.id);
      resolver(message);
    }
  }
});

child.stderr.on('data', (chunk) => process.stderr.write(chunk));

function request(method, params) {
  const id = nextId++;
  return new Promise((resolvePromise) => {
    pending.set(id, resolvePromise);
    child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
  });
}

function fail(message) {
  console.error(message);
  child.kill();
  process.exit(1);
}

await request('initialize', {
  protocolVersion: '2024-11-05',
  capabilities: {},
  clientInfo: { name: 'godot-mcp-call', version: '1.0.0' },
});
child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`);

if (steps.length === 1 && steps[0].name === 'list_tools') {
  const listed = await request('tools/list', {});
  for (const tool of listed.result?.tools ?? []) {
    const required = tool.inputSchema?.required ?? [];
    const props = Object.keys(tool.inputSchema?.properties ?? {});
    console.log(`${tool.name}`);
    console.log(`    ${tool.description ?? ''}`);
    if (props.length) {
      console.log(`    args: ${props.map((p) => (required.includes(p) ? `${p}*` : p)).join(', ')}`);
    }
  }
  child.kill();
  process.exit(0);
}

let sawToolError = false;

for (const step of steps) {
  if (step.sleep) {
    await new Promise((r) => setTimeout(r, step.sleep));
    continue;
  }

  if (steps.length > 1) console.log(`\n=== ${step.name} ===`);
  const response = await request('tools/call', { name: step.name, arguments: step.args });

  if (response.error) {
    fail(`error: ${JSON.stringify(response.error, null, 2)}`);
  }
  for (const item of response.result?.content ?? []) {
    console.log(item.type === 'text' ? item.text : JSON.stringify(item));
  }
  if (response.result?.isError) sawToolError = true;
}

child.kill();
process.exit(sawToolError ? 1 : 0);
