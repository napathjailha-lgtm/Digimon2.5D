import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { WebSocket } from 'ws';
import { EncryptedJsonStore } from './encrypted_json_store.js';

const TEST_ENCRYPTION_KEY = '11'.repeat(32);

async function fixture(t, heartbeat = 30000) {
  const dir = await mkdtemp(join(tmpdir(), 'online-test-'));
  const child = spawn(process.execPath, ['server.js'], {
    cwd: import.meta.dirname,
    env: {
      ...process.env,
      PORT: '0',
      DATA_DIR: dir,
      GUILD_DATA_PATH: join(dir, 'guilds.json'),
      DATA_ENCRYPTION_KEY: TEST_ENCRYPTION_KEY,
      HEARTBEAT_MS: String(heartbeat),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const peers = [];
  t.after(async () => {
    for (const peer of peers) peer.ws.terminate();
    const exited = new Promise(resolve => child.once('exit', resolve));
    child.kill();
    await exited;
    await rm(dir, { recursive: true, force: true });
  });
  const port = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('server startup timeout')), 5000);
    child.once('error', reject);
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`server exited: ${code}`)); });
    child.stdout.on('data', data => {
      const match = String(data).match(/listening on :(\d+)/);
      if (match) { clearTimeout(timer); resolve(Number(match[1])); }
    });
    child.stderr.on('data', data => reject(new Error(String(data))));
  });
  async function peer(autoPong = true) {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`, { autoPong });
    const history = [], waiters = [];
    ws.on('error', () => {});
    ws.on('message', data => {
      const msg = JSON.parse(data);
      history.push(msg);
      for (const wake of [...waiters]) wake();
    });
    const client = {
      ws, history,
      send(msg) { ws.send(JSON.stringify(msg)); },
      wait(type, predicate = () => true, after = 0) {
        return new Promise((resolve, reject) => {
          const timeout = setTimeout(() => { cleanup(); reject(new Error(`missing ${type}`)); }, 3000);
          function cleanup() { clearTimeout(timeout); const i = waiters.indexOf(check); if (i >= 0) waiters.splice(i, 1); }
          function check() {
            const found = history.slice(after).find(m => m.type === type && predicate(m));
            if (found) { cleanup(); resolve(found); }
          }
          waiters.push(check); check();
        });
      },
      async hello(letter) {
        const character_key = 'v2:' + letter.repeat(64);
        this.send({ type: 'hello', protocol_version: 3, character_key, name: letter, zone: 'file_island' });
        return await this.wait('online_ready', m => m.character_key === character_key);
      },
    };
    peers.push(client);
    client.id = (await client.wait('welcome')).id;
    return client;
  }
  return {
    dir,
    peer,
    health: async () => (await fetch(`http://127.0.0.1:${port}/health`)).json(),
  };
}

test('encrypted JSON store migrates plaintext and rejects authenticated tampering', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'encrypted-store-test-'));
  t.after(async () => rm(dir, { recursive: true, force: true }));
  const path = join(dir, 'legacy.json');
  await writeFile(path, JSON.stringify({ version: 1, secret: 'plain-secret-value' }), 'utf8');

  const store = new EncryptedJsonStore({
    path,
    name: 'legacy-test',
    defaultValue: { version: 1 },
    key: TEST_ENCRYPTION_KEY,
  });
  assert.deepEqual(store.load(), { version: 1, secret: 'plain-secret-value' });

  const encryptedText = await readFile(path, 'utf8');
  assert.equal(encryptedText.includes('plain-secret-value'), false);
  const envelope = JSON.parse(encryptedText);
  assert.equal(envelope.algorithm, 'aes-256-gcm');

  const ciphertext = Buffer.from(envelope.ciphertext, 'base64');
  ciphertext[0] ^= 0xff;
  envelope.ciphertext = ciphertext.toString('base64');
  await writeFile(path, JSON.stringify(envelope), 'utf8');
  assert.throws(() => store.load(), /could not be decrypted/);
});

