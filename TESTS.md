# Couverture de tests — état des lieux et pistes

Document d'analyse : ce que le dépôt vérifie aujourd'hui, ce qu'il ne vérifie
pas, et par quoi commencer. Rien ici n'est encore implémenté.

## Résumé

Le dépôt n'a **aucun test automatisé au sens strict** : pas de framework, pas de
suite, pas d'assertion. Ce n'est pas une anomalie — c'est un choix cohérent avec
« HTML/CSS/JS pur, sans dépendance ni étape de build ». Il existe en revanche
deux outils de vérification déjà écrits et déjà utiles :

| Outil | Ce qu'il fait | Ce qu'il ne fait pas |
| --- | --- | --- |
| `mecha-survivant-2/scripts/check.sh` | Joue 4 parties en accéléré, sans écran | N'assert rien : c'est un humain qui lit la sortie |
| `tools/capture.js` | Charge un jeu dans Chromium, capture, remonte les erreurs console | N'est lancé par personne automatiquement |

L'écart le plus rentable à combler n'est donc pas « écrire des tests » depuis
zéro, mais **transformer ces deux outils en vérifications qui échouent toutes
seules**, et les brancher sur la CI.

## Ce qui est couvert aujourd'hui

**`check.sh` (mecha-survivant-2)** joue quatre scénarios — vague 1, vague 5
(boss), vague 15 (méga-boss), Titan en phase finale — via le mode smoke de
`scenes/main.gd`. C'est une vraie couverture de bout en bout : spawns, vagues,
montée en tier, machines à états des boss, tirage des pouvoirs. Sur un jeu de
1 500 lignes de GDScript, c'est beaucoup de code réellement exécuté.

**`capture.js` (tous les jeux)** sort en code 1 si la page a produit une erreur
console. C'est un test de fumée déguisé, applicable à `pong/`, à
`mecha-survivant/` et à la page d'accueil.

## Les six angles morts

### 1. `check.sh` ne peut pas échouer sur une régression de gameplay

C'est le point le plus important. Le mode smoke imprime bien son bilan :

```
[smoke] terminé — vague atteinte : 7, ennemis vivants : 3
```

…mais **rien ne lit cette ligne**. `check.sh` filtre la sortie
(`grep -Ev '^Godot Engine|^$'`) et s'arrête là. Conséquences :

- Une régression qui bloque la progression des vagues (`wave_cleared` jamais
  émis, spawn cassé, boss invincible) laisse `check.sh` parfaitement vert : la
  partie dure ses 25 s simulées et se termine « normalement » à la vague 1.
- Une erreur GDScript d'exécution s'imprime dans la sortie mais ne change pas le
  code de sortie du script — elle n'est vue que si quelqu'un relit le terminal.

**Piste :** assertions minimales dans `check.sh`, sur la sortie déjà produite.

- Échouer si la sortie contient `SCRIPT ERROR`, `ERROR:`, `Attempt to call`,
  `resources still in use at exit`.
- Échouer si la ligne `[smoke] terminé` est absente (partie plantée avant la
  fin) ou si la vague atteinte n'a pas progressé d'au moins N vagues par rapport
  à la vague de départ.
