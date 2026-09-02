const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const W = canvas.width;
const H = canvas.height;

// ---------------------------------------------------------------------------
// Données de progression persistante (équipement + or entre les runs)
// ---------------------------------------------------------------------------

const SAVE_KEY = 'hells-survivant-save';

const SWORDS = [
  { name: 'Poings nus', cost: 0, dmg: 3, range: 70 },
  { name: 'Épée rouillée', cost: 25, dmg: 6, range: 82 },
  { name: 'Épée en acier', cost: 75, dmg: 11, range: 92 },
  { name: 'Épée enchantée', cost: 180, dmg: 18, range: 102 },
  { name: 'Lame des enfers', cost: 400, dmg: 30, range: 112 },
  { name: 'Excalibur déchue', cost: 900, dmg: 50, range: 126 },
];

const ARMORS = [
  { name: 'Peau nue', cost: 0, hp: 50, def: 0 },
  { name: 'Haillons', cost: 25, hp: 65, def: 0.05 },
  { name: 'Cuir clouté', cost: 75, hp: 85, def: 0.12 },
  { name: 'Cotte de mailles', cost: 180, hp: 115, def: 0.20 },
  { name: 'Armure infernale', cost: 400, hp: 160, def: 0.30 },
  { name: 'Armure du Damné', cost: 900, hp: 230, def: 0.40 },
];

function loadSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) throw new Error('empty');
    const data = JSON.parse(raw);
    return {
      gold: data.gold || 0,
      swordTier: data.swordTier || 0,
      armorTier: data.armorTier || 0,
    };
  } catch {
    return { gold: 0, swordTier: 0, armorTier: 0 };
  }
}

function writeSave() {
  localStorage.setItem(SAVE_KEY, JSON.stringify({
    gold: save.gold,
    swordTier: save.swordTier,
    armorTier: save.armorTier,
  }));
}

const save = loadSave();

// ---------------------------------------------------------------------------
// Difficultés et éléments
// ---------------------------------------------------------------------------

const DIFFICULTIES = {
  facile: { label: 'Facile', hpMult: 0.7, dmgMult: 0.7, goldMult: 0.8 },
  intermediaire: { label: 'Intermédiaire', hpMult: 1, dmgMult: 1, goldMult: 1 },
  difficile: { label: 'Difficile', hpMult: 1.7, dmgMult: 1.6, goldMult: 1.6 },
};
const DIFFICULTY_ORDER = ['facile', 'intermediaire', 'difficile'];

const ELEMENTS = {
  cendres: { label: 'Cendres', color: '#9a9a9a', glow: '#c8c8c8', hpMult: 0.7, dmgMult: 0.8, speedMult: 1.5, trait: 'Rapides et fragiles' },
  sang: { label: 'Sang', color: '#7a0d18', glow: '#c81e2e', hpMult: 1, dmgMult: 1.1, speedMult: 1, lifesteal: 0.35, trait: 'Se soignent en frappant' },
  violence: { label: 'Violence', color: '#c2410c', glow: '#ff7a3c', hpMult: 0.9, dmgMult: 1.6, speedMult: 1.1, trait: 'Dégâts très élevés' },
  terre: { label: 'Terre', color: '#5a3a1e', glow: '#8a6238', hpMult: 1.9, dmgMult: 1, speedMult: 0.6, trait: 'Très résistants, lents' },
  feu: { label: 'Feu', color: '#ff8c1a', glow: '#ffd23c', hpMult: 1, dmgMult: 1, speedMult: 1, burn: true, trait: 'Laissent brûler leur cible' },
  destruction: { label: 'Destruction', color: '#3c0a5a', glow: '#a020f0', hpMult: 1.4, dmgMult: 1.4, speedMult: 0.9, aoe: true, trait: 'Choc destructeur en zone' },
};
const ELEMENT_ORDER = ['cendres', 'sang', 'violence', 'terre', 'feu', 'destruction'];

// ---------------------------------------------------------------------------
// État global
// ---------------------------------------------------------------------------

let state = 'menu'; // 'menu' | 'playing' | 'shop' | 'gameover'
let selection = { difficulty: 'intermediaire', element: 'sang' };

