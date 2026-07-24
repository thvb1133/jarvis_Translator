import { test } from 'node:test';
import assert from 'node:assert';
import { spawn, type ChildProcess } from 'node:child_process';
import { setTimeout } from 'node:timers/promises';
import { installCookieJar, isServerRunning } from '@aws-blocks/blocks/utils';
import type { api as apiType } from 'aws-blocks';

installCookieJar();

let server: ChildProcess | null = null;
let api: typeof apiType;

test.before(async () => {
  if (!await isServerRunning()) {
    server = spawn('npm', ['run', 'dev'], {
      cwd: process.cwd(),
      stdio: ['ignore', 'pipe', 'pipe'],
      detached: true,
      env: { ...process.env, NODE_OPTIONS: '' },
    });
    server.unref();
    await setTimeout(2000);
  }

  const mod = await import('aws-blocks');
  api = mod.api;

  // Wait for server to be ready
  for (let i = 0; i < 30; i++) {
    try { await api.ping(); return; } catch {
      await setTimeout(1000);
    }
  }
  throw new Error('Server not ready');
});

test.after(() => {
  if (server?.pid) {
    try { process.kill(-server.pid, 'SIGTERM'); } catch {}
  }
});

test('ping returns pong', async () => {
  const result = await api.ping();
  assert.strictEqual(result.message, 'pong');
  assert.ok(typeof result.timestamp === 'number');
});

test('register, session, and per-user history', async () => {
  const username = `user_${Date.now()}@example.com`;
  const reg = await api.register(username, 'password123');
  assert.strictEqual(reg.username, username);

  const me = await api.me();
  assert.ok(me && me.username === username);

  const entry = await api.saveEntry('translate', 'hello', 'હેલો', 'en', 'gu');
  assert.strictEqual(entry.output, 'હેલો');

  const list = await api.listHistory();
  assert.ok(list.length >= 1);

  const cleared = await api.clearHistory();
  assert.ok(cleared.success);
});
