# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Aperçu du dépôt

Collection de petits jeux navigateur, chacun dans son propre dossier à la racine. Chaque jeu est autonome : HTML/CSS/JS pur, sans dépendance externe ni étape de build. Il n'y a pas de `package.json`, pas de bundler, pas de framework de test — ce dépôt reste volontairement minimal.

Jeu actuel : `pong/` — un Pong classique (joueur humain à gauche, IA à droite).

## Lancer un jeu

Chaque jeu s'ouvre directement dans un navigateur, sans build :

```bash
# Option 1 : ouvrir directement le fichier
xdg-open pong/index.html   # ou double-clic depuis l'explorateur de fichiers

# Option 2 : servir en local (utile si le fichier:// pose problème)
cd pong && python3 -m http.server 8000
# puis ouvrir http://localhost:8000
```

Pas de commande de build, de lint ou de test — la vérification se fait manuellement dans le navigateur (interagir avec le jeu, vérifier `console --errors` s'il y a un outil de type chromium-cli disponible).

## Architecture

- Chaque nouveau jeu doit suivre la même convention que `pong/` : son propre dossier avec `index.html`, `style.css`, `game.js` (ou équivalent), sans dépendance sur d'autres jeux du dépôt.
- `pong/game.js` illustre le patron à réutiliser pour un jeu basé sur Canvas 2D :
  - État du jeu dans des objets simples (`player`, `ai`, `ball`) plutôt que des classes.
  - Contrôles clavier via une map `keysPressed` peuplée par les listeners `keydown`/`keyup`, lue à chaque frame (pas de logique dans les handlers eux-mêmes).
  - Boucle de jeu unique pilotée par `requestAnimationFrame` (`loop()`), qui enchaîne update (mouvement, collisions, score) puis rendu (`draw()`).
  - Le rendu redessine l'intégralité du canvas à chaque frame (pas de diffing).
