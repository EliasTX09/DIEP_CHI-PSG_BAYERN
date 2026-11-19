// Live-Pruefung eines ECHTEN Supabase-Projekts - genau die Wege, die das Spiel benutzt.
// Laeuft nur auf Knopfdruck (Actions -> Build Android APK -> Run workflow -> "Live-Backend pruefen"),
// nie bei normalen Pushes. Braucht Node 22 (fetch + WebSocket eingebaut), keine Pakete.
//
// Zugang: SUPABASE_URL / SUPABASE_ANON_KEY aus der Umgebung (GitHub-Secrets), sonst aus config/backend.cfg.
// Der Schluessel wird nie ausgegeben.
//
// Jeder Lauf legt zwei Gast-Accounts an ("CI Test A/B"); die kann man im Supabase-Dashboard unter
// Authentication -> Users loeschen. Die Test-Lobby wird am Ende wieder entfernt.
import { readFileSync } from "node:fs";

const TIMEOUT_MS = 20000;
let failed = 0;

function ok(name, detail = "") { console.log(`[LIVE] OK   ${name}${detail ? " - " + detail : ""}`); }
function warn(name, detail) { console.log(`[LIVE] WARN ${name} - ${detail}`); }
function fail(name, detail) { failed++; console.log(`[LIVE][FAIL] ${name} - ${detail}`); }

function fromCfg(key) {
  try {
    const text = readFileSync(new URL("../../config/backend.cfg", import.meta.url), "utf8");
    const m = text.match(new RegExp(`^${key}="(.*)"\\s*$`, "m"));
    return m ? m[1].trim() : "";
  } catch { return ""; }
}

const BASE = (process.env.SUPABASE_URL || fromCfg("url")).trim().replace(/\/+$/, "");
const KEY = (process.env.SUPABASE_ANON_KEY || fromCfg("anon_key")).trim();
const SOURCE = process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY ? "GitHub-Secrets" : "config/backend.cfg";

if (!BASE.startsWith("https://") || BASE.includes("DEIN-PROJEKT") || KEY.length < 20 || KEY.startsWith("DEIN_")) {
  console.log("[LIVE][FAIL] Kein Backend eingetragen - erst Supabase einrichten (README, Abschnitt 1+2).");
  console.log("LIVE CHECK: FAIL");
  process.exit(1);
}
console.log(`[LIVE] Projekt: ${new URL(BASE).host} (Zugang aus ${SOURCE})`);

// --------------------------------------------------------------------------- HTTP wie im Spiel
async function call(method, path, { token = "", body, prefer = "" } = {}) {
  const headers = { apikey: KEY, "Content-Type": "application/json", Authorization: "Bearer " + (token || KEY) };
  if (prefer) headers.Prefer = prefer;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 12000);
  try {
    const r = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), signal: ctrl.signal });
    const text = await r.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text; }
    return { status: r.status, ok: r.ok, data };
  } catch (e) {
    return { status: 0, ok: false, data: { message: String(e && e.message || e) } };
  } finally {
    clearTimeout(timer);
  }
}

function msg(r) {
  const d = r.data || {};
  return `HTTP ${r.status}: ${typeof d === "string" ? d.slice(0, 160) : (d.msg || d.message || d.error_description || d.error || JSON.stringify(d).slice(0, 160))}`;
}

function schemaHint(r) {
  const d = r.data || {};
  const code = typeof d === "object" ? String(d.code || "") : "";
  if (r.status === 404 || code === "42P01" || code === "PGRST205" || code === "PGRST202") {
    return " -> Schema fehlt: supabase_schema.sql im SQL-Editor ausfuehren";
  }
  return "";
}

// --------------------------------------------------------------------------- 1. Auth-Einstellungen
const settings = await call("GET", "/auth/v1/settings");
if (!settings.ok) {
  fail("Projekt erreichbar", msg(settings) + (settings.status === 401 ? " -> anon-Key falsch?" : ""));
} else {
  const s = settings.data || {};
  const anonOn = s.external && s.external.anonymous_users;
  ok("Projekt erreichbar", "Auth-Server antwortet");
  if (anonOn === false) warn("Gast-Login", "laut Einstellungen AUS -> Authentication -> Sign In / Providers -> 'Allow anonymous sign-ins'");
  if (s.disable_signup === true) warn("Registrierung", "neue Anmeldungen sind abgeschaltet (Allow new users to sign up)");
  console.log(`[LIVE] Info: E-Mail-Bestaetigung ${s.mailer_autoconfirm ? "aus (Konten sofort aktiv)" : "an (Portal-Registrierung braucht eine Bestaetigungs-Mail)"}`);
}

