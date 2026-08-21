# CLAUDE.md

Guidance pour Claude Code sur `mecha-survivant-2/`.

## Ce que c'est

Refonte visuelle et sonore de `mecha-survivant/`, sous **Godot 4** exporté en
HTML5. Les mécaniques sont reprises telles quelles depuis la v1 — mêmes vagues,
mêmes ennemis, mêmes pouvoirs, mêmes boss. Ce qui change : un vrai moteur de
rendu, des sprites pixel art et de l'audio en fichiers, là où la v1 dessinait
des formes au Canvas 2D et synthétisait tout en Web Audio.

La v1 reste en place, intacte et jouable. Ce n'est pas un remplacement.

## Écarts assumés avec la convention du dépôt

Le dépôt est fait de jeux « HTML/CSS/JS pur, ouvrir `index.html` suffit ». Ce
jeu déroge sur deux points, en connaissance de cause :

1. **Il y a une étape de build.** Les sources sont dans `godot/`, le jeu jouable
   est produit par `scripts/build.sh` dans `export/` — qui n'est **pas**
   versionné (39 Mo de wasm à chaque rebuild gonfleraient l'historique pour
   rien). C'est la CI GitHub Pages qui construit à la publication, et qui
   déplace ensuite le contenu d'`export/` à la racine du dossier pour que le jeu
   soit servi depuis `/mecha-survivant-2/` comme les autres.
2. **Il ne s'ouvre pas en `file://`.** Un export Godot charge son `.pck` et son
   `.wasm` par requête réseau. En local : `scripts/serve.sh` puis
   <http://localhost:8123>.

## Outillage

```sh
scripts/install-godot.sh   # une fois : Godot 4.7.2 + template Web
scripts/play.sh            # joue directement dans Godot, sans build ni serveur
scripts/build.sh           # import des assets puis export HTML5 dans export/
scripts/serve.sh [port]    # sert export/ (8123 par défaut)
scripts/check.sh           # non-régression sans écran (voir plus bas)
scripts/gen-sprites.py     # génère les planches de sprites (voir « Assets »)
scripts/preview-sheet.py   # agrandit une planche, case par case, pour la relire
```

**Sur une machine avec écran, `scripts/play.sh` suffit pour jouer** : il lance
le projet dans Godot, sans export, sans serveur, et sans avoir besoin des
export templates. Le build web ne sert qu'à la publication.

Les scripts marchent sur Linux x86_64 et sur macOS (téléchargement universel,
donc Apple Silicon compris). `scripts/godot-env.sh`, sourcé par les autres,
résout le binaire : `$GODOT` s'il est défini, puis `~/.local/bin/godot`, le
`godot` du PATH, et enfin `Godot.app`. Deux détails propres à macOS gérés par
`install-godot.sh` : les templates y vivent dans
`~/Library/Application Support/Godot/export_templates/`, et l'app téléchargée
doit être sortie de la quarantaine Gatekeeper (`xattr -dr com.apple.quarantine`)
sans quoi macOS la déclare « endommagée ».

La version de Godot et celle des export templates **doivent coïncider
exactement** (`4.7.2.stable`). `install-godot.sh` est idempotent et ne garde du
`.tpz` d'1 Go que les deux fichiers Web.

## Travailler sans éditeur

La machine n'a pas d'écran : l'éditeur Godot ne s'ouvre jamais. Tout
(`project.godot`, `.tscn`, `.tres`) est écrit à la main en texte. Règles qui
rendent cela tenable :

- **Ne jamais écrire d'`uid=`** dans un `[ext_resource]`. Un UID inventé produit
  un avertissement et parfois une ressource invalide ; `path=` suffit. Les
  `.gd.uid`, eux, sont générés par Godot et **sont versionnés**.
- Les scènes restent **minimalistes** — presque tout est construit en code. Une
  propriété inconnue dans un `.tscn` est ignorée en silence, alors qu'une faute
  en GDScript typé est une erreur de compilation.
