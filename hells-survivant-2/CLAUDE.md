# CLAUDE.md

Guidance pour Claude Code sur `hells-survivant-2/`.

## Ce que c'est

Refonte visuelle de `hells-survivant/`, sous **Godot 4** exporté en HTML5, dans
un style pixel art façon *Heroes of Might and Magic 2*. Les mécaniques sont
reprises telles quelles de la v1 : 3 difficultés, 7 éléments, boss toutes les
5 vagues, Nécromancien Putréfié en vague 30 (élément Ombre), forge épée/armure
persistante. Ce qui change : sprites, halos lumineux, particules, shaders,
interface et sons en fichiers, là où la v1 dessinait des formes au Canvas 2D et
synthétisait tout en Web Audio.

**En ligne** : <https://gungagungi.github.io/games/hells-survivant-2/>, lié
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

`scripts/check.sh` joue quatre parties accélérées via le mode smoke de
`scenes/main.gd` (`--headless -- --smoke [--element=X] [--difficulty=X]
[--wave=N] [--duration=S]`) : vagues ordinaires (Sang, vague 1), boss de mêlée
(Feu, vague 5), boss tireur de briques en Difficile (Destruction, vague 10), et
boss final jusqu'à la **victoire** (Ombre, vague 30). Le héros y est immortel,
équipé au maximum (en mémoire, `Save.write()` ne fait rien en smoke) et combat
tout seul. Une partie échoue si elle ne progresse pas, si la vague 30 ne se
conclut pas en victoire, ou sur toute erreur GDScript.

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
- `scenes/entities/` — `Player`, `Enemy`, `Projectile` ne portent que l'état
  (champs de la v1) et leur visuel ; ils ne décident de rien.
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

### Écarts assumés avec la v1

- Le menu au clavier boucle sur les **7** éléments (la v1 bouclait sur 6 et
  sautait l'Ombre).
- Un tireur (Destruction, Ombre) qui recule s'arrête au bord de l'arène : dans la
  v1, acculé, il sortait de l'écran pour de bon.
- Un coup qui tue plusieurs ennemis les touche tous (la v1 retirait l'ennemi
  du tableau en le parcourant et sautait le suivant).

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
| Héros | `player/base`, `body_N`, `legs_N`, `boots_N`, `head_N`, `cloak_N`, `sword_N` | `player/…` (calques paperdoll, N = niveau d'armure ou d'épée) |
| Arène | `dungeon/floor_0..6`, `lava_0..3` | `dungeon/floor/volcanic_floor_*`, `lava_*` |
| Projectiles, or | `fx/brick`, `fx/bolt`, `fx/gold` | `effect/rock_0_new`, `effect/magic_bolt_1`, `item/gold/gold_pile_5` |

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

- **Le son n'a jamais été écouté** : la machine de développement n'a pas de
  sortie audio, et le mode smoke charge les sons sans les jouer. Choix des
  bruitages, volumes (`Audio`, −4 dB effets, −10 dB musique) et boucle de
  `music/boss.wav` sont à valider à l'oreille.
- Les traits d'ombre (`fx/bolt`) restent **bleutés** : le sprite source est bleu
  et le `modulate` violet ne suffit pas à le recolorer.
- Les sprites étant fixes, un monstre ne se retourne que par `flip_h` : pas
  d'animation de marche ni d'attaque propre à chaque créature.
- La CI affiche un avertissement de dépréciation de Node.js 20 sur les actions
  (`checkout`, `cache`, `configure-pages`, `deploy-pages`…) : sans effet pour
  l'instant, à traiter en passant à leurs versions suivantes.
