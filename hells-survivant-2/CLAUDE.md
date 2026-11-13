# CLAUDE.md

Guidance pour Claude Code sur `hells-survivant-2/`.

## Ce que c'est

Refonte visuelle de `hells-survivant/`, sous **Godot 4** exporté en HTML5, dans
un style pixel art façon *Heroes of Might and Magic 2*. Les mécaniques sont
reprises telles quelles de la v1 : 3 difficultés, 7 éléments, boss toutes les
5 vagues, Nécromancien Putréfié en vague 30 (élément Ombre), forge épée/armure
persistante. Ce qui change : sprites, halos lumineux, particules, shaders,
interface et sons en fichiers, là où la v1 dessinait des formes au Canvas 2D et
synthétisait tout en Web Audio. S'y ajoutent deux modes absents de la v1 : le
**Chaos** (voir « Mode Chaos ») et le niveau spécial **Conclave des boss**
(voir « Conclave des boss »).

**En ligne** : <https://jeux.lambertdeharosanchez.com/hells-survivant-2/>, lié
depuis le portail du dépôt. Premier chargement de quelques secondes (≈ 40 Mo de
wasm, mis en cache ensuite).

La v1 reste en place, intacte et jouable. Sa sauvegarde n'est **pas** partagée :
la v2 écrit dans `user://save.cfg` (IndexedDB dans le navigateur).

Le projet reprend l'outillage et les conventions de `mecha-survivant-2/` — lire
son `CLAUDE.md` pour le détail des pièges Godot sans éditeur (UID, cache de
`class_name`, `version.txt`, `--no-step`), tous valables ici.

## Outillage

```sh
../mecha-survivant-2/scripts/install-godot.sh   # une fois : Godot 4.7.2 + template Web (commun aux deux jeux)
scripts/play.sh            # joue directement dans Godot, sans build ni serveur
scripts/check.sh           # non-régression sans écran (voir « Vérification »)
scripts/build.sh           # import puis export HTML5 dans export/ (non versionné)
scripts/serve.sh [port]    # sert export/ (8123 par défaut)
```

## Publication

Chaque push sur `main` déclenche `.github/workflows/deploy-pages.yml` : l'étape
« Exporter Hell's Survivant 2 » lance `scripts/build.sh` puis déplace `export/`
à la racine du dossier, pour que le jeu soit servi depuis `/hells-survivant-2/`
comme les autres. Rien du build n'est versionné (`export/`, `version.txt`,
`.godot/` sont ignorés). Pas de branche de publication à part : pour mettre le
jeu en ligne, il suffit de pousser sur `main`, puis de suivre le run
(`gh run watch`) et de vérifier que `index.pck` et `index.wasm` répondent en 200.

Godot est restauré depuis le cache de la CI, clé `godot-<version>-web`. Changer
de version de Godot oblige à modifier **ensemble** `GODOT_VERSION` dans le
workflow et `VERSION` dans `mecha-survivant-2/scripts/install-godot.sh` : les
deux jeux partagent le même binaire et le même template, qui doivent coïncider
exactement.

## Vérification

`scripts/check.sh` joue huit parties accélérées via le mode smoke de
`scenes/main.gd` (`--headless -- --smoke [--element=X] [--difficulty=X]
[--wave=N] [--duration=S] [--boss-rush]`) : vagues ordinaires (Sang, vague 1),
boss de mêlée (Feu, vague 5), boss tireur de briques en Difficile (Destruction,
vague 10), et boss final jusqu'à la **victoire** (Ombre, vague 30), puis trois
parties Chaos : vagues mélangées (vague 1), dernier boss de la file (vague 35)
et Créature cauchemardesque jusqu'à la victoire (vague 40, sur 60 s au lieu de
20 : elle saute, charge et se dédouble, le pilote automatique met plus
longtemps à la finir), enfin le Conclave des boss (60 s aussi), où le pilote
fait le tour des boss, un toutes les 4 s de jeu. Chaque apparition de boss est écrite dans la sortie
(`[smoke] vague N : <boss>`). Le héros y est immortel, équipé au maximum (en
mémoire, `Save.write()` ne fait rien en smoke) et combat tout seul. Une partie
échoue si elle ne progresse pas, si une vague de boss final ne se conclut pas
en victoire, ou sur toute erreur GDScript. Le Conclave, lui, échoue s'il ne
finit pas **en cours** (ni victoire ni défaite), si un boss manque ou a perdu
des PV, si moins de 3 boss ont eu leur infobulle, si le boss de l'infobulle a
bougé de plus de 0,5 px d'une frame à l'autre, ou si deux sprites de boss
(doubles de la Créature compris) se recouvrent de plus de 8 px : la sortie
donne le pire écart (`chevauchement max`, −6 px quand ils se touchent à la
limite).

