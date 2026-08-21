# Manifeste des assets

Le jeu tourne **sans aucun de ces fichiers** : tant qu'un asset est absent,
l'entité se dessine en placeholder géométrique (`scenes/fx/sprite_or_shape.gd`)
et les appels audio sont silencieux (`autoload/audio_manager.gd`). Déposer un
fichier au bon nom suffit à le brancher — aucun code à modifier, juste relancer
`scripts/build.sh`.

## Sprites — `assets/sprites/`

**Format** : PNG, fond transparent, strip horizontal (une frame par case,
frames carrées de la taille indiquée), palette limitée, pas d'anti-aliasing.
Le filtrage est en *nearest* pour tout le projet
(`rendering/textures/canvas_textures/default_texture_filter=0`), le pixel art
reste donc net.

| Fichier | Tuile | Frames | Contenu |
| --- | --- | --- | --- |
| `player_mech.png` | 48×48 | 13 | idle 4, marche 6, dash 3 |
| `enemy_zombie.png` | 32×32 | 8 | marche 4, mort 4 |
| `enemy_skeleton.png` | 32×32 | 8 | marche 4, mort 4 |
| `enemy_risen.png` | 32×32 | 8 | marche 4, mort 4 |
| `enemy_shade.png` | 32×32 | 8 | marche 4, mort 4 |
| `enemy_flameling.png` | 32×32 | 8 | marche 4, mort 4 |
| `boss_gravedigger.png` | 96×96 | 8 | idle 4, attaque 4 |
| `boss_bone_colossus.png` | 96×96 | 8 | idle 4, attaque 4 |
| `boss_plague.png` | 96×96 | 8 | idle 4, attaque 4 |
| `megaboss.png` | 128×128 | 8 | idle 4, attaque 4 (les phases sont teintées en `modulate`) |
| `titan.png` | 160×160 | 14 | idle 4, faux 6, charge 4 |
| `proj_bullet.png` | 16×16 | 1 | projectile du joueur |
| `proj_arrow.png` | 16×16 | 1 | flèche de squelette |
| `proj_fireball.png` | 16×16 | 4 | boule de feu du flameling |
| `proj_poison.png` | 16×16 | 1 | projectile empoisonné |
| `proj_orb.png` | 16×16 | 1 | orbe de boss |
| `proj_ultimate.png` | 64×64 | 4 | boule de feu ultime du Titan |
| `fx_shockwave.png` | 64×64 | 6 | onde de choc du joueur |
| `fx_hit.png` | 64×64 | 5 | impact |
| `fx_telegraph.png` | 64×64 | 1 | cercle d'annonce |
| `tiles_floor.png` | 32×32 | 4 | variantes de dalle de sol |
| `hazard_poison.png` | 48×48 | 4 | flaque de poison |
| `ui_upgrades.png` | 32×32 | 8 | cadence, dégâts, coque, vitesse, salve, bouclier, onde, endurance |
| `icon.png` | 64×64 | 1 | icône du jeu (placeholder généré, à remplacer) |

**Direction artistique suggérée** — donjon de morts-vivants, palette froide et
désaturée (bleus-gris, verts putrides), le mech du joueur en cyan lumineux
tranchant sur le fond, les boss en rouge/violet. Prompt type pour un générateur
de sprites :

> pixel art sprite sheet, 32x32 tiles, walk cycle 4 frames, transparent
> background, limited palette, dark fantasy undead <créature>, top-down view,
> no anti-aliasing, no outline glow

## Effets sonores — `assets/sfx/`

**Format** : `.wav` mono 44,1 kHz 16 bits, moins de 2 s. `.ogg` accepté aussi.
Outil suggéré : ElevenLabs Sound Effects (description textuelle → bruitage).

`shoot`, `hit_enemy`, `enemy_death`, `enemy_groan`, `player_hurt`, `dash`,
`shockwave`, `upgrade_pick`, `ui_click`, `wave_start`, `boss_spawn`,
`boss_hurt`, `boss_death`, `shade_phase`, `flameling_cast`, `fireball_impact`,
`bone_sweep`, `laser_charge`, `titan_charge`, `titan_ultimate`, `game_over`.

## Musique — `assets/music/`

**Format** : `.ogg` Vorbis, boucle de 60 à 90 s, ~112 kbps (le budget total du
`.pck` visé est de 8 Mo). Outil suggéré : Suno ou Soundraw.

| Fichier | Moment |
| --- | --- |
| `menu.ogg` | écran-titre |
| `dungeon.ogg` | vagues ordinaires |
| `boss.ogg` | vagues de boss (5, 10, 15) |
| `titan.ogg` | combat final (vague 20) |

Après avoir déposé un `.ogg`, ouvrir son `.ogg.import` (créé par
`scripts/build.sh`) et y mettre `loop=true`, sinon la piste ne boucle pas.
