/* =====================================================================
   BANK HEIST - sons de l'interface (WebAudio, aucun fichier à charger)
   Sfx.play(nom, volume) : sting, cash, unlock, boom, arm, open, click, ok, ko, cut, beep
   Sfx.alarm(true|false, volume) : sirène de banque à deux tons, volume réglable en continu
   ===================================================================== */
window.Sfx = (() => {
  let ctx = null, master = null;
  const ac = () => {
    if (!ctx) {
      const A = window.AudioContext || window.webkitAudioContext;
      if (!A) return null;
      ctx = new A(); master = ctx.createGain(); master.gain.value = 0.8; master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  };
  const tone = (f, t0, dur, { type = 'sine', vol = 0.3, to = null, attack = 0.005 } = {}) => {
    const g = ctx.createGain(), o = ctx.createOscillator();
    o.type = type; o.frequency.setValueAtTime(f, t0);
    if (to) o.frequency.exponentialRampToValueAtTime(to, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(vol, t0 + attack); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g); g.connect(master); o.start(t0); o.stop(t0 + dur + 0.05);
  };
  let noiseBuf = null;
  const noise = (t0, dur, { vol = 0.4, freq = 1200, q = 0.8, type = 'bandpass', to = null } = {}) => {
    if (!noiseBuf) {
      noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 1.5, ctx.sampleRate);
      const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noiseBuf; f.type = type; f.frequency.setValueAtTime(freq, t0); f.Q.value = q;
    if (to) f.frequency.exponentialRampToValueAtTime(to, t0 + dur);
    g.gain.setValueAtTime(vol, t0); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    s.connect(f); f.connect(g); g.connect(master); s.start(t0); s.stop(t0 + dur + 0.05);
  };
  const SFX = {
    click: (t, v) => tone(1400, t, 0.05, { type: 'square', vol: 0.05 * v }),
    open: (t, v) => { tone(520, t, 0.12, { vol: 0.12 * v }); tone(780, t + 0.07, 0.18, { vol: 0.1 * v }); },
    ok: (t, v) => { [660, 880, 1320].forEach((f, i) => tone(f, t + i * 0.08, 0.2, { type: 'triangle', vol: 0.16 * v })); },
    ko: (t, v) => { tone(220, t, 0.25, { type: 'sawtooth', vol: 0.12 * v, to: 110 }); tone(180, t + 0.15, 0.3, { type: 'sawtooth', vol: 0.1 * v, to: 90 }); },
    beep: (t, v) => tone(2000, t, 0.07, { type: 'square', vol: 0.06 * v }),
    cut: (t, v) => { noise(t, 0.08, { vol: 0.5 * v, freq: 5000, q: 2 }); tone(90, t, 0.1, { vol: 0.2 * v }); },
    cash: (t, v) => { for (let i = 0; i < 4; i++) noise(t + i * 0.045, 0.06, { vol: 0.35 * v, freq: 2600 + i * 300, q: 1.5 }); },
    arm: (t, v) => { [0, 0.18, 0.36].forEach((d) => tone(1800, t + d, 0.09, { type: 'square', vol: 0.08 * v })); tone(900, t + 0.6, 0.4, { type: 'square', vol: 0.07 * v, to: 1800 }); },
    unlock: (t, v) => { tone(140, t, 0.35, { type: 'sawtooth', vol: 0.12 * v, to: 60 }); noise(t + 0.05, 0.4, { vol: 0.25 * v, freq: 400, to: 120 }); [880, 1175].forEach((f, i) => tone(f, t + 0.45 + i * 0.1, 0.3, { type: 'triangle', vol: 0.12 * v })); },
    boom: (t, v) => { noise(t, 1.4, { vol: 0.9 * v, freq: 800, type: 'lowpass', to: 60, q: 0.5 }); tone(70, t, 1.0, { vol: 0.6 * v, to: 30 }); },
    sting: (t, v) => { tone(110, t, 0.9, { type: 'sawtooth', vol: 0.18 * v, to: 55 }); tone(165, t, 0.9, { type: 'sawtooth', vol: 0.12 * v, to: 82 }); noise(t, 0.6, { vol: 0.25 * v, freq: 300, type: 'lowpass' }); tone(880, t + 0.05, 0.5, { type: 'triangle', vol: 0.1 * v }); },
  };
  function play(name, volume = 1) {
    if (!ac() || !SFX[name]) return;
    SFX[name](ctx.currentTime + 0.01, Math.max(0, Math.min(1.5, Number(volume) || 1)));
  }
  // Sirène : deux tons alternés (~0,55 s), passe par un gain réglable sans recréer le son
  let siren = null;
  function alarm(on, volume = 0.6) {
    if (!on) {
      if (siren) { const s = siren; siren = null; s.g.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.08); setTimeout(() => { try { s.o.stop(); s.lfo.stop(); } catch (e) { /* déjà arrêté */ } }, 400); }
      return;
    }
    if (!ac()) return;
    const v = Math.max(0, Math.min(1, Number(volume) || 0)) * 0.22;
    if (siren) { siren.g.gain.setTargetAtTime(v, ctx.currentTime, 0.15); return; }
    const o = ctx.createOscillator(), g = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain(), f = ctx.createBiquadFilter();
    o.type = 'square'; o.frequency.value = 820;
    lfo.type = 'square'; lfo.frequency.value = 0.9; lg.gain.value = 160;
    lfo.connect(lg); lg.connect(o.frequency);
    f.type = 'lowpass'; f.frequency.value = 2400;
    g.gain.value = 0.0001; g.gain.setTargetAtTime(v, ctx.currentTime, 0.1);
    o.connect(f); f.connect(g); g.connect(master); o.start(); lfo.start();
    siren = { o, g, lfo };
  }
  return { play, alarm };
})();