const player = {
  x: W / 2,
  y: H / 2,
  radius: 16,
  speed: 3.2,
  facingX: 0,
  facingY: 1,
  hp: 0,
  maxHp: 0,
  attackTimer: 0,
  attackCooldown: 0,
  burnTimer: 0,
};

let enemies = [];
let particles = []; // texte flottant (or, dégâts)
let waveNumber = 1;
let waveIntermission = 0;
let enemiesToSpawn = 0;
let spawnTimer = 0;
let runGoldEarned = 0;
let shopReturnState = 'menu';

const keysPressed = {};
let mouseX = W / 2, mouseY = H / 2;

document.addEventListener('keydown', (e) => {
  keysPressed[e.key.toLowerCase()] = true;
  if (state === 'menu') handleMenuKey(e.key.toLowerCase());
  else if (state === 'playing' && (e.key === ' ')) doAttack();
  if (e.key.toLowerCase() === 'i' && (state === 'playing' || state === 'shop' || state === 'menu')) {
    if (state === 'shop') {
      state = shopReturnState;
    } else {
      shopReturnState = state;
      state = 'shop';
    }
  }
  if (e.key === 'Escape' && state === 'shop') state = shopReturnState;
  if (e.key === 'Enter' && state === 'gameover') resetToMenu();
});
document.addEventListener('keyup', (e) => { keysPressed[e.key.toLowerCase()] = false; });
canvas.addEventListener('mousemove', (e) => {
  const rect = canvas.getBoundingClientRect();
  mouseX = (e.clientX - rect.left) * (W / rect.width);
  mouseY = (e.clientY - rect.top) * (H / rect.height);
});
canvas.addEventListener('mousedown', () => {
  if (state === 'playing') {
    player.facingX = mouseX - player.x;
    player.facingY = mouseY - player.y;
    normalizeFacing();
    doAttack();
  } else if (state === 'shop') {
    handleShopClick();
  } else if (state === 'menu') {
    handleMenuClick();
  } else if (state === 'gameover') {
    resetToMenu();
  }
});

function normalizeFacing() {
  const len = Math.hypot(player.facingX, player.facingY) || 1;
  player.facingX /= len;
  player.facingY /= len;
}

// ---------------------------------------------------------------------------
// Menu de sélection
// ---------------------------------------------------------------------------

function handleMenuKey(key) {
  const diffIdx = DIFFICULTY_ORDER.indexOf(selection.difficulty);
  const elemIdx = ELEMENT_ORDER.indexOf(selection.element);
  if (key === 'q' || key === 'arrowleft') {
    selection.difficulty = DIFFICULTY_ORDER[(diffIdx - 1 + 3) % 3];
  } else if (key === 'd' || key === 'arrowright') {
    selection.difficulty = DIFFICULTY_ORDER[(diffIdx + 1) % 3];
  } else if (key === 'z' || key === 'arrowup') {
    selection.element = ELEMENT_ORDER[(elemIdx - 1 + 6) % 6];
  } else if (key === 's' || key === 'arrowdown') {
    selection.element = ELEMENT_ORDER[(elemIdx + 1) % 6];
  } else if (key === 'enter' || key === ' ') {
    startRun();
  }
}

const menuButtons = { diffs: [], elems: [], start: null, shop: null };

function handleMenuClick() {
  for (const b of menuButtons.diffs) {
    if (mouseX >= b.x && mouseX <= b.x + b.w && mouseY >= b.y && mouseY <= b.y + b.h) {
      selection.difficulty = b.id;
      return;
    }
  }
  for (const b of menuButtons.elems) {
    if (mouseX >= b.x && mouseX <= b.x + b.w && mouseY >= b.y && mouseY <= b.y + b.h) {
      selection.element = b.id;
      return;
    }
  }
  const b = menuButtons.start;
  if (b && mouseX >= b.x && mouseX <= b.x + b.w && mouseY >= b.y && mouseY <= b.y + b.h) {
    startRun();
    return;
  }
  const s = menuButtons.shop;
  if (s && mouseX >= s.x && mouseX <= s.x + s.w && mouseY >= s.y && mouseY <= s.y + s.h) {
    shopReturnState = 'menu';
    state = 'shop';
  }
}

