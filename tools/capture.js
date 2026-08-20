#!/usr/bin/env node
// Capture d'écran d'un jeu du dépôt dans un Chromium headless.
//
//   node tools/capture.js <jeu.html> <sortie.png> [--frames N] [--scenario fichier.js]
//
// Sans scénario, la page est chargée puis capturée telle quelle.
// Avec `--frames`, la boucle de jeu est pilotée image par image (voir driver.js),
// ce qui rend les captures déterministes : indispensable pour attraper un effet
// qui ne dure que quelques frames.
//
// Prérequis : chromium installé (`sudo apt install chromium`) et
// `npm install` lancé dans ce dossier.

const path = require("path");
const { launch, CHROMIUM } = require("./driver.js");

function parseArgs(argv) {
  const args = { file: null, out: null, frames: 0, scenario: null };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--frames") args.frames = parseInt(argv[++i], 10) || 0;
    else if (argv[i] === "--scenario") args.scenario = argv[++i];
    else rest.push(argv[i]);
  }
  [args.file, args.out] = rest;
  return args;
}

(async () => {
  const args = parseArgs(process.argv.slice(2));
  if (!args.file || !args.out) {
    console.error("usage : node tools/capture.js <jeu.html> <sortie.png> [--frames N] [--scenario fichier.js]");
    process.exit(1);
  }

  const { browser, page, errors } = await launch({ stepped: args.frames > 0 || !!args.scenario });

  await page.goto("file://" + path.resolve(args.file), { waitUntil: "load" });

  if (args.scenario) {
    // Un scénario reçoit la page et des utilitaires, et décide lui-même de ce
    // qu'il capture. Voir scenarios/ pour des exemples.
    const scenario = require(path.resolve(args.scenario));
    await scenario({ page, out: args.out, step: (n = 1) => page.evaluate(n => window.__step(n), n) });
  } else {
    if (args.frames > 0) await page.evaluate(n => window.__step(n), args.frames);
    else await new Promise(r => setTimeout(r, 500));
    await page.screenshot({ path: args.out });
    console.log("capture :", args.out);
  }

  console.log(errors.length ? "ERREURS PAGE :\n" + errors.join("\n") : "aucune erreur console");
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