// --------------------------------------------------------------------------- 2. Gast-Login wie im Spiel
async function guest(name) {
  const r = await call("POST", "/auth/v1/signup", { body: { data: { device_id: "ci-live-check", name } } });
  if (!r.ok || !r.data || !r.data.access_token) {
    const d = JSON.stringify(r.data || "").toLowerCase();
    const hint = d.includes("anonymous") ? " -> Gast-Login einschalten: Authentication -> Sign In / Providers -> 'Allow anonymous sign-ins'" : "";
    fail(`Gast-Login ${name}`, msg(r) + hint);
    return null;
  }
  return { id: r.data.user.id, token: r.data.access_token, name };
}

const a = await guest("CI Test A");
if (a) ok("Gast-Login (anonym, wie beim ersten Spielstart)", "anon-Key funktioniert auch als Bearer");
const b = a ? await guest("CI Test B") : null;

let lobbyCode = "";
if (a && b) {
  // ------------------------------------------------------------------------- 3. Profil + RLS
  const prof = await call("GET", `/rest/v1/profiles?id=eq.${a.id}&select=id,username,friend_code`, { token: a.token });
  if (prof.ok && Array.isArray(prof.data) && prof.data.length === 1 && prof.data[0].username === "CI Test A") {
    ok("Profil automatisch angelegt (Trigger) und lesbar", `Freundescode ${prof.data[0].friend_code}`);
  } else {
    fail("Profil automatisch angelegt", msg(prof) + schemaHint(prof));
  }
  const foreign = await call("GET", `/rest/v1/profiles?id=eq.${a.id}&select=id,save`, { token: b.token });
  if (foreign.ok && Array.isArray(foreign.data) && foreign.data.length === 0) ok("RLS: fremder Spielstand bleibt privat");
  else fail("RLS: fremder Spielstand bleibt privat", foreign.ok ? `B sieht ${foreign.data.length} Zeile(n) von A` : msg(foreign));
  const nologin = await call("GET", "/rest/v1/profiles?select=id&limit=1");
  if ((nologin.ok && Array.isArray(nologin.data) && nologin.data.length === 0) || nologin.status === 401) ok("RLS: ohne Login keine Profile");
  else fail("RLS: ohne Login keine Profile", nologin.ok ? `${nologin.data.length} Zeile(n) sichtbar` : msg(nologin));

  // ------------------------------------------------------------------------- 4. Lobby wie im Spiel
  const chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  lobbyCode = Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
  const row = { code: lobbyCode, host_id: a.id, world: "emerald", rounds: 3, is_public: false, status: "open", player_count: 1 };
  const ins = await call("POST", "/rest/v1/lobbies", { token: a.token, body: row, prefer: "return=minimal" });
  if (!ins.ok) {
    fail("Lobby anlegen", msg(ins) + schemaHint(ins));
    lobbyCode = "";
  } else {
    const look = await call("GET", `/rest/v1/lobbies?code=eq.${lobbyCode}&select=*`, { token: b.token });
    if (look.ok && Array.isArray(look.data) && look.data.length === 1) ok("Lobby anlegen und per Code finden", `Code ${lobbyCode}`);
    else fail("Lobby per Code finden", msg(look));
  }

  // ------------------------------------------------------------------------- 5. Echtzeit (Presence + Broadcast)
  const rt = await realtimeCheck(lobbyCode || "ZZZZ", a, b);
  if (rt.joined) ok("Echtzeit: beide Spieler im Lobby-Kanal");
  else fail("Echtzeit: Kanal beitreten", rt.error || "keine Antwort");
  if (rt.joined) {
    if (rt.presence) ok("Echtzeit: Presence (Spielerliste der Lobby)");
    else fail("Echtzeit: Presence", "A hat B nicht in der Spielerliste gesehen");
    if (rt.broadcast) ok("Echtzeit: Broadcast (Schuesse/Positionen)");
    else fail("Echtzeit: Broadcast", "Nachricht von B kam bei A nicht an");
  }

  // ------------------------------------------------------------------------- 6. Spiel-Code-Funktion + Speicher
  const rpc = await call("POST", "/rest/v1/rpc/redeem_game_link_code", { token: a.token, body: { p_code: "ZZZZZZZZ" } });
  const rpcText = JSON.stringify(rpc.data || "").toLowerCase();
  if (rpcText.includes("invalid or expired code")) ok("Spiel-Code-Funktion vorhanden", "unbekannter Code wird abgelehnt");
  else fail("Spiel-Code-Funktion", msg(rpc) + schemaHint(rpc));
  const obj = await call("GET", "/storage/v1/object/public/avatars/ci-live-check-gibt-es-nicht.png");
  const om = JSON.stringify(obj.data || "").toLowerCase();
  if (om.includes("bucket not found")) fail("Speicher-Bucket 'avatars'", "fehlt -> supabase_schema.sql erneut ausfuehren");
  else if (om.includes("object not found") || obj.status === 404 || obj.status === 400) ok("Speicher-Bucket 'avatars' vorhanden");
  else warn("Speicher-Bucket 'avatars'", "Antwort nicht eindeutig: " + msg(obj));

  // ------------------------------------------------------------------------- Aufraeumen
  if (lobbyCode) {
    const del = await call("DELETE", `/rest/v1/lobbies?code=eq.${lobbyCode}`, { token: a.token });
    if (!del.ok) warn("Test-Lobby entfernen", msg(del));
  }
  await call("POST", "/auth/v1/logout?scope=local", { token: a.token, body: {} });
  await call("POST", "/auth/v1/logout?scope=local", { token: b.token, body: {} });
}

