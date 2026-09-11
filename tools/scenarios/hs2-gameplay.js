// Capture Hell's Survivant 2 (Godot/wasm) en cours de partie.
//
//   node tools/capture.js http://localhost:8124/index.html sortie.png \
//     --scenario tools/scenarios/hs2-gameplay.js --no-step
//
// Aucune coordonnée de clic : l'écran-titre se pilote au clavier comme la v1
// (Z/S pour l'élément, Entrée pour combattre). HS2_ELEMENT_STEPS avance d'autant
// d'éléments depuis « Sang » (1 = Violence, 3 = Feu, 5 = Ombre…).

const BOOT_MS = 15000;
const PLAY_MS = parseInt(process.env.HS2_PLAY_MS || "9000", 10);

const sleep = ms => new Promise(r => setTimeout(r, ms));

module.exports = async ({ page, out }) => {
  await sleep(BOOT_MS);
  await page.mouse.click(450, 580);
  const steps = parseInt(process.env.HS2_ELEMENT_STEPS || "0", 10);
  for (let i = 0; i < steps; i++) {
    await page.keyboard.press("KeyS");
    await sleep(150);
  }
  await page.keyboard.press("Enter");
  await sleep(2500);

  // Le héros tourne en rond en frappant, pour que les vagues l'atteignent.
  const keys = ["KeyD", "KeyS", "KeyQ", "KeyZ"];
  const end = Date.now() + PLAY_MS;
  let k = 0;
  while (Date.now() < end) {
    await page.keyboard.down(keys[k % 4]);
    for (let i = 0; i < 4; i++) {
      await page.keyboard.press("Space");
      await sleep(150);
    }
    await page.keyboard.up(keys[k % 4]);
    k++;
  }
  await page.keyboard.press("Space");
  await sleep(120);
  await page.screenshot({ path: out });
  console.log("capture :", out);
};