- Pour `--titan`, faire imprimer au mode smoke un marqueur explicite (ultime
  lancé, phase atteinte) et l'exiger — c'est le scénario le plus fragile du jeu
  et celui dont `mecha-survivant-2/CLAUDE.md` documente déjà deux régressions
  passées (closure capturant `self`, barre traversée d'un trait).

Robustesse, au passage : `run()` fait passer la sortie dans `grep -Ev` sous
`set -euo pipefail`. Une partie dont **toute** la sortie serait filtrée fait
sortir `grep` en 1, donc échouer le script — un faux négatif possible. Un
`|| true` sur le filtre, ou un filtre en `sed`, lève l'ambiguïté.

### 2. Les runs ne sont pas déterministes

`main.gd::_ready()` appelle `randomize()` sans condition. Le mode smoke tire donc
des positions de spawn, des types d'ennemis et des pouvoirs différents à chaque
exécution. Aujourd'hui c'est sans conséquence (rien n'est asserté) ; dès qu'on
assert, ça devient de la flakiness.

**Piste :** `--seed=N` en mode smoke (`seed(n)` plutôt que `randomize()`), et une
graine fixe dans `check.sh`. Bonus : un échec devient reproductible à
l'identique, ce qui vaut cher sur un jeu qu'on ne peut pas regarder tourner.

### 3. Aucune vérification n'est branchée sur la CI

`.github/workflows/deploy-pages.yml` est le seul workflow : il se déclenche sur
`push` vers `main`, installe Godot, exporte, publie. Il ne lance **ni**
`check.sh` — alors qu'il a déjà Godot installé et en cache, à trois lignes près —
ni la moindre vérification sur les jeux JS. Une branche peut casser Pong ou la
page d'accueil et être mise en ligne sans un signal.

**Piste :** un workflow `verify.yml` sur `pull_request` :

- `check.sh` (réutilise le cache Godot du workflow de déploiement) ;
- `capture.js` sur `index.html`, `pong/index.html`, `mecha-survivant/index.html`,
  qui échoue déjà tout seul sur erreur console ;
- éventuellement le job d'export en dry-run, pour ne pas découvrir un build
  cassé au moment de publier.

C'est le changement au meilleur rapport valeur/effort du lot : les outils
existent, il ne manque que l'appel.

### 4. Zéro test unitaire possible sur les jeux JS, faute de frontière

`pong/game.js` et `mecha-survivant/index.html` sont écrits entièrement en portée
globale, avec `canvas`/`ctx` résolus au chargement. Rien n'est exportable, donc
rien n'est testable hors navigateur — même des fonctions parfaitement pures :

- `paddleCollision()`, la déviation selon le point d'impact et l'accélération de
  1,05 à chaque renvoi, le rebond haut/bas, `checkWin()` (Pong) ;
- `isBossLevel()`, `5 + n*2`, `floor((n-1)/2)`, `clamp(50 - n*1.5, 14, 50)`,
  les tables de stats et `ALL_UPGRADES` (Mecha Survivant).

Ce sont exactement les endroits où une régression est silencieuse : le jeu
tourne, il est juste devenu injouable ou trivial.

**Piste, sans trahir la contrainte « aucune dépendance » :** exposer la logique
pure sans la déplacer hors du navigateur. Par exemple, en fin de `game.js` :

```js
if (typeof module !== "undefined") module.exports = { paddleCollision, checkWin, /* … */ };
```

…et des tests en `node:test` (livré avec Node, zéro dépendance installée), dans
`tools/` qui a déjà un `package.json`. Le jeu continue de s'ouvrir en `file://`
sans rien savoir de tout ça.

Pour `mecha-survivant/index.html`, l'extraction est plus coûteuse et
`CLAUDE.md` interdit explicitement de l'éclater en fichiers séparés. L'angle
réaliste y est plutôt le n°6 (parité) et le pilotage image par image.

### 5. La parité v1 ↔ v2 n'est vérifiée par rien

`mecha-survivant-2` annonce des mécaniques « reprises telles quelles » de la v1.
C'est vrai aujourd'hui, et vérifiable à la main :

| Grandeur | v1 (px/frame) | v2 (px/s) |
| --- | --- | --- |
| Zombie, vitesse | `0.65 + tier*0.08` | `39.0 + tier*4.8` |
| Squelette, vitesse | `1.3 + tier*0.1` | `78.0 + tier*6.0` |
| Ennemis par vague | `5 + n*2` | `5 + n*2` |
| Tier | `floor((n-1)/2)` | `(wave - 1) / 2` |

Rien n'empêche un réglage d'un seul côté. Le jour où ça arrive, les deux jeux
divergent en silence et le tableau ci-dessus devient faux sans que personne le
sache.

**Piste :** un script de comparaison qui lit les constantes des deux sources
(`EnemyStats.DEFS` côté GDScript, les `makeXxx()` côté v1) et vérifie le facteur
60. C'est du parsing de texte, un peu ingrat, mais c'est le seul garde-fou
possible sur une promesse que le dépôt écrit noir sur blanc dans trois fichiers.

Variante moins ambitieuse et déjà utile : figer les valeurs attendues dans un
fichier de référence et vérifier les deux sources contre lui.

### 6. Le harnais visuel est fragile là où il est le plus utile

`tools/scenarios/ms2-gameplay.js` clique par **coordonnées en dur** (`cx = 500`,
`PLAY_Y = 377`…) parce que l'UI de Godot est peinte dans le canvas. `CLAUDE.md`
prévient qu'un changement de `start_screen.gd` oblige à les réajuster — mais rien
ne le détecte : un clic à côté produit une capture de l'écran-titre, sans erreur
console, et le scénario sort en succès.

Symétriquement, `main.gd::_expose_debug_bridge()` annonce en commentaire
« on expose donc des commandes appelables depuis Chromium headless », mais ne
pose qu'un booléen `window.godotDebugReady`. Le pont existe, il est vide.

**Piste :** étoffer ce pont (vague courante, PV du boss, phase, « partie en
cours ») et faire échouer le scénario si l'état attendu n'est pas atteint dans
un délai. On gagne deux choses d'un coup : des scénarios qui détectent leur
propre décalage, et la possibilité d'assertions de gameplay côté web, pas
seulement côté headless Godot.

Dans le même esprit, la vérification des planches de sprites décrite dans
`mecha-survivant-2/CLAUDE.md` (compter les cases réellement distinctes) est un
extrait Python à copier-coller. C'est un test — il a déjà attrapé les cinq
planches de boss dupliquées — qui gagnerait à devenir un script appelable, avec
la cohérence `SHEETS` ↔ `MANIFEST.md` ↔ fichiers présents.

## Par où commencer

Dans cet ordre — le coût monte, la valeur marginale baisse :

1. **Assertions dans `check.sh`** (§1). Une heure de travail, transforme le seul
   test existant en test qui échoue vraiment.
2. **Workflow de vérification en CI** (§3). Les outils existent déjà ; il manque
   l'appel et un `on: pull_request`.
3. **Graine fixe en mode smoke** (§2). Prérequis pour que 1 et 2 ne deviennent
   pas flaky.
4. **`node:test` sur la logique pure de Pong** (§4). Petit périmètre, sert de
   patron pour tout jeu Canvas à venir.
5. **Pont de débogage et scénarios qui s'auto-vérifient** (§6).
6. **Parité v1 ↔ v2** (§5). Le plus ingrat, mais le seul filet sous une promesse
   affichée partout.

## Ce qu'il ne faut sans doute pas faire

- **Introduire un framework de test lourd** (Jest, Vitest, GUT). La contrainte
  « aucune dépendance » est structurante ici ; `node:test` et un `check.sh` qui
  assert couvrent le besoin réel.
- **Viser une couverture de lignes.** Sur du jeu, la moitié du code est du rendu
  dont le seul oracle est l'œil. Les captures y répondent mieux qu'une
  assertion.
- **Tester le rendu au pixel près.** Trop fragile pour ce dépôt : la moindre
  retouche de sprite ou de police invaliderait la référence.
