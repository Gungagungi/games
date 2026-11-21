# CLAUDE.md

Guidance pour Claude Code sur `mecha-survivant-2-3d/`.

## Ce que c'est

**Mecha Survivant 2 porté en 3D**, caméra à l'épaule du mech. Ce n'est plus un
essai : c'est le jeu de la v2 (`mecha-survivant-2/`), mêmes règles, mêmes
chiffres, rejoué en vue à la troisième personne. Il est parti d'une copie du
prototype `mecha-survivant-3d/` (caméra, visée, tactile, radar), qui reste en
ligne, figé, comme trace de l'essai. La v2 n'est pas touchée.

Le portage se fait **par étapes**, chacune jouable une fois publiée :

1. **(fait)** la boucle de jeu : le village procédural, les 30 vagues, les six
   ennemis ordinaires, les 8 pouvoirs et l'écran de choix, l'onde de choc, le
   bouclier, l'endurance, l'embrasement, le HUD complet.
2. les boss des vagues 1 à 20 : faux Titan et sa réplique, Chevalier Géant,
   Monstre des Égouts, Zombie Titan, Boss Galaxie, télégraphes au sol ;
3. la fin : Esclave du Destructeur (25), Robot géant mutant (30), le niveau
   spécial du Destructeur d'univers, la gemme dorée et le Cristal.

**En attendant l'étape 2, les vagues de boss (1, 5, 10…, 30) se jouent comme
des vagues ordinaires**, et conclure la 30 affiche un écran de victoire
provisoire.

## Fidélité à la v2

Les règles sont reprises **chiffre pour chiffre** : quand un comportement
diffère, c'est un bug, sauf les écarts listés ici.

- **Échelle** : la v2 compte en pixels, ce jeu en mètres. 16 px = 1 m (une case
  de 32 px = 2 m), dans `Units.PX`. Les stats d'ennemis sont **recopiées en
  pixels** dans `systems/enemy_stats.gd` et converties par `scaled()`, pour
  rester comparables ligne à ligne avec la v2.
- **Obus du mech** : 60 m/s au lieu de 26 (420 px/s). Vu de l'épaule, un obus
  aussi lent ratait tout ce qui bouge. Voir `actors/bullet.gd`.
- **Tireurs** (squelettes, flameling) : ils ne s'arrêtent à portée que s'ils
  **voient** le mech (`Enemy.sees_mech()`). En vue de dessus ce n'était pas
  gênant ; en 3D, un squelette tirant dans un mur bloquait la vague.
- **Embrasement** : appliqué **avant** les dégâts du coup. Dans la v2, l'ordre
  inverse le rendait inopérant : le coup donne au mech une demi-seconde
  d'invulnérabilité, que `ignite()` interprète comme un refus.
- **Apparitions** : hors du champ de la caméra, entre 20 et 46 m (la v2 les
  faisait naître juste hors de l'écran), et 70 ennemis vivants au plus en même
  temps (`WaveManager.MAX_ALIVE`).
- **Revenant** : émergence de 0,6 s au lieu de 20 frames, pour qu'on la voie.
- **Dash** : Maj ou Espace ; à l'arrêt, il part droit devant (au clavier, la
  v2 ne dashait pas sans direction). Le tir est au clic gauche.

## Commandes

- Souris : viser (pointeur verrouillé au premier clic), clic gauche maintenu :
  tirer. ZQSD / WASD / flèches : marcher (touches **physiques**). Maj ou
  Espace : dash. F (ou E) : onde de choc, une fois débloquée. Échap : pause.
- **Tir automatique**, bascule T ou clic droit (bouton TIR au doigt) : le
  mech tire seul sur l'ennemi sous le réticule, sinon le plus près du réticule
  dans un cône de 12°, sinon le plus proche à moins de 12 m dans n'importe
  quelle direction — toujours un ennemi visible (`main._aim_assist`). Le torse
  se tourne vers la cible. Éteint au départ à la souris (le clic gauche
  maintenu tire toujours, droit sur le réticule), allumé d'office au premier
  toucher.
- Entre deux vagues : clic sur une carte, ou touches 1 / 2 / 3.
- Tactile : glisser à gauche pour marcher, à droite pour tourner la caméra ;
  boutons TIR (bascule du tir automatique), DASH et ONDE en bas à droite.

## Outillage

Même modèle que la v2 (voir `mecha-survivant-2/CLAUDE.md`) : Godot 4.7.2
installé par `mecha-survivant-2/scripts/install-godot.sh`, export web produit
par `scripts/build.sh` dans `export/`, non versionné, construit par la CI.

```sh
scripts/play.sh            # joue dans Godot (machine avec écran)
scripts/build.sh           # export HTML5 dans export/
scripts/serve.sh [port]    # sert export/ (8123 par défaut)
scripts/check.sh           # cinq parties accélérées sans écran (≈ 50 s)
```

Mêmes règles de travail sans éditeur que la v2 : jamais d'`uid=` inventé, les
`.gd.uid` et `.import` générés par Godot sont versionnés, et le cache des
`class_name` se rafraîchit par `ensure_import()` (`scripts/godot-env.sh`).

## Vérification

