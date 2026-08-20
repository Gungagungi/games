# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Aperçu du dépôt

Collection de petits jeux navigateur, chacun dans son propre dossier à la racine. Chaque jeu est autonome : HTML/CSS/JS pur, sans dépendance externe ni étape de build.

## Lancer un jeu

Chaque jeu s'ouvre directement dans un navigateur, sans build (ouvrir `index.html`, ou servir le dossier en local si `file://` pose problème).

Pas de commande de build, de lint ou de test — la vérification se fait manuellement dans le navigateur (interagir avec le jeu, vérifier `console --errors` s'il y a un outil de type chromium-cli disponible).

## Architecture

- Exception assumée : `mecha-survivant/` est une série de fichiers HTML monolithiques (`mecha-survivant.html` → `-4`, tout inline, versionnés par suffixe numérique). Voir son propre `CLAUDE.md` ; ne pas l'aligner sur la convention ci-dessous sans demande explicite.
- Chaque nouveau jeu doit suivre la même convention que `pong/` : son propre dossier avec `index.html`, `style.css`, `game.js` (ou équivalent), sans dépendance sur d'autres jeux du dépôt.
- `pong/game.js` illustre le patron à réutiliser pour un jeu basé sur Canvas 2D :
  - État du jeu dans des objets simples (`player`, `opponent`, `ball`) plutôt que des classes.
  - Contrôles clavier via une map `keysPressed` peuplée par les listeners `keydown`/`keyup`, lue à chaque frame (pas de logique dans les handlers eux-mêmes).
  - Boucle de jeu unique pilotée par `requestAnimationFrame` (`loop()`), qui enchaîne update (mouvement, collisions, score) puis rendu (`draw()`).
  - Le rendu redessine l'intégralité du canvas à chaque frame (pas de diffing).
