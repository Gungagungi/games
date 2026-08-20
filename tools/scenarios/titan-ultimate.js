// Scénario : le combat final de Mecha Survivant, jusqu'à l'attaque ultime.
//
//   node tools/capture.js mecha-survivant/index.html tools/shots/ultime.png \
//     --scenario tools/scenarios/titan-ultimate.js
//
// Passe par le bouton « TEST : TITAN À 5 % » de l'écran d'accueil, mitraille le
// boss jusqu'à ce qu'il tombe à 1 % et entre en charge, puis capture la charge
// et le vol de la boule de feu frame par frame.

const path = require("path");
const fs = require("fs");

module.exports = async function ({ page, out, step }) {
  const dir = path.dirname(out);
  const base = path.basename(out, ".png");
  fs.mkdirSync(dir, { recursive: true });
  const shot = (name) => page.screenshot({ path: path.join(dir, `${base}-${name}.png`) });
  const phaseLabel = () => page.$eval("#bossPhaseLabel", el => el.textContent);

  await page.click("#testUltimateBtn");

  const box = await (await page.$("#gameCanvas")).boundingBox();
  await page.mouse.move(box.x + 500, box.y + 160); // viser le boss
  await page.mouse.down();

  // avancer jusqu'à l'entrée en charge (le HUD passe à « INVULNÉRABLE »)
  let f = 0;
  while (f < 4000 && !(await phaseLabel()).includes("INVULNÉRABLE")) { await step(1); f++; }
  await page.mouse.up();
  if (f >= 4000) { console.error("le boss n'est jamais entré en charge"); return; }
  console.log("charge amorcée à la frame", f);
  await shot("1-charge-debut");

  await step(90);
  await shot("2-charge-milieu");
  await step(88); // la charge dure 180 frames : on s'arrête juste avant le tir
  await shot("3-avant-tir");

  // vol de la boule : une capture toutes les 3 frames
  for (let i = 0; i < 12; i++) {
    await step(3);
    await shot(`4-vol-${String(i).padStart(2, "0")}`);
  }
  console.log("captures écrites dans", dir);
};
