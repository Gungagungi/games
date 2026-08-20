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
4. **Entités** — objets littéraux via des fabriques `makeZombie/makeSkeleton/makeRisen/makeShade/makeFlameling/makeBoss/makeMegaZombie/makeTitan`. Deux ennemis élémentaires complètent les morts-vivants : la **créature de l'ombre** (`shade`, rapide, alterne des phases `intangible` où les balles la traversent et où elle ne blesse pas — invoquée en continu par le Fossoyeur) et le **mob de feu** (`flameling`, garde ses distances et lance une boule de feu toutes les 3 s via `FLAMELING_SHOT_INTERVAL`, incantation `FLAMELING_WINDUP` comprise, pour 5 % des PV max du joueur recalculés au tir). Les `flameling` n'apparaissent ni vague 1 ni sur une vague de boss. Pas de classes, pas d'héritage : chaque fabrique retourne un objet plat, et le comportement est choisi dans `update()` par `switch` sur `e.type` / `e.bossKey`.
5. **Vagues** — `startWave(n)` ; `isBossLevel(n)` (`n % 5 === 0`) route vers `beginBossWave` / `beginMegaBossWave` (15) / `beginTitanBossWave` (20). La difficulté vient d'un `tier = Math.floor((n-1)/2)` appliqué aux stats des ennemis.
6. **Upgrades** — `ALL_UPGRADES` (id, libellé, `apply(player)`), 3 tirés au sort par `openUpgradeScreen()`. `ownedPowerIds` alimente le HUD. `firerate` est **multiplicatif et sans plafond** (`fireRate *= 0.78`) : `fireRate` est un délai en frames qui peut devenir fractionnaire, et `shoot()` boucle sur `fireSalvo()` pour tirer plusieurs salves dans la même frame au-delà de 1/frame (garde-fou à 20 salves, un seul `sfxShoot()` par frame).
7. **Attaques de boss nommées** — le Fossoyeur invoque des `shade` en continu ; le Colosse d'os relève des squelettes (`spawnTelegraphThenSkeleton`, 8 vivants au maximum) et déclenche le **balayage d'ossements** : un secteur de rayon `BONE_SWEEP_RADIUS` (560 px, presque tout l'écran) qui tourne autour de lui. Même patron que les autres effets — tableau `boneSweeps` + `updateBoneSweeps()` + `drawBoneSweeps()` — avec une phase `windup` d'avertissement qui ne blesse pas, puis `duration` frames actives.
8. **Boss multi-phases** — `MEGA_PHASE_HP` / `TITAN_PHASE_HP` : la barre est **remise à plein à chaque phase** via `megaAdvancePhase` / `titanAdvancePhase`, qui montent aussi les multiplicateurs de vitesse et de dégâts. En phase 5, dès que le Titan tombe à 1 % de vie, `ultimateInvuln` lui accorde `TITAN_ULTIMATE_INVULN` frames (10 s) d'immunité totale pour charger et lâcher son attaque ultime. Celle-ci est un **projectile** (`launchTitanUltimate`) : une énorme boule de feu (`TITAN_ULTIMATE_RADIUS` / `TITAN_ULTIMATE_SPEED`) visant la position du joueur au tir. Elle a son propre chemin dans la boucle `enemyBullets` — elle ne passe jamais par `damagePlayer()` mais par `damagePlayerUltimate()`, qui tue net sauf si le bouclier d'énergie est actif (alors entièrement consommé). Elle s'esquive en se déplaçant, pas en dashant : l'invulnérabilité du dash ne la stoppe pas. Au déclenchement, le Titan **cesse toute autre attaque** (tous ses cooldowns sont repoussés), **perd son bouclier** et se **téléporte à `TITAN_ULTIMATE_RANGE`** du joueur via `anchorTitanForUltimate()` — sans ce recalage, collé au joueur ou plaqué contre un bord, la boule le touchait dans la frame du tir sans jamais être visible. `isDamageImmune(e)` centralise cette immunité (avec le bouclier du méga-boss et le déphasage des ombres) et **toutes** les sources de dégâts doivent passer par elle, balles comme onde de choc.
9. **Écran d'accueil** — outre le `<select>` de vague de départ, un bouton `#testUltimateBtn` (« TEST : TITAN À 5 % ») saute au combat final avec le Titan déjà en phase 5 à 5 % de vie. C'est un raccourci de test assumé, gardé dans le jeu livré : quelques tirs suffisent alors à déclencher l'attaque ultime.
10. **Boucle** — `loop()` (rAF) → `update()` puis `render()`. `render()` redessine tout le canvas chaque frame (grille, hazards, entités, HUD canvas), avec un screen-shake appliqué en translation globale.
11. **Bootstrap** — remplissage du `<select>` de niveau, `applyStartingLevelScaling()` (accorde des upgrades gratuits si l'on démarre plus loin), `beginGame(startLevel)`.

Le HUD hors-canvas (barres de vie/endurance/bouclier, barre de boss, écrans start/upgrade/game-over) est du DOM classique manipulé par largeur en `%` et classe `hidden`.

## Vérification visuelle

Sur une machine sans écran, `tools/` (à la racine du dépôt) capture le jeu dans un Chromium headless — voir `tools/README.md`. Pour le combat final :

```sh
node tools/capture.js mecha-survivant/index.html tools/shots/ultime.png \
  --scenario tools/scenarios/titan-ultimate.js
```

Le scénario pilote la boucle **image par image**, ce qui est le seul moyen d'attraper la boule de feu : elle traverse l'arène en une trentaine de frames.

## Conventions

- Interface, commentaires et messages de commit en **français** ; identifiants de code en anglais.
- Contrôles : ZQSD/flèches, Espace ou clic pour tirer (visée souris), Maj pour le dash, F pour l'onde de choc.
- Les timers sont en **frames** (décrément de 1 par tick), pas en millisecondes — `performance.now()` n'est utilisé que pour les oscillations d'animation.