function startRun() {
  const armor = ARMORS[save.armorTier];
  player.maxHp = armor.hp;
  player.hp = player.maxHp;
  player.x = W / 2;
  player.y = H / 2;
  player.burnTimer = 0;
  enemies = [];
  particles = [];
  waveNumber = 1;
  waveIntermission = 60;
  enemiesToSpawn = 0;
  runGoldEarned = 0;
  state = 'playing';
}

function resetToMenu() {
  state = 'menu';
}

// ---------------------------------------------------------------------------
// Vagues et ennemis
// ---------------------------------------------------------------------------

function currentEnemyCount() {
  return 3 + Math.floor(waveNumber * 1.4);
}

function isBossWave() {
  return waveNumber % 5 === 0;
}

function spawnEnemy(isBoss) {
  const diff = DIFFICULTIES[selection.difficulty];
  const elem = ELEMENTS[selection.element];
  const side = Math.floor(Math.random() * 4);
  let x, y;
  if (side === 0) { x = -30; y = Math.random() * H; }
  else if (side === 1) { x = W + 30; y = Math.random() * H; }
  else if (side === 2) { x = Math.random() * W; y = -30; }
  else { x = Math.random() * W; y = H + 30; }

  const waveGrowth = 1 + waveNumber * 0.08;
  const baseHp = 18 * elem.hpMult * diff.hpMult * waveGrowth;
  const baseDmg = 4 * elem.dmgMult * diff.dmgMult;
  const baseSpeed = 1.3 * elem.speedMult;

  const mult = isBoss ? 8 : 1;
  const dmgMult = isBoss ? 2 : 1;

  enemies.push({
    x, y,
    radius: isBoss ? 34 : 15,
    hp: baseHp * mult,
    maxHp: baseHp * mult,
    dmg: baseDmg * dmgMult,
    speed: isBoss ? baseSpeed * 0.7 : baseSpeed,
    element: selection.element,
    isBoss,
    attackCooldown: 0,
    hitFlash: 0,
    chargeTimer: isBoss ? 180 + Math.random() * 60 : 0,
    charging: false,
    goldValue: Math.round((isBoss ? 40 : 4) * diff.goldMult * (1 + waveNumber * 0.05)),
  });
}

function startWave() {
  if (isBossWave()) {
    spawnEnemy(true);
    enemiesToSpawn = 0;
  } else {
    enemiesToSpawn = currentEnemyCount();
  }
  spawnTimer = 0;
}

function updateWaves() {
  if (waveIntermission > 0) {
    waveIntermission--;
    if (waveIntermission === 0) startWave();
    return;
  }
  if (enemiesToSpawn > 0) {
    spawnTimer--;
    if (spawnTimer <= 0) {
      spawnEnemy(false);
      enemiesToSpawn--;
      spawnTimer = 35;
    }
  }
  if (enemies.length === 0 && enemiesToSpawn === 0 && waveIntermission === 0) {
    waveNumber++;
    waveIntermission = 90;
    addParticle(W / 2, H / 2 - 40, `Vague ${waveNumber} dans 1,5s`, '#ffd23c', true);
  }
}

// ---------------------------------------------------------------------------
// Combat
// ---------------------------------------------------------------------------

function doAttack() {
  if (player.attackCooldown > 0 || player.attackTimer > 0) return;
  const swordDmg = SWORDS[save.swordTier].dmg;
  const range = SWORDS[save.swordTier].range;
  player.attackTimer = 14;
  player.attackCooldown = 22;

  for (const e of enemies) {
    const dx = e.x - player.x;
    const dy = e.y - player.y;
    const dist = Math.hypot(dx, dy);
    if (dist > range + e.radius) continue;
    const angle = Math.atan2(dy, dx);
    const facingAngle = Math.atan2(player.facingY, player.facingX);
    let diff = Math.abs(angle - facingAngle);
    if (diff > Math.PI) diff = Math.PI * 2 - diff;
    if (diff < Math.PI / 2.2) {
      damageEnemy(e, swordDmg);
    }
  }
}

function damageEnemy(e, amount) {
  e.hp -= amount;
  e.hitFlash = 8;
  addParticle(e.x, e.y - e.radius, `-${Math.round(amount)}`, '#fff', false);
  if (e.hp <= 0) killEnemy(e);
}

