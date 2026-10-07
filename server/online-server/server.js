import http from "node:http";
import crypto from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { dirname } from "node:path";
import { WebSocketServer, WebSocket } from "ws";

const PORT = Number(process.env.PORT || 8787);
const MAX_PACKET = 8192;
const MAX_CHAT = 160;
const MAX_GUILD_NAME = 20;
const MAX_GUILD_MEMBERS = 50;
const GUILD_INVITE_TTL_MS = 30_000;
const RELEASE = "online-safety-2026-10-07";
const TRADE_UNAVAILABLE = "Trade ปิดชั่วคราวเพื่อปรับปรุงความปลอดภัยของไอเทมและ Bits";
const HEARTBEAT_MS = Number(process.env.HEARTBEAT_MS || 30_000);
const GUILD_DATA_PATH =
  process.env.GUILD_DATA_PATH ||
  (existsSync("/data") ? "/data/guilds.json" : "./data/guilds.json");

const clients = new Map();
const guildInvites = new Map();
let guildStore = loadGuildStore();

function emptyGuildStore() {
  return { version: 2, guilds: {}, memberships: {} };
}

function loadGuildStore() {
  try {
    if (!existsSync(GUILD_DATA_PATH)) return emptyGuildStore();
    const parsed = JSON.parse(readFileSync(GUILD_DATA_PATH, "utf8"));
    if (!parsed || parsed.version !== 2 || typeof parsed.guilds !== "object") {
      if (parsed?.version === 1) {
        console.warn("Resetting legacy guild store: v1 used non-unique demo character identities");
      }
      return emptyGuildStore();
    }
    if (!parsed.memberships || typeof parsed.memberships !== "object") {
      parsed.memberships = {};
    }
    return parsed;
  } catch (error) {
    console.error("Guild store load failed:", error);
    return emptyGuildStore();
  }
}

function saveGuildStore() {
  try {
    mkdirSync(dirname(GUILD_DATA_PATH), { recursive: true });
    const temp = `${GUILD_DATA_PATH}.tmp`;
    writeFileSync(temp, JSON.stringify(guildStore, null, 2), "utf8");
    renameSync(temp, GUILD_DATA_PATH);
    return true;
  } catch (error) {
    console.error("Guild store save failed:", error);
    return false;
  }
}

function validCharacterKey(value) {
  return /^v2:[a-f0-9]{64}$/.test(String(value ?? ""));
}

function cleanText(value, max = 24) {
  return String(value ?? "").replace(/[\r\n\t]/g, " ").trim().slice(0, max);
}

function safeNumber(value, fallback = 0, min = -20000, max = 20000) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback;
}

function normalizeVector(raw, fallback = { x: 0, y: 0 }) {
  return {
    x: safeNumber(raw?.x, fallback.x),
    y: safeNumber(raw?.y, fallback.y),
  };
}

function normalizeScale(raw, fallback = { x: 0.24, y: 0.24 }) {
  return {
    x: safeNumber(raw?.x, fallback.x, 0.01, 4),
    y: safeNumber(raw?.y, fallback.y, 0.01, 4),
  };
}

function normalizeFacing(value, fallback = "down") {
  const facing = cleanText(value, 8);
  return ["up", "down", "left", "right"].includes(facing)
    ? facing
    : fallback;
}

function normalizePartner(raw, previous = null) {
  if (!raw || typeof raw !== "object") return null;
  const formId = cleanText(raw.form_id, 64);
  if (!formId) return null;
  return {
    form_id: formId,
    name: cleanText(raw.name, 48),
    position: normalizeVector(raw.position, previous?.position),
    velocity: normalizeVector(raw.velocity, previous?.velocity),
    facing: normalizeFacing(raw.facing, previous?.facing),
    animation: cleanText(raw.animation, 64),
    scale: normalizeScale(
      raw.scale,
      previous?.scale ?? { x: 0.25, y: 0.25 },
    ),
    offset: normalizeVector(raw.offset, previous?.offset ?? { x: 0, y: 0 }),
    visible: raw.visible !== false,
  };
}

