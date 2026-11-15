# CLAUDE.md

Guidance pour Claude Code sur `mecha-survivant-3d/`.

## Ce que c'est

Un **prototype** : Mecha Survivant 2 en 3D, caméra derrière le mech (vue à la
troisième personne). Il sert à juger si cette vue se joue bien avant de
convertir le vrai jeu. Il ne reprend pas le code de la v2, pensé en 2D vue de
dessus : seulement quelques bruitages, la musique `dungeon.mp3` et la police,
copiés depuis `mecha-survivant-2/godot/assets/`. La v2 n'est pas touchée.

Contenu volontairement réduit :

- une arène ronde fermée (piliers, blocs, caisses, quatre braseros) ;
- le mech, en primitives : les jambes suivent la marche, le torse suit la
  caméra ; deux canons qui tirent en alternance vers le point visé ;
- trois sortes de morts-vivants (marcheur, coureur dès la vague 2, brute dès
  la vague 3), qui sortent de terre et frappent au contact ;
- des vagues sans fin, `5 + n*2` ennemis comme dans la v2, et 15 points de
  blindage rendus entre deux vagues ;
- un **radar** en haut à droite, orienté comme la caméra, qui montre en rouge
  ce qui arrive dans le dos. C'est la réponse au principal défaut de cette vue
  dans un jeu de hordes : on ne voit plus derrière soi.

Pas de pouvoirs, pas de boss, pas d'écran de choix : c'est la vue et le
ressenti qui sont testés.

## Commandes

- Souris : viser (le pointeur est verrouillé après le premier clic), clic
  gauche maintenu : tirer.
- ZQSD / WASD / flèches : marcher (touches **physiques**, donc les deux
  claviers marchent). Espace ou Maj : dash. Échap : pause.
- Tactile : glisser sur la gauche de l'écran pour marcher, sur la droite pour
  tourner la caméra ; le tir est automatique dès qu'un ennemi est à moins de
  12° du réticule ; bouton DASH en bas à droite.

## Outillage

Même modèle que la v2 (voir `mecha-survivant-2/CLAUDE.md`) : Godot 4.7.2
installé par `mecha-survivant-2/scripts/install-godot.sh`, export web produit
par `scripts/build.sh` dans `export/`, non versionné, construit par la CI.

```sh
scripts/play.sh            # joue dans Godot (machine avec écran)
scripts/build.sh           # export HTML5 dans export/
scripts/serve.sh [port]    # sert export/ (8123 par défaut)
scripts/check.sh           # partie accélérée sans écran jusqu'à la vague 4
```

`check.sh` lance le mode smoke (`-- --smoke`) : mech immortel en pilote
automatique, temps ×4, un point d'étape toutes les 10 s de jeu, puis
« [smoke] OK » quand la vague 4 est conclue. Une partie qui tourne en rond sur
les mêmes chiffres signale un ennemi qu'on ne peut plus toucher ou atteindre.

`index.html?demo` lance le même pilote automatique à l'écran, sans clic : c'est
ce qui permet de capturer une partie avec `tools/capture.js` (`--no-step`
obligatoire, comme pour la v2) :

```sh
node tools/capture.js "http://localhost:8123/index.html?demo" tools/shots/3d.png --wait 30000 --no-step
```

## Architecture

Tout est construit en code ; `scenes/main.tscn` ne contient que le nœud racine.

- `scenes/main.gd` — monde, caméra, visée, tirs, collisions, vagues, états
  (titre, jeu, pause, fin), son. Pas de moteur physique : obstacles et
  ennemis sont des cercles au sol, les balles des segments testés contre des
  sphères.
- `scenes/mech.gd` — le mech, son animation, dash, cadence, dégâts.
- `scenes/enemy.gd` — les morts-vivants (`TYPES`), marche et attaque.
- `scenes/hud.gd` — interface dessinée en `_draw()` : réticule, blindage,
  radar, commandes tactiles.
- `scenes/shapes.gd` — fabriques de primitives et d'éclats.
- `scenes/ground.gdshader` — dalles du sol.

La visée : un rayon part du centre de la caméra ; il s'arrête sur le premier
ennemi touché, sinon sur le sol, et les canons tirent vers ce point. La
caméra est décalée sur l'épaule droite (`CAM_SHOULDER`) pour que le mech ne
cache pas le réticule.

Les ennemis contournent les obstacles (`_avoid_obstacles`) : sans ce coup de
pouce latéral, un ennemi aligné derrière un pilier restait plaqué contre lui
et la vague ne se terminait jamais.

Les actions clavier sont déclarées dans `_setup_input()`, pas dans
`project.godot` : plus sûr à écrire à la main.
