# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Aperçu du dépôt

Collection de petits jeux navigateur, chacun dans son propre dossier à la racine. Chaque jeu est autonome : HTML/CSS/JS pur, sans dépendance externe ni étape de build.

## Lancer un jeu

Chaque jeu s'ouvre directement dans un navigateur, sans build (ouvrir `index.html`, ou servir le dossier en local si `file://` pose problème).

Pas de commande de build, de lint ou de test — la vérification se fait manuellement dans le navigateur (interagir avec le jeu, vérifier `console --errors` s'il y a un outil de type chromium-cli disponible).

## Vérification visuelle

Il n'y a ni test ni lint, mais `tools/` permet de regarder un jeu tourner sans écran (Chromium headless piloté par puppeteer-core) :

```sh
sudo apt install chromium && (cd tools && npm install)   # une fois
node tools/capture.js <jeu.html> <sortie.png>
```

La sortie remonte aussi les erreurs de console de la page. Pour un effet qui ne dure que quelques frames (un projectile rapide), `--frames N` et les scénarios de `tools/scenarios/` pilotent la boucle **image par image**. Voir `tools/README.md`.

C'est de l'outillage de développement : les jeux n'en dépendent pas et restent sans dépendance.

## Architecture

- Exception assumée : `mecha-survivant/` tient dans un unique `index.html` monolithique (CSS, HTML et JS inline) ; les itérations antérieures dorment dans `mecha-survivant/archives/`. Voir son propre `CLAUDE.md` ; ne pas l'éclater en `style.css` + `game.js` sans demande explicite.
- Chaque nouveau jeu doit suivre la même convention que `pong/` : son propre dossier avec `index.html`, `style.css`, `game.js` (ou équivalent), sans dépendance sur d'autres jeux du dépôt.
- `pong/game.js` illustre le patron à réutiliser pour un jeu basé sur Canvas 2D :
  - État du jeu dans des objets simples (`player`, `opponent`, `ball`) plutôt que des classes.
  - Contrôles clavier via une map `keysPressed` peuplée par les listeners `keydown`/`keyup`, lue à chaque frame (pas de logique dans les handlers eux-mêmes).
  - Boucle de jeu unique pilotée par `requestAnimationFrame` (`loop()`), qui enchaîne update (mouvement, collisions, score) puis rendu (`draw()`).
  - Le rendu redessine l'intégralité du canvas à chaque frame (pas de diffing).
