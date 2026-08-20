# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Aperçu

Jeu de survie/roguelite en vue de dessus (Canvas 2D), dans la lignée de *Vampire Survivors* : on pilote un mech, on survit à des vagues de morts-vivants, on choisit un pouvoir entre chaque vague, un boss tombe toutes les 5 vagues.

Le dossier ne contient **que des fichiers HTML monolithiques** — tout (CSS, HTML, JS) est inline dans un seul fichier, pas de build, pas de dépendance. Ouvrir le fichier directement dans un navigateur suffit ; la vérification se fait manuellement (jouer, regarder la console).

## Versions

`index.html` est la **version principale**, seul fichier de jeu à la racine du dossier — c'est l'ancien `mecha-survivant-4.html`. Les itérations précédentes (`mecha-survivant.html`, `-2`, `-3`) sont conservées telles quelles dans `archives/` : ce sont des **étapes successives, pas des variantes**, chacune étant une copie complète de la précédente enrichie.

| Fichier | Ajouts |
| --- | --- |
| `archives/mecha-survivant.html` | base : vagues, 3 ennemis (zombie/squelette/revenant), boss tous les 5 niveaux, upgrades, audio WebAudio généré |
| `archives/mecha-survivant-2.html` | méga-boss à 3 phases (vague 15) |
| `archives/mecha-survivant-3.html` | sélecteur de vague de départ sur l'écran d'accueil |
| `index.html` (ex-`-4`) | Titan de la Mort, boss à 5 phases (vague 20), faux au corps à corps, attaque ultime |

Toute évolution se fait désormais dans `index.html` en place. Pour préserver un jalon avant un gros changement, en copier l'état dans `archives/` sous le prochain suffixe libre (`mecha-survivant-5.html`, etc.). Ne jamais rétroporter un correctif dans `archives/` — ces fichiers sont figés.

Note : les fichiers portaient auparavant le préfixe `mech-survivant`, renommé en `mecha-survivant` pour s'aligner sur le nom du dossier. Ce préfixe ne concerne plus que les archives ; le fichier joué s'appelle `index.html`.

## Écart assumé avec la convention du dépôt

Le `CLAUDE.md` parent impose `index.html` + `style.css` + `game.js`. Ce jeu ne respecte que le premier : tout (CSS, HTML, JS) reste inline dans `index.html`. C'est délibéré : le fichier est autoportant et se partage tel quel. Ne pas l'éclater en trois sans demande explicite.

## Architecture (dans `index.html`)

Tout le JS est dans une IIFE `(() => { "use strict"; ... })()` en fin de fichier, organisée en sections séparées par des bannières de commentaires, dans cet ordre :

1. **Audio** — `ensureAudio()`, `playTone()`/`playNoise()` comme primitives, puis une famille `sfxXxx()` par événement de jeu. Musique procédurale : `startDungeonMusic()` / `startBossMusic()` bouclent via `setInterval` sur `musicTimer`. Aucun fichier son ; tout est synthétisé.
2. **Entrées** — map `keys` remplie par `keydown`/`keyup`, `mouseX/mouseY/mouseDown` ; aucune logique de jeu dans les handlers, tout est lu dans `update()`.
3. **Effets** — `particles`, `floatTexts`, `telegraphs` (zones d'apparition/impact annoncées avant l'effet), `groundHazards` (flaques de poison), `laserWarnings`. Même patron partout : tableau global + `updateX()` + `drawX()`, suppression par boucle descendante.
4. **Entités** — objets littéraux via des fabriques `makeZombie/makeSkeleton/makeRisen/makeBoss/makeMegaZombie/makeTitan`. Pas de classes, pas d'héritage : chaque fabrique retourne un objet plat, et le comportement est choisi dans `update()` par `switch` sur `e.type` / `e.bossKey`.
5. **Vagues** — `startWave(n)` ; `isBossLevel(n)` (`n % 5 === 0`) route vers `beginBossWave` / `beginMegaBossWave` (15) / `beginTitanBossWave` (20). La difficulté vient d'un `tier = Math.floor((n-1)/2)` appliqué aux stats des ennemis.
6. **Upgrades** — `ALL_UPGRADES` (id, libellé, `apply(player)`), 3 tirés au sort par `openUpgradeScreen()`. `ownedPowerIds` alimente le HUD.
7. **Boss multi-phases** — `MEGA_PHASE_HP` / `TITAN_PHASE_HP` : la barre est **remise à plein à chaque phase** via `megaAdvancePhase` / `titanAdvancePhase`, qui montent aussi les multiplicateurs de vitesse et de dégâts.
8. **Boucle** — `loop()` (rAF) → `update()` puis `render()`. `render()` redessine tout le canvas chaque frame (grille, hazards, entités, HUD canvas), avec un screen-shake appliqué en translation globale.
9. **Bootstrap** — remplissage du `<select>` de niveau, `applyStartingLevelScaling()` (accorde des upgrades gratuits si l'on démarre plus loin), `beginGame(startLevel)`.

Le HUD hors-canvas (barres de vie/endurance/bouclier, barre de boss, écrans start/upgrade/game-over) est du DOM classique manipulé par largeur en `%` et classe `hidden`.

## Conventions

- Interface, commentaires et messages de commit en **français** ; identifiants de code en anglais.
- Contrôles : ZQSD/flèches, Espace ou clic pour tirer (visée souris), Maj pour le dash, F pour l'onde de choc.
- Les timers sont en **frames** (décrément de 1 par tick), pas en millisecondes — `performance.now()` n'est utilisé que pour les oscillations d'animation.
