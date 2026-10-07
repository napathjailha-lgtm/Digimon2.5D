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
const TRADE_INVITE_TTL_MS = 30_000;
const MAX_TRADE_ITEMS = 8;
const GUILD_DATA_PATH =
  process.env.GUILD_DATA_PATH ||
  (existsSync("/data") ? "/data/guilds.json" : "./data/guilds.json");

const clients = new Map();
const guildInvites = new Map();
const tradeInvites = new Map();
const tradeSessions = new Map();
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


function cleanTradeOffer(raw) {
  const itemTotals = new Map();
  if (Array.isArray(raw?.items)) {
    for (const entry of raw.items.slice(0, MAX_TRADE_ITEMS * 2)) {
      const id = cleanText(entry?.id, 64);
      const quantity = Math.floor(safeNumber(entry?.quantity, 0, 0, 999));
      if (!id || quantity <= 0) continue;
      itemTotals.set(id, Math.min(999, (itemTotals.get(id) ?? 0) + quantity));
      if (itemTotals.size >= MAX_TRADE_ITEMS) break;
    }
  }
  return {
    items: Array.from(itemTotals.entries()).map(([id, quantity]) => ({
      id,
      quantity,
    })),
    bits: Math.floor(safeNumber(raw?.bits, 0, 0, 2_000_000_000)),
  };
}

function tradeParticipant(session, peerId) {
  return session?.participants?.find((part) => part.peerId === peerId) ?? null;
}

function tradeOtherParticipant(session, peerId) {
  return session?.participants?.find((part) => part.peerId !== peerId) ?? null;
}

function tradePayload(session, client) {
  const mine = tradeParticipant(session, client.id);
  const other = tradeOtherParticipant(session, client.id);
  return {
    trade_id: session.id,
    partner: {
      id: other?.peerId ?? "",
      name: other?.name ?? "ผู้เล่น",
    },
    your_offer: mine?.offer ?? { items: [], bits: 0 },
    their_offer: other?.offer ?? { items: [], bits: 0 },
    your_ready: mine?.ready === true,
    their_ready: other?.ready === true,
    your_confirmed: mine?.confirmed === true,
    their_confirmed: other?.confirmed === true,
    status: session.status,
  };
}

function sendTradeSnapshot(session) {
  for (const part of session.participants) {
    const live = onlineClientForPeer(part.peerId);
    if (live) send(live.ws, { type: "trade_snapshot", ...tradePayload(session, live.client) });
  }
}

function clearTradeSession(session) {
  if (!session) return;
  for (const part of session.participants) {
    const live = onlineClientForPeer(part.peerId);
    if (live && live.client.tradeId === session.id) {
      live.client.tradeId = "";
    }
  }
  tradeSessions.delete(session.id);
}

function closeTrade(session, message, success = false) {
  if (!session) return;
  for (const part of session.participants) {
    const live = onlineClientForPeer(part.peerId);
    if (live) {
      send(live.ws, {
        type: "trade_closed",
        trade_id: session.id,
        success,
        message: cleanText(message, 160),
      });
    }
  }
  clearTradeSession(session);
}

function requestTrade(ws, client, targetPeerId) {
  if (!client.ready || !client.characterKey) {
    send(ws, { type: "trade_feedback", message: "ยังไม่มีข้อมูลตัวละครออนไลน์", ok: false });
    return;
  }
  if (client.tradeId) {
    send(ws, { type: "trade_feedback", message: "คุณกำลังแลกเปลี่ยนอยู่แล้ว", ok: false });
    return;
  }

  const target = onlineClientForPeer(cleanText(targetPeerId, 80));
  if (!target || target.client.id === client.id) {
    send(ws, { type: "trade_feedback", message: "ไม่พบผู้เล่นที่ต้องการแลกเปลี่ยน", ok: false });
    return;
  }
  if (target.client.zone !== client.zone) {
    send(ws, { type: "trade_feedback", message: "ผู้เล่นไม่ได้อยู่ในแมพเดียวกันแล้ว", ok: false });
    return;
  }
  if (target.client.tradeId) {
    send(ws, { type: "trade_feedback", message: "ผู้เล่นนี้กำลังแลกเปลี่ยนกับคนอื่น", ok: false });
    return;
  }

  const now = Date.now();
  for (const [inviteId, invite] of tradeInvites) {
    if (invite.expiresAt <= now) {
      tradeInvites.delete(inviteId);
      continue;
    }
    if (invite.fromPeerId === client.id && invite.targetPeerId === target.client.id) {
      send(ws, { type: "trade_feedback", message: "ส่งคำขอแลกเปลี่ยนไปแล้ว กรุณารออีกฝ่าย", ok: false });
      return;
    }
  }

  const inviteId = crypto.randomUUID();
  tradeInvites.set(inviteId, {
    id: inviteId,
    fromPeerId: client.id,
    fromName: client.name,
    targetPeerId: target.client.id,
    expiresAt: now + TRADE_INVITE_TTL_MS,
  });
  send(target.ws, {
    type: "trade_invite",
    invite_id: inviteId,
    from_id: client.id,
    from_name: client.name,
    expires_in: Math.floor(TRADE_INVITE_TTL_MS / 1000),
  });
  send(ws, { type: "trade_feedback", message: `ส่งคำขอแลกเปลี่ยนให้ ${target.client.name} แล้ว`, ok: true });
}

