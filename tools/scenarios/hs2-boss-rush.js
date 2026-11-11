// Capture Hell's Survivant 2 (Godot/wasm) : menu, puis Conclave des boss.
//
//   node tools/capture.js http://localhost:8124/index.html sortie.png \
//     --scenario tools/scenarios/hs2-boss-rush.js --no-step
//
// Écrit trois images : <sortie>-menu.png (écran-titre), <sortie>-intro.png
// (boss en anneau, pendant l'annonce) et <sortie> (en plein combat, après
// HS2_PLAY_MS ms). Le Conclave se lance au clavier (Q : Facile, puis B), sans
// coordonnée de clic. Le héros reste au centre et frappe : les boss
// convergent sur lui, ce qui montre leur séparation. Sans équipement, il ne
// tient que quelques secondes, d'où la courte durée par défaut.

const BOOT_MS = 15000;
const PLAY_MS = parseInt(process.env.HS2_PLAY_MS || "2500", 10);

const sleep = ms => new Promise(r => setTimeout(r, ms));

module.exports = async ({ page, out }) => {
  const suffixed = tag => out.replace(/\.png$/, `-${tag}.png`);
  await sleep(BOOT_MS);
  await page.mouse.click(450, 590);
  await page.keyboard.press("KeyQ");
  await sleep(150);
  await page.screenshot({ path: suffixed("menu") });
  await page.keyboard.press("KeyB");
  await sleep(1200);
  await page.screenshot({ path: suffixed("intro") });
  await sleep(1000);

  const end = Date.now() + PLAY_MS;
  while (Date.now() < end) {
    await page.keyboard.press("Space");
    await sleep(150);
  }
  await page.screenshot({ path: out });
  console.log("capture :", suffixed("menu"), suffixed("intro"), out);
};
