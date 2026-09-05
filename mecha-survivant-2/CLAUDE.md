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
scripts/gen-audio.py       # génère bruitages et musiques (voir « Audio »)
scripts/preview-sheet.py   # agrandit une planche, case par case, pour la relire
scripts/gen-version.sh     # écrit godot/version.txt (branche@hash), voir « Version »
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
smoke de `scenes/main.gd` (`--headless -- --smoke [--wave=N]`) : le mech
y est immortel et tire tout seul, sinon rien n'irait plus loin que la première
vague. Toute erreur GDScript apparaît dans la sortie. C'est le test de
non-régression du jeu — le lancer après chaque changement.

Pour le visuel, `tools/` (racine du dépôt) pilote un Chromium headless :

```sh
scripts/serve.sh &
node tools/capture.js http://localhost:8123/index.html tools/shots/ms2.png --wait 15000
MS2_WAVE=20 node tools/capture.js http://localhost:8123/index.html tools/shots/final.png \
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
  si `n % 5 == 0` **ou `n == 1`** (mapping explicite `BOSS_BY_WAVE` pour
  1/5/10/15/20). La vague 1 est spéciale : voir « Le faux Titan et le vrai
  combat final » ci-dessous.
- `systems/enemy_stats.gd` — stats des six ennemis ordinaires et leur scaling
  par tier. **Les vitesses sont en pixels/seconde** : la v1 comptait en
  pixels/frame, tout a été multiplié par 60, timers compris.
- `scenes/enemies/enemy_base.gd` — chaque variante surcharge `_behaviour()`, là
  où la v1 faisait un `switch (e.type)`. `is_damage_immune()` est le **point de
  passage unique** de toute immunité (déphasage des ombres, bouclier d'un boss
  en phase) : toute nouvelle source de dégâts doit l'interroger.
- `scenes/enemies/fire_skeleton.gd` — squelette de feu (vagues 1-19, jamais
  pendant un combat de boss puisque le pool ordinaire ne tourne pas alors).
  Ses flèches et son contact embrasent le joueur (`Player.ignite()`, dégâts
  continus hors bouclier/invulnérabilité de coup) ; le laisser trop longtemps
  sans riposte (`ENRAGE_DELAY` sans dégât reçu) lui vaut une boule de feu à
  la moitié de la vie max.
- `scenes/bosses/boss_base.gd` — machine à états de phases : quand la barre
  tombe à zéro et qu'il reste une phase, elle **repart à plein** et les
  multiplicateurs montent. `_telegraph_strike()` y est central : un télégraphe
  survit au boss qui l'a lancé, sa closure ne doit donc capturer que des
  valeurs, jamais `self` ni `player` — un boss tué pendant l'annonce faisait
  planter l'impact.

### Le faux Titan (vague 1) et le vrai combat final (vague 20)

Le Titan de la Mort annoncé depuis la v1 n'a en réalité qu'1 point de vie
(`scenes/bosses/titan_decoy.gd`) : c'est le boss qui ouvre le jeu, dès la
vague 1. Sa barre s'affiche pleine à l'apparition puis se vide au premier
coup. Sa mort ne passe **pas** par `die()` / `EventBus.boss_defeated` (qui
ferait conclure la vague en victoire) mais par `EventBus.titan_decoy_defeated`,
que `WaveManager` relaie en `EventBus.dialogue_requested` — une réplique
affichée par `scenes/ui/dialogue_box.gd`, qui coupe `GameState.running` (donc
joueur, ennemis et vagues, tous gardés par ce flag) jusqu'au clic. Une fois le
dialogue refermé (`EventBus.dialogue_finished`), la vague se termine
normalement, sans lien avec la suite — c'est la boucle habituelle de
`WaveManager._process` (plus de boss vivant, plus d'ennemi vivant) qui conclut
la vague. En mode smoke, la réplique est sautée instantanément, sinon
`check.sh` resterait bloqué en attente d'un clic.

Le vrai boss final, `scenes/bosses/galaxy_boss.gd` (trois phases), n'a aucun
lien avec le leurre : il apparaît directement à la vague 20, via le même
`BOSS_BY_WAVE` que les autres boss.

Piège rencontré (toujours d'actualité même sans l'enchaînement leurre → Boss
Galaxie) : faire naître un boss **synchrone** avec la mort du boss précédent
plante le moteur (« Can't change this state while flushing queries »), parce
que toute la chaîne remonte depuis la collision d'une balle — ajouter une
`Area2D` en pleine mise à jour physique n'est pas permis. `WaveManager` ajoute
donc le boss via `arena.call_deferred("add_child", boss)`, dans
`_spawn_boss_script()`, utilisé pour **tous** les spawns de boss.

Les trois autres nouveaux boss (vagues 5/10/15) n'ont pas cette contrainte :
`scenes/bosses/giant_knight.gd` (Chevalier Géant, corps-à-corps),
`scenes/bosses/sewer_monster.gd` (Monstre des Égouts, poison + invocations) et
`scenes/bosses/zombie_titan.gd` (Zombie Titan, deux phases, invocations +
ponction de vie) remplacent les anciens gravedigger / bone_colossus / plague /
mega_boss, retirés avec leurs sprites laissés dans `assets/sprites/` (non
référencés, mais toujours utilisables) — voir « Assets ».

- `scenes/fx/sprite_or_shape.gd` — visuel tolérant à l'absence d'asset : sprite
  s'il existe, placeholder géométrique sinon. C'est ce qui permet de livrer le
  jeu jouable avant les assets. Le même principe vaut hors des entités : le sol
  d'`arena.gd`, l'onde de choc, le télégraphe et la flaque de poison gardent
  chacun leur rendu géométrique en secours, et `HitSpark` ne s'instancie pas du
  tout tant que `fx_hit.png` manque.

## Assets

**Les 24 planches de sprites d'origine sont là**, dont cinq boss aujourd'hui
retirés du jeu (gravedigger, bone_colossus, plague, mega_boss, titan — ce
dernier réutilisé tel quel par `titan_decoy.gd`, voir plus haut). **Les 21
bruitages et les 4 musiques aussi** (voir « Audio »). En revanche, les quatre
nouveaux boss (Chevalier Géant, Monstre des Égouts, Zombie Titan, Boss
Galaxie) et le squelette de feu n'ont pas de planche dédiée : ils tournent en
placeholder géométrique via `sprite_or_shape.gd`, sans entrée dans `SHEETS` ni
dans le manifeste — ce n'est pas une omission, juste pas encore fait.
`godot/assets/MANIFEST.md` donne la liste exacte des fichiers attendus pour ce
qui existe, leurs dimensions et leur découpage. Déposer un fichier au bon nom
suffit à le brancher, sans toucher au code.

`scripts/gen-sprites.py` produit ces planches depuis un générateur externe.
`--provider retrodiffusion` (par défaut) ou `--provider pixellab` : les deux
sont pilotés par le même code, seuls le jeton et les prompts changent. Il ne
décide de rien : il **lit** `SHEETS` et le tableau du manifeste, et refuse de
travailler si les deux divergent. Chaque planche est faite d'une image de base
puis d'animations dérivées de cette base, assemblées en strip horizontal aux
dimensions exactes. Les prompts vivent dans `scripts/sprite-prompts.json`, hors
du code, pour être retouchés sans y toucher.

Cinq choses à savoir avant de le lancer :

- **Les frames brutes sont mises en cache** dans `.gen-cache/` (non versionné),
  et depuis peu la **planche rendue** avec elles (`<anim>_sheet.png`). Relancer
  ne regénère que ce qui manque — une frame générée est une frame payée — et un
  découpage à revoir se rejoue hors ligne au lieu de se repayer. `--force` jette
  le cache, `--assemble-only` réassemble sans appeler l'API.
- **La planche rendue est une grille, pas une bande.** Retro Diffusion rend
  quatre frames de 128 px en 256×256 (2×2), six en 3×2. `slice_grid()` les lit
  ligne par ligne ; la lire comme une bande jetait la moitié des frames payées,
  et `fit()` comblait le trou en dupliquant les autres — huit cases pour quatre
  images distinctes, sans le moindre avertissement.
- **`--fake` valide toute la chaîne sans dépenser un crédit** : aplats colorés
  aux bonnes dimensions, une teinte par case et un repère de coin, de quoi voir
  au premier coup d'œil une planche découpée de travers.
- **L'API impose un nombre de frames pair** (4 à 16) : le dash à 3 cases et
  l'impact à 5 sont demandés au pair supérieur puis échantillonnés. C'est le
  script qui s'adapte au générateur, jamais `SHEETS` — le découpage est le
  contrat avec le moteur.
- **Le jeton** est lu dans `$RETRODIFFUSION_TOKEN` / `$PIXELLAB_TOKEN` selon le
  fournisseur, sinon `.retrodiffusion-token` / `.pixellab-token` à la racine
  (ignorés par git). Aucun ne doit finir dans un commit.

Ce que Retro Diffusion apporte, et pourquoi c'est lui par défaut : les cases de
16 px passent nativement, `num_images` rend plusieurs images en **un seul
appel**, et les styles `rd_tile__*` sont **raccordables par construction** —
c'est ce qui a sauvé le sol. Le style employé est déclaré par asset sous
`rd_style` ; `GET /v1/styles/selector` en donne la liste avec les bornes de
dimensions de chacun, et ces styles refusent `tile_x`/`tile_y` puisqu'ils sont
déjà raccordables. Le mode `variations` d'un asset produit une image de base
puis ses variantes : elles en héritent texture et palette, là où des tirages
indépendants donnent un patchwork.

`scripts/preview-sheet.py <planche>` la rend relisible : agrandissement au plus
proche voisin sur un damier qui marque les limites de case. C'est le seul moyen,
sans écran, de voir qu'un sprite déborde sur la case voisine ou n'est pas centré
pareil d'une frame à l'autre — un défaut invisible sur une planche de 256×32.

**Ni les bonnes dimensions ni un `check.sh` vert ne prouvent qu'une planche est
juste.** Les cinq planches de boss sont sorties une première fois à la taille
attendue, importées sans une erreur, et pourtant chaque case y était dupliquée.
Après toute génération, compter les cases réellement distinctes vaut le détour :

```sh
python3 - <<'PY'
import sys, pathlib; sys.path.insert(0, "scripts")
from pngtool import Image
for f in sorted(pathlib.Path("godot/assets/sprites").glob("*.png")):
    im = Image.decode(f.read_bytes()); t = im.height; n = im.width // t
    uniq = {bytes(im.crop(i * t, 0, t, t).pixels) for i in range(n)}
    print(f"{f.stem:22} {n} cases, {len(uniq)} distinctes")
