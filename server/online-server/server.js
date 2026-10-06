import http from "node:http";
import crypto from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";

const PORT = Number(process.env.PORT || 8787);
const MAX_PACKET = 4096;
const MAX_CHAT = 160;
const clients = new Map();

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, players: clients.size }));
    return;
  }
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Prism Tamer Online Server");
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

function cleanText(value, max = 24) {
  return String(value ?? "").replace(/[\r\n\t]/g, " ").trim().slice(0, max);
}
function safeNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(-20000, Math.min(20000, n)) : fallback;
}
function normalizePosition(raw) {
  return { x: safeNumber(raw?.x), y: safeNumber(raw?.y) };
}
function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}
function broadcast(payload, except = null, zone = "") {
  for (const [ws, client] of clients) {
    if (ws === except || ws.readyState !== WebSocket.OPEN) continue;
    if (zone && client.zone !== zone) continue;
    send(ws, payload);
  }
}
function emitExistingPlayers(ws, self) {
  for (const [otherWs, other] of clients) {
    if (otherWs === ws || other.zone !== self.zone) continue;
    send(ws, {
      type: "join",
      id: other.id,
      name: other.name,
      zone: other.zone,
      position: other.position,
      velocity: other.velocity,
      facing: other.facing
    });
  }
}

wss.on("connection", (ws) => {
  const client = {
    id: crypto.randomUUID(),
    name: "Tamer",
    zone: "file_island",
    position: { x: 0, y: 0 },
    velocity: { x: 0, y: 0 },
    facing: "down",
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
      client.name = cleanText(msg.name) || "Tamer";
      client.zone = cleanText(msg.zone, 40) || "file_island";
      client.position = normalizePosition(msg.position);
      emitExistingPlayers(ws, client);
      broadcast({
        type: "join", id: client.id, name: client.name, zone: client.zone,
        position: client.position, velocity: client.velocity, facing: client.facing
      }, ws, client.zone);
      return;
    }

    if (msg.type === "state") {
      const now = Date.now();
      if (now - client.lastStateAt < 40) return;
      client.lastStateAt = now;
      const oldZone = client.zone;
      client.zone = cleanText(msg.zone, 40) || client.zone;
      client.name = cleanText(msg.name) || client.name;
      client.position = normalizePosition(msg.position);
      client.velocity = normalizePosition(msg.velocity);
      const facing = cleanText(msg.facing, 8);
      client.facing = ["up", "down", "left", "right"].includes(facing) ? facing : client.facing;
      if (oldZone !== client.zone) {
        broadcast({ type: "leave", id: client.id }, ws, oldZone);
        emitExistingPlayers(ws, client);
        broadcast({ type: "join", id: client.id, name: client.name, zone: client.zone, position: client.position }, ws, client.zone);
      }
      broadcast({
        type: "state", id: client.id, name: client.name, zone: client.zone,
        position: client.position, velocity: client.velocity, facing: client.facing
      }, ws, client.zone);
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
    clients.delete(ws);
    broadcast({ type: "leave", id: client.id }, null, client.zone);
  });
  ws.on("error", () => {});
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Prism Tamer Online Server listening on :${PORT}`);
});
