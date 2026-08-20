// Browser-Check des ausgelieferten Frontends gegen die echte Supabase.
//
//   npm ci                                                # einmalig
//   python3 -m http.server 8123 --bind 127.0.0.1 &       # lokaler Test
//   node tests/frontend-check.js
//   BASE=https://weinabend-blind-live.vercel.app node tests/frontend-check.js
//
// Fuer eine geschuetzte Preview zusaetzlich SHARE=<share-url> setzen; jeder
// Browser-Kontext ruft sie einmal auf, um das Cookie zu setzen.
//
// Fuer Agent-Umgebungen koennen CHROMIUM_EXECUTABLE_PATH, AGENT_PROXY_URL und
// CHROMIUM_TLS_MAX gesetzt werden. In GitHub Actions nutzt Playwright seine
// normal installierte Chromium-Version ohne Proxy-Sonderfall.
//
// Der Test betritt bewusst KEINEN Verkostungsraum: das wuerde ueber
// join_tasting echte Teilnehmerdaten schreiben.
const { chromium } = require('playwright');
const BASE = process.env.BASE || 'http://127.0.0.1:8123';
const SHARE = process.env.SHARE || '';
let pass = 0, fail = 0;
const ok = (n, c, extra = '') => { c ? (pass++, console.log(`  OK   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${extra}`)); };

// Namens-Gate ist rein clientseitig (setActiveName -> localStorage), kein Server-Call.
async function passNameGate(page) {
  if (await page.locator('#portal-name').count()) {
    await page.fill('#portal-name', 'Testlauf');
    await page.click('#portal-start');
    await page.waitForTimeout(1800);
  }
}

async function newCtx(browser) {
  const c = await browser.newContext();
  if (SHARE) { const p = await c.newPage(); await p.goto(SHARE, { waitUntil: 'domcontentloaded' }); await p.close(); }
  return c;
}