function killEnemy(e) {
  enemies.splice(enemies.indexOf(e), 1);
  save.gold += e.goldValue;
  runGoldEarned += e.goldValue;
  writeSave();
  addParticle(e.x, e.y, `+${e.goldValue} or`, '#ffd23c', false);
}

function updateEnemies() {
  const elem = ELEMENTS[selection.element];
  for (const e of enemies) {
    if (e.hitFlash > 0) e.hitFlash--;

    if (e.isBoss) {
      e.chargeTimer--;
      if (e.chargeTimer <= 0 && !e.charging) {
        e.charging = true;
        e.chargeTelegraph = 45;
      }
      if (e.charging) {
        if (e.chargeTelegraph > 0) {
          e.chargeTelegraph--;
        } else {
          const dx = player.x - e.x, dy = player.y - e.y;
          const len = Math.hypot(dx, dy) || 1;
          e.x += (dx / len) * e.speed * 6;
          e.y += (dy / len) * e.speed * 6;
          e.chargeTimer = 180 + Math.random() * 60;
          e.charging = false;
        }
        continue;
      }
    }

    const dx = player.x - e.x;
    const dy = player.y - e.y;
    const dist = Math.hypot(dx, dy) || 1;
    if (dist > e.radius + player.radius) {
      e.x += (dx / dist) * e.speed;
      e.y += (dy / dist) * e.speed;
    } else if (e.attackCooldown <= 0) {
      hitPlayer(e.dmg);
      e.attackCooldown = 50;
      if (elem.lifesteal) {
        e.hp = Math.min(e.maxHp, e.hp + e.dmg * elem.lifesteal);
      }
      if (elem.burn) {
        player.burnTimer = 120;
      }
      if (elem.aoe) {
        addParticle(e.x, e.y - 20, 'ONDE DE CHOC', '#a020f0', false);
      }
    }
    if (e.attackCooldown > 0) e.attackCooldown--;
  }
}

function hitPlayer(rawDmg) {
  const def = ARMORS[save.armorTier].def;
  const dmg = rawDmg * (1 - def);
  player.hp -= dmg;
  addParticle(player.x, player.y - player.radius - 10, `-${Math.round(dmg)}`, '#ff4444', false);
  if (player.hp <= 0) {
    player.hp = 0;
    state = 'gameover';
  }
}

// ---------------------------------------------------------------------------
// Joueur
// ---------------------------------------------------------------------------

function updatePlayer() {
  let dx = 0, dy = 0;
  if (keysPressed['z'] || keysPressed['arrowup']) dy -= 1;
  if (keysPressed['s'] || keysPressed['arrowdown']) dy += 1;
  if (keysPressed['q'] || keysPressed['arrowleft']) dx -= 1;
  if (keysPressed['d'] || keysPressed['arrowright']) dx += 1;

  if (dx !== 0 || dy !== 0) {
    const len = Math.hypot(dx, dy);
    dx /= len; dy /= len;
    player.x += dx * player.speed;
    player.y += dy * player.speed;
    if (player.attackTimer <= 0) {
      player.facingX = dx;
      player.facingY = dy;
    }
  }
  player.x = Math.max(player.radius, Math.min(W - player.radius, player.x));
  player.y = Math.max(player.radius, Math.min(H - player.radius, player.y));

  if (player.attackTimer > 0) player.attackTimer--;
  if (player.attackCooldown > 0) player.attackCooldown--;

  if (player.burnTimer > 0) {
    player.burnTimer--;
    if (player.burnTimer % 20 === 0) {
      hitPlayer(2);
    }
  }
}

// ---------------------------------------------------------------------------
// Particules (textes flottants)
// ---------------------------------------------------------------------------

function addParticle(x, y, text, color, big) {
  particles.push({ x, y, text, color, big, life: 50, vy: -0.6 });
}

function updateParticles() {
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.y += p.vy;
    p.life--;
    if (p.life <= 0) particles.splice(i, 1);
  }
}

// ---------------------------------------------------------------------------
// Boutique
// ---------------------------------------------------------------------------

const shopButtons = { sword: null, armor: null, close: null };

