# games

Collection de petits jeux navigateur — un dossier par jeu. Tous sont en HTML/CSS/JS pur, sans dépendance ni étape de build, à l'exception de Mecha Survivant 2 qui est un projet Godot exporté en WebAssembly.

**Jouer en ligne : https://gungagungi.github.io/games/**

| Jeu | Lancer | Description |
| --- | --- | --- |
| **Pong** | [`pong/index.html`](pong/index.html) | Le classique, en solo contre l'ordinateur ou à deux en local. |
| **Mecha Survivant** | [`mecha-survivant/index.html`](mecha-survivant/index.html) | Survie/roguelite en Canvas 2D : vagues d'ennemis (morts-vivants, créatures de l'ombre, mobs de feu), un pouvoir à choisir entre chaque vague, un boss toutes les 5 vagues. |
| **Mecha Survivant 2** | [en ligne](https://gungagungi.github.io/games/mecha-survivant-2/) | Les mêmes mécaniques, refondues sous Godot 4 : rendu pixel art et bande-son en fichiers. Ne s'ouvre pas en `file://` — voir [`mecha-survivant-2/`](mecha-survivant-2/). |

Chaque jeu s'ouvre directement dans un navigateur. Si `file://` pose problème (selon le navigateur), servir le dossier en local, par exemple avec `python3 -m http.server`.

> Mecha Survivant est un fichier HTML unique et autoportant. Les itérations qui l'ont précédé sont figées dans [`mecha-survivant/archives/`](mecha-survivant/archives/). La v1 reste en place : la v2 est un jeu à part, pas un remplacement.
>
> Mecha Survivant 2 fait exception à tout ce qui précède : ses sources Godot sont dans [`mecha-survivant-2/godot/`](mecha-survivant-2/godot/), le jeu jouable est produit par `mecha-survivant-2/scripts/build.sh` et n'est pas versionné. Il se lance en local avec `mecha-survivant-2/scripts/serve.sh` puis <http://localhost:8123>, car un export Godot charge son `.pck` et son `.wasm` par requête réseau.

## Développement

Les jeux n'ont besoin de rien : ouvrir le fichier HTML suffit. Pour les inspecter sur une machine sans écran, [`tools/`](tools/) capture un jeu dans un Chromium headless, image par image si besoin — voir [`tools/README.md`](tools/README.md).

## Mise en ligne

Le site est publié sur GitHub Pages par [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml), à chaque poussée sur `main`. Le dépôt est publié tel quel — `index.html` à la racine sert de portail vers les jeux — après une seule étape de construction : l'export web de Mecha Survivant 2, que la CI produit avec Godot plutôt que de le versionner.