Deux points à connaître :

- **Un script qui ne compile pas laisse Godot tourner indéfiniment** au lieu de
  quitter. `check.sh` plafonne donc chaque partie avec `timeout -s INT` —
  SIGINT, pas SIGTERM, sinon la sortie mise en tampon (dont l'erreur) est
  perdue. Même précaution pour tout lancement headless à la main.
- **Typage GDScript** : `var x := ...` sur une valeur non typée (élément de
  `Dictionary`, tableau issu de `duplicate()`) est une erreur de compilation.
  Typer explicitement (`var hp: float = d["hp"]`, `for e: Enemy in ...`).

Pour le visuel, `tools/` (racine du dépôt) pilote un Chromium headless. Le port
8124 évite de heurter `mecha-survivant-2/scripts/serve.sh`, qui prend le 8123 par
défaut :

```sh
scripts/serve.sh 8124 &
node tools/capture.js http://localhost:8124/index.html tools/shots/hs2.png --wait 15000 --no-step
HS2_ELEMENT_STEPS=3 node tools/capture.js http://localhost:8124/index.html tools/shots/feu.png \
  --scenario tools/scenarios/hs2-gameplay.js --no-step
HS2_PLAY_MS=7000 node tools/capture.js http://localhost:8124/index.html tools/shots/conclave.png \
  --scenario tools/scenarios/hs2-boss-rush.js --no-step
```

Les scénarios passent l'écran-titre **au clavier** (Z/S, Entrée, B), sans
coordonnée de clic : changer la mise en page du menu ne les casse pas.
`hs2-boss-rush.js` écrit aussi `<sortie>-menu.png` et `<sortie>-intro.png`.
Chromium headless fait tourner le wasm bien plus lentement que le temps réel :
7 s d'attente ne donnent qu'une seconde de combat environ.

## Architecture

Autoloads (`autoload/`) : `Data` (tables de la v1 : épées, armures, difficultés,
éléments, boss), `Game` (écran courant, sélection, vague, mode smoke), `Save`
(or et niveaux d'équipement), `Audio`.

- `scenes/world.gd` — arène, vagues et combat. **La logique tourne à pas fixe
  de 1/60 s** (`_tick()`), si bien que tous les compteurs de la v1, exprimés en
  frames, sont repris tels quels : les formules de `game.js` se relisent ligne à
  ligne. Seul le rendu suit la fréquence d'affichage. Ne pas convertir ces
  compteurs en secondes par petites touches.
- `scenes/entities/` — `Player`, `Enemy`, `Projectile`, `Pickup` ne portent que
  l'état (champs de la v1) et leur visuel ; ils ne décident de rien.
- `scenes/fx.gd` — halos, auras de particules par élément, textes flottants,
  pièces d'or. `shaders/sprite.gdshader` fait le flash de coup, le contour
  (télégraphe de charge des boss) et la dissolution à la mort.
- **Pas de `PointLight2D`** : sous `CanvasModulate`, les lumières 2D ne
  donnaient aucun éclairage visible dans l'export web. `Fx.light()` renvoie un
  `Fx.Glow`, sprite radial en mélange additif, à ajouter **avant** le sprite de
  l'entité (sinon il le délave). Textes, éclats et traits d'estoc sont
  `unshaded` pour rester lisibles dans l'obscurité.
- **Échelle** : tout le visuel est à texel ×2 (sol en tuiles de 64 px, héros et
  monstres ×2, boss ×3, boss final ×4), mais les `radius` de la v1 — hitbox,
  portée de contact — sont inchangés. Les sprites débordent donc de leur
  hitbox, volontairement : l'équilibrage reste celui de la v1.
- `scenes/ui/` — menu, HUD (dont la barre du boss), forge, écran de fin, tous
  construits en code avec le thème de `ui_theme.gd`. **Tous les boutons sont
  sans focus** : sinon Espace (frapper) et Entrée (combattre) activeraient le
  dernier bouton cliqué.

### Mode Chaos

Huitième case de la grille des éléments, sans équivalent dans la v1.
`"chaos"` figure dans `Data.ELEMENTS` (libellé, couleurs, icône du menu, boss
final) mais **n'est jamais l'élément d'un monstre ordinaire** : ceux-ci tirent
l'un des 7 `Data.MOB_ELEMENTS` à l'apparition.

- **Comportement par monstre** : tir, briques, vol de vie et brûlure se lisent
  dans `Data.ELEMENTS[e.element]` à chaque tick, et plus dans l'élément choisi
  au menu. Une même vague mêle donc tireurs et monstres de mêlée.
- **Boss** : `Game.boss_queue` mélange les 7 éléments au début de la partie ;
  chaque vague multiple de 5 en retire la tête. Comme une vague ne s'achève
  qu'à la mort de son boss, un boss tué ne revient jamais. Les 7 boss occupent
  les vagues 5 à 35.
- **Boss final** : la Créature cauchemardesque en vague 40 (`Data.FINAL_BOSSES`).
  Sa prime est fixe : **300 or**, quelle que soit la difficulté. La victoire
  mène à l'écran de fin, puis au menu. Contrairement aux autres boss, elle a
  son propre jeu d'attaques, dans `scenes/nightmare.gd` (`Nightmare.tick`,
  appelé par `World` à la place de la logique commune) :
  - au contact, brûlure et vol de vie ;
  - **laser** tiré de l'œil : visée, direction figée, puis rayon qui balaie
    lentement vers le héros. La position de l'œil (`Enemy.eye_offset`) est
    repérée sur le sprite 32×32 : à refaire si on change de sprite ;
  - **fouet** : trois tentacules à longue portée ; **balayage** circulaire quand
    le héros est proche ; **ruée** en ligne droite ;
  - **saut** sur la position du héros, puis **onde de choc** en anneau : on n'est
    touché qu'au passage du front ;
  - **invocation** de mini-créatures (`is_mini`), monstres de mêlée ordinaires
    d'élément Chaos, six au plus ;
  - **champ de force**, quand le héros est proche : une sphère gonfle autour
    d'elle (le cercle de sa portée, 200 px, s'affiche dès le début), puis
    éclate. Le héros pris dedans est blessé et **projeté à l'autre bout de
    l'arène** (`World.knock_player`) : il glisse, sans contrôle, vers le point
    du bord le plus éloigné d'elle, devant lui (`Nightmare.knock_target`) ;
  - **dédoublement** à 75, 50 et 25 % de PV : le double (`is_clone`) reprend ses
    attaques sauf laser, invocation, champ de force et dédoublement.

  Toutes les attaques sont télégraphiées. Les créatures nées pendant le tick
  passent par `World.queue_spawn`. Sa mort emporte doubles et mini-créatures,
  sans prime.

