import crypto from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { dirname } from "node:path";

const FORMAT = "prism-tamer-encrypted-json";
const VERSION = 1;
const ALGORITHM = "aes-256-gcm";

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function decodeEncryptionKey(raw) {
  const value = String(raw ?? "").trim();
  if (/^[a-f0-9]{64}$/i.test(value)) {
    return Buffer.from(value, "hex");
  }

  try {
    const decoded = Buffer.from(value, "base64");
    if (decoded.length === 32 && value.length >= 43) {
      return decoded;
    }
  } catch {
    // Fall through to the explicit error below.
  }

  throw new Error(
    "DATA_ENCRYPTION_KEY must be exactly 32 bytes (64 hex characters or base64)",
  );
}

function isEncryptedEnvelope(value) {
  return (
    value &&
    typeof value === "object" &&
    value.format === FORMAT &&
    value.version === VERSION &&
    value.algorithm === ALGORITHM &&
    typeof value.iv === "string" &&
    typeof value.tag === "string" &&
    typeof value.ciphertext === "string"
  );
}

export class EncryptedJsonStore {
  constructor({ path, name, defaultValue, key = process.env.DATA_ENCRYPTION_KEY }) {
    if (!path) throw new Error("EncryptedJsonStore requires path");
    if (!name) throw new Error("EncryptedJsonStore requires name");
    this.path = path;
    this.name = name;
    this.defaultValue = cloneJson(defaultValue);
    this.key = decodeEncryptionKey(key);
    this.aad = Buffer.from(`prism-tamer:${name}:v1`, "utf8");
  }

  load() {
    if (!existsSync(this.path)) {
      const initial = cloneJson(this.defaultValue);
      this.save(initial);
      return initial;
    }

    const text = readFileSync(this.path, "utf8");
    const parsed = JSON.parse(text);

    if (!isEncryptedEnvelope(parsed)) {
      // One-time migration path for the legacy plaintext JSON stores.
      const legacyValue = cloneJson(parsed);
      this.save(legacyValue);
      return legacyValue;
    }

    const iv = Buffer.from(parsed.iv, "base64");
    const tag = Buffer.from(parsed.tag, "base64");
    const ciphertext = Buffer.from(parsed.ciphertext, "base64");

    if (iv.length !== 12 || tag.length !== 16) {
      throw new Error(`Encrypted store ${this.name} has an invalid envelope`);
    }

    const decipher = crypto.createDecipheriv(ALGORITHM, this.key, iv);
    decipher.setAAD(this.aad);
    decipher.setAuthTag(tag);

    let plaintext;
    try {
      plaintext = Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]).toString("utf8");
    } catch {
      throw new Error(
        `Encrypted store ${this.name} could not be decrypted; refusing to reset data`,
      );
    }

    return JSON.parse(plaintext);
  }

  save(value) {
    const plaintext = Buffer.from(JSON.stringify(value), "utf8");
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv(ALGORITHM, this.key, iv);
    cipher.setAAD(this.aad);

    const ciphertext = Buffer.concat([
      cipher.update(plaintext),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    const envelope = {
      format: FORMAT,
      version: VERSION,
      algorithm: ALGORITHM,
      iv: iv.toString("base64"),
      tag: tag.toString("base64"),
      ciphertext: ciphertext.toString("base64"),
    };

    mkdirSync(dirname(this.path), { recursive: true });
    const temp = `${this.path}.tmp-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
    writeFileSync(temp, JSON.stringify(envelope), {
      encoding: "utf8",
      mode: 0o600,
    });
    renameSync(temp, this.path);
  }
}

export const encryptedJsonFormat = Object.freeze({
  format: FORMAT,
  version: VERSION,
  algorithm: ALGORITHM,
});