function respondTradeInvite(ws, client, inviteId, accepted) {
  const id = cleanText(inviteId, 80);
  const invite = tradeInvites.get(id);
  if (!invite || invite.targetPeerId !== client.id) {
    send(ws, { type: "trade_feedback", message: "คำขอแลกเปลี่ยนหมดอายุหรือไม่ถูกต้อง", ok: false });
    return;
  }
  tradeInvites.delete(id);

  const inviter = onlineClientForPeer(invite.fromPeerId);
  if (!inviter || invite.expiresAt <= Date.now()) {
    send(ws, { type: "trade_feedback", message: "คำขอแลกเปลี่ยนหมดอายุแล้ว", ok: false });
    return;
  }
  if (!accepted) {
    send(ws, { type: "trade_feedback", message: "ปฏิเสธคำขอแลกเปลี่ยนแล้ว", ok: true });
    send(inviter.ws, { type: "trade_feedback", message: `${client.name} ปฏิเสธการแลกเปลี่ยน`, ok: false });
    return;
  }
  if (client.tradeId || inviter.client.tradeId) {
    send(ws, { type: "trade_feedback", message: "มีผู้เล่นกำลังแลกเปลี่ยนอยู่แล้ว", ok: false });
    return;
  }
  if (client.zone !== inviter.client.zone) {
    send(ws, { type: "trade_feedback", message: "ผู้เล่นไม่ได้อยู่ในแมพเดียวกันแล้ว", ok: false });
    return;
  }

  const tradeId = crypto.randomUUID();
  const session = {
    id: tradeId,
    status: "open",
    participants: [
      {
        peerId: inviter.client.id,
        name: inviter.client.name,
        offer: { items: [], bits: 0 },
        ready: false,
        confirmed: false,
        prepared: false,
      },
      {
        peerId: client.id,
        name: client.name,
        offer: { items: [], bits: 0 },
        ready: false,
        confirmed: false,
        prepared: false,
      },
    ],
  };
  tradeSessions.set(tradeId, session);
  inviter.client.tradeId = tradeId;
  client.tradeId = tradeId;

  send(inviter.ws, { type: "trade_open", ...tradePayload(session, inviter.client) });
  send(ws, { type: "trade_open", ...tradePayload(session, client) });
  sendTradeSnapshot(session);
}

function updateTradeOffer(ws, client, rawOffer) {
  const session = tradeSessions.get(client.tradeId);
  if (!session || session.status !== "open") {
    send(ws, { type: "trade_feedback", message: "ไม่พบ Trade session ที่แก้ไขได้", ok: false });
    return;
  }
  const mine = tradeParticipant(session, client.id);
  if (!mine) return;
  mine.offer = cleanTradeOffer(rawOffer);
  for (const part of session.participants) {
    part.ready = false;
    part.confirmed = false;
    part.prepared = false;
  }
  sendTradeSnapshot(session);
}

function setTradeReady(ws, client, ready) {
  const session = tradeSessions.get(client.tradeId);
  if (!session || session.status !== "open") return;
  const mine = tradeParticipant(session, client.id);
  if (!mine) return;
  mine.ready = ready === true;
  mine.confirmed = false;
  if (!mine.ready) {
    for (const part of session.participants) part.confirmed = false;
  }
  sendTradeSnapshot(session);
}