### Conclave des boss

Niveau spécial, sans équivalent dans la v1, lancé par le bouton du menu ou la
touche B (`World.start_boss_rush`). Il ignore l'élément et la vague de départ du
menu et garde la difficulté. Les **9 boss** entrent ensemble : les 7 boss
d'élément, le Nécromancien Putréfié et la Créature cauchemardesque
(`Data.BOSS_RUSH_ROSTER`), avec les PV et l'or d'une vague 10
(`Data.BOSS_RUSH`).

- **Annonce** : 2 s (`RUSH_INTRO`) pendant lesquelles les boss restent figés en
  anneau autour du héros, pour qu'on les voie tous.
- **Réveil à l'approche** (`_update_rush_awake`) : un boss **endormi** rôde en
  petite boucle autour de sa place sur l'anneau (`Enemy.home`, `_rest`) et
  n'attaque pas. Il se réveille quand le héros arrive à moins de `RUSH_WAKE`
  (110 px) du bord de son sprite, et se rendort au-delà de `RUSH_SLEEP`
  (170 px). Au réveil, sa première attaque arrive vite (compteurs de charge,
  de tir et d'attaque de la Créature raccourcis) ; en s'endormant, il abandonne
  sa charge, mais la Créature finit d'abord son attaque en cours.
- **Comportement d'un boss réveillé** : chacun garde son IA de boss (mêlée,
  tir, charge, brûlure, vol de vie), sauf qu'un tireur reste à sa place au lieu
  de garder ses distances, ce qui le ferait sortir du rayon d'observation.
  S'y ajoutent une **promenade** (`_wander_bosses` : pas de côté autour du
  héros, dont le sens s'inverse lentement et diffère d'un boss à l'autre) et
  une **séparation** (`_separate_bosses`), endormis compris, qui écarte deux
  boss dont les sprites se chevauchent. La distance minimale suit la taille du sprite
  (`Enemy.top()`), pas la hitbox de la v1 : c'est la lisibilité qui est visée,
  l'équilibrage des coups ne change pas.
