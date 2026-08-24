#!/usr/bin/env node
// Capture d'écran d'un jeu du dépôt dans un Chromium headless.
//
//   node tools/capture.js <jeu.html|URL> <sortie.png> [--frames N] [--wait ms]
//                          [--scenario fichier.js] [--no-step]
//
// Sans scénario, la page est chargée puis capturée telle quelle. `--wait` laisse
// le temps au jeu de démarrer : un export Godot met plusieurs secondes à
// télécharger son wasm et à afficher autre chose que l'écran de chargement.
// Avec `--frames`, la boucle de jeu est pilotée image par image (voir driver.js),
// ce qui rend les captures déterministes : indispensable pour attraper un effet
// qui ne dure que quelques frames.
//
// `--no-step` désactive ce pilotage même avec un scénario. C'est obligatoire
// pour un jeu Godot exporté en wasm : sa boucle est dans le wasm et passe par
// requestAnimationFrame, que driver.js remplace — le jeu resterait figé.
//
// Prérequis : chromium installé (`sudo apt install chromium`) et
// `npm install` lancé dans ce dossier.

const path = require("path");
const { launch, CHROMIUM } = require("./driver.js");

function parseArgs(argv) {
  const args = { file: null, out: null, frames: 0, wait: 500, scenario: null, noStep: false };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--frames") args.frames = parseInt(argv[++i], 10) || 0;
    else if (argv[i] === "--wait") args.wait = parseInt(argv[++i], 10) || 0;
    else if (argv[i] === "--scenario") args.scenario = argv[++i];
    else if (argv[i] === "--no-step") args.noStep = true;
    else rest.push(argv[i]);
  }
  [args.file, args.out] = rest;
  return args;
}

(async () => {
  const args = parseArgs(process.argv.slice(2));
  if (!args.file || !args.out) {
    console.error("usage : node tools/capture.js <jeu.html|URL> <sortie.png> [--frames N] [--wait ms] [--scenario fichier.js] [--no-step]");
    process.exit(1);
  }

  const stepped = !args.noStep && (args.frames > 0 || !!args.scenario);
  const { browser, page, errors } = await launch({ stepped });

  // Un jeu Godot exporté ne tourne pas en file:// (il va chercher son .pck et son
  // .wasm) : on accepte donc aussi une URL servie en http.
  const target = /^https?:\/\//.test(args.file)
    ? args.file
    : "file://" + path.resolve(args.file);
  await page.goto(target, { waitUntil: "load" });

  if (args.scenario) {
    // Un scénario reçoit la page et des utilitaires, et décide lui-même de ce
    // qu'il capture. Voir scenarios/ pour des exemples.
    const scenario = require(path.resolve(args.scenario));
    await scenario({ page, out: args.out, step: (n = 1) => page.evaluate(n => window.__step(n), n) });
  } else {
    if (args.frames > 0) await page.evaluate(n => window.__step(n), args.frames);
    else await new Promise(r => setTimeout(r, args.wait));
    await page.screenshot({ path: args.out });
    console.log("capture :", args.out);
  }

  console.log(errors.length ? "ERREURS PAGE :\n" + errors.join("\n") : "aucune erreur console");
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
