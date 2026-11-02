// TikTok -> Bedrock bridge. Plain Node http, no framework needed.
// Binds to 127.0.0.1 only by default: never expose port 3001 to the internet.
// The Bedrock addon polls GET /events and drains the queue.
// POST /test-event is for simulated testing only: localhost, or a TEST_KEY
// header if TEST_KEY is set. It is NOT a way to fake a real TikTok event:
// simulated events are marked source:"simulated" in game announcements/logs.
const http = require("http");
const fs = require("fs");
const path = require("path");
const { startTikTokLive } = require("./tiktok");

const PORT = parseInt(process.env.BRIDGE_PORT || process.env.PORT || "3001", 10);
// On Render / a public host, HOST must be 0.0.0.0. Locally it defaults to localhost.
// Set BRIDGE_HOST explicitly to override. Render sets PORT automatically.
const HOST = process.env.BRIDGE_HOST || (process.env.RENDER ? "0.0.0.0" : "127.0.0.1");
const TEST_KEY = process.env.TEST_KEY || "";
// Optional: if POLL_KEY is set, GET /events requires ?key=<POLL_KEY>.
// Use this on a public bridge so a stranger who guesses the URL cannot
// drain (steal) your queued TikTok events. The addon URL must then include
// ?key=<POLL_KEY> (see addon/scripts/main.js). If POLL_KEY is unset,
// /events is open — only use that for local testing, never on a public host.
const POLL_KEY = process.env.POLL_KEY || "";
const TIKTOK_USERNAME = process.env.TIKTOK_USERNAME || "";

function loadConfig() {
  const p = path.join(__dirname, "config.json");
  return JSON.parse(fs.readFileSync(p, "utf8"));
}
let config;
try {
  config = loadConfig();
} catch (e) {
  console.error("Could not load bridge/config.json:", e.message);
  process.exit(1);
}

let queue = [];
let nextId = 1;
let totalLikes = 0;
let lastMilestoneAt = 0;
const lastSeen = {}; // cooldown key -> timestamp ms

function log(...args) {
  console.log(new Date().toISOString(), ...args);
}

function cooldownOk(key, seconds) {
  if (!seconds) return true;
  const now = Date.now();
  if (lastSeen[key] && now - lastSeen[key] < seconds * 1000) return false;
  lastSeen[key] = now;
  return true;
}

function pushEvent(event) {
  const item = {
    id: nextId++,
    source: event.source || "simulated",
    username: event.username || "a viewer",
    kind: event.kind || "event",
    label: event.label || event.kind || "event",
    actions: event.actions || [],
    receivedAt: new Date().toISOString(),
  };
  const max = config.defaults?.maxEventsPerPoll || 20;
  queue.push(item);
  if (queue.length > 200) queue.splice(0, queue.length - 200);
  log(`[queue] id=${item.id} source=${item.source} user=${item.username} kind=${item.kind} label=${item.label} actions=${item.actions.length}`);
  return item;
}

// Translate a raw TikTok-style event (live or simulated) into game actions
// using config.json. Returns the queued item, or null if dropped by cooldown.
function enqueue(raw) {
  const source = raw.source || "simulated";
  const username = raw.username || "a viewer";

  if (raw.kind === "like") {
    const likes = raw.likes || 1;
    totalLikes += likes;
    const every = config.likeMilestones?.everyLikes || 100;
    const milestones = Math.floor(totalLikes / every);
    if (milestones > lastMilestoneAt) {
      lastMilestoneAt = milestones;
      if (!cooldownOk("likeMilestone", config.cooldownsSeconds?.likeMilestone || 10)) return null;
      return pushEvent({
        source, username, kind: "like",
        label: `${every * milestones} total likes`,
        actions: config.likeMilestones.actions || [],
      });
    }
    return null;
  }

  if (raw.kind === "gift") {
    const name = (raw.giftName || "").toLowerCase().replace(/[^a-z0-9]/g, "");
    if (!cooldownOk("gift:" + name, config.cooldownsSeconds?.gift || 3)) return null;
    const actions = config.gifts?.[name] || config.gifts?.default || [];
    return pushEvent({ source, username, kind: "gift", label: `gift: ${raw.giftName || name}`, actions });
  }

  if (raw.kind === "chat") {
    const msg = (raw.message || "").trim();
    const key = msg.split(/\s+/)[0].toLowerCase();
    const actions = config.chatCommands?.[key];
    if (!actions) return null;
    if (!cooldownOk("chat:" + key, config.cooldownsSeconds?.chatCommand || 5)) return null;
    return pushEvent({ source, username, kind: "chat", label: `chat command ${key}`, actions });
  }

  if (raw.kind === "follow") {
    return pushEvent({ source, username, kind: "follow", label: "follow", actions: [{ type: "say", text: `${username} just followed! Welcome!` }] });
  }
  if (raw.kind === "share") {
    return pushEvent({ source, username, kind: "share", label: "share", actions: [{ type: "say", text: `${username} shared the live!` }] });
  }
  return null;
}