function applyAppearance(client, msg) {
  client.model = cleanText(msg.tamer_model, 64) || client.model;
  client.tamerScale = normalizeScale(msg.tamer_scale, client.tamerScale);
  client.tamerOffset = normalizeVector(msg.tamer_offset, client.tamerOffset);
  client.partner = normalizePartner(msg.partner, client.partner);
}

function guildForCharacter(characterKey) {
  const guildId = guildStore.memberships[characterKey];
  if (!guildId) return null;
  const guild = guildStore.guilds[guildId];
  if (!guild) {
    delete guildStore.memberships[characterKey];
    return null;
  }
  return guild;
}

function guildForClient(client) {
  if (!client.characterKey) return null;
  return guildForCharacter(client.characterKey);
}

function guildNameForClient(client) {
  return guildForClient(client)?.name ?? "";
}

function guildIdForClient(client) {
  return guildStore.memberships[client.characterKey] ?? "";
}

function playerPayload(type, client) {
  return {
    type,
    id: client.id,
    name: client.name,
    zone: client.zone,
    position: client.position,
    velocity: client.velocity,
    facing: client.facing,
    tamer_model: client.model,
    tamer_scale: client.tamerScale,
    tamer_offset: client.tamerOffset,
    partner: client.partner ?? {},
    guild_id: guildIdForClient(client),
    guild_name: guildNameForClient(client),
  };
}

function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}

function broadcast(payload, except = null, zone = "") {
  for (const [ws, client] of clients) {
    if (ws === except || ws.readyState !== WebSocket.OPEN || !client.ready)
      continue;
    if (zone && client.zone !== zone) continue;
    send(ws, payload);
  }
}

function emitExistingPlayers(ws, self) {
  for (const [otherWs, other] of clients) {
    if (otherWs === ws || !other.ready || other.zone !== self.zone) continue;
    send(ws, playerPayload("join", other));
  }
}

function readyPlayerCount() {
  let total = 0;
  for (const client of clients.values()) {
    if (client.ready) total += 1;
  }
  return total;
}

function zonePlayerCounts() {
  const counts = new Map();
  for (const client of clients.values()) {
    if (!client.ready) continue;
    counts.set(client.zone, (counts.get(client.zone) ?? 0) + 1);
  }
  return counts;
}

function broadcastOnlineCounts() {
  const total = readyPlayerCount();
  const zones = zonePlayerCounts();
  for (const [ws, client] of clients) {
    if (!client.ready || ws.readyState !== WebSocket.OPEN) continue;
    send(ws, {
      type: "online_count",
      total,
      zone: client.zone,
      zone_count: zones.get(client.zone) ?? 0,
    });
  }
}

function onlineClientForPeer(peerId) {
  for (const [ws, client] of clients) {
    if (
      client.ready &&
      client.id === peerId &&
      ws.readyState === WebSocket.OPEN
    ) {
      return { ws, client };
    }
  }
  return null;
}

function onlineClientForCharacter(characterKey) {
  for (const [ws, client] of clients) {
    if (
      client.ready &&
      client.characterKey === characterKey &&
      ws.readyState === WebSocket.OPEN
    ) {
      return { ws, client };
    }
  }
  return null;
}

function guildSnapshotFor(client) {
  const guild = guildForClient(client);
  if (!guild) {
    return {
      type: "guild_snapshot",
      guild: {},
    };
  }

  const members = Object.entries(guild.members)
    .map(([characterKey, member]) => ({
      name: cleanText(member.name, 24) || "Tamer",
      role: member.role === "owner" ? "owner" : "member",
      online: onlineClientForCharacter(characterKey) !== null,
      joined_at: Number(member.joinedAt || 0),
    }))
    .sort((a, b) => {
      if (a.role !== b.role) return a.role === "owner" ? -1 : 1;
      if (a.online !== b.online) return a.online ? -1 : 1;
      return a.joined_at - b.joined_at;
    });

  return {
    type: "guild_snapshot",
    guild: {
      id: guild.id,
      name: guild.name,
      code: guild.code,
      role: guild.members[client.characterKey]?.role ?? "member",
      member_count: members.length,
      online_count: members.filter((member) => member.online).length,
      members,
    },
  };
}