- Les données de jeu (stats d'ennemis, pouvoirs) sont des **dictionnaires const
  GDScript**, pas des `.tres` : plus sûrs à éditer à l'aveugle.
- `.godot/` est ignoré ; les `.import` sont versionnés. Après tout ajout
  d'asset, relancer `scripts/build.sh` (qui fait l'`--import`).
- **Le cache de `class_name` se périme.** Il vit dans
  `.godot/global_script_class_cache.cfg`, hors du dépôt : un clone frais ne l'a
  pas, et un `class_name` ajouté depuis le dernier import n'y est pas non plus —
  dans les deux cas rien ne démarre (« Could not find type "Arena" »).
  `ensure_import()` dans `godot-env.sh` réimporte quand le cache manque ou
  qu'un `.gd` est plus récent que lui ; `play.sh` et `check.sh` l'appellent, tout
  nouveau script d'entrée doit le faire aussi.

## Vérification

`scripts/check.sh` joue quatre parties en accéléré, sans rendu, via le mode
smoke de `scenes/main.gd` (`--headless -- --smoke [--wave=N|--titan]`) : le mech
y est immortel et tire tout seul, sinon rien n'irait plus loin que la première
vague. Toute erreur GDScript apparaît dans la sortie. C'est le test de
non-régression du jeu — le lancer après chaque changement.

Pour le visuel, `tools/` (racine du dépôt) pilote un Chromium headless :

```sh
scripts/serve.sh &
node tools/capture.js http://localhost:8123/index.html tools/shots/ms2.png --wait 15000
MS2_TITAN=1 node tools/capture.js http://localhost:8123/index.html tools/shots/titan.png \
  --scenario tools/scenarios/ms2-gameplay.js --no-step
```

Deux points à connaître :

- **`--no-step` est obligatoire ici.** `driver.js` remplace
  `requestAnimationFrame` pour piloter la v1 image par image ; la boucle de
  Godot vit dans le wasm et passe par ce même rAF — sans `--no-step` le jeu
  reste figé sur son écran de chargement.
- Le scénario `ms2-gameplay.js` clique par **coordonnées** relevées sur une
  capture : les boutons sont peints dans le canvas, il n'y a pas de DOM. Changer
  la mise en page de `start_screen.gd` oblige à réajuster ces constantes.

## Architecture

Autoloads (`autoload/`) : `EventBus` (tous les signaux transverses),
`GameState` (vague, tier, mode smoke), `AudioManager`, `UpgradeManager`.

- `systems/wave_manager.gd` — `5 + n*2` ennemis, `tier = floor((n-1)/2)`, boss
  si `n % 5 == 0`, méga-boss en 15, Titan en 20.
- `systems/enemy_stats.gd` — stats des cinq ennemis et leur scaling par tier.
  **Les vitesses sont en pixels/seconde** : la v1 comptait en pixels/frame, tout
  a été multiplié par 60, timers compris.
- `scenes/enemies/enemy_base.gd` — chaque variante surcharge `_behaviour()`, là
  où la v1 faisait un `switch (e.type)`. `is_damage_immune()` est le **point de
  passage unique** de toute immunité (déphasage des ombres, bouclier du
  méga-boss, invulnérabilité ultime du Titan) : toute nouvelle source de dégâts
  doit l'interroger.
- `scenes/bosses/boss_base.gd` — machine à états de phases : quand la barre
  tombe à zéro et qu'il reste une phase, elle **repart à plein** et les
  multiplicateurs montent. `_telegraph_strike()` y est central : un télégraphe
  survit au boss qui l'a lancé, sa closure ne doit donc capturer que des
  valeurs, jamais `self` ni `player` — un boss tué pendant l'annonce faisait
  planter l'impact.
