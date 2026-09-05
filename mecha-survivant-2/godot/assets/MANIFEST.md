# Manifeste des assets

Le jeu tourne **sans aucun de ces fichiers** : tant qu'un asset est absent,
l'entité se dessine en placeholder géométrique (`scenes/fx/sprite_or_shape.gd`)
et les appels audio sont silencieux (`autoload/audio_manager.gd`). Déposer un
fichier au bon nom suffit à le brancher — aucun code à modifier, juste relancer
`scripts/build.sh`.

**Tout ce qui est listé ici est branché** : chaque fichier a son point de
chargement dans le code, et le rendu de secours qu'il remplace. Rien n'est
décoratif ni « pour plus tard » — si un fichier de cette liste ne se voit pas
une fois déposé, c'est un bug.

## Sprites — `assets/sprites/`

**Format** : PNG, fond transparent, strip horizontal (une frame par case,
frames carrées de la taille indiquée), palette limitée, pas d'anti-aliasing.
Le filtrage est en *nearest* pour tout le projet
(`rendering/textures/canvas_textures/default_texture_filter=0`), le pixel art
reste donc net.

**L'ordre des cases compte** : la colonne « Découpage » donne les plages que le
code va chercher, dans l'ordre où elles doivent apparaître sur la planche. Ce
découpage est déclaré une seule fois, dans `SHEETS`
(`scenes/fx/sprite_or_shape.gd`) — c'est là qu'il faut regarder en cas de doute,
et là qu'il faudrait le changer si une planche livrée s'organisait autrement.