function sendGuildSnapshot(ws, client) {
  send(ws, guildSnapshotFor(client));
}

function broadcastGuildSnapshot(guildId) {
  if (!guildId) return;
  for (const [ws, client] of clients) {
    if (
      client.ready &&
      guildIdForClient(client) === guildId &&
      ws.readyState === WebSocket.OPEN
    ) {
      sendGuildSnapshot(ws, client);
    }
  }
}

function broadcastClientPresence(client, ws) {
  broadcast(playerPayload("state", client), ws, client.zone);
}

function sendGuildFeedback(ws, message, ok = false) {
  send(ws, {
    type: "guild_feedback",
    ok,
    message: cleanText(message, 160),
  });
}

function normalizeGuildName(value) {
  return cleanText(value, MAX_GUILD_NAME).replace(/\s+/g, " ");
}

function guildNameExists(name) {
  const key = name.toLocaleLowerCase();
  return Object.values(guildStore.guilds).some(
    (guild) => String(guild.name).toLocaleLowerCase() === key,
  );
}

function guildByCode(code) {
  const wanted = cleanText(code, 12).toUpperCase();
  if (!wanted) return null;
  return (
    Object.values(guildStore.guilds).find((guild) => guild.code === wanted) ??
    null
  );
}

function generateGuildCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  for (let attempt = 0; attempt < 50; attempt += 1) {
    let code = "";
    for (let i = 0; i < 6; i += 1) {
      code += alphabet[crypto.randomInt(0, alphabet.length)];
    }
    if (!guildByCode(code)) return code;
  }
  return crypto.randomBytes(4).toString("hex").slice(0, 6).toUpperCase();
}

function createGuild(ws, client, requestedName) {
  if (!client.ready || !client.characterKey) {
    sendGuildFeedback(ws, "ยังไม่มีข้อมูลตัวละครออนไลน์");
    return;
  }
  if (guildForClient(client)) {
    sendGuildFeedback(ws, "ออกจากกิลด์เดิมก่อนสร้างกิลด์ใหม่");
    return;
  }

  const name = normalizeGuildName(requestedName);
  if (name.length < 3) {
    sendGuildFeedback(ws, "ชื่อกิลด์ต้องยาว 3–20 ตัวอักษร");
    return;
  }
  if (guildNameExists(name)) {
    sendGuildFeedback(ws, "ชื่อกิลด์นี้ถูกใช้แล้ว");
    return;
  }

  const id = crypto.randomUUID();
  guildStore.guilds[id] = {
    id,
    name,
    code: generateGuildCode(),
    createdAt: Date.now(),
    members: {
      [client.characterKey]: {
        name: client.name,
        role: "owner",
        joinedAt: Date.now(),
      },
    },
  };
  guildStore.memberships[client.characterKey] = id;

  if (!saveGuildStore()) {
    delete guildStore.guilds[id];
    delete guildStore.memberships[client.characterKey];
    sendGuildFeedback(ws, "บันทึกข้อมูลกิลด์ไม่สำเร็จ");
    return;
  }

  sendGuildFeedback(ws, `สร้างกิลด์ ${name} สำเร็จ`, true);
  broadcastGuildSnapshot(id);
  broadcastClientPresence(client, ws);
}