- `scenes/bosses/titan.gd` — cinq phases. En phase finale, la barre **ne peut
  pas descendre sous 1 %** tant que l'ultime n'a pas eu lieu : un coup assez
  fort la traverserait d'un trait et le Titan mourrait sans jamais lancer son
  attaque. L'ultime lui donne 10 s d'immunité totale, coupe toutes ses autres
  attaques, et le **recale à 420 px du joueur** (`_anchor_for_ultimate`) — collé
  à lui, la boule le touchait dans la frame du tir sans être visible. Elle
  s'esquive en se déplaçant, pas en dashant, et tue net sauf bouclier actif.
- `scenes/fx/sprite_or_shape.gd` — visuel tolérant à l'absence d'asset : sprite
  s'il existe, placeholder géométrique sinon. C'est ce qui permet de livrer le
  jeu jouable avant les assets. Le même principe vaut hors des entités : le sol
  d'`arena.gd`, l'onde de choc, le télégraphe et la flaque de poison gardent
  chacun leur rendu géométrique en secours, et `HitSpark` ne s'instancie pas du
  tout tant que `fx_hit.png` manque.

## Assets

Aucun n'est encore présent : voir `godot/assets/MANIFEST.md` pour la liste
exacte des fichiers attendus, leurs dimensions et leur découpage. Déposer un
fichier au bon nom suffit à le brancher, sans toucher au code.

`scripts/gen-sprites.py` produit ces planches depuis l'API PixelLab. Il ne
décide de rien : il **lit** `SHEETS` et le tableau du manifeste, et refuse de
travailler si les deux divergent. Chaque planche est faite d'une image de base
(`create-image-pixflux`) puis d'animations dérivées de cette base
(`animate-with-text-v3`), assemblées en strip horizontal aux dimensions exactes.
Les prompts vivent dans `scripts/sprite-prompts.json`, hors du code, pour être
retouchés sans y toucher.

Quatre choses à savoir avant de le lancer :

- **Les frames brutes sont mises en cache** dans `.gen-cache/` (non versionné).
  Relancer ne regénère que ce qui manque — une frame générée est une frame
  payée. `--force` la jette, `--assemble-only` réassemble sans appeler l'API.
- **`--fake` valide toute la chaîne sans dépenser un crédit** : aplats colorés
  aux bonnes dimensions, une teinte par case et un repère de coin, de quoi voir
  au premier coup d'œil une planche découpée de travers.
- **L'API impose un nombre de frames pair** (4 à 16) : le dash à 3 cases et
  l'impact à 5 sont demandés au pair supérieur puis échantillonnés. C'est le
  script qui s'adapte au générateur, jamais `SHEETS` — le découpage est le
  contrat avec le moteur.
- **Le jeton** est lu dans `$PIXELLAB_TOKEN`, sinon `.pixellab-token` à la
  racine (ignoré par git). Ni l'un ni l'autre ne doit finir dans un commit.

`scripts/preview-sheet.py <planche>` la rend relisible : agrandissement au plus
proche voisin sur un damier qui marque les limites de case. C'est le seul moyen,
sans écran, de voir qu'un sprite déborde sur la case voisine ou n'est pas centré
pareil d'une frame à l'autre — un défaut invisible sur une planche de 256×32.

Le codec PNG (`scripts/pngtool.py`) est écrit à la main sur `zlib` : Pillow
n'est pas installé et le dépôt tient à rester sans dépendance à installer.

Le découpage des planches vit dans `SHEETS` (`scenes/fx/sprite_or_shape.gd`) :
combien de cases, et quelles plages forment `idle`, `walk`, `death`, `attack`…
Les appelants ne nomment jamais un numéro de case, seulement une animation
(`_visual.play("walk")`, ou `play_once("attack", "idle")` pour un geste
ponctuel). Ajouter une planche, c'est ajouter une entrée dans `SHEETS` — la
régler chez l'appelant, c'est se garantir un découpage faux le jour où le
fichier arrive.

La police par défaut de Godot **ne rend pas les emoji** : ne pas en mettre dans
l'UI (le HUD affiche des libellés courts pour cette raison).