`scripts/check.sh` lance cinq parties en mode smoke (`-- --smoke`) : le mech
y est en pilote automatique (il vise l'ennemi visible le plus proche, tourne
autour, va chercher par les rues ceux qu'il ne voit pas), les pouvoirs se
choisissent seuls, le temps est ×6.

1. vagues 1 à 4 ;
2. vagues 12 et 13 (avec les pouvoirs qu'on aurait eus) ;
3. vagues 29 et 30, jusqu'à la victoire ;
4. dès la vague 22 avec `--mortal` : le mech n'est plus immortel, la partie
   s'arrête à sa destruction. C'est la seule qui passe par les dégâts subis,
   l'embrasement jusqu'au bout et la mort ;
5. vagues 8 et 9 avec `--auto-fire` : le pilote marche et oriente la caméra
   mais ne tire plus, c'est le tir automatique du joueur qui tire.

Chaque partie finit par `[smoke] OK` ; `[smoke] ÉCHEC` signale une vague qui
ne se conclut pas dans le temps alloué (un ennemi inatteignable, un tireur
bloqué), et le script sort alors en erreur. Options : `--wave=N`,
`--waves=K`, `--mortal`, `--auto-fire`.

Pour le rendu, `tools/` (racine du dépôt) pilote un Chromium headless, avec
`--no-step` obligatoire comme pour la v2 :

```sh
scripts/serve.sh 8137 &
node tools/capture.js "http://localhost:8137/index.html?demo&vague=12" tools/shots/3d.png --wait 45000 --no-step
node tools/capture.js "http://localhost:8137/index.html?galerie&vague=7" tools/shots/galerie.png --wait 15000 --no-step
```

- `?demo` : le pilote automatique, à l'écran, sans clic ;
- `?vague=N` : commence à la vague N, avec les pouvoirs correspondants ;
- `?galerie` : les six ennemis alignés et figés, mech caché — pour juger les
  silhouettes.

Chromium headless rend la 3D en logiciel, à quelques images par seconde : le
temps de jeu y avance lentement (« 0 détruits » après 45 s n'est pas un bug),
c'est le smoke qui juge le déroulement.

## Architecture

Tout est construit en code ; `scenes/main.tscn` ne contient que le nœud racine.
Le découpage suit celui de la v2.

- `autoload/` — `EventBus` (signaux transverses), `GameState` (vague, tier,
  `running`, smoke, tactile), `AudioManager`, `UpgradeManager` (les 8
  pouvoirs). `GameState.running` garde **tout** ce qui bouge : le passer à
  faux suffit à figer le jeu (pause, écran de pouvoirs).
- `scenes/main.gd` — états (titre, jeu, choix, pause, fin), entrées souris et
  tactiles, séparation de la horde, onde de choc, pilote automatique, smoke.
- `scenes/camera_rig.gd` — caméra à l'épaule droite, **recul anti-mur** (elle
  s'avance quand un mur se glisse entre elle et le mech) et rayon de visée.
- `world/village.gd` — le niveau. **Génération reprise case pour case de
  `mecha-survivant-2/godot/scenes/level.gd`** ; requêtes en mètres sur le plan
  XZ : `move_circle`, `flow_dir` (champ de distances BFS vers le mech),
  `seek_dir` (second champ, pour le pilote), `blocks_point` / `segment_hit`
  (la hauteur compte : une balle passe au-dessus d'une tombe, pas d'un mur),
  `spawn_point`, `line_clear`.
- `world/village_builder.gd` — le rendu du village : murs fusionnés en un
  maillage par tronçon de 16 × 16 cases (sans faces cachées), sol peint par
  `ground.gdshader` qui lit la nature des cases dans une petite texture,
  obstacles et décor en `MultiMesh`, lanternes et braseros.
- `actors/mech.gd` — le mech (`Mech`) : stats de la v2, dash, bouclier,
  embrasement, salve en éventail, et son modèle en primitives.
- `actors/enemy.gd` — base des ennemis : `_behaviour()` et `_build_body()` par
  variante, `is_damage_immune()` point de passage unique de l'immunité, corps
  touché comme une capsule verticale. Les six variantes sont dans
  `actors/enemies/`.
- `actors/bullet.gd`, `actors/enemy_projectile.gd` — projectiles, segments
  testés contre les corps puis contre le village.
- `systems/wave_manager.gd`, `systems/enemy_stats.gd`, `systems/units.gd`.
- `ui/hud.gd` (tout en `_draw()` : barres, compétences, radar, tactile, voiles),
  `ui/upgrade_screen.gd`. Les icônes viennent de `assets/ui/ui_upgrades.png`,
  copiée de la v2.

Pièges propres à la 3D en rendu **Compatibility** (celui du web) :

- un objet ne reçoit que quelques lumières : d'où les maillages découpés en
  tronçons, et **pas de lumière par ennemi** (une horde de flamelings
  multiplierait les passes d'éclairage) ;
- l'émulation souris des doigts est active (elle fait marcher les cartes de
  pouvoirs) : en jeu, `main.gd` ignore les clics émulés
  (`InputEvent.DEVICE_ID_EMULATION`), sinon chaque toucher tirerait.

Les actions clavier sont déclarées dans `main._setup_input()`, pas dans
`project.godot`.