function joinGuild(ws, client, code) {
  if (!client.ready || !client.characterKey) {
    sendGuildFeedback(ws, "ยังไม่มีข้อมูลตัวละครออนไลน์");
    return;
  }
  if (guildForClient(client)) {
    sendGuildFeedback(ws, "ตัวละครนี้มีกิลด์อยู่แล้ว");
    return;
  }

  const guild = guildByCode(code);
  if (!guild) {
    sendGuildFeedback(ws, "ไม่พบกิลด์จากรหัสนี้");
    return;
  }
  if (Object.keys(guild.members).length >= MAX_GUILD_MEMBERS) {
    sendGuildFeedback(ws, "กิลด์นี้สมาชิกเต็ม 50 คนแล้ว");
    return;
  }

  guild.members[client.characterKey] = {
    name: client.name,
    role: "member",
    joinedAt: Date.now(),
  };
  guildStore.memberships[client.characterKey] = guild.id;

  if (!saveGuildStore()) {
    delete guild.members[client.characterKey];
    delete guildStore.memberships[client.characterKey];
    sendGuildFeedback(ws, "บันทึกข้อมูลกิลด์ไม่สำเร็จ");
    return;
  }

  sendGuildFeedback(ws, `เข้ากิลด์ ${guild.name} แล้ว`, true);
  broadcastGuildSnapshot(guild.id);
  broadcastClientPresence(client, ws);
}

function inviteToGuild(ws, client, targetPeerId) {
  const guild = guildForClient(client);
  if (!guild) {
    sendGuildFeedback(ws, "ต้องอยู่ในกิลด์ก่อนจึงจะเชิญผู้เล่นได้");
    return;
  }
  if (Object.keys(guild.members).length >= MAX_GUILD_MEMBERS) {
    sendGuildFeedback(ws, "กิลด์สมาชิกเต็ม 50 คนแล้ว");
    return;
  }

  const target = onlineClientForPeer(cleanText(targetPeerId, 80));
  if (!target || target.client.id === client.id) {
    sendGuildFeedback(ws, "ไม่พบผู้เล่นที่ต้องการเชิญ");
    return;
  }
  if (target.client.zone !== client.zone) {
    sendGuildFeedback(ws, "ผู้เล่นไม่ได้อยู่ในแมพเดียวกันแล้ว");
    return;
  }
  if (guildForClient(target.client)) {
    sendGuildFeedback(ws, "ผู้เล่นนี้มีกิลด์อยู่แล้ว");
    return;
  }

  const now = Date.now();
  for (const [inviteId, invite] of guildInvites) {
    if (invite.expiresAt <= now) {
      guildInvites.delete(inviteId);
      continue;
    }
    if (
      invite.targetPeerId === target.client.id &&
      invite.guildId === guild.id
    ) {
      sendGuildFeedback(ws, "ส่งคำเชิญให้ผู้เล่นนี้ไปแล้ว กรุณารอการตอบรับ");
      return;
    }
  }

  const inviteId = crypto.randomUUID();
  guildInvites.set(inviteId, {
    id: inviteId,
    guildId: guild.id,
    fromPeerId: client.id,
    fromName: client.name,
    targetPeerId: target.client.id,
    expiresAt: now + GUILD_INVITE_TTL_MS,
  });

  send(target.ws, {
    type: "guild_invite",
    invite_id: inviteId,
    guild_id: guild.id,
    guild_name: guild.name,
    from_id: client.id,
    from_name: client.name,
    expires_in: Math.floor(GUILD_INVITE_TTL_MS / 1000),
  });
  sendGuildFeedback(
    ws,
    `ส่งคำเชิญกิลด์ให้ ${target.client.name} แล้ว`,
    true,
  );
}