test('online server persists guild and character shell only as encrypted JSON', async t => {
  const f = await fixture(t);
  const a = await f.peer();
  await a.hello('a');
  a.send({ type: 'guild_create', name: 'Encrypted Guild' });
  await a.wait('guild_snapshot', m => m.guild?.name === 'Encrypted Guild');

  const guildText = await readFile(join(f.dir, 'guilds.json'), 'utf8');
  const characterText = await readFile(join(f.dir, 'characters.json'), 'utf8');
  assert.equal(guildText.includes('Encrypted Guild'), false);
  assert.equal(characterText.includes('v2:' + 'a'.repeat(64)), false);
  assert.equal(JSON.parse(guildText).algorithm, 'aes-256-gcm');
  assert.equal(JSON.parse(characterText).algorithm, 'aes-256-gcm');

  const health = await f.health();
  assert.equal(health.storage.encrypted, true);
  assert.equal(health.storage.algorithm, 'aes-256-gcm');
  assert.equal(health.storage.characters, 1);
});

test('economy migration is one-time, revisioned and encrypted per character', async t => {
  const f = await fixture(t);
  const a = await f.peer();
  await a.hello('a');

  const initial = await a.wait('economy_snapshot', m => m.migrated === false);
  assert.equal(initial.revision, 0);

  const migratedState = {
    bits: 12345,
    inventory: {
      version: 1,
      stacks: [
        { id: 'hp_potion_small', quantity: 25 },
        { id: 'emberclaw_egg', quantity: 6 },
      ],
    },
    equipment: {
      version: 2,
      bag: { forest_guardian_armor: 1 },
      equipped: { chest: 'forest_guardian_armor' },
    },
    incubator: { selected_egg: 'emberclaw_egg', level: 3 },
    partner_progress: { level: 31, exp: 15800 },
    form_id: 'emberclaw_mega',
    hp: 4421,
    digimon_mp: 188,
    egg: false,
    partner_roster: {
      version: 6,
      active_id: 'emberclaw',
      active_uid: 'emberclaw-100-200',
      members: [{
        uid: 'emberclaw-100-200',
        id: 'emberclaw',
        form_id: 'emberclaw_mega',
        hp: 4421,
        max_hp: 5000,
        mp: 188,
        egg: false,
        progress: { level: 31, exp: 15800 },
        enhancement: 3,
        unlocked_forms: ['emberclaw_rookie', 'emberclaw_mega'],
        cooldowns: { skill_1: 1.25 },
        basic_cooldown: 0.5,
      }],
      storage: [],
    },
  };

  const beforeMigrate = a.history.length;
  a.send({ type: 'economy_migrate', state: migratedState });
  const ack1 = await a.wait('economy_ack', m => m.revision === 1, beforeMigrate);
  assert.equal(ack1.migrated, true);

  const profilePath = join(f.dir, 'profiles', 'a'.repeat(64) + '.json');
  const profileText = await readFile(profilePath, 'utf8');
  assert.equal(profileText.includes('emberclaw_egg'), false);
  assert.equal(profileText.includes('12345'), false);
  assert.equal(JSON.parse(profileText).algorithm, 'aes-256-gcm');

  const beforeSecondMigration = a.history.length;
  a.send({ type: 'economy_migrate', state: { ...migratedState, bits: 999999999 } });
  const preserved = await a.wait(
    'economy_snapshot',
    m => m.migrated === true && m.revision === 1,
    beforeSecondMigration,
  );
  assert.equal(preserved.state.bits, 12345);

  const beforeStale = a.history.length;
  a.send({ type: 'economy_update', revision: 0, state: { ...migratedState, bits: 1 } });
  const conflict = await a.wait(
    'economy_feedback',
    m => m.code === 'revision_conflict',
    beforeStale,
  );
  assert.equal(conflict.revision, 1);
  const latest = await a.wait(
    'economy_snapshot',
    m => m.revision === 1,
    beforeStale,
  );
  assert.equal(latest.state.bits, 12345);

  const beforeUpdate = a.history.length;
  a.send({
    type: 'economy_update',
    revision: 1,
    state: { ...migratedState, bits: 12000 },
  });
  const ack2 = await a.wait('economy_ack', m => m.revision === 2, beforeUpdate);
  assert.equal(ack2.revision, 2);

  const beforeRequest = a.history.length;
  a.send({ type: 'economy_request' });
  const current = await a.wait(
    'economy_snapshot',
    m => m.migrated === true && m.revision === 2,
    beforeRequest,
  );
  assert.equal(current.state.bits, 12000);
  assert.equal(current.state.inventory.stacks[0].quantity, 25);
  assert.equal(current.state.partner_roster.members[0].enhancement, 3);
});