function handleShopClick() {
  if (shopButtons.sword && withinButton(shopButtons.sword)) tryBuySword();
  if (shopButtons.armor && withinButton(shopButtons.armor)) tryBuyArmor();
  if (shopButtons.close && withinButton(shopButtons.close)) state = shopReturnState;
}

function withinButton(b) {
  return mouseX >= b.x && mouseX <= b.x + b.w && mouseY >= b.y && mouseY <= b.y + b.h;
}

function tryBuySword() {
  const next = save.swordTier + 1;
  if (next >= SWORDS.length) return;
  if (save.gold >= SWORDS[next].cost) {
    save.gold -= SWORDS[next].cost;
    save.swordTier = next;
    writeSave();
  }
}

function tryBuyArmor() {
  const next = save.armorTier + 1;
  if (next >= ARMORS.length) return;
  if (save.gold >= ARMORS[next].cost) {
    save.gold -= ARMORS[next].cost;
    save.armorTier = next;
    const hpGain = ARMORS[next].hp - ARMORS[next - 1].hp;
    player.maxHp += hpGain;
    player.hp += hpGain;
    writeSave();
  }
}

// ---------------------------------------------------------------------------
// Rendu
// ---------------------------------------------------------------------------

function drawBackground() {
  ctx.fillStyle = '#1a0505';
  ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = 'rgba(120, 20, 10, 0.25)';
  ctx.lineWidth = 1;
  for (let x = 0; x < W; x += 40) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, H);
    ctx.stroke();
  }
  for (let y = 0; y < H; y += 40) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y);
    ctx.stroke();
  }
}

function drawPlayer() {
  const armor = ARMORS[save.armorTier];
  const armorColors = ['#d8a878', '#8a6a4a', '#6a6a6a', '#5a7a3a', '#8a2a2a', '#c8a020'];
  const bodyColor = save.armorTier === 0 ? '#d8a878' : armorColors[save.armorTier];

  ctx.save();
  ctx.translate(player.x, player.y);

  // ombre
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(0, player.radius - 2, player.radius * 0.8, player.radius * 0.35, 0, 0, Math.PI * 2);
  ctx.fill();

  // corps (bloc pixel-art)
  ctx.fillStyle = bodyColor;
  ctx.fillRect(-10, -18, 20, 26);
  // tête
  ctx.fillStyle = '#d8a878';
  ctx.fillRect(-8, -32, 16, 16);
  // yeux
  ctx.fillStyle = '#1a0505';
  ctx.fillRect(-5, -26, 3, 3);
  ctx.fillRect(3, -26, 3, 3);
  // jambes
  ctx.fillStyle = '#3a2a1a';
  ctx.fillRect(-9, 8, 7, 10);
  ctx.fillRect(2, 8, 7, 10);

  // épée
  if (player.attackTimer > 0) {
    const progress = 1 - player.attackTimer / 14;
    const baseAngle = Math.atan2(player.facingY, player.facingX);
    const swing = (progress - 0.5) * (Math.PI / 1.6);
    const angle = baseAngle + swing;
    const range = SWORDS[save.swordTier].range;
    ctx.strokeStyle = '#e8e8e8';
    ctx.lineWidth = 7;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(angle) * range, Math.sin(angle) * range);
    ctx.stroke();
  } else {
    const angle = Math.atan2(player.facingY, player.facingX);
    const range = SWORDS[save.swordTier].range * 0.6;
    ctx.strokeStyle = '#c8c8c8';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(Math.cos(angle) * 10, Math.sin(angle) * 10);
    ctx.lineTo(Math.cos(angle) * range, Math.sin(angle) * range);
    ctx.stroke();
  }

  ctx.restore();
}

