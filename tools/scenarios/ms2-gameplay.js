// Capture Mecha Survivant 2 (Godot/wasm) en cours de partie.
//
//   node tools/capture.js http://localhost:8123/index.html sortie.png \
//     --scenario tools/scenarios/ms2-gameplay.js
//
// La boucle de jeu vit dans le wasm : `driver.js` n'a pas prise dessus, on
// pilote donc par de vrais événements souris/clavier et par de l'attente.
// La vague de départ se choisit avec MS2_WAVE (1-20) ou MS2_TITAN=1.

const BOOT_MS = 15000;
const PLAY_MS = 6000;

const sleep = ms => new Promise(r => setTimeout(r, ms));

module.exports = async ({ page, out }) => {
  await sleep(BOOT_MS);

  const wave = parseInt(process.env.MS2_WAVE || "1", 10);
  const titan = process.env.MS2_TITAN === "1";

  // Coordonnées relevées sur une capture de l'écran-titre : les boutons sont
  // dessinés par Godot dans le canvas, il n'y a pas de DOM à cliquer. À
  // réajuster si la mise en page de start_screen.gd change.
  const cx = 500;
  const SELECT_Y = 336;
  const PLAY_Y = 377;
  const TITAN_Y = 420;
  if (titan) {
    await page.mouse.click(cx, TITAN_Y);
  } else {
    if (wave > 1) {
      await page.mouse.click(cx, SELECT_Y);        // ouvre le sélecteur
      await sleep(400);
      // Une pression est absorbée par l'ouverture du popup, d'où le <= .
      for (let i = 1; i <= wave; i++) {
        await page.keyboard.press("ArrowDown");
      }
      await page.keyboard.press("Enter");
      await sleep(400);
    }
    await page.mouse.click(cx, PLAY_Y);          // LANCER
  }

  await sleep(1000);
  // Le mech se déplace et arrose : sans entrée, il reste planté au centre.
  await page.mouse.move(700, 250);
  await page.keyboard.down("KeyD");
  await page.mouse.down();
  await sleep(PLAY_MS);
  await page.mouse.up();
  await page.keyboard.up("KeyD");

  await page.screenshot({ path: out });
  console.log("capture :", out);
};