PY
```

Une case répétée n'est pas toujours un bug : les animations partant d'une frame
de base la réutilisent en tête de séquence. Deux cases distinctes pour quatre
demandées, en revanche, est le signe d'un découpage faux.

Le codec PNG (`scripts/pngtool.py`) est écrit à la main sur `zlib` : Pillow
n'est pas installé et le dépôt tient à rester sans dépendance à installer.

Le découpage des planches vit dans `SHEETS` (`scenes/fx/sprite_or_shape.gd`) :
combien de cases, et quelles plages forment `idle`, `walk`, `death`, `attack`…
Les appelants ne nomment jamais un numéro de case, seulement une animation
(`_visual.play("walk")`, ou `play_once("attack", "idle")` pour un geste
ponctuel). Ajouter une planche, c'est ajouter une entrée dans `SHEETS` — la
régler chez l'appelant, c'est se garantir un découpage faux le jour où le
fichier arrive.

## Audio

`scripts/gen-audio.py` produit bruitages et musiques depuis ElevenLabs, sur le
modèle de `gen-sprites.py` : il ne décide de rien, il **lit** la liste du
manifeste et la recoupe avec les appels réels du code
(`AudioManager.sfx(...)`, `play_music(...)`). Une clé déclarée mais jamais
jouée, ou l'inverse, arrête la génération avant la première dépense. Les
prompts vivent dans `scripts/audio-prompts.json`.

Quatre choses à savoir :

- **Le PCM rendu par l'API est stéréo entrelacé**, alors que le format demandé
  s'appelle `pcm_44100` et que rien dans les octets ne l'indique. Lu comme du
  mono, chaque bruitage s'écrit, s'importe et se joue sans la moindre erreur —
  il dure simplement deux fois trop longtemps et sonne une octave trop bas.
  C'est arrivé sur les 21 premiers. `wavtool.downmix()` est le point de passage,
  et le doublement exact de la durée demandée est le symptôme à guetter.
- **La Music API exige un plan payant** (`paid_plan_required`), la Sound Effects
  API non. Un compte gratuit produit les 21 bruitages et zéro musique ; le plan
  Starter à 5 $ débloque les quatre pistes, qui en consomment 0,81.
- **Les réponses brutes sont en cache** dans `.gen-cache/audio/` (non versionné),
  et tout le post-traitement — rognage du silence, plafond de durée, fondus,
  normalisation — est hors ligne : `--assemble-only` le rejoue autant qu'on veut
  sans repayer. C'est ce qui a permis de rattraper la bévue stéréo pour rien.
- **`--fake` valide la chaîne sans dépenser** : il rend du stéréo entrelacé lui
  aussi, avec silence de tête et de queue, pour éprouver exactement le même
  chemin de décodage que l'API.

Le codec WAV (`scripts/wavtool.py`) est écrit à la main sur `array`/`struct`,
comme `pngtool.py` pour le PNG : ni Pillow ni `ffmpeg` à installer.

Deux détails côté moteur. Une musique ne boucle que si son `.import` porte
`loop=true` : `scripts/gen-audio.py --loops` le pose, mais **après** le build qui
crée ces `.import`, et il faut donc rebuilder derrière pour que le réimport
prenne le changement — l'ordre est `build.sh` → `--loops` → `build.sh`. Et **le
mode smoke charge les sons sans les jouer** — sous le pilote
audio muet du headless, les lectures ne se terminent jamais et s'empilent
jusqu'à un « resources still in use at exit » qui masquerait une vraie erreur
dans `check.sh`.

## Police

Toute l'UI est rendue en **MedievalSharp** (SIL OFL, `assets/fonts/`), posée en
police par défaut du projet (`gui/theme/custom_font` dans `project.godot`) : un
seul réglage habille écran-titre, HUD, choix de pouvoir et écran de fin. Changer
de fonte décale la mise en page de `start_screen.gd`, donc les coordonnées de
clic de `tools/scenarios/ms2-gameplay.js` — les revérifier sur une capture.

La police par défaut de Godot **ne rend pas les emoji** : ne pas en mettre dans
l'UI (le HUD affiche des libellés courts pour cette raison).

## Version

L'écran-titre affiche `branche@hash-court` en bas à gauche
(`scenes/ui/start_screen.gd`, via `GameVersion.read()` dans `version.gd`). La
donnée vient de `godot/version.txt`, écrit par `scripts/gen-version.sh`
(`GITHUB_REF_NAME` si présent, sinon la branche git locale, `+` le hash court
de HEAD) — **non versionné**, comme `/export/` : la CI le régénère à chaque
déploiement, `scripts/build.sh` l'appelle avant l'import/export.

Deux pièges déjà rencontrés :

- **Un fichier `.gd` fictif n'aurait pas suffi.** Un premier essai encodait la
  version directement dans une constante GDScript regénérée à chaque build —
  mais ce fichier est versionné, donc le committer changerait le hash qu'il
  est censé décrire (problème de la poule et l'œuf). Le séparer en
  `version.txt` (donnée, gitignoré) + `version.gd` (logique de lecture,
  versionné) évite ça : le script ne modifie jamais un fichier suivi par git.
- **Un fichier texte brut n'est pas exporté par défaut.** Avec
  `export_filter="all_resources"` (`export_presets.cfg`), Godot n'embarque que
  les fichiers reconnus comme ressources (ceux avec un `.import`) — un `.txt`
  généré à la main en est absent tant qu'il n'est pas explicitement listé dans
  `include_filter`. Sans ça, `version.txt` compilait et s'exportait sans
  erreur mais n'atterrissait jamais dans le `.pck`, et l'écran-titre retombait
  silencieusement sur `"dev"` (le fallback de `GameVersion.read()` en
  l'absence du fichier).

Absent du `.pck` (éditeur, `play.sh` sans avoir lancé `gen-version.sh`),
l'écran-titre affiche `"dev"` au lieu de planter — même tolérance qu'ailleurs
dans le projet face à un asset manquant (voir `sprite_or_shape.gd`).