| Fichier | Tuile | Cases | Découpage |
| --- | --- | --- | --- |
| `player_mech.png` | 48×48 | 13 | `idle` 0-3, `walk` 4-9, `dash` 10-12 |
| `enemy_zombie.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `enemy_skeleton.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `enemy_risen.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `enemy_shade.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `enemy_flameling.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `enemy_fire_skeleton.png` | 32×32 | 8 | `walk` 0-3, `death` 4-7 |
| `boss_giant_knight.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_sewer_monster.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_zombie_titan.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_galaxy_boss.png` | 128×128 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_gravedigger.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_bone_colossus.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `boss_plague.png` | 96×96 | 8 | `idle` 0-3, `attack` 4-7 |
| `megaboss.png` | 128×128 | 8 | `idle` 0-3, `attack` 4-7 (phases teintées en `modulate`) |
| `titan.png` | 160×160 | 14 | `idle` 0-3, `scythe` 4-9, `charge` 10-13 |
| `proj_bullet.png` | 16×16 | 1 | projectile du joueur |
| `proj_arrow.png` | 16×16 | 1 | flèche de squelette |
| `proj_fireball.png` | 16×16 | 4 | boule de feu du flameling, en boucle |
| `proj_poison.png` | 16×16 | 1 | projectile empoisonné |
| `proj_orb.png` | 16×16 | 1 | orbe de boss |
| `proj_ultimate.png` | 64×64 | 4 | boule de feu ultime du Titan, en boucle |
| `fx_shockwave.png` | 64×64 | 6 | onde de choc, déroulée une fois sur 0,35 s |
| `fx_hit.png` | 64×64 | 5 | impact, déroulé une fois à chaque coup encaissé |
| `fx_telegraph.png` | 64×64 | 1 | cercle d'annonce, opacité pilotée par le code |
| `tiles_floor.png` | 32×32 | 4 | variantes de dalle, tirées au hachage des coordonnées |
| `hazard_poison.png` | 48×48 | 4 | flaque de poison, en boucle |
| `ui_upgrades.png` | 32×32 | 8 | cadence, dégâts, coque, vitesse, salve, bouclier, onde, endurance — **cet ordre exactement**, c'est celui de `UpgradeManager.ALL` |
| `icon.png` | 64×64 | 1 | icône du jeu (placeholder généré, à remplacer) |

**Cadrage** — un sprite est affiché à la taille de sa case, sans mise à
l'échelle : une case de 32 px occupe 32 px à l'écran, l'entité doit donc
remplir sa case. Trois exceptions, mises à l'échelle de la zone qu'elles
couvrent : `fx_shockwave`, `fx_telegraph` et `hazard_poison` sont cadrées sur le
**diamètre** de l'effet, cercle inscrit dans la case.

**Orientation** — le mech est le seul sprite tourné par le code
(`player.gd` : `rotation = velocity.angle() + PI/2`), il doit donc être dessiné
**vu de dessus, face vers le haut**. Ni les ennemis, ni les boss, ni les
projectiles ne sont tournés : ils gardent à l'écran l'orientation dans laquelle
ils sont dessinés, quelle que soit leur direction de déplacement. Conséquence à
accepter ou à corriger un jour dans le code : la flèche de squelette pointera
toujours du même côté.

**Direction artistique** — donjon de morts-vivants, palette froide et
désaturée (bleus-gris, verts putrides), le mech du joueur en cyan lumineux
tranchant sur le fond, les boss en rouge/violet.

**Génération** — `scripts/gen-sprites.py` produit ces 24 planches depuis l'API
PixelLab, aux dimensions exactes du tableau ci-dessus. Les prompts, un par
planche, vivent dans `scripts/sprite-prompts.json` : c'est là qu'on retouche
une créature qui ne ressemble à rien, pas dans le code.

```sh
scripts/gen-sprites.py --list                  # ce qu'il y a à produire
scripts/gen-sprites.py --fake                  # valide la chaîne sans crédit
scripts/gen-sprites.py --only enemy_zombie     # une planche
scripts/gen-sprites.py --budget 5              # tout, en s'arrêtant à 5 $
scripts/gen-sprites.py --only titan --redo scythe   # refaire une seule animation
scripts/preview-sheet.py titan                 # relire la planche, case par case
```

Une planche produite à la main ou par un autre outil reste parfaitement
valable : le jeu ne connaît que le fichier, jamais son origine.

## Polices — `assets/fonts/`

| Fichier | Rôle |
| --- | --- |
| `MedievalSharp.ttf` | police par défaut de tout l'UI (licence SIL OFL, `MedievalSharp-OFL.txt`) |

## Effets sonores — `assets/sfx/`

**Format** : `.wav` mono 44,1 kHz 16 bits, moins de 2 s. `.ogg` accepté aussi.
Produits par `scripts/gen-audio.py` (ElevenLabs Sound Effects) ; les prompts
vivent dans `scripts/audio-prompts.json`.

**Les 21 bruitages sont là.** La liste ci-dessous est recoupée par
`gen-audio.py` avec les appels réels du code : ajouter une clé ici sans
l'appeler nulle part, ou l'inverse, fait échouer la génération avant de dépenser
quoi que ce soit.

`shoot`, `hit_enemy`, `enemy_death`, `enemy_groan`, `player_hurt`, `dash`,
`shockwave`, `upgrade_pick`, `ui_click`, `wave_start`, `boss_spawn`,
`boss_hurt`, `boss_death`, `shade_phase`, `flameling_cast`, `fireball_impact`,
`bone_sweep`, `laser_charge`, `titan_charge`, `titan_ultimate`, `game_over`.

Le nom du fichier est la clé passée à `AudioManager.sfx()` : `shoot.wav` et rien
d'autre. Chaque son est joué avec ±8 % de variation de hauteur, inutile donc de
livrer des variantes.

## Musique — `assets/music/`

**Format** : `.mp3` 44,1 kHz 128 kbps, boucle de 60 à 90 s (le budget total du
`.pck` visé est de 8 Mo ; les quatre pistes en pèsent environ 5). Godot 4 lit le
mp3 nativement (`AudioStreamMP3`) — inutile de passer par du Vorbis, et
`AudioManager` accepte de toute façon `.ogg`, `.wav` ou `.mp3`.

| Fichier | Moment |
| --- | --- |
| `menu.mp3` | écran-titre |
| `dungeon.mp3` | vagues ordinaires |
| `boss.mp3` | vagues de boss (5, 10, 15) |
| `titan.mp3` | combat final (vague 20) |

**Les quatre musiques sont là.** Elles sortent de `scripts/gen-audio.py --kind
music` (Eleven Music, endpoint réservé aux comptes payants là où les bruitages
passent en gratuit) et pèsent 4,96 Mo à elles quatre, pour un `.pck` de 5,56 Mo.

Une piste ne boucle pas toute seule : il faut `loop=true` dans son `.import`
(créé par `scripts/build.sh`). `scripts/gen-audio.py --loops` le pose sur les
quatre, à relancer après le premier build qui voit les fichiers.