function confirmTrade(ws, client) {
  const session = tradeSessions.get(client.tradeId);
  if (!session || session.status !== "open") return;
  if (!session.participants.every((part) => part.ready === true)) {
    send(ws, { type: "trade_feedback", message: "ทั้งสองฝ่ายต้อง Ready ก่อน", ok: false });
    return;
  }
  const mine = tradeParticipant(session, client.id);
  if (!mine) return;
  mine.confirmed = true;
  sendTradeSnapshot(session);

  if (!session.participants.every((part) => part.confirmed === true)) return;

  session.status = "preparing";
  for (const part of session.participants) {
    part.prepared = false;
    const live = onlineClientForPeer(part.peerId);
    if (live) {
      const payload = tradePayload(session, live.client);
      send(live.ws, {
        type: "trade_prepare",
        trade_id: session.id,
        outgoing: payload.your_offer,
        incoming: payload.their_offer,
      });
    }
  }
}

function tradePrepareResult(ws, client, tradeId, ok, message) {
  const session = tradeSessions.get(cleanText(tradeId, 80));
  if (!session || session.id !== client.tradeId || session.status !== "preparing") return;
  const mine = tradeParticipant(session, client.id);
  if (!mine) return;

  if (ok !== true) {
    closeTrade(session, cleanText(message, 160) || `${client.name} ไม่พร้อมทำรายการ`, false);
    return;
  }
  mine.prepared = true;
  if (!session.participants.every((part) => part.prepared === true)) return;

  session.status = "committing";
  const commitTargets = [];
  for (const part of session.participants) {
    const live = onlineClientForPeer(part.peerId);
    if (!live) {
      closeTrade(session, "มีผู้เล่นหลุดจากระบบก่อนยืนยันรายการ", false);
      return;
    }
    commitTargets.push(live);
  }

  for (const live of commitTargets) {
    const payload = tradePayload(session, live.client);
    send(live.ws, {
      type: "trade_commit",
      trade_id: session.id,
      outgoing: payload.your_offer,
      incoming: payload.their_offer,
    });
  }
  // WebSocket preserves packet order: each client receives commit before completed.
  for (const live of commitTargets) {
    send(live.ws, {
      type: "trade_closed",
      trade_id: session.id,
      success: true,
      message: "แลกเปลี่ยนสำเร็จ",
    });
    live.client.tradeId = "";
  }
  tradeSessions.delete(session.id);
}

function cancelTrade(ws, client) {
  const session = tradeSessions.get(client.tradeId);
  if (!session) return;
  closeTrade(session, `${client.name} ยกเลิกการแลกเปลี่ยน`, false);
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
    tradeId: "",
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

    if (msg.type === "trade_request") {
      requestTrade(ws, client, msg.target_peer_id);
      return;
    }

    if (msg.type === "trade_invite_response") {
      respondTradeInvite(ws, client, msg.invite_id, msg.accept === true);
      return;
    }

    if (msg.type === "trade_offer") {
      updateTradeOffer(ws, client, msg.offer);
      return;
    }

    if (msg.type === "trade_ready") {
      setTradeReady(ws, client, msg.ready === true);
      return;
    }

    if (msg.type === "trade_confirm") {
      confirmTrade(ws, client);
      return;
    }

    if (msg.type === "trade_prepare_result") {
      tradePrepareResult(ws, client, msg.trade_id, msg.ok === true, msg.message);
      return;
    }

    if (msg.type === "trade_cancel") {
      cancelTrade(ws, client);
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

  ws.on("close", () => {
    const wasReady = client.ready;
    const guildId = guildIdForClient(client);
    if (client.tradeId) {
      const session = tradeSessions.get(client.tradeId);
      if (session) closeTrade(session, `${client.name} หลุดจากการแลกเปลี่ยน`, false);
    }
    for (const [inviteId, invite] of tradeInvites) {
      if (invite.fromPeerId === client.id || invite.targetPeerId === client.id) {
        tradeInvites.delete(inviteId);
      }
    }
    for (const [inviteId, invite] of guildInvites) {
      if (invite.fromPeerId === client.id || invite.targetPeerId === client.id) {
        guildInvites.delete(inviteId);
      }
    }
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