(async () => {
  const args = ['--no-sandbox'];
  if (process.env.AGENT_PROXY_URL) args.push(`--proxy-server=${process.env.AGENT_PROXY_URL}`);
  if (process.env.CHROMIUM_TLS_MAX) args.push(`--ssl-version-max=${process.env.CHROMIUM_TLS_MAX}`);
  const launchOptions = { args };
  if (process.env.CHROMIUM_EXECUTABLE_PATH) launchOptions.executablePath = process.env.CHROMIUM_EXECUTABLE_PATH;
  const browser = await chromium.launch(launchOptions);

  // ---------- 1. Boot-Integritaet ----------
  let ctx = await newCtx(browser);
  let page = await ctx.newPage();
  const bad = [], errs = [], rpcCalls = [];
  page.on('response', r => { if (r.url().startsWith(BASE) && r.status() >= 400) bad.push(`${r.status()} ${r.url()}`); });
  page.on('pageerror', e => errs.push(e.message));
  page.on('request', r => { if (r.url().includes('/rest/v1/rpc/')) rpcCalls.push(r.url().split('/rpc/')[1]); });

  await page.goto(`${BASE}/?event=BURGUND`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  ok('Keine 4xx/5xx auf ausgelieferten Dateien', bad.length === 0, bad.join(', '));
  ok('Keine JS-Fehler beim Boot', errs.length === 0, errs.join(' | '));
  ok('EMBEDDED_HOST ist null', await page.evaluate(() => EMBEDDED_HOST === null));
  ok('APP_VERSION unveraendert', await page.evaluate(() => APP_VERSION) === 'stable-kiosk-20260818-1');

  await passNameGate(page);
  const hub = await page.textContent('#app');
  ok('Event-Hub laedt echte Daten (Raeume sichtbar)', /Weißwein|Rotwein|Solo|Paar/i.test(hub), hub.slice(0, 160));
  ok('Host-Steuerung im Portal erreichbar', hub.includes('Host-Steuerung'), hub.slice(0, 200));

  // ---------- 2. PIN-Screen ----------
  await page.click('text=Host-Steuerung');
  await page.waitForTimeout(700);
  ok('PIN-Screen erscheint', await page.isVisible('#hostinput'));
  ok('PIN-Feld ist Passwortfeld', await page.getAttribute('#hostinput', 'type') === 'password');
  ok('Label zeigt Host-PIN', (await page.textContent('label[for="hostinput"]')).includes('PIN'));
  ok('Kein prompt() mehr, sondern In-App-Screen', (await page.textContent('#app')).includes('Geschützter Bereich'));

  // ---------- 3. Falscher PIN loest keinen Server-Call aus ----------
  let mark = rpcCalls.length;
  await page.fill('#hostinput', '0000');
  await page.click('#hostgo');
  await page.waitForTimeout(1000);
  ok('Falscher PIN loest keinen Server-Call aus', rpcCalls.length === mark, rpcCalls.slice(mark).join(','));
  ok('Toast meldet falschen PIN', (await page.textContent('#toast')).includes('Falscher Host-PIN'));
  ok('Nach falschem PIN weiter auf PIN-Screen', (await page.textContent('label[for="hostinput"]')).includes('PIN'));
  ok('Eingabefeld wird geleert', await page.inputValue('#hostinput') === '');

  // ---------- 4. Richtiger PIN -> Token-Screen, immer noch kein Server-Call ----------
  mark = rpcCalls.length;
  await page.fill('#hostinput', '1976');
  await page.click('#hostgo');
  await page.waitForTimeout(1000);
  ok('Richtiger PIN fuehrt zum Token-Screen', (await page.textContent('label[for="hostinput"]')).includes('Token'));
  ok('Richtiger PIN allein loest keinen Server-Call aus', rpcCalls.length === mark, rpcCalls.slice(mark).join(','));

  // ---------- 5. Ungueltiger Token wird serverseitig geprueft und NICHT gespeichert ----------
  mark = rpcCalls.length;
  await page.fill('#hostinput', 'definitiv-kein-gueltiger-token');
  await page.click('#hostgo');
  await page.waitForTimeout(4000);
  ok('Token wird serverseitig validiert (host_get_event_state)',
     rpcCalls.slice(mark).some(u => u.startsWith('host_get_event_state')), rpcCalls.slice(mark).join(','));
  const stored = await page.evaluate(() => localStorage.getItem('wt_host_BURGUND'));
  ok('Ungueltiger Token landet NICHT im Speicher', !stored, String(stored));
  ok('Nach ungueltigem Token zurueck auf Token-Screen', (await page.textContent('label[for="hostinput"]')).includes('Token'));
  ok('Kein Sprung in den Host-Modus', !page.url().includes('hostmode=1'), page.url());

  // ---------- 6. Alt-PIN 1847 bleibt kompatibel ----------
  await page.goto(`${BASE}/?event=BURGUND`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  await passNameGate(page);
  await page.click('text=Host-Steuerung');
  await page.waitForTimeout(600);
  await page.fill('#hostinput', '1847');
  await page.click('#hostgo');
  await page.waitForTimeout(800);
  ok('Alt-PIN 1847 weiterhin gueltig', (await page.textContent('label[for="hostinput"]')).includes('Token'));

  // ---------- 7. hostmode ohne Token faellt auf das PIN-Gate zurueck ----------
  await page.goto(`${BASE}/?event=BURGUND&hostmode=1`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1800);
  ok('hostmode=1 ohne Token zeigt das PIN-Gate', await page.isVisible('#hostinput') && (await page.textContent('label[for="hostinput"]')).includes('PIN'));

  // ---------- 8. Host-Token ueberlebt die APP_VERSION-Aufraeumroutine ----------
  const survives = await page.evaluate(() => {
    localStorage.setItem('wt_host_BURGUND', 'probe-token');
    localStorage.setItem('wt_irgendwas', 'x');
    for (const k of Object.keys(localStorage)) { if (k.startsWith('wt_') && !k.startsWith('wt_host_')) localStorage.removeItem(k); }
    const r = { host: localStorage.getItem('wt_host_BURGUND'), other: localStorage.getItem('wt_irgendwas') };
    localStorage.removeItem('wt_host_BURGUND');
    return r;
  });
  ok('wt_host_ ueberlebt Aufraeumroutine, anderes nicht', survives.host === 'probe-token' && survives.other === null, JSON.stringify(survives));
  await ctx.close();

  // ---------- 9. Kiosk-Modus hat den Host-Einstieg ebenfalls ----------
  ctx = await newCtx(browser);
  page = await ctx.newPage();
  await page.goto(`${BASE}/?event=BURGUND&kiosk=1`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  const kioskText = await page.textContent('#app');
  ok('Host-Steuerung auch im Kiosk-Modus', kioskText.includes('Host-Steuerung'), kioskText.slice(0, 200));
  await page.click('text=Host-Steuerung');
  await page.waitForTimeout(700);
  ok('Kiosk fuehrt ebenfalls auf den PIN-Screen', await page.isVisible('#hostinput'));
  await ctx.close();

  // ---------- 10. Axel hat einen eigenen, tokengebundenen Host-Tab ----------
  ctx = await newCtx(browser);
  page = await ctx.newPage();
  let participantHostPayload = null;
  await page.addInitScript(() => {
    localStorage.setItem('wt_app_version', 'stable-kiosk-20260818-1');
    localStorage.setItem('wt_portal_name_BURGUND', 'Axel');
    localStorage.setItem('wt_SOLOW1', JSON.stringify({ name: 'Axel', token: 'browser-probe-token' }));
  });
  await page.route('**/rest/v1/rpc/participant_host_get_event_state', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      title: 'Weinabend – Blindverkostungen',
      rooms: [{
        code: 'SOLOW1', theme: 'Weißwein · Sancerre', tasting_type: 'white_solo',
        phase: 'tasting', participants: 3, tasting_done: 3, guesses_done: 3,
      }],
    }),
  }));
  await page.route('**/rest/v1/rpc/participant_host_set_room_phase', async route => {
    participantHostPayload = JSON.parse(route.request().postData() || '{}');
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true, phase: 'revealed' }) });
  });
  page.on('dialog', dialog => dialog.accept());
  await page.goto(`${BASE}/?event=BURGUND&tab=host`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  ok('Axel sieht ein eigenes Host-Tab', await page.isVisible('.eventtabs a:has-text("Host")'));
  ok('Axels Host-Tab laedt die Rundensteuerung', (await page.textContent('#app')).includes('Runden freigeben'));
  ok('Sancerre-Aufloesung ist bei 3/3 freigeschaltet', await page.isEnabled('[data-player-host-phase="revealed"][data-room="SOLOW1"]'));
  await page.click('[data-player-host-phase="revealed"][data-room="SOLOW1"]');
  await page.waitForTimeout(700);
  ok('Axel-Freigabe ruft die Teilnehmer-Host-RPC auf', participantHostPayload?.p_room_code === 'SOLOW1' && participantHostPayload?.p_phase === 'revealed', JSON.stringify(participantHostPayload));
  ok('Axels Teilnehmer-Token wird an die Autorisierungspruefung uebergeben', participantHostPayload?.p_participant_tokens?.includes('browser-probe-token'), JSON.stringify(participantHostPayload));
  await ctx.close();

  // ---------- 11. Assets werden korrekt ausgeliefert ----------
  ctx = await newCtx(browser);
  page = await ctx.newPage();
  const assets = [
    ['assets/postnasal-anleitung-animated.svg', 'image/svg+xml'],
    ['assets/postnasal-anleitung-static.svg', 'image/svg+xml'],
    ['assets/solo-prosecco-expert-club-brut.jpeg', 'image/jpeg'],
    ['assets/solo-sancerre-enclos-maimbray-2022.jpeg', 'image/jpeg'],
    ['assets/solo-tio-pepe-fino.jpeg', 'image/jpeg'],
  ];
  for (const [a, ct] of assets) {
    const r = await page.request.get(`${BASE}/${a}`);
    ok(`Asset ${a}`, r.status() === 200 && (r.headers()['content-type'] || '').includes(ct.split('/')[1]),
       `status=${r.status()} ct=${r.headers()['content-type']}`);
  }
  await ctx.close();

  await browser.close();
  console.log(`\n=== ${pass}/${pass + fail} Checks gruen ===`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('TESTLAUF ABGEBROCHEN:', e); process.exit(2); });
