# games

Collection de petits jeux navigateur en HTML/CSS/JS pur — un dossier par jeu, sans dépendance ni étape de build.

**Jouer en ligne : https://gungagungi.github.io/games/**

| Jeu | Lancer | Description |
| --- | --- | --- |
| **Pong** | [`pong/index.html`](pong/index.html) | Le classique, en solo contre l'ordinateur ou à deux en local. |
| **Mecha Survivant** | [`mecha-survivant/index.html`](mecha-survivant/index.html) | Survie/roguelite en Canvas 2D : vagues d'ennemis (morts-vivants, créatures de l'ombre, mobs de feu), un pouvoir à choisir entre chaque vague, un boss toutes les 5 vagues. |

Chaque jeu s'ouvre directement dans un navigateur. Si `file://` pose problème (selon le navigateur), servir le dossier en local, par exemple avec `python3 -m http.server`.

> Mecha Survivant est un fichier HTML unique et autoportant. Les itérations qui l'ont précédé sont figées dans [`mecha-survivant/archives/`](mecha-survivant/archives/).

## Développement

Les jeux n'ont besoin de rien : ouvrir le fichier HTML suffit. Pour les inspecter sur une machine sans écran, [`tools/`](tools/) capture un jeu dans un Chromium headless, image par image si besoin — voir [`tools/README.md`](tools/README.md).

## Mise en ligne

Le site est publié sur GitHub Pages par [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml), à chaque poussée sur `main`. Rien n'est construit : le dépôt est publié tel quel, `index.html` à la racine servant de portail vers les jeux.