- **Infobulle des attaques** (`scenes/boss_tags.gd`) : au-dessus, en dessous
  ou à côté du boss réveillé le plus proche (`World.inspected_boss`), de
  préférence à l'opposé du héros pour ne pas le cacher, et jamais sur le boss
  lui-même. Une ligne par attaque, icône et description, sur deux colonnes
  au-delà de 6 (la Créature en a 11). Textes dans `Data.ATTACKS`, liste par boss
  dans `Data.BOSS_ATTACKS` (clé `final_<élément>` pour un boss final), icônes
  dans `assets/sprites/attacks/<id>.png`. **Une attaque ajoutée à un boss doit
  aussi l'être là**, sinon l'infobulle ment.
- **Boss figé pendant l'infobulle** : le boss inspecté ne bouge plus, sinon il
  s'éloignerait et l'infobulle avec lui. `World._tick` remet sa position après
  la mise à jour des ennemis : ses attaques continuent sur place (charge, ruée,
  saut compris), et la séparation fait reculer l'autre boss de tout l'écart.
  Le choix du boss inspecté (`_update_inspected`, une fois par tick) est
  **collant** : il le reste tant qu'il est éveillé, sauf si un autre est plus
  proche d'au moins `RUSH_INSPECT_SWITCH` (40 px). Sans cette marge, entre
  deux boss à égale distance, l'infobulle alternait à chaque frame et le boss
  non figé dérivait.
- **Personne ne blesse personne** : on observe les boss, on ne les combat
  pas. Ils lancent leurs attaques (charges, tirs, laser, fouet, champ de
  force…) mais ne blessent jamais le héros — ni dégâts, ni brûlure, ni vol de
  vie, ni projection. Tout passe par `World.harms_player()`, faux dans le
  Conclave, que consultent `hit_player`, `knock_player` et `Nightmare._hit`.
  En retour, un coup du héros sur un boss (ou un double) n'affiche
  qu'« Invulnérable » (`World.damage_enemy`) ; les mini-créatures, elles,
  meurent normalement. La partie ne se perd ni ne se gagne : **on en sort par
  P**, et le dédoublement de la Créature ne se déclenche jamais.
- La **Créature cauchemardesque**, réveillée, garde son jeu d'attaques
  (`Nightmare`) et ne se promène pas : elle bouge déjà par ses sauts et ruées.
  Ses doubles seraient séparés comme des boss (`_is_bulky`), mais elle ne se
  dédouble plus, faute de PV perdus.
