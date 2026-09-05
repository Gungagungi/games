// ---------------------------------------------------------------------------
// Moteur audio synthétique (Web Audio API) — pas de fichier son externe,
// tout est généré à la volée (oscillateurs + bruit) pour rester sans dépendance.
// ---------------------------------------------------------------------------

const SoundEngine = (() => {
  const MUTE_KEY = 'hells-survivant-muted';
  let ctx = null;
  let masterGain, musicGain, sfxGain;
  let muted = localStorage.getItem(MUTE_KEY) === '1';
  let currentMusic = null;
  let musicMode = null;

  function ensureContext() {
    if (ctx) return;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    masterGain = ctx.createGain();
    masterGain.gain.value = muted ? 0 : 1;
    masterGain.connect(ctx.destination);
    musicGain = ctx.createGain();
    musicGain.gain.value = 0.3;
    musicGain.connect(masterGain);
    sfxGain = ctx.createGain();
    sfxGain.gain.value = 0.55;
    sfxGain.connect(masterGain);
  }

  function unlock() {
    ensureContext();
    if (ctx.state === 'suspended') ctx.resume();
  }
  window.addEventListener('keydown', unlock, { once: true });
  window.addEventListener('mousedown', unlock, { once: true });

  function setMuted(v) {
    muted = v;
    localStorage.setItem(MUTE_KEY, v ? '1' : '0');
    if (masterGain) masterGain.gain.setTargetAtTime(v ? 0 : 1, ctx.currentTime, 0.01);
  }
  function toggleMuted() { setMuted(!muted); return muted; }
  function isMuted() { return muted; }

  // --- Briques sonores ---

  function tone({ freq, duration = 0.15, type = 'sine', gain = 0.3, dest, freqEnd = null, delay = 0 }) {
    if (!ctx) return;
    const t0 = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (freqEnd) osc.frequency.exponentialRampToValueAtTime(Math.max(1, freqEnd), t0 + duration);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
    osc.connect(g);
    g.connect(dest || sfxGain);
    osc.start(t0);
    osc.stop(t0 + duration + 0.03);
  }

  function noiseBurst({ duration = 0.15, gain = 0.3, dest, filterFreq = 1200, delay = 0 }) {
    if (!ctx) return;
    const t0 = ctx.currentTime + delay;
    const bufferSize = Math.max(1, Math.floor(ctx.sampleRate * duration));
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) data[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    src.buffer = buffer;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = filterFreq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(gain, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
    src.connect(filter);
    filter.connect(g);
    g.connect(dest || sfxGain);
    src.start(t0);
  }

  // --- Bruitages ---

  const SFX = {
    attack() { tone({ freq: 900, freqEnd: 300, duration: 0.09, type: 'triangle', gain: 0.22 }); },
    hitEnemy() { noiseBurst({ duration: 0.06, gain: 0.22, filterFreq: 2500 }); },
    hitPlayer() { tone({ freq: 180, freqEnd: 70, duration: 0.2, type: 'sawtooth', gain: 0.28 }); },
    enemyDeath() { tone({ freq: 320, freqEnd: 50, duration: 0.25, type: 'square', gain: 0.2 }); },
    gold() {
      tone({ freq: 1200, duration: 0.08, type: 'sine', gain: 0.14 });
      tone({ freq: 1600, duration: 0.1, type: 'sine', gain: 0.14, delay: 0.06 });
    },
    purchase() {
      tone({ freq: 500, duration: 0.1, type: 'square', gain: 0.18 });
      tone({ freq: 700, duration: 0.15, type: 'square', gain: 0.18, delay: 0.08 });
      tone({ freq: 900, duration: 0.2, type: 'square', gain: 0.18, delay: 0.16 });
    },
    waveStart() { tone({ freq: 220, freqEnd: 440, duration: 0.4, type: 'sawtooth', gain: 0.16 }); },
    bossWarning() {
      noiseBurst({ duration: 0.5, gain: 0.3, filterFreq: 500 });
      tone({ freq: 80, freqEnd: 45, duration: 0.7, type: 'sawtooth', gain: 0.3 });
    },
    bossCharge() { tone({ freq: 150, freqEnd: 900, duration: 0.35, type: 'sawtooth', gain: 0.22 }); },
    click() { tone({ freq: 700, duration: 0.05, type: 'square', gain: 0.14 }); },
    victory() {
      [0, 4, 7, 12].forEach((semi, i) =>
        tone({ freq: 220 * Math.pow(2, semi / 12), duration: 0.5, type: 'triangle', gain: 0.2, delay: i * 0.12 }));
    },
    gameover() {
      [0, -2, -4, -7].forEach((semi, i) =>
        tone({ freq: 220 * Math.pow(2, semi / 12), duration: 0.6, type: 'sawtooth', gain: 0.2, delay: i * 0.15 }));
    },
  };

  // --- Musiques (séquenceur pas-à-pas avec lookahead) ---

  const MUSIC = {
    menu: {
      bpm: 78, stepsPerBeat: 2, leadType: 'sine',
      bass: [110, null, 110, null, 98, null, 98, null],
      lead: [220, null, 262, null, 196, null, 220, null],
    },
    combat: {
      bpm: 130, stepsPerBeat: 2, leadType: 'square',
      bass: [82, 82, null, 82, 73, 73, null, 73],
      lead: [330, 392, 330, 392, 294, 349, 294, 349],
    },
    boss: {
      bpm: 152, stepsPerBeat: 2, leadType: 'sawtooth',
      bass: [65, 65, 65, null, 61, 61, 61, null],
      lead: [440, 523, 440, 523, 392, 466, 392, 466],
    },
    victory: {
      bpm: 100, stepsPerBeat: 2, leadType: 'triangle',
      bass: [130, null, 164, null, 196, null, 261, null],
      lead: [523, 587, 659, 784, 659, 587, 523, 392],
    },
  };

  function createMusic(pattern) {
    let stopped = false;
    let nextStepTime = ctx.currentTime + 0.05;
    let stepIndex = 0;
    const stepDur = 60 / pattern.bpm / (pattern.stepsPerBeat || 1);
    let timerId = null;

    function scheduleStep(time, idx) {
      const delay = time - ctx.currentTime;
      const bassNote = pattern.bass[idx % pattern.bass.length];
      if (bassNote) tone({ freq: bassNote, duration: stepDur * 0.9, type: 'sine', gain: 0.16, dest: musicGain, delay });
      const leadNote = pattern.lead[idx % pattern.lead.length];
      if (leadNote) tone({ freq: leadNote, duration: stepDur * 0.7, type: pattern.leadType, gain: 0.1, dest: musicGain, delay });
    }

    function scheduler() {
      if (stopped) return;
      while (nextStepTime < ctx.currentTime + 0.15) {
        scheduleStep(nextStepTime, stepIndex);
        nextStepTime += stepDur;
        stepIndex++;
      }
      timerId = setTimeout(scheduler, 50);
    }

    scheduler();
    return { stop() { stopped = true; if (timerId) clearTimeout(timerId); } };
  }

  function playMusic(name) {
    if (musicMode === name) return;
    musicMode = name;
    ensureContext();
    if (currentMusic) currentMusic.stop();
    currentMusic = name ? createMusic(MUSIC[name]) : null;
  }

  function stopMusic() {
    musicMode = null;
    if (currentMusic) { currentMusic.stop(); currentMusic = null; }
  }

  return { unlock, setMuted, toggleMuted, isMuted, SFX, playMusic, stopMusic };
})();
