// Golf Battle 3D – Account-Portal (GitHub Pages).
// Spricht direkt mit der Supabase-REST-API (GoTrue, PostgREST, Storage) – ohne externe Bibliothek.
// Alle Nutzerdaten werden per textContent eingesetzt (nie als HTML).
"use strict";

(function () {
  const cfg = window.GOLF_CONFIG || {};
  const BASE = String(cfg.supabaseUrl || "").replace(/\/+$/, "");
  const KEY = String(cfg.anonKey || "");
  const SESSION_KEY = "golfbattle3d.session";
  const CODE_TTL_MS = 10 * 60 * 1000;
  const AVATAR_SIZE = 256;
  const MAX_UPLOAD_BYTES = 512 * 1024;

  const $ = (id) => document.getElementById(id);
  let session = null;   // {access_token, refresh_token, expires_at, user:{id,email}}
  let profile = null;
  let codeTimer = null;

  function configured() {
    return /^https:\/\//.test(BASE) && !BASE.includes("DEIN-PROJEKT") && KEY.length > 20 && !KEY.startsWith("DEIN_");
  }

  // ------------------------------------------------------------------ Hilfen
  function show(el, visible) { el.classList.toggle("hidden", !visible); }

  function toast(text, kind) {
    const t = $("toast");
    t.textContent = text;
    t.className = "toast show" + (kind ? " " + kind : "");
    clearTimeout(toast._h);
    toast._h = setTimeout(() => { t.className = "toast"; }, 3200);
  }

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function errorText(data, status) {
    if (data && typeof data === "object") {
      const msg = data.msg || data.message || data.error_description || data.error;
      if (msg) return translate(String(msg));
    }
    return status ? "Fehler " + status : "Keine Verbindung zum Server.";
  }

  function translate(msg) {
    const m = msg.toLowerCase();
    if (m.includes("invalid login credentials")) return "E-Mail oder Passwort ist falsch.";
    if (m.includes("email not confirmed")) return "Bitte bestätige zuerst deine E-Mail-Adresse.";
    if (m.includes("already registered") || m.includes("already been registered")) return "Diese E-Mail ist schon registriert.";
    if (m.includes("password should be")) return "Das Passwort ist zu kurz (mind. 6 Zeichen).";
    if (m.includes("rate limit")) return "Zu viele Versuche – bitte kurz warten.";
    return msg;
  }

  async function api(method, path, body, opts) {
    opts = opts || {};
    const headers = { apikey: KEY, "Content-Type": "application/json" };
    const token = opts.token !== undefined ? opts.token : (session ? session.access_token : null);
    headers.Authorization = "Bearer " + (token || KEY);
    if (opts.prefer) headers.Prefer = opts.prefer;
    Object.assign(headers, opts.headers || {});
    let res;
    try {
      res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : (opts.raw ? body : JSON.stringify(body)) });
    } catch (e) {
      return { ok: false, status: 0, data: null, message: "Keine Verbindung zum Server." };
    }
    let data = null;
    const text = await res.text();
    if (text) { try { data = JSON.parse(text); } catch (e) { data = text; } }
    if (res.status === 401 && !opts.noRefresh && session && session.refresh_token) {
      if (await refresh()) return api(method, path, body, Object.assign({}, opts, { noRefresh: true, token: undefined }));
    }
    return { ok: res.ok, status: res.status, data, message: res.ok ? "" : errorText(data, res.status) };
  }

  // ------------------------------------------------------------------ Session
  function saveSession(s) {
    session = s;
    try {
      if (s) localStorage.setItem(SESSION_KEY, JSON.stringify(s));
      else localStorage.removeItem(SESSION_KEY);
    } catch (e) { /* privater Modus: Session gilt nur fuer diesen Tab */ }
  }

  function loadSession() {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  function sessionFrom(data) {
    if (!data || !data.access_token || !data.refresh_token || !data.user) return null;
    return {
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      expires_at: Date.now() + (Number(data.expires_in) || 3600) * 1000,
      user: { id: data.user.id, email: data.user.email || "", is_anonymous: !!data.user.is_anonymous }
    };
  }

  async function refresh() {
    if (!session || !session.refresh_token) return false;
    const r = await api("POST", "/auth/v1/token?grant_type=refresh_token", { refresh_token: session.refresh_token }, { token: null, noRefresh: true });
    const s = r.ok ? sessionFrom(r.data) : null;
    saveSession(s);
    return !!s;
  }

  async function passwordLogin(email, password) {
    const r = await api("POST", "/auth/v1/token?grant_type=password", { email, password }, { token: null, noRefresh: true });
    return { ok: r.ok && !!sessionFrom(r.data), session: sessionFrom(r.data), message: r.message };
  }

  // Rueckkehr aus Bestaetigungs-/Reset-Mail: Tokens stehen im URL-Fragment
  function sessionFromUrlFragment() {
    if (!location.hash || location.hash.length < 2) return null;
    const p = new URLSearchParams(location.hash.slice(1));
    const at = p.get("access_token");
    const rt = p.get("refresh_token");
    const type = p.get("type") || "";
    history.replaceState(null, "", location.pathname + location.search);
    if (!at || !rt) return null;
    let uid = "";
    try { uid = JSON.parse(atob(at.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))).sub || ""; } catch (e) { uid = ""; }
    if (!uid) return null;
    return { type, session: { access_token: at, refresh_token: rt, expires_at: Date.now() + (Number(p.get("expires_in")) || 3600) * 1000, user: { id: uid, email: "" } } };
  }

  // ------------------------------------------------------------------ Ansichten
  function render() {
    const loggedIn = !!session;
    show($("authView"), !loggedIn);
    show($("profileView"), loggedIn);
    show($("logoutBtn"), loggedIn);
    if (loggedIn) loadProfile();
  }

  function setTab(tab) {
    document.querySelectorAll(".tab").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));
    show($("loginForm"), tab === "login");
    show($("registerForm"), tab === "register");
  }

  function avatarUrl(path) {
    return BASE + "/storage/v1/object/public/avatars/" + path.split("/").map(encodeURIComponent).join("/");
  }

  function validAvatarPath(path, uid) {
    return typeof path === "string" && new RegExp("^" + uid + "/avatar-[0-9]{1,16}\\.(png|jpg|jpeg|webp)$").test(path);
  }

  function makeAvatar(name, path, uid) {
    const wrap = el("div", "mini-avatar");
    if (path && validAvatarPath(path, uid)) {
      const img = el("img");
      img.alt = "";
      img.src = avatarUrl(path);
      wrap.appendChild(img);
    } else {
      wrap.textContent = (name || "?").charAt(0).toUpperCase();
    }
    return wrap;
  }

  async function loadProfile() {
    const uid = session.user.id;
    const r = await api("GET", "/rest/v1/profiles?id=eq." + encodeURIComponent(uid) + "&select=id,username,friend_code,trophies,avatar_path");
    if (!r.ok) { toast(r.message, "error"); return; }
    profile = (r.data && r.data[0]) || { id: uid, username: "", friend_code: "", trophies: 0, avatar_path: null };
    $("profileName").textContent = profile.username || "Spieler";
    $("profileTrophies").textContent = String(profile.trophies || 0);
    $("profileCode").textContent = profile.friend_code || "—";
    $("profileEmail").textContent = session.user.email || "";
    $("nameInput").value = profile.username || "";
    const img = $("avatarImg");
    if (profile.avatar_path && validAvatarPath(profile.avatar_path, uid)) {
      img.src = avatarUrl(profile.avatar_path) + "?v=" + Date.now();
      show(img, true);
      show($("avatarInitial"), false);
    } else {
      show(img, false);
      show($("avatarInitial"), true);
      $("avatarInitial").textContent = (profile.username || "?").charAt(0).toUpperCase();
    }
    loadFriends();
  }

  // ------------------------------------------------------------------ Login / Registrieren / Passwort
  async function onLogin(ev) {
    ev.preventDefault();
    const f = ev.target;
    const res = await passwordLogin(f.email.value.trim(), f.password.value);
    if (!res.ok) { toast(res.message || "Anmeldung fehlgeschlagen.", "error"); return; }
    f.password.value = "";
    saveSession(res.session);
    toast("Willkommen zurück!", "ok");
    render();
  }

  async function onRegister(ev) {
    ev.preventDefault();
    const f = ev.target;
    const name = f.name.value.trim();
    if (name.length < 3 || name.length > 16 || /[<>]/.test(name)) { toast("Der Name braucht 3 bis 16 Zeichen.", "error"); return; }
    const redirect = encodeURIComponent(location.origin + location.pathname);
    const r = await api("POST", "/auth/v1/signup?redirect_to=" + redirect,
      { email: f.email.value.trim(), password: f.password.value, data: { name } }, { token: null, noRefresh: true });
    if (!r.ok) { toast(r.message, "error"); return; }
    f.password.value = "";
    const s = sessionFrom(r.data);
    if (s) {
      saveSession(s);
      toast("Account erstellt!", "ok");
      render();
    } else {
      toast("Fast geschafft: Bitte bestätige die E-Mail und logge dich dann ein.", "ok");
      setTab("login");
    }
  }

  async function onForgot() {
    const email = $("loginForm").email.value.trim();
    if (!email) { toast("Bitte zuerst die E-Mail-Adresse eintragen.", "error"); return; }
    const redirect = encodeURIComponent(location.origin + location.pathname);
    const r = await api("POST", "/auth/v1/recover?redirect_to=" + redirect, { email }, { token: null, noRefresh: true });
    toast(r.ok ? "Falls die Adresse registriert ist, kommt gleich eine Mail." : r.message, r.ok ? "ok" : "error");
  }

  async function onRecovery(ev) {
    ev.preventDefault();
    const r = await api("PUT", "/auth/v1/user", { password: ev.target.password.value });
    if (!r.ok) { toast(r.message, "error"); return; }
    toast("Passwort geändert.", "ok");
    show($("recoveryView"), false);
    render();
  }

  async function onLogout() {
    if (session) await api("POST", "/auth/v1/logout?scope=local", {}, { noRefresh: true });
    saveSession(null);
    profile = null;
    render();
  }

  // ------------------------------------------------------------------ Profil
  async function onName(ev) {
    ev.preventDefault();
    const name = $("nameInput").value.trim();
    if (name.length < 3 || name.length > 16 || /[<>]/.test(name)) { toast("Der Name braucht 3 bis 16 Zeichen.", "error"); return; }
    const r = await api("PATCH", "/rest/v1/profiles?id=eq." + encodeURIComponent(session.user.id), { username: name }, { prefer: "return=minimal" });
    toast(r.ok ? "Name gespeichert." : r.message, r.ok ? "ok" : "error");
    if (r.ok) loadProfile();
  }

  // Bild quadratisch zuschneiden und auf 256 px verkleinern (PNG)
  function resizeImage(file) {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        const side = Math.min(img.naturalWidth, img.naturalHeight);
        const canvas = document.createElement("canvas");
        canvas.width = AVATAR_SIZE;
        canvas.height = AVATAR_SIZE;
        const ctx = canvas.getContext("2d");
        ctx.imageSmoothingQuality = "high";
        ctx.drawImage(img, (img.naturalWidth - side) / 2, (img.naturalHeight - side) / 2, side, side, 0, 0, AVATAR_SIZE, AVATAR_SIZE);
        URL.revokeObjectURL(url);
        canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("encode"))), "image/png");
      };
      img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("decode")); };
      img.src = url;
    });
  }

  async function onAvatar(ev) {
    const file = ev.target.files && ev.target.files[0];
    ev.target.value = "";
    if (!file) return;
    if (!/^image\/(png|jpeg|webp)$/.test(file.type)) { toast("Bitte ein PNG-, JPEG- oder WebP-Bild wählen.", "error"); return; }
    if (file.size > 15 * 1024 * 1024) { toast("Das Bild ist zu groß.", "error"); return; }
    let blob;
    try { blob = await resizeImage(file); } catch (e) { toast("Das Bild konnte nicht gelesen werden.", "error"); return; }
    if (blob.size > MAX_UPLOAD_BYTES) { toast("Das Bild ist zu groß.", "error"); return; }
    const uid = session.user.id;
    const path = uid + "/avatar-" + Date.now() + ".png";
    const up = await api("POST", "/storage/v1/object/avatars/" + path, blob, { raw: true, headers: { "Content-Type": "image/png", "x-upsert": "true" } });
    if (!up.ok) { toast("Hochladen fehlgeschlagen: " + up.message, "error"); return; }
    const old = profile && profile.avatar_path;
    const r = await api("PATCH", "/rest/v1/profiles?id=eq." + encodeURIComponent(uid), { avatar_path: path }, { prefer: "return=minimal" });
    if (!r.ok) { toast(r.message, "error"); return; }
    if (old && validAvatarPath(old, uid) && old !== path) {
      await api("DELETE", "/storage/v1/object/avatars/" + old, undefined);
    }
    toast("Profilbild gespeichert – im Spiel erscheint es beim nächsten Start.", "ok");
    loadProfile();
  }

  // ------------------------------------------------------------------ Spiel-Code
  function formatCode(code) { return code.slice(0, 4) + "-" + code.slice(4); }

  async function onCreateCode(ev) {
    ev.preventDefault();
    const pw = ev.target.password.value;
    ev.target.password.value = "";
    $("codeDialog").close();
    // Eigene, unabhaengige Anmeldung nur fuer das Spiel – die Browser-Sitzung wird nie weitergegeben.
    const game = await passwordLogin(session.user.email, pw);
    if (!game.ok) { toast(game.message || "Passwort falsch.", "error"); return; }
    const r = await api("POST", "/rest/v1/rpc/create_game_link_code", { p_refresh_token: game.session.refresh_token },
      { token: game.session.access_token, noRefresh: true });
    if (!r.ok || typeof r.data !== "string") { toast("Code konnte nicht erzeugt werden: " + r.message, "error"); return; }
    const code = r.data;
    $("codeValue").textContent = formatCode(code);
    show($("codeBox"), true);
    const until = Date.now() + CODE_TTL_MS;
    clearInterval(codeTimer);
    const tick = () => {
      const left = Math.max(0, until - Date.now());
      const m = Math.floor(left / 60000);
      const s = Math.floor((left % 60000) / 1000);
      $("codeTimer").textContent = left > 0 ? "gültig noch " + m + ":" + String(s).padStart(2, "0") : "abgelaufen";
      if (left <= 0) { clearInterval(codeTimer); $("codeValue").classList.add("expired"); }
    };
    $("codeValue").classList.remove("expired");
    tick();
    codeTimer = setInterval(tick, 1000);
  }

  async function onCopyCode() {
    const code = $("codeValue").textContent.replace("-", "");
    try { await navigator.clipboard.writeText(code); toast("Code kopiert.", "ok"); }
    catch (e) { toast("Kopieren nicht möglich – bitte abtippen.", "error"); }
  }

  // ------------------------------------------------------------------ Freunde
  async function loadFriends() {
    const uid = session.user.id;
    const r = await api("GET", "/rest/v1/friends?select=id,user_id,friend_id,status&or=(user_id.eq." + uid + ",friend_id.eq." + uid + ")");
    const rows = r.ok && Array.isArray(r.data) ? r.data : [];
    const ids = [...new Set(rows.map((row) => (row.user_id === uid ? row.friend_id : row.user_id)))];
    const profiles = {};
    if (ids.length) {
      const pr = await api("GET", "/rest/v1/public_profiles?select=id,username,trophies,avatar_path,last_seen&id=in.(" + ids.join(",") + ")");
      (pr.ok && Array.isArray(pr.data) ? pr.data : []).forEach((p) => { profiles[p.id] = p; });
    }
    const friendList = $("friendList");
    const requestList = $("requestList");
    friendList.replaceChildren();
    requestList.replaceChildren();
    let friends = 0;
    let requests = 0;
    rows.forEach((row) => {
      const otherId = row.user_id === uid ? row.friend_id : row.user_id;
      const p = profiles[otherId] || { username: "Spieler", trophies: 0 };
      const li = el("li", "item");
      li.appendChild(makeAvatar(p.username, p.avatar_path, otherId));
      const info = el("div", "item-info");
      info.appendChild(el("div", "item-name", p.username));
      const online = p.last_seen && Date.now() - Date.parse(p.last_seen) < 150000;
      info.appendChild(el("div", "item-sub" + (online ? " online" : ""), row.status === "accepted" ? (online ? "online" : "offline") + " · 🏆 " + (p.trophies || 0) : (row.user_id === uid ? "Anfrage gesendet" : "möchte dein Freund sein")));
      li.appendChild(info);
      const actions = el("div", "item-actions");
      if (row.status !== "accepted" && row.friend_id === uid) {
        const accept = el("button", "btn btn-small btn-primary", "Annehmen");
        accept.type = "button";
        accept.addEventListener("click", async () => {
          const a = await api("PATCH", "/rest/v1/friends?id=eq." + encodeURIComponent(row.id), { status: "accepted" }, { prefer: "return=minimal" });
          toast(a.ok ? "Freundschaft angenommen." : a.message, a.ok ? "ok" : "error");
          loadFriends();
        });
        actions.appendChild(accept);
      }
      const remove = el("button", "btn btn-small btn-ghost", row.status === "accepted" ? "Entfernen" : (row.user_id === uid ? "Zurückziehen" : "Ablehnen"));
      remove.type = "button";
      remove.addEventListener("click", async () => {
        if (row.status === "accepted" && !confirm(p.username + " wirklich entfernen?")) return;
        const d = await api("DELETE", "/rest/v1/friends?id=eq." + encodeURIComponent(row.id), undefined);
        toast(d.ok ? "Erledigt." : d.message, d.ok ? "ok" : "error");
        loadFriends();
      });
      actions.appendChild(remove);
      li.appendChild(actions);
      if (row.status === "accepted") { friendList.appendChild(li); friends++; }
      else { requestList.appendChild(li); requests++; }
    });
    show($("requestsTitle"), requests > 0);
    show($("friendsEmpty"), friends === 0);
  }

  async function onSearch(ev) {
    ev.preventDefault();
    const q = $("searchInput").value.trim();
    const list = $("searchResults");
    list.replaceChildren();
    if (q.length < 2) { toast("Mindestens 2 Zeichen eingeben.", "error"); return; }
    // PostgREST-Sonderzeichen entfernen, damit die Suche nichts anderes filtert
    const safe = q.replace(/[^\p{L}\p{N} _-]/gu, "");
    if (!safe) return;
    const enc = encodeURIComponent(safe);
    const r = await api("GET", "/rest/v1/public_profiles?select=id,username,trophies,friend_code,avatar_path&or=(username.ilike.*" + enc + "*,friend_code.eq." + encodeURIComponent(safe.toUpperCase()) + ")&id=neq." + session.user.id + "&limit=12");
    const rows = r.ok && Array.isArray(r.data) ? r.data : [];
    if (!rows.length) { list.appendChild(el("li", "muted", "Niemand gefunden.")); return; }
    rows.forEach((p) => {
      const li = el("li", "item");
      li.appendChild(makeAvatar(p.username, p.avatar_path, p.id));
      const info = el("div", "item-info");
      info.appendChild(el("div", "item-name", p.username));
      info.appendChild(el("div", "item-sub", "#" + p.friend_code + " · 🏆 " + (p.trophies || 0)));
      li.appendChild(info);
      const add = el("button", "btn btn-small btn-primary", "Hinzufügen");
      add.type = "button";
      add.addEventListener("click", async () => {
        const a = await api("POST", "/rest/v1/friends", { user_id: session.user.id, friend_id: p.id, status: "pending" }, { prefer: "return=minimal" });
        toast(a.ok ? "Anfrage gesendet." : "Bereits befreundet oder angefragt.", a.ok ? "ok" : "error");
        li.remove();
        loadFriends();
      });
      li.appendChild(add);
      list.appendChild(li);
    });
  }

  // ------------------------------------------------------------------ Start
  async function init() {
    document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => setTab(b.dataset.tab)));
    $("loginForm").addEventListener("submit", onLogin);
    $("registerForm").addEventListener("submit", onRegister);
    $("forgotBtn").addEventListener("click", onForgot);
    $("recoveryForm").addEventListener("submit", onRecovery);
    $("logoutBtn").addEventListener("click", onLogout);
    $("nameForm").addEventListener("submit", onName);
    $("avatarInput").addEventListener("change", onAvatar);
    $("searchForm").addEventListener("submit", onSearch);
    $("codeBtn").addEventListener("click", () => $("codeDialog").showModal());
    $("codeCancel").addEventListener("click", () => $("codeDialog").close());
    $("codeForm").addEventListener("submit", onCreateCode);
    $("copyCodeBtn").addEventListener("click", onCopyCode);

    if (!configured()) {
      show($("setupNotice"), true);
      return;
    }
    const fromMail = sessionFromUrlFragment();
    if (fromMail) {
      saveSession(fromMail.session);
      if (fromMail.type === "recovery") {
        show($("recoveryView"), true);
        return;
      }
      await refresh();   // holt vollstaendige Nutzerdaten (E-Mail)
    } else {
      session = loadSession();
      if (session && (!session.expires_at || session.expires_at < Date.now() + 60000)) await refresh();
    }
    if (session && session.user && session.user.is_anonymous) saveSession(null);   // Gast-Sessions gehoeren ins Spiel
    render();
  }

  init();
})();