function respondGuildInvite(ws, client, inviteId, accepted) {
  const id = cleanText(inviteId, 80);
  const invite = guildInvites.get(id);
  if (!invite || invite.targetPeerId !== client.id) {
    sendGuildFeedback(ws, "คำเชิญกิลด์หมดอายุหรือไม่ถูกต้อง");
    return;
  }
  guildInvites.delete(id);

  const inviter = onlineClientForPeer(invite.fromPeerId);
  if (invite.expiresAt <= Date.now()) {
    sendGuildFeedback(ws, "คำเชิญกิลด์หมดอายุแล้ว");
    if (inviter) {
      sendGuildFeedback(inviter.ws, `${client.name} ไม่ได้ตอบรับคำเชิญทันเวลา`);
    }
    return;
  }

  const guild = guildStore.guilds[invite.guildId];
  if (!guild) {
    sendGuildFeedback(ws, "กิลด์นี้ไม่มีอยู่แล้ว");
    return;
  }
  if (!accepted) {
    sendGuildFeedback(ws, `ปฏิเสธคำเชิญจากกิลด์ ${guild.name} แล้ว`, true);
    if (inviter) {
      sendGuildFeedback(inviter.ws, `${client.name} ปฏิเสธคำเชิญเข้ากิลด์`);
    }
    return;
  }
  if (guildForClient(client)) {
    sendGuildFeedback(ws, "คุณมีกิลด์อยู่แล้ว");
    return;
  }
  if (Object.keys(guild.members).length >= MAX_GUILD_MEMBERS) {
    sendGuildFeedback(ws, "กิลด์สมาชิกเต็ม 50 คนแล้ว");
    return;
  }

  guild.members[client.characterKey] = {
    name: client.name,
    role: "member",
    joinedAt: Date.now(),
  };
  guildStore.memberships[client.characterKey] = guild.id;

  if (!saveGuildStore()) {
    delete guild.members[client.characterKey];
    delete guildStore.memberships[client.characterKey];
    sendGuildFeedback(ws, "บันทึกข้อมูลกิลด์ไม่สำเร็จ");
    return;
  }

  for (const [pendingId, pending] of guildInvites) {
    if (pending.targetPeerId === client.id) guildInvites.delete(pendingId);
  }

  sendGuildFeedback(ws, `เข้ากิลด์ ${guild.name} แล้ว`, true);
  if (inviter) {
    sendGuildFeedback(
      inviter.ws,
      `${client.name} ตอบรับและเข้ากิลด์ ${guild.name} แล้ว`,
      true,
    );
  }
  broadcastGuildSnapshot(guild.id);
  broadcastClientPresence(client, ws);
}

function leaveGuild(ws, client) {
  const guild = guildForClient(client);
  if (!guild) {
    sendGuildFeedback(ws, "ตัวละครนี้ยังไม่มีกิลด์");
    return;
  }

  const guildId = guild.id;
  const wasOwner = guild.members[client.characterKey]?.role === "owner";
  delete guild.members[client.characterKey];
  delete guildStore.memberships[client.characterKey];

  const remainingKeys = Object.keys(guild.members);
  if (remainingKeys.length === 0) {
    delete guildStore.guilds[guildId];
  } else if (wasOwner) {
    remainingKeys.sort(
      (a, b) =>
        Number(guild.members[a]?.joinedAt || 0) -
        Number(guild.members[b]?.joinedAt || 0),
    );
    guild.members[remainingKeys[0]].role = "owner";
  }

  if (!saveGuildStore()) {
    console.error("Guild leave persisted state could not be saved");
  }

  sendGuildFeedback(ws, "ออกจากกิลด์แล้ว", true);
  sendGuildSnapshot(ws, client);
  broadcastGuildSnapshot(guildId);
  broadcastClientPresence(client, ws);
}

function broadcastGuildChat(client, text) {
  const guildId = guildIdForClient(client);
  if (!guildId) return false;

  for (const [ws, other] of clients) {
    if (
      other.ready &&
      guildIdForClient(other) === guildId &&
      ws.readyState === WebSocket.OPEN
    ) {
      send(ws, {
        type: "guild_chat",
        id: client.id,
        name: client.name,
        guild_id: guildId,
        text,
      });
    }
  }
  return true;
}


// Local saves are not an authoritative economy. No trade mutation/commit path
// may be restored until balances and durable transactions are server-owned.
function removeClient(ws) {
  const client = clients.get(ws);
  if (!client) return;
  const wasReady = client.ready;
  const guildId = guildIdForClient(client);
  client.ready = false;
  clients.delete(ws);
  for (const [inviteId, invite] of guildInvites) {
    if (invite.fromPeerId === client.id || invite.targetPeerId === client.id) {
      guildInvites.delete(inviteId);
    }
  }
  if (wasReady) {
    broadcast({ type: "leave", id: client.id }, null, client.zone);
    broadcastOnlineCounts();
    if (guildId) broadcastGuildSnapshot(guildId);
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
        release: RELEASE,
        commit: process.env.RAILWAY_GIT_COMMIT_SHA || "",
        capabilities: { trade: false, single_character_session: true },
        players: readyPlayerCount(),
        sockets: clients.size,
        guilds: Object.keys(guildStore.guilds).length,
      }),
    );
    return;
  }
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Prism Tamer Online Server");
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