- Un boss ne monte pas dans la bande du haut réservée au HUD (`RUSH_HUD_TOP`).
- Pas de vagues ni de fiole (le héros n'y perd pas de PV). La victoire du
  Conclave (mort du dernier boss, écran de fin avec le temps) reste dans le
  code mais n'est plus atteignable. Nom et barre de vie de chaque boss sont dessinés par
  `scenes/boss_tags.gd` ; le HUD affiche les boss restants et la vie cumulée.
- `Game.boss_rush` est remis à faux par `World.start_run`.

### Écarts assumés avec la v1

- **P ramène au menu principal** depuis la partie, la forge ou l'écran de fin
  (la partie en cours est abandonnée, l'or gagné reste acquis). Absent de la v1.
- **Sélecteur de vague de départ** au menu (boutons −5/−1/+1/+5, touches A/E),
  absent de la v1 : `Game.start_wave`, borné à la vague du boss final de
  l'élément (30 Ombre, 40 Chaos), sinon à 50. Non sauvegardé. Un départ en
  cours de partie ne donne ni or ni équipement ; en Chaos, les boss des vagues
  sautées sont réputés tués (`World.start_run`).
- Le menu au clavier boucle sur les **7** éléments et le Chaos (la v1 bouclait
  sur 6 et sautait l'Ombre).
- Un tireur (Destruction, Ombre) qui recule s'arrête au bord de l'arène : dans la
  v1, acculé, il sortait de l'écran pour de bon.
- Un coup qui tue plusieurs ennemis les touche tous (la v1 retirait l'ennemi
  du tableau en le parcourant et sautait le suivant).
- L'or gagné croît de **+12 % par vague** au lieu de +5 % dans la v1
  (`World._spawn_enemy`), pour raccourcir l'attente avant un achat à la forge.
- La cadence des tireurs (Ombre, Destruction) suit la difficulté via
  `shoot_mult` : **Difficile garde le rechargement de la v1** (90 frames, 55
  pour un boss), Intermédiaire ×1,3 et Facile ×1,7. La v1 tirait à cadence fixe.
- Une **fiole de soin** tombe à chaque début de vague (`World._drop_potion`) et
  rend 20 % des PV max. Elle n'existe pas dans la v1. Jamais deux au sol : celle
  qu'on laisse traîner tient lieu de réserve. Elle ne se ramasse qu'à PV
  entamés, sinon un simple passage dessus la gâcherait.

## Assets

Tous libres — sources et licences dans `CREDITS.md`.

**Sprites** : pack [Dungeon Crawl Stone Soup 32×32](https://opengameart.org/content/dungeon-crawl-32x32-tiles)
(CC0). Ce sont des **images fixes** : l'animation est procédurale (balancement,
fente de l'attaque, flash, dissolution, particules, halos). Fichiers renommés
à la copie :

| Rôle | Fichier du jeu | Original (`Dungeon Crawl Stone Soup Full/`) |
| --- | --- | --- |
| Cendres / boss | `monsters/smoke_demon`, `skeletal_warrior` | `monster/demons/smoke_demon_new`, `monster/undead/skeletal_warrior_new` |
| Sang / boss | `flayed_ghost`, `flesh_golem` | `monster/undead/flayed_ghost_new`, `monster/nonliving/flesh_golem` |
| Violence / boss | `imp`, `warmonger` | `monster/demons/imp`, `monster/demonspawn/warmonger` |
| Terre / boss | `earth_elemental`, `rotting_hulk` | `monster/nonliving/earth_elemental`, `monster/undead/rotting_hulk_new` |
| Feu / boss | `fire_elemental`, `balrug` | `monster/nonliving/fire_elemental_new`, `monster/demons/balrug_new` |
| Destruction / boss | `hell_sentinel`, `pit_fiend` | `monster/demons/hell_sentinel`, `monster/demons/pit_fiend` |
| Ombre / boss | `shadow_imp`, `shadow_fiend` | `monster/demons/shadow_imp_new`, `monster/demons/shadow_fiend_new` |
| Boss final | `zonguldrok_lich` | `monster/undead/zonguldrok_lich_1` |
| Chaos : boss final et icône du menu | `unseen_horror` | `monster/aberration/unseen_horror_new` |
| Héros | `player/base`, `body_N`, `legs_N`, `boots_N`, `head_N`, `cloak_N`, `sword_N` | `player/…` (calques paperdoll, N = niveau d'armure ou d'épée) |
| Arène | `dungeon/floor_0..6`, `lava_0..3` | `dungeon/floor/volcanic_floor_*`, `lava_*` |
| Projectiles, or, fiole | `fx/brick`, `fx/bolt`, `fx/gold`, `fx/potion` | `effect/rock_0_new`, `effect/magic_bolt_1`, `item/gold/gold_pile_5`, `item/potion/ruby` |
| Icônes d'attaque (Conclave) | `attacks/melee`, `heavy`, `fast`, `tough`, `charge`, `lifesteal`, `burn`, `bricks`, `bolts`, `giant` | `gui/spells/` : `components/sword`, `enchantment/berserker_rage_new`, `air/swiftness_new`, `earth/stoneskin_new`, `enchantment/haste_new`, `necromancy/vampiric_draining_new`, `fire/sticky_flame_new`, `components/stones`, `conjuration/magic_dart`, `necromancy/deaths_door_new` |
| Icônes d'attaque de la Créature | `attacks/laser`, `whip`, `sweep`, `rush`, `leap`, `summon`, `field`, `split` | `gui/spells/` : `conjuration/searing_ray`, `summoning/summon_horrible_things`, `air/tornado`, `translocation/blink`, `earth/shatter_new`, `summoning/summon_shadow_creatures_new`, `translocation/gravitas`, `necromancy/simulacrum_new` |
| Difficultés (menu) | `ui/difficulty_facile`, `_intermediaire`, `_difficile` | `monster/animals/rat`, `monster/orc`, `monster/ogre` |

Les trois icônes de difficulté suivent la même convention que les éléments, mais
sans clé dans `Data` : le menu les charge par `ui/difficulty_<id>.png`, d'après
l'identifiant de `Data.DIFFICULTY_ORDER`. Le rat, l'orc et l'ogre ne disent rien
de l'enfer ; ils sont là parce qu'ils **s'échelonnent lisiblement en taille** à
32 px, sans empiéter sur les sprites d'élément voisins.

Le sprite de chaque élément est déclaré dans `Data.ELEMENTS` (`sprite`,
`boss_sprite`). Un calque de héros absent (`body_0`, `sword_0`…) est simplement
vide : c'est ce qui rend « Peau nue » et « Poings nus ».

Le pack d'origine contient plus de 3000 tuiles : pour changer un monstre, un
sol ou une pièce d'armure, en copier une autre sous le même nom.

**Sons** : Kenney (RPG Audio, Impact Sounds) et OpenGameArt, tous CC0. Les
musiques bouclent par `Audio._enable_loop()` à l'exécution, sans toucher aux
`.import`. `music/boss.wav` a été réduit en mono 22 kHz (5 Mo au lieu de 21) ;
il n'y a ni `ffmpeg` ni encodeur OGG sur la machine.

**Police** : MedievalSharp (SIL OFL), copiée de ms2.

## Limites connues

- Les bruitages ont été validés à l'oreille et sont bons. Restent à écouter les
  **musiques**, en particulier la boucle de `music/boss.wav` : la machine de
  développement n'a pas de sortie audio et le mode smoke charge les sons sans
  les jouer.
- La fiole de soin **emprunte le bruitage `purchase`**, faute d'un son de
  gorgée dans les packs copiés.
- Le mode smoke maintient le héros à PV pleins, si bien que `check.sh`
  **n'exerce jamais le ramassage de la fiole** — seule son apparition l'est.
- Les traits d'ombre (`fx/bolt`) restent **bleutés** : le sprite source est bleu
  et le `modulate` violet ne suffit pas à le recolorer.
- Les parties smoke se jouent **une par une** : lancées en parallèle, chacune
  ralentit (le pas fixe est plafonné par frame) et la vague 40 du Chaos
  n'aboutit plus en 60 s.
- Les sprites étant fixes, un monstre ne se retourne que par `flip_h` : pas
  d'animation de marche ni d'attaque propre à chaque créature.
