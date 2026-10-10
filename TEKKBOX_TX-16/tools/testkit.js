/* Test-Helfer für tools/test.html (im Browser per javascript ausführen, z. B. eval(await (await fetch('/tools/testkit.js')).text())).
   Bedienelemente werden über ihre aria-labels angesprochen, genau wie ein Mensch sie drückt. */
window.T = (() => {
  const wait = ms => new Promise(r => setTimeout(r, ms));
  const X = () => window.__tx;
  const btn = l => [...document.querySelectorAll('#dev .btn')].find(b => b.getAttribute('aria-label') === l);
  const knob = l => [...document.querySelectorAll('#dev .knob')].find(b => b.getAttribute('aria-label') === l);
  const KEYS = ['KeyQ','KeyW','KeyE','KeyR','KeyT','KeyY','KeyU','KeyI','KeyO','KeyP','BracketLeft','BracketRight',
                'KeyA','KeyS','KeyD','KeyF','KeyG','KeyH','KeyJ','KeyK','KeyL','Semicolon','Quote','Backslash'];
  return {
    wait,
    /* Einschalten und warten, bis die Sample-Bibliothek fertig ist */
    async power() { document.querySelector('#power2').click(); for (let k = 0; k < 80 && document.querySelector('#power').textContent !== 'Eingeschaltet'; k++) await wait(250); },
    /* Taste drücken (keydown/keyup Enter = wie Mausklick, inkl. gehaltener Tasten) */
    down: l => btn(l).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })),
    up: l => btn(l).dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', bubbles: true })),
    press(l) { this.down(l); this.up(l); },
    /* SHIFT wird über die Tastatur-Shift-Taste gehalten (kbShift), nicht über e.shiftKey */
    async shift(fn) { window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Shift' })); await fn(); window.dispatchEvent(new KeyboardEvent('keyup', { key: 'Shift' })); },
    /* Regler n Raster/Schritte drehen, gibt den angezeigten Wert zurück */
    turn(l, n) { const k = knob(l); for (let i = 0; i < Math.abs(n); i++) k.dispatchEvent(new KeyboardEvent('keydown', { key: n > 0 ? 'ArrowUp' : 'ArrowDown', bubbles: true })); return k.getAttribute('aria-valuetext'); },
    /* Pad 0..23 (0 = Pad 1 oben links, 16..23 = rechter Block) */
    pad(i, hold) { const r = i < 16 ? Math.floor(i / 8) : Math.floor((i - 16) / 4), c = i < 16 ? i % 8 : 8 + (i - 16) % 4, code = KEYS[r * 12 + c];
      window.dispatchEvent(new KeyboardEvent('keydown', { code, bubbles: true })); if (!hold) window.dispatchEvent(new KeyboardEvent('keyup', { code, bubbles: true })); },
    /* Pattern-JSON importieren (wie "Pattern importieren") */
    async importObj(o) { const inp = document.querySelector('#impFile'), dt = new DataTransfer(); dt.items.add(new File([JSON.stringify(o)], 'x.json')); inp.files = dt.files; inp.dispatchEvent(new Event('change')); await wait(800); },
    /* Summe (E.master) für sec Sekunden aufnehmen – AudioWorklet, verliert keine Blöcke */
    async capture(sec, start) { const ctx = X().ctx; if (!window.__wl) { await ctx.audioWorklet.addModule(URL.createObjectURL(new Blob(["class R extends AudioWorkletProcessor{process(i){const c=i[0]&&i[0][0];if(c)this.port.postMessage([currentFrame,c.slice()]);return true;}}registerProcessor('rec-tap',R);"], { type: 'text/javascript' }))); window.__wl = 1; }
      const rec = [], w = new AudioWorkletNode(ctx, 'rec-tap', { numberOfOutputs: 0 }); w.port.onmessage = e => rec.push(e.data); X().E.master.connect(w);
      if (start) await start(); await wait(sec * 1000); X().E.master.disconnect(w); rec.sort((a, b) => a[0] - b[0]);
      const d = new Float32Array(rec.length * 128); rec.forEach((b, k) => d.set(b[1], k * 128)); return d; },
    peakDb: d => { let m = 0; for (const v of d) m = Math.max(m, Math.abs(v)); return 20 * Math.log10(m + 1e-9); },
    rmsDb: d => { let s = 0; for (const v of d) s += v * v; return 10 * Math.log10(s / d.length + 1e-12); },
  };
})();