function drawEnemy(e) {
  const elem = ELEMENTS[e.element];
  ctx.save();
  ctx.translate(e.x, e.y);

  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(0, e.radius - 2, e.radius * 0.8, e.radius * 0.3, 0, 0, Math.PI * 2);
  ctx.fill();

  const flashColor = e.hitFlash > 0 ? '#ffffff' : elem.color;
  ctx.fillStyle = flashColor;
  if (e.charging && e.chargeTelegraph > 0) {
    ctx.shadowColor = elem.glow;
    ctx.shadowBlur = 20;
  }
  ctx.beginPath();
  ctx.arc(0, 0, e.radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;

  ctx.fillStyle = elem.glow;
  ctx.beginPath();
  ctx.arc(-e.radius * 0.35, -e.radius * 0.25, e.radius * 0.18, 0, Math.PI * 2);
  ctx.arc(e.radius * 0.35, -e.radius * 0.25, e.radius * 0.18, 0, Math.PI * 2);
  ctx.fill();

  // barre de vie
  const barW = e.radius * 2.2;
  ctx.fillStyle = '#000';
  ctx.fillRect(-barW / 2, -e.radius - 14, barW, 5);
  ctx.fillStyle = elem.glow;
  ctx.fillRect(-barW / 2, -e.radius - 14, barW * Math.max(0, e.hp / e.maxHp), 5);

  ctx.restore();

  if (e.isBoss) {
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.textAlign = 'center';
    ctx.fillText(`Boss ${elem.label}`, e.x, e.y - e.radius - 20);
  }
}

function drawParticles() {
  ctx.textAlign = 'center';
  for (const p of particles) {
    ctx.globalAlpha = Math.max(0, p.life / 50);
    ctx.fillStyle = p.color;
    ctx.font = p.big ? 'bold 20px "Courier New", monospace' : '13px "Courier New", monospace';
    ctx.fillText(p.text, p.x, p.y);
  }
  ctx.globalAlpha = 1;
}

function drawHUD() {
  // barre de vie joueur
  ctx.fillStyle = '#000';
  ctx.fillRect(20, 20, 220, 22);
  ctx.fillStyle = '#22c55e';
  ctx.fillRect(20, 20, 220 * Math.max(0, player.hp / player.maxHp), 22);
  ctx.strokeStyle = '#fff';
  ctx.strokeRect(20, 20, 220, 22);
  ctx.fillStyle = '#fff';
  ctx.font = '13px "Courier New", monospace';
  ctx.textAlign = 'left';
  ctx.fillText(`${Math.round(player.hp)} / ${player.maxHp} PV`, 28, 36);

  ctx.fillText(`Or : ${save.gold}`, 20, 62);
  ctx.fillText(`Vague ${waveNumber}${isBossWave() ? ' — BOSS' : ''}`, 20, 82);
  ctx.fillText(`${DIFFICULTIES[selection.difficulty].label} — ${ELEMENTS[selection.element].label}`, 20, 102);

  ctx.textAlign = 'right';
  ctx.fillText(`I : boutique`, W - 20, 30);

  if (waveIntermission > 0 && enemies.length === 0) {
    ctx.textAlign = 'center';
    ctx.font = 'bold 22px "Courier New", monospace';
    ctx.fillStyle = '#ffd23c';
    ctx.fillText(`Vague ${waveNumber} arrive...`, W / 2, 60);
  }
}

function drawMenu() {
  ctx.fillStyle = '#1a0505';
  ctx.fillRect(0, 0, W, H);

  ctx.textAlign = 'center';
  ctx.fillStyle = '#ff5a3c';
  ctx.font = 'bold 30px "Courier New", monospace';
  ctx.fillText("Choisis ton arène", W / 2, 70);

  ctx.font = '14px "Courier New", monospace';
  ctx.fillStyle = '#b58a80';
  ctx.fillText('ZD ou clic : difficulté — ZS ou clic : élément — Entrée : combattre', W / 2, 96);

  // difficulté
  ctx.font = 'bold 18px "Courier New", monospace';
  ctx.fillStyle = '#fff';
  ctx.fillText('Difficulté', W / 2, 140);
  menuButtons.diffs = [];
  const diffW = 160, diffH = 42, diffGap = 20;
  const diffTotal = DIFFICULTY_ORDER.length * diffW + (DIFFICULTY_ORDER.length - 1) * diffGap;
  let dx = W / 2 - diffTotal / 2;
  for (const id of DIFFICULTY_ORDER) {
    const d = DIFFICULTIES[id];
    const selected = selection.difficulty === id;
    ctx.fillStyle = selected ? '#ff5a3c' : '#3a1a1a';
    ctx.fillRect(dx, 155, diffW, diffH);
    ctx.strokeStyle = selected ? '#ffd23c' : '#5a1e14';
    ctx.lineWidth = 2;
    ctx.strokeRect(dx, 155, diffW, diffH);
    ctx.fillStyle = '#fff';
    ctx.font = '15px "Courier New", monospace';
    ctx.fillText(d.label, dx + diffW / 2, 155 + diffH / 2 + 5);
    menuButtons.diffs.push({ id, x: dx, y: 155, w: diffW, h: diffH });
    dx += diffW + diffGap;
  }

  // éléments
  ctx.font = 'bold 18px "Courier New", monospace';
  ctx.fillStyle = '#fff';
  ctx.fillText('Élément des monstres', W / 2, 235);
  menuButtons.elems = [];
  const elemW = 190, elemH = 52, elemGap = 14;
  const cols = 3;
  const startX = W / 2 - (cols * elemW + (cols - 1) * elemGap) / 2;
  let col = 0, row = 0;
  for (const id of ELEMENT_ORDER) {
    const el = ELEMENTS[id];
    const selected = selection.element === id;
    const ex = startX + col * (elemW + elemGap);
    const ey = 250 + row * (elemH + elemGap);
    ctx.fillStyle = selected ? el.color : '#241010';
    ctx.fillRect(ex, ey, elemW, elemH);
    ctx.strokeStyle = selected ? el.glow : '#5a1e14';
    ctx.lineWidth = 2;
    ctx.strokeRect(ex, ey, elemW, elemH);
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 15px "Courier New", monospace';
    ctx.fillText(el.label, ex + elemW / 2, ey + 22);
    ctx.font = '11px "Courier New", monospace';
    ctx.fillStyle = '#e0d0c8';
    ctx.fillText(el.trait, ex + elemW / 2, ey + 40);
    menuButtons.elems.push({ id, x: ex, y: ey, w: elemW, h: elemH });
    col++;
    if (col >= cols) { col = 0; row++; }
  }

  // boutons start + boutique
  const btnW = 220, btnH = 50, btnGap = 20, btnY = 420;
  const btnX = W / 2 - btnW - btnGap / 2;
  ctx.fillStyle = '#7a0d18';
  ctx.fillRect(btnX, btnY, btnW, btnH);
  ctx.strokeStyle = '#ffd23c';
  ctx.lineWidth = 2;
  ctx.strokeRect(btnX, btnY, btnW, btnH);
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 18px "Courier New", monospace';
  ctx.fillText('Entrer dans l\'arène', btnX + btnW / 2, btnY + btnH / 2 + 6);
  menuButtons.start = { x: btnX, y: btnY, w: btnW, h: btnH };

  const shopX = W / 2 + btnGap / 2;
  ctx.fillStyle = '#4a1a5a';
  ctx.fillRect(shopX, btnY, btnW, btnH);
  ctx.strokeStyle = '#c8a020';
  ctx.lineWidth = 2;
  ctx.strokeRect(shopX, btnY, btnW, btnH);
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 18px "Courier New", monospace';
  ctx.fillText('Boutique', shopX + btnW / 2, btnY + btnH / 2 + 6);
  menuButtons.shop = { x: shopX, y: btnY, w: btnW, h: btnH };

  // équipement actuel
  ctx.font = '13px "Courier New", monospace';
  ctx.fillStyle = '#b58a80';
  ctx.fillText(`Équipement : ${SWORDS[save.swordTier].name} — ${ARMORS[save.armorTier].name} — Or : ${save.gold}`, W / 2, 500);
}

function drawShopItem(x, y, title, current, next, isSword) {
  const w = 380, h = 130;
  ctx.fillStyle = '#241010';
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#5a1e14';
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, w, h);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#ffd23c';
  ctx.font = 'bold 16px "Courier New", monospace';
  ctx.fillText(title, x + 16, y + 26);

  ctx.fillStyle = '#fff';
  ctx.font = '13px "Courier New", monospace';
  ctx.fillText(`Actuel : ${current.name}`, x + 16, y + 50);
  if (isSword) {
    ctx.fillText(`Dégâts : ${current.dmg}`, x + 16, y + 68);
  } else {
    ctx.fillText(`PV : ${current.hp}   Défense : ${Math.round(current.def * 100)}%`, x + 16, y + 68);
  }

  let btn = null;
  if (next) {
    const afford = save.gold >= next.cost;
    ctx.fillStyle = afford ? '#2f7a2f' : '#4a2020';
    const bx = x + 16, by = y + 84, bw = w - 32, bh = 34;
    ctx.fillRect(bx, by, bw, bh);
    ctx.strokeStyle = afford ? '#7fffa0' : '#7a3a3a';
    ctx.strokeRect(bx, by, bw, bh);
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    const stat = isSword ? `Dégâts ${next.dmg}` : `PV ${next.hp} · Déf ${Math.round(next.def * 100)}%`;
    ctx.fillText(`Acheter ${next.name} (${stat}) — ${next.cost} or`, x + w / 2, by + 22);
    btn = { x: bx, y: by, w: bw, h: bh };
  } else {
    ctx.fillStyle = '#8a6a4a';
    ctx.textAlign = 'center';
    ctx.font = 'italic 13px "Courier New", monospace';
    ctx.fillText('Niveau maximum atteint', x + w / 2, y + 105);
  }
  return btn;
}