test('all legacy trade commands fail closed, including forged commit preparation', async t => {
  const f = await fixture(t), a = await f.peer(), b = await f.peer();
  await a.hello('a'); await b.hello('b');
  for (const type of ['trade_request', 'trade_invite_response', 'trade_offer', 'trade_ready', 'trade_confirm', 'trade_prepare_result', 'trade_commit', 'trade_cancel']) {
    const after = a.history.length;
    a.send({ type, target_peer_id: b.id, accept: true, ready: true, ok: true,
      trade_id: 'forged', offer: { items: [{ item_id: 'meat', quantity: 999 }], bits: 1000000 } });
    const result = await a.wait('trade_feedback', () => true, after);
    assert.equal(result.ok, false); assert.equal(result.code, 'trade_unavailable');
  }
  for (const p of [a, b]) assert.equal(p.history.some(m => ['trade_open', 'trade_prepare', 'trade_commit', 'trade_closed'].includes(m.type)), false);
  assert.equal((await f.health()).capabilities.trade, false);
});

test('duplicate identity replaces old presence once; repeated hello remains idempotent', async t => {
  const f = await fixture(t), observer = await f.peer(), old = await f.peer();
  await observer.hello('b'); await old.hello('a');
  const fresh = await f.peer(); await fresh.hello('a');
  await old.wait('session_replaced');
  await observer.wait('leave', m => m.id === old.id);
  await observer.wait('join', m => m.id === fresh.id);
  assert.equal((await f.health()).players, 2);
  fresh.send({ type: 'hello', protocol_version: 3, character_key: 'v2:' + 'a'.repeat(64), zone: 'file_island' });
  fresh.send({ type: 'guild_request' });
  await fresh.wait('guild_snapshot');
  assert.equal((await f.health()).players, 2);
  assert.equal(observer.history.filter(m => m.type === 'leave' && m.id === old.id).length, 1);
});

test('leave immediately clears counts and presence, then the character can reconnect', async t => {
  const f = await fixture(t), observer = await f.peer(), a = await f.peer();
  await observer.hello('b'); await a.hello('a');
  a.send({ type: 'leave' });
  await observer.wait('leave', m => m.id === a.id);
  assert.equal((await f.health()).players, 1);
  const fresh = await f.peer(); await fresh.hello('a');
  assert.equal((await f.health()).players, 2);
});

test('socket identity cannot change to another character or inherit its guild', async t => {
  const f = await fixture(t), a = await f.peer(), b = await f.peer();
  await a.hello('a'); await b.hello('b');
  a.send({ type: 'guild_create', name: 'Audit Guild' });
  await a.wait('guild_snapshot', m => !!m.guild?.id);
  const offset = b.history.length;
  b.send({ type: 'guild_request' });
  const snapshot = await b.wait('guild_snapshot', () => true, offset);
  assert.ok(!snapshot.guild?.id);
  a.send({ type: 'hello', protocol_version: 3, character_key: 'v2:' + 'b'.repeat(64) });
  await a.wait('identity_error');
  assert.equal((await f.health()).players, 1);
  assert.equal(b.history.some(m => m.type === 'session_replaced'), false);
});

test('heartbeat removes half-open players and unauthenticated idle sockets', async t => {
  const f = await fixture(t, 100), observer = await f.peer(), stale = await f.peer(false);
  await observer.hello('b'); await stale.hello('a');
  await observer.wait('leave', m => m.id === stale.id);
  assert.equal((await f.health()).players, 1);
  const idle = await f.peer();
  await new Promise(resolve => idle.ws.once('close', resolve));
  assert.equal((await f.health()).sockets, 1);
});


test('legacy clients cannot evict an upgraded character session', async t => {
  const f = await fixture(t), current = await f.peer(), legacy = await f.peer();
  await current.hello('a');
  legacy.send({ type: 'hello', character_key: 'v2:' + 'a'.repeat(64) });
  await legacy.wait('identity_error');
  assert.equal((await f.health()).players, 1);
  assert.equal(current.history.some(m => m.type === 'session_replaced'), false);
});