wss.on("connection", (ws) => {
  const client = {
    id: crypto.randomUUID(),
    ready: false,
    characterKey: "",
    name: "Tamer",
    zone: "file_island",
    position: { x: 0, y: 0 },
    velocity: { x: 0, y: 0 },
    facing: "down",
    model: "",
    tamerScale: { x: 0.24, y: 0.24 },
    tamerOffset: { x: 0, y: -256 },
    partner: null,
    lastStateAt: 0,
    lastChatAt: 0,
    lastGuildChatAt: 0,
    isAlive: true,
    connectedAt: Date.now(),
  };
  clients.set(ws, client);
  send(ws, { type: "welcome", id: client.id, release: RELEASE, capabilities: { trade: false } });
  ws.on("pong", () => { client.isAlive = true; });

  ws.on("message", (buffer) => {
    if (!clients.has(ws) || buffer.length > MAX_PACKET) return;
    let msg;
    try {
      msg = JSON.parse(buffer.toString("utf8"));
    } catch {
      return;
    }
    if (!msg || typeof msg !== "object") return;

    if (msg.type === "leave") {
      removeClient(ws);
      ws.close(1000, "left world");
      return;
    }

    // Block every legacy/future trade message, including forged prepare results.
    if (typeof msg.type === "string" && msg.type.startsWith("trade_")) {
      send(ws, { type: "trade_feedback", ok: false, code: "trade_unavailable", message: TRADE_UNAVAILABLE });
      return;
    }

    if (msg.type === "hello") {
      // Older clients reconnect after replacement and advertise menu presence.
      if (msg.protocol_version !== 3) {
        send(ws, { type: "identity_error", message: "กรุณารีเฟรช/อัปเดตเกมเพื่อใช้งาน Online รุ่นใหม่" });
        removeClient(ws);
        ws.close(1008, "client upgrade required");
        return;
      }
      const incomingCharacterKey = cleanText(msg.character_key, 80);
      // v2 identity is a persistent random UID stored per character.
      // Reject legacy username+slot hashes because separate devices could collide.
      if (!validCharacterKey(incomingCharacterKey)) {
        if (incomingCharacterKey) {
          send(ws, {
            type: "identity_error",
            message: "Client รุ่นเก่า กรุณารีเฟรช/อัปเดตเกมก่อนใช้งาน Online"
          });
        }
        return;
      }

      if (client.ready && client.characterKey !== incomingCharacterKey) {
        send(ws, { type: "identity_error", message: "กรุณาเชื่อมต่อใหม่เมื่อเปลี่ยนตัวละคร" });
        removeClient(ws);
        ws.close(1008, "identity change");
        return;
      }
      // Newest session wins. Remove presence synchronously before acknowledging
      // the new socket; a delayed close event cannot remove its replacement.
      for (const [otherWs, other] of clients) {
        if (otherWs !== ws && other.ready && other.characterKey === incomingCharacterKey) {
          send(otherWs, { type: "session_replaced", message: "ตัวละครนี้เชื่อมต่อจากหน้าต่างอื่นแล้ว" });
          removeClient(otherWs);
          otherWs.close(4001, "session replaced");
        }
      }

      const wasReady = client.ready;
      const oldZone = client.zone;
      const previousGuildId = guildIdForClient(client);

      client.characterKey = incomingCharacterKey;
      client.name = cleanText(msg.name) || "Tamer";
      client.zone = cleanText(msg.zone, 40) || "file_island";
      client.position = normalizeVector(msg.position, client.position);
      applyAppearance(client, msg);
      client.ready = true;
      send(ws, {
        type: "online_ready",
        character_key: client.characterKey,
        id: client.id,
        zone: client.zone,
      });

      const guild = guildForClient(client);
      if (guild?.members?.[client.characterKey]) {
        guild.members[client.characterKey].name = client.name;
        saveGuildStore();
      }

      if (!wasReady || oldZone !== client.zone) {
        if (wasReady && oldZone !== client.zone) {
          broadcast({ type: "leave", id: client.id }, ws, oldZone);
        }
        emitExistingPlayers(ws, client);
        broadcast(playerPayload("join", client), ws, client.zone);
      }

      sendGuildSnapshot(ws, client);
      const guildId = guildIdForClient(client);
      if (guildId) broadcastGuildSnapshot(guildId);
      if (previousGuildId && previousGuildId !== guildId) {
        broadcastGuildSnapshot(previousGuildId);
      }
      broadcastOnlineCounts();
      return;
    }

    if (!client.ready) return;

    if (msg.type === "state") {
      const now = Date.now();
      if (now - client.lastStateAt < 40) return;
      client.lastStateAt = now;

      const oldZone = client.zone;
      client.zone = cleanText(msg.zone, 40) || client.zone;
      client.name = cleanText(msg.name) || client.name;
      client.position = normalizeVector(msg.position, client.position);
      client.velocity = normalizeVector(msg.velocity, client.velocity);
      client.facing = normalizeFacing(msg.facing, client.facing);
      applyAppearance(client, msg);

      if (oldZone !== client.zone) {
        broadcast({ type: "leave", id: client.id }, ws, oldZone);
        emitExistingPlayers(ws, client);
        broadcast(playerPayload("join", client), ws, client.zone);
        broadcastOnlineCounts();
      }
      broadcast(playerPayload("state", client), ws, client.zone);
      return;
    }

    if (msg.type === "chat") {
      const now = Date.now();
      if (now - client.lastChatAt < 500) return;
      client.lastChatAt = now;
      const text = cleanText(msg.text, MAX_CHAT);
      if (!text) return;
      broadcast(
        {
          type: "chat",
          id: client.id,
          name: client.name,
          zone: client.zone,
          text,
        },
        null,
        client.zone,
      );
      return;
    }

    if (msg.type === "guild_create") {
      createGuild(ws, client, msg.name);
      return;
    }

    if (msg.type === "guild_join") {
      joinGuild(ws, client, msg.code);
      return;
    }

    if (msg.type === "guild_leave") {
      leaveGuild(ws, client);
      return;
    }

    if (msg.type === "guild_invite") {
      inviteToGuild(ws, client, msg.target_peer_id);
      return;
    }

    if (msg.type === "guild_invite_response") {
      respondGuildInvite(ws, client, msg.invite_id, msg.accept === true);
      return;
    }

    if (msg.type === "guild_request") {
      sendGuildSnapshot(ws, client);
      return;
    }

    if (msg.type === "guild_chat") {
      const now = Date.now();
      if (now - client.lastGuildChatAt < 700) return;
      client.lastGuildChatAt = now;
      const text = cleanText(msg.text, MAX_CHAT);
      if (!text) return;
      if (!broadcastGuildChat(client, text)) {
        sendGuildFeedback(ws, "ต้องเข้ากิลด์ก่อนใช้แชตกิลด์");
      }
    }
  });

  ws.on("close", () => removeClient(ws));

  ws.on("error", () => {});
});

// Ping/pong catches half-open sockets; never count abandoned tabs forever.
const heartbeat = setInterval(() => {
  for (const [ws, client] of clients) {
    if (!client.isAlive || (!client.ready && Date.now() - client.connectedAt > HEARTBEAT_MS * 2)) {
      removeClient(ws);
      ws.terminate();
      continue;
    }
    client.isAlive = false;
    ws.ping();
  }
}, HEARTBEAT_MS);
heartbeat.unref();
wss.on("close", () => clearInterval(heartbeat));

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `Prism Tamer Online Server listening on :${server.address().port} • guild store ${GUILD_DATA_PATH}`,
  );
});
