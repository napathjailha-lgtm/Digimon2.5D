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
const GUILD_DATA_PATH =
  process.env.GUILD_DATA_PATH ||
  (existsSync("/data") ? "/data/guilds.json" : "./data/guilds.json");

const clients = new Map();
let guildStore = loadGuildStore();

function emptyGuildStore() {
  return { version: 1, guilds: {}, memberships: {} };
}

function loadGuildStore() {
  try {
    if (!existsSync(GUILD_DATA_PATH)) return emptyGuildStore();
    const parsed = JSON.parse(readFileSync(GUILD_DATA_PATH, "utf8"));
    if (!parsed || parsed.version !== 1 || typeof parsed.guilds !== "object") {
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

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
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
  };
  clients.set(ws, client);
  send(ws, { type: "welcome", id: client.id });

  ws.on("message", (buffer) => {
    if (buffer.length > MAX_PACKET) return;
    let msg;
    try {
      msg = JSON.parse(buffer.toString("utf8"));
    } catch {
      return;
    }
    if (!msg || typeof msg !== "object") return;

    if (msg.type === "hello") {
      const incomingCharacterKey = cleanText(msg.character_key, 80);
      // Autoload connects from the login screen too. Count/register a player only
      // after a real character is bound to the world.
      if (!incomingCharacterKey) return;

      const wasReady = client.ready;
      const oldZone = client.zone;
      const previousGuildId = guildIdForClient(client);

      client.characterKey = incomingCharacterKey;
      client.name = cleanText(msg.name) || "Tamer";
      client.zone = cleanText(msg.zone, 40) || "file_island";
      client.position = normalizeVector(msg.position, client.position);
      applyAppearance(client, msg);
      client.ready = true;

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

  ws.on("close", () => {
    const wasReady = client.ready;
    const guildId = guildIdForClient(client);
    clients.delete(ws);
    if (wasReady) {
      broadcast({ type: "leave", id: client.id }, null, client.zone);
      broadcastOnlineCounts();
      if (guildId) broadcastGuildSnapshot(guildId);
    }
  });

  ws.on("error", () => {});
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `Prism Tamer Online Server listening on :${PORT} • guild store ${GUILD_DATA_PATH}`,
  );
});
