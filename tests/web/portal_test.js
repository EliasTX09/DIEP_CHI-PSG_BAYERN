// Browser-Test des Web-Portals (webapp/) bei Handy-Breite mit simuliertem Supabase (page.route).
// Start: npm install playwright && npx playwright install chromium && node tests/web/portal_test.js
// Prueft Registrieren, Profilbild, Freunde (inkl. XSS-Schutz), Spiel-Code mit eigener Sitzung, Abmelden.
const { chromium } = require('playwright');
const path = require('path');
const OUT = process.env.PORTAL_SHOTS || path.dirname(__filename);
const WEB = path.resolve(__dirname, '..', '..', 'webapp');
const BASE = 'https://mock.supabase.co';
const UID = '22222222-2222-4222-8222-222222222222';
const FRIEND = '33333333-3333-4333-8333-333333333333';
const ASKER = '44444444-4444-4444-8444-444444444444';
const fails = [];
const check = (c, msg) => { if (!c) { fails.push(msg); console.log('FAIL', msg); } else console.log('ok  ', msg); };
const calls = [];
let profile = { id: UID, username: 'NeuSpieler', friend_code: 'ABCD1234', trophies: 120, avatar_path: null };
let friendRows = [
  { id: 1, user_id: UID, friend_id: FRIEND, status: 'accepted' },
  { id: 2, user_id: ASKER, friend_id: UID, status: 'pending' },
];
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVQI12P8z8DwnwEJMDGgAQYGBgAkXAL/n8nQBwAAAABJRU5ErkJggg==', 'base64');
function session(rt) { return { access_token: 'h.' + Buffer.from(JSON.stringify({ sub: UID })).toString('base64') + '.s', refresh_token: rt, expires_in: 3600, user: { id: UID, email: 'neu@example.com', is_anonymous: false } }; }

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let dialogs = 0;
  page.on('dialog', d => { if (d.type() === 'alert') dialogs++; d.accept(); });
  page.on('pageerror', e => fails.push('JS-Fehler: ' + e.message));
  await page.route('**/config.js', r => r.fulfill({ contentType: 'application/javascript', body: `window.GOLF_CONFIG={supabaseUrl:"${BASE}",anonKey:"anon-key-0123456789abcdefghij"};` }));
  await page.route(BASE + '/**', async route => {
    const req = route.request(); const url = new URL(req.url()); const p = url.pathname + url.search; const m = req.method();
    calls.push(m + ' ' + url.pathname);
    const json = (status, body) => route.fulfill({ status, contentType: 'application/json', body: body === null ? '' : JSON.stringify(body) });
    if (m === 'POST' && url.pathname === '/auth/v1/signup') { const b = req.postDataJSON(); profile.username = b.data.name; return json(200, session('rt-browser')); }
    if (m === 'POST' && url.pathname === '/auth/v1/token') {
      const b = req.postDataJSON();
      if (url.search.includes('password')) return b.password === 'geheim123' ? json(200, session('rt-game-' + Date.now())) : json(400, { error_description: 'Invalid login credentials' });
      return json(200, session('rt-browser2'));
    }
    if (m === 'POST' && url.pathname === '/rest/v1/rpc/create_game_link_code') {
      const b = req.postDataJSON(); check(b.p_refresh_token.startsWith('rt-game-'), 'RPC bekommt das Token der EIGENEN Spiel-Sitzung');
      check(req.headers()['authorization'] !== undefined, 'RPC mit Bearer-Token');
      return json(200, 'ABCD2345');
    }
    if (m === 'GET' && url.pathname === '/rest/v1/profiles') return json(200, [profile]);
    if (m === 'PATCH' && url.pathname === '/rest/v1/profiles') { Object.assign(profile, req.postDataJSON()); return json(204, null); }
    if (m === 'POST' && url.pathname.startsWith('/storage/v1/object/avatars/')) { check(url.pathname.includes(UID + '/avatar-'), 'Upload in eigenen Ordner'); check(req.headers()['content-type'] === 'image/png', 'Upload als PNG'); return json(200, { Key: 'x' }); }
    if (m === 'GET' && url.pathname.startsWith('/storage/v1/object/public/avatars/')) return route.fulfill({ status: 200, contentType: 'image/png', body: png });
    if (m === 'GET' && url.pathname === '/rest/v1/friends') return json(200, friendRows);
    if (m === 'GET' && url.pathname === '/rest/v1/public_profiles') {
      if (url.search.includes('ilike')) return json(200, [{ id: '55555555-5555-4555-8555-555555555555', username: 'Anna', trophies: 300, friend_code: 'ANNA2222', avatar_path: null }]);
      return json(200, [
        { id: FRIEND, username: '<img src=x onerror=alert(1)>', trophies: 50, avatar_path: null, last_seen: new Date().toISOString() },
        { id: ASKER, username: 'Bernd', trophies: 10, avatar_path: null, last_seen: null }]);
    }
    if (m === 'POST' && url.pathname === '/rest/v1/friends') return json(201, null);
    if (m === 'PATCH' && url.pathname === '/rest/v1/friends') { friendRows[1].status = 'accepted'; return json(204, null); }
    if (m === 'POST' && url.pathname === '/auth/v1/logout') return json(204, null);
    return json(404, { message: 'nicht gemockt: ' + m + ' ' + p });
  });
  await page.goto('file://' + WEB + '/index.html');
  check(await page.isVisible('#authView'), 'Login-Ansicht sichtbar');
  await page.screenshot({ path: OUT + '/portal_login.png' });
  await page.click('.tab[data-tab=register]');
  await page.fill('#registerForm [name=name]', 'NeuSpieler');
  await page.fill('#registerForm [name=email]', 'neu@example.com');
  await page.fill('#registerForm [name=password]', 'geheim123');
  await page.click('#registerForm button[type=submit]');
  await page.waitForSelector('#profileView:not(.hidden)');
  check((await page.textContent('#profileName')) === 'NeuSpieler', 'Profilname angezeigt');
  await page.waitForSelector('#friendList li');
  const friendName = await page.textContent('#friendList .item-name');
  check(friendName === '<img src=x onerror=alert(1)>', 'Fremder Name wird als Text angezeigt (kein HTML)');
  check(await page.$('#friendList img[src="x"]') === null, 'Kein eingeschleustes <img>-Element');
  check(await page.isVisible('#requestList li'), 'Freundschaftsanfrage sichtbar');
  // Profilbild
  await page.setInputFiles('#avatarInput', { name: 'bild.png', mimeType: 'image/png', buffer: png });
  await page.waitForFunction(() => !document.getElementById('avatarImg').classList.contains('hidden'));
  check(/^22222222-2222-4222-8222-222222222222\/avatar-\d+\.png$/.test(profile.avatar_path || ''), 'avatar_path im Profil gespeichert');
  // Suche + Anfrage
  await page.fill('#searchInput', 'An');
  await page.click('#searchForm button');
  await page.waitForSelector('#searchResults li .btn');
  await page.click('#searchResults li .btn');
  // Anfrage annehmen
  await page.click('#requestList .btn-primary');
  // Spiel-Code
  await page.click('#codeBtn');
  await page.fill('#codeForm [name=password]', 'geheim123');
  await page.click('#codeForm button[type=submit]');
  await page.waitForSelector('#codeBox:not(.hidden)');
  check((await page.textContent('#codeValue')) === 'ABCD-2345', 'Spiel-Code angezeigt');
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + '/portal_profile.png', fullPage: true });
  const sw = await page.evaluate(() => document.documentElement.scrollWidth);
  if (sw > 390) console.log(await page.evaluate(() => [...document.querySelectorAll('body *')].filter(e => e.getBoundingClientRect().right > 391).slice(0, 8).map(e => e.tagName + '#' + e.id + '.' + e.className + ' ' + Math.round(e.getBoundingClientRect().right)).join('\n')));
  check(sw <= 390, 'Kein horizontales Scrollen bei 390 px (' + sw + ')');
  check(dialogs === 0, 'Kein Script aus Nutzerdaten ausgefuehrt');
  // Falsches Passwort beim Code
  await page.click('#codeBtn');
  await page.fill('#codeForm [name=password]', 'falsch999');
  await page.click('#codeForm button[type=submit]');
  await page.waitForTimeout(300);
  check((await page.textContent('#toast')).includes('falsch'), 'Falsches Passwort wird gemeldet');
  // Seite neu laden -> Session bleibt (localStorage), dann Abmelden
  await page.reload();
  await page.waitForSelector('#profileView:not(.hidden)');
  check(true, 'Session ueberlebt Neuladen');
  await page.click('#logoutBtn');
  await page.waitForSelector('#authView:not(.hidden)', { timeout: 3000 }).catch(() => {});
  check(await page.isVisible('#authView'), 'Abmelden zeigt wieder Login');
  check(calls.includes('POST /auth/v1/logout'), 'Logout an Server gemeldet');
  // Ohne Konfiguration: Hinweis
  const p2 = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await p2.goto('file://' + WEB + '/index.html');
  check(await p2.isVisible('#setupNotice'), 'Ohne Konfiguration: Einrichtungs-Hinweis');
  await browser.close();
  console.log(fails.length ? 'PORTAL TEST: FAIL ' + JSON.stringify(fails) : 'PORTAL TEST: PASS');
  process.exit(fails.length ? 1 : 0);
})();
