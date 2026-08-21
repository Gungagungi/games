# tools — inspection visuelle des jeux

Outillage de **développement** uniquement : il sert à regarder les jeux tourner sur une machine sans écran (serveur headless). Aucun jeu du dépôt n'en dépend — ils restent du HTML/CSS/JS pur, ouvrables directement dans un navigateur.

## Installation

```sh
sudo apt install chromium          # une fois ; ou définir CHROMIUM_PATH
cd tools && npm install            # puppeteer-core, qui pilote le chromium système
```

## Capturer un jeu

```sh
node tools/capture.js mecha-survivant/index.html tools/shots/accueil.png
```

La sortie signale aussi les erreurs de console de la page — un moyen rapide de vérifier qu'un jeu ne casse pas au chargement.

## Attraper un effet fugace

Un projectile rapide traverse l'écran en une demi-seconde : une capture prise « à peu près au bon moment » le rate. `driver.js` remplace donc `requestAnimationFrame` par une file vidée à la demande, si bien que **le temps du jeu n'avance que sur commande** :

```sh
node tools/capture.js mecha-survivant/index.html tools/shots/x.png --frames 240
```

capture exactement la frame 240 après le chargement.

Pour une séquence pilotée (cliquer, jouer, attendre un état précis puis capturer), écrire un scénario dans `scenarios/` :

```sh
node tools/capture.js mecha-survivant/index.html tools/shots/ultime.png \
  --scenario tools/scenarios/titan-ultimate.js
```

`scenarios/titan-ultimate.js` sert de modèle : il passe par le bouton de test de l'écran d'accueil, mitraille le boss jusqu'à sa charge finale, puis capture le vol de la boule de feu image par image.

## Note

`shots/` et `node_modules/` ne sont pas versionnés.

## Jeux Godot (WebAssembly)

`mecha-survivant-2` est un export Godot, ce qui change deux choses :

- Il faut le **servir en http** (`mecha-survivant-2/scripts/serve.sh`) et passer
  l'URL à `capture.js` — un export Godot ne tourne pas en `file://`. Prévoir
  `--wait 15000` : le wasm met plusieurs secondes à démarrer.
- Il faut **`--no-step`**. Le pilotage image par image de `driver.js` remplace
  `requestAnimationFrame` ; la boucle de Godot vit dans le wasm et passe par ce
  même rAF, le jeu resterait donc figé sur son écran de chargement.

```sh
node tools/capture.js http://localhost:8123/index.html tools/shots/ms2.png --wait 15000

MS2_TITAN=1 node tools/capture.js http://localhost:8123/index.html tools/shots/titan.png \
  --scenario tools/scenarios/ms2-gameplay.js --no-step
```

`scenarios/ms2-gameplay.js` lance une partie et joue quelques secondes.
`MS2_WAVE=N` choisit la vague de départ, `MS2_TITAN=1` saute au combat final.
Comme l'UI est peinte dans le canvas, il clique par **coordonnées** relevées sur
une capture : les réajuster si l'écran-titre du jeu change.