console.log("");
console.log(`LIVE CHECK: ${failed === 0 && a && b ? "PASS" : "FAIL"}`);
process.exit(failed === 0 && a && b ? 0 : 1);

// --------------------------------------------------------------------------- Realtime-Helfer
// Gleiches Protokoll wie NetworkManager.gd (_open_channel / _poll_socket): vsn 1.0.0, JSON-Objekte.
function realtimeCheck(code, a, b) {
  const topic = "realtime:golf-lobby-" + code;
  const wsUrl = `${BASE.replace("https://", "wss://")}/realtime/v1/websocket?apikey=${encodeURIComponent(KEY)}&vsn=1.0.0`;
  return new Promise((resolve) => {
    const state = { joined: false, presence: false, broadcast: false, error: "" };
    const joined = { a: false, b: false };
    const sockets = [];
    let ref = 0;
    let sentPing = false;
    const finish = () => {
      clearTimeout(timer);
      for (const s of sockets) { try { s.close(); } catch {} }
      resolve(state);
    };
    const timer = setTimeout(() => { if (!state.error) state.error = "Zeitlimit (20 s)"; finish(); }, TIMEOUT_MS);
    const send = (ws, event, payload, t = topic) => ws.send(JSON.stringify({ topic: t, event, payload, ref: String(++ref), join_ref: "1" }));
    const open = (who, user) => {
      let ws;
      try { ws = new WebSocket(wsUrl); } catch (e) { state.error = "WebSocket: " + e.message; finish(); return null; }
      sockets.push(ws);
      ws.addEventListener("open", () => send(ws, "phx_join", {
        config: { broadcast: { ack: false, self: false }, presence: { key: user.id }, postgres_changes: [], private: false },
        access_token: user.token,
      }));
      ws.addEventListener("error", () => { state.error = state.error || "WebSocket-Fehler (Realtime erreichbar?)"; });
      ws.addEventListener("message", (ev) => {
        let m;
        try { m = JSON.parse(String(ev.data)); } catch { return; }
        if (m.topic !== topic) return;
        const p = m.payload || {};
        if (m.event === "phx_reply" && !joined[who]) {
          if (p.status === "ok") {
            joined[who] = true;
            send(ws, "presence", { type: "presence", event: "track", payload: { id: user.id, name: user.name } });
            if (joined.a && joined.b) state.joined = true;
          } else {
            state.error = `Beitritt abgelehnt (${who}): ${JSON.stringify(p.response || p).slice(0, 160)}`;
            finish();
          }
        } else if (who === "a" && (m.event === "presence_state" || m.event === "presence_diff")) {
          const keys = Object.keys(m.event === "presence_state" ? p : (p.joins || {}));
          if (keys.includes(b.id)) state.presence = true;
        } else if (who === "a" && m.event === "broadcast" && p.event === "g") {
          state.broadcast = true;
        } else if (m.event === "phx_error" || m.event === "phx_close") {
          state.error = state.error || `Kanal geschlossen (${who})`;
        }
        if (state.joined && state.presence && !sentPing) {
          sentPing = true;
          send(sockets[1], "broadcast", { type: "broadcast", event: "g", payload: { e: "ping", d: { n: 1 } } });
        }
        if (state.joined && state.presence && state.broadcast) finish();
      });
      return ws;
    };
    open("a", a);
    setTimeout(() => open("b", b), 400);
  });
}
