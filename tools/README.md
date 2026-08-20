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
