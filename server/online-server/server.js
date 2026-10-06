import http from "node:http";
import crypto from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";

const PORT = Number(process.env.PORT || 8787);
const MAX_PACKET = 8192;
const MAX_CHAT = 160;
const clients = new Map();

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
      zone_count: zones.get(client.zone) ?? 0
    });
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, players: readyPlayerCount(), sockets: clients.size }));
    return;
  }
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Prism Tamer Online Server");
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

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
    y: safeNumber(raw?.y, fallback.y)
  };
}
function normalizeScale(raw, fallback = { x: 0.24, y: 0.24 }) {
  return {
    x: safeNumber(raw?.x, fallback.x, 0.01, 4),
    y: safeNumber(raw?.y, fallback.y, 0.01, 4)
  };
}
function normalizeFacing(value, fallback = "down") {
  const facing = cleanText(value, 8);
  return ["up", "down", "left", "right"].includes(facing) ? facing : fallback;
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
    scale: normalizeScale(raw.scale, previous?.scale ?? { x: 0.25, y: 0.25 }),
    offset: normalizeVector(raw.offset, previous?.offset ?? { x: 0, y: 0 }),
    visible: raw.visible !== false
  };
}
function applyAppearance(client, msg) {
  client.model = cleanText(msg.tamer_model, 64) || client.model;
  client.tamerScale = normalizeScale(msg.tamer_scale, client.tamerScale);
  client.tamerOffset = normalizeVector(msg.tamer_offset, client.tamerOffset);
  client.partner = normalizePartner(msg.partner, client.partner);
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
    partner: client.partner ?? {}
  };
}
function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}
function broadcast(payload, except = null, zone = "") {
  for (const [ws, client] of clients) {
    if (ws === except || ws.readyState !== WebSocket.OPEN || !client.ready) continue;
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

wss.on("connection", (ws) => {
  const client = {
    id: crypto.randomUUID(),
    ready: false,
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
    lastChatAt: 0
  };
  clients.set(ws, client);
  send(ws, { type: "welcome", id: client.id });

  ws.on("message", (buffer) => {
    if (buffer.length > MAX_PACKET) return;
    let msg;
    try { msg = JSON.parse(buffer.toString("utf8")); } catch { return; }
    if (!msg || typeof msg !== "object") return;

    if (msg.type === "hello") {
      const wasReady = client.ready;
      const oldZone = client.zone;
      client.name = cleanText(msg.name) || "Tamer";
      client.zone = cleanText(msg.zone, 40) || "file_island";
      client.position = normalizeVector(msg.position, client.position);
      applyAppearance(client, msg);
      client.ready = true;

      if (!wasReady || oldZone !== client.zone) {
        if (wasReady && oldZone !== client.zone) {
          broadcast({ type: "leave", id: client.id }, ws, oldZone);
        }
        emitExistingPlayers(ws, client);
        broadcast(playerPayload("join", client), ws, client.zone);
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
      broadcast({ type: "chat", id: client.id, name: client.name, zone: client.zone, text }, null, client.zone);
    }
  });

  ws.on("close", () => {
    const wasReady = client.ready;
    clients.delete(ws);
    if (wasReady) {
      broadcast({ type: "leave", id: client.id }, null, client.zone);
      broadcastOnlineCounts();
    }
  });
  ws.on("error", () => {});
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Prism Tamer Online Server listening on :${PORT}`);
});
