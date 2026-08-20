// Lancement d'un Chromium headless pour inspecter les jeux, avec une boucle de
// jeu pilotable image par image.
//
// Les jeux du dépôt tournent tous sur `requestAnimationFrame`. En mode « stepped »,
// on remplace rAF par une file que l'on vide à la demande via `window.__step(n)` :
// le temps du jeu n'avance que lorsqu'on le décide. Une capture tombe alors
// exactement sur la frame voulue, ce qui permet d'observer un projectile rapide
// ou une animation de quelques frames.

const puppeteer = require("puppeteer-core");

const CHROMIUM = process.env.CHROMIUM_PATH || "/usr/bin/chromium";

// Injecté avant tout script de la page.
const STEP_HOOK = () => {
  window.__q = [];
  window.__frame = 0;
  window.requestAnimationFrame = (cb) => { window.__q.push(cb); return window.__q.length; };
  window.__step = (n = 1) => {
    for (let i = 0; i < n; i++) {
      const batch = window.__q;
      window.__q = [];
      window.__frame++;
      for (const cb of batch) cb(window.__frame * 16.7);
    }
    return window.__frame;
  };
};

async function launch({ stepped = false, width = 1000, height = 660 } = {}) {
  const browser = await puppeteer.launch({
    executablePath: CHROMIUM,
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--hide-scrollbars",
      "--mute-audio",
    ],
  });
  const page = await browser.newPage();
  await page.setViewport({ width, height });

  const errors = [];
  page.on("pageerror", e => errors.push("pageerror: " + e.message));
  page.on("console", m => { if (m.type() === "error") errors.push("console: " + m.text()); });

  if (stepped) await page.evaluateOnNewDocument(STEP_HOOK);

  return { browser, page, errors };
}

module.exports = { launch, CHROMIUM };