function drawShop() {
  ctx.fillStyle = 'rgba(0,0,0,0.75)';
  ctx.fillRect(0, 0, W, H);

  ctx.textAlign = 'center';
  ctx.fillStyle = '#ff5a3c';
  ctx.font = 'bold 26px "Courier New", monospace';
  ctx.fillText('Forge infernale', W / 2, 60);
  ctx.font = '13px "Courier New", monospace';
  ctx.fillStyle = '#b58a80';
  ctx.fillText(`Or disponible : ${save.gold} — I ou Échap pour fermer`, W / 2, 84);

  shopButtons.sword = drawShopItem(W / 2 - 400, 110, 'Épée', SWORDS[save.swordTier], SWORDS[save.swordTier + 1], true);
  shopButtons.armor = drawShopItem(W / 2 + 20, 110, 'Armure', ARMORS[save.armorTier], ARMORS[save.armorTier + 1], false);

  const cbx = W / 2 - 70, cby = 270, cbw = 140, cbh = 36;
  ctx.fillStyle = '#5a1e14';
  ctx.fillRect(cbx, cby, cbw, cbh);
  ctx.strokeStyle = '#fff';
  ctx.strokeRect(cbx, cby, cbw, cbh);
  ctx.fillStyle = '#fff';
  ctx.font = '14px "Courier New", monospace';
  ctx.fillText('Fermer', W / 2, cby + 23);
  shopButtons.close = { x: cbx, y: cby, w: cbw, h: cbh };
}

