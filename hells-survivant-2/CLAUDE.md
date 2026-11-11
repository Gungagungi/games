# CLAUDE.md

Guidance pour Claude Code sur `hells-survivant-2/`.

## Ce que c'est

Refonte visuelle de `hells-survivant/`, sous **Godot 4** exporté en HTML5, dans
un style pixel art façon *Heroes of Might and Magic 2*. Les mécaniques sont
reprises telles quelles de la v1 : 3 difficultés, 7 éléments, boss toutes les
5 vagues, Nécromancien Putréfié en vague 30 (élément Ombre), forge épée/armure
persistante. Ce qui change : sprites, halos lumineux, particules, shaders,
interface et sons en fichiers, là où la v1 dessinait des formes au Canvas 2D et
synthétisait tout en Web Audio. S'y ajoute un mode absent de la v1, le
**Chaos** (voir « Mode Chaos »).

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

`scripts/check.sh` joue sept parties accélérées via le mode smoke de
`scenes/main.gd` (`--headless -- --smoke [--element=X] [--difficulty=X]
[--wave=N] [--duration=S]`) : vagues ordinaires (Sang, vague 1), boss de mêlée
(Feu, vague 5), boss tireur de briques en Difficile (Destruction, vague 10), et
boss final jusqu'à la **victoire** (Ombre, vague 30), puis trois parties Chaos :
vagues mélangées (vague 1), dernier boss de la file (vague 35) et Créature
cauchemardesque jusqu'à la victoire (vague 40, sur 60 s au lieu de 20 : elle
saute, charge et se dédouble, le pilote automatique met plus longtemps à la
finir). Chaque apparition de boss est
écrite dans la sortie (`[smoke] vague N : <boss>`). Le héros y est immortel,
équipé au maximum (en mémoire, `Save.write()` ne fait rien en smoke) et combat
tout seul. Une partie échoue si elle ne progresse pas, si une vague de boss
final ne se conclut pas en victoire, ou sur toute erreur GDScript.

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
```

Le scénario passe l'écran-titre **au clavier** (Z/S, Entrée), sans coordonnée
de clic : changer la mise en page du menu ne le casse pas.

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
  - **dédoublement** à 75, 50 et 25 % de PV : le double (`is_clone`) reprend ses
    attaques sauf laser, invocation et dédoublement.

  Toutes les attaques sont télégraphiées. Les créatures nées pendant le tick
  passent par `World.queue_spawn`. Sa mort emporte doubles et mini-créatures,
  sans prime.

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
