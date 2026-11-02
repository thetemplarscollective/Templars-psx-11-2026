// TikTok Live listener - username-only, NEVER a password.
// This module is intentionally separate from server.js so the bridge still
// runs (with simulated / test events) even if the TikTok library is missing
// or TikTok changes its unofficial live API.
//
// How it works, when enabled:
//   TIKTOK_USERNAME=someone node server.js
// The open-source tiktok-live-connector library opens TikTok's public
// webcast websocket for that username's live room. It does not log in as
// the streamer. If the streamer is not live, there is no room to connect to
// and no events will arrive - that is expected, not an error in the addon.
//
// If the library cannot be loaded, start() logs a clear warning and returns
// false. It never pretends a live connection exists.

function startTikTokLive(username, enqueue, log) {
  if (!username) {
    log("[tiktok] LIVE DISABLED: set TIKTOK_USERNAME to enable live events. Test events still work.");
    return null;
  }
  let WebcastPushConnection;
  try {
    // v2 of the library moved the old class to the /legacy entry point.
    // Verified 2026-11-02 with tiktok-live-connector 2.5.0: the legacy
    // constructor needs an options object as the second argument.
    ({ WebcastPushConnection } = require("tiktok-live-connector/legacy"));
  } catch (e) {
    log("[tiktok] LIVE STUBBED: tiktok-live-connector is not installed. Run 'npm install' in bridge/ first, then restart. No live connection was made.");
    log("[tiktok] Stub reason: " + e.message);
    return null;
  }

  const connection = new WebcastPushConnection(username, { enableExtendedGiftInfo: true });

  connection.connect().then((state) => {
    log(`[tiktok] LIVE CONNECTED to @${username} (room ${state.roomId}). Real TikTok events will now queue.`);
  }).catch((err) => {
    log(`[tiktok] LIVE CONNECT FAILED for @${username}: ${err.message || err}. Is that account live right now?`);
  });

  connection.on("chat", (data) => {
    enqueue({ kind: "chat", username: data.nickname || data.uniqueId || "viewer", message: data.comment || "", source: "live" });
  });
  connection.on("gift", (data) => {
    const giftName = (data.giftName || data.extendedGiftInfo?.name || "").toLowerCase();
    enqueue({ kind: "gift", username: data.nickname || data.uniqueId || "viewer", giftName, count: data.repeatCount || 1, source: "live" });
  });
  connection.on("like", (data) => {
    enqueue({ kind: "like", username: data.nickname || data.uniqueId || "viewer", likes: data.likeCount || 1, totalLikes: data.totalLikeCount || null, source: "live" });
  });
  connection.on("follow", (data) => {
    enqueue({ kind: "follow", username: data.nickname || data.uniqueId || "viewer", source: "live" });
  });
  connection.on("share", (data) => {
    enqueue({ kind: "share", username: data.nickname || data.uniqueId || "viewer", source: "live" });
  });
  connection.on("disconnected", () => {
    log("[tiktok] LIVE DISCONNECTED. The bridge keeps running; restart it to reconnect.");
  });
  connection.on("error", (err) => {
    log("[tiktok] live error: " + (err.message || err));
  });

  return connection;
}

module.exports = { startTikTokLive };