function drawGameOver() {
  ctx.fillStyle = 'rgba(0,0,0,0.8)';
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#ff3c3c';
  ctx.font = 'bold 32px "Courier New", monospace';
  ctx.fillText('Tu es tombé aux enfers', W / 2, H / 2 - 40);
  ctx.fillStyle = '#fff';
  ctx.font = '16px "Courier New", monospace';
  ctx.fillText(`Vague atteinte : ${waveNumber}`, W / 2, H / 2);
  ctx.fillText(`Or récolté ce run : ${runGoldEarned}`, W / 2, H / 2 + 26);
  ctx.font = '14px "Courier New", monospace';
  ctx.fillStyle = '#b58a80';
  ctx.fillText('Clic ou Entrée : retour au menu (équipement conservé)', W / 2, H / 2 + 60);
}

// ---------------------------------------------------------------------------
// Boucle principale
// ---------------------------------------------------------------------------

function update() {
  if (state !== 'playing') return;
  updatePlayer();
  updateWaves();
  updateEnemies();
  updateParticles();
}

function draw() {
  if (state === 'menu' || (state === 'shop' && shopReturnState === 'menu')) {
    drawMenu();
    if (state === 'shop') drawShop();
    return;
  }

  drawBackground();
  for (const e of enemies) drawEnemy(e);
  drawPlayer();
  drawParticles();
  drawHUD();

  if (state === 'shop') drawShop();
  if (state === 'gameover') drawGameOver();
}

function loop() {
  update();
  draw();
  requestAnimationFrame(loop);
}

loop();