function isLocalhost(req) {
  const a = req.socket.remoteAddress || "";
  return a === "127.0.0.1" || a === "::1" || a === "::ffff:127.0.0.1";
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => { data += c; if (data.length > 100000) req.destroy(); });
    req.on("end", () => {
      if (!data) return resolve({});
      try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
    });
    req.on("error", reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  res.setHeader("Content-Type", "application/json");

  if (req.method === "GET" && url.pathname === "/health") {
    res.end(JSON.stringify({ ok: true, queued: queue.length, totalLikes, liveEnabled: !!TIKTOK_USERNAME, liveUsername: TIKTOK_USERNAME || null }));
    return;
  }
  if (req.method === "GET" && url.pathname === "/") {
    res.end(JSON.stringify({ service: "tiktok-bedrock-bridge", eventsEndpoint: "GET /events (polled by the Bedrock addon)", testEndpoint: "POST /test-event (localhost only, simulated events)", liveEnabled: !!TIKTOK_USERNAME }));
    return;
  }
  if (req.method === "GET" && url.pathname === "/events") {
    if (POLL_KEY && url.searchParams.get("key") !== POLL_KEY) {
      res.statusCode = 403;
      res.end(JSON.stringify({ error: "poll key required" }));
      return;
    }
    const events = queue.splice(0, config.defaults?.maxEventsPerPoll || 20);
    if (events.length) log(`[drain] addon polled ${events.length} event(s)`);
    res.end(JSON.stringify({ events }));
    return;
  }
  if (req.method === "POST" && url.pathname === "/test-event") {
    const keyOk = TEST_KEY && req.headers["x-test-key"] === TEST_KEY;
    if (!isLocalhost(req) && !keyOk) {
      res.statusCode = 403;
      res.end(JSON.stringify({ error: "test-event is localhost-only unless TEST_KEY matches" }));
      return;
    }
    let body;
    try { body = await readBody(req); } catch (e) {
      res.statusCode = 400; res.end(JSON.stringify({ error: "invalid JSON" })); return;
    }
    // Direct action injection (addon testing only, still marked simulated).
    if (body.action || body.actions) {
      const item = pushEvent({
        source: "simulated", username: body.username || "TestUser",
        kind: body.kind || "test", label: body.label || "simulated test event",
        actions: body.actions || [body.action],
      });
      res.end(JSON.stringify({ ok: true, queued: item }));
      return;
    }
    // TikTok-style simulated event, mapped through config.json.
    const kind = (body.event || body.kind || "").toLowerCase();
    const mapped = enqueue({ source: "simulated", username: body.username || "TestUser", kind, message: body.message || body.comment || "", giftName: body.giftName || body.gift || "", likes: body.likes || 1, totalLikes: body.totalLikes || null });
    res.end(JSON.stringify({ ok: true, queued: mapped, totalLikes }));
    return;
  }
  res.statusCode = 404;
  res.end(JSON.stringify({ error: "not found" }));
});

server.listen(PORT, HOST, () => {
  log(`Bridge listening on http://${HOST}:${PORT} (public if HOST=0.0.0.0; poll key ${POLL_KEY ? "ENABLED" : "not set — local testing only"})`);
  log(`Live TikTok: ${TIKTOK_USERNAME ? "ENABLED for @" + TIKTOK_USERNAME : "DISABLED (set TIKTOK_USERNAME to enable; test events still work)"}`);
  log("Config loaded from bridge/config.json. Edit it, then restart the bridge.");
  startTikTokLive(TIKTOK_USERNAME, enqueue, log);
});
