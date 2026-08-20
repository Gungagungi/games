# games

Collection de petits jeux navigateur en HTML/CSS/JS pur — un dossier par jeu, sans dépendance ni étape de build.

| Jeu | Lancer | Description |
| --- | --- | --- |
| **Pong** | [`pong/index.html`](pong/index.html) | Le classique, en solo contre l'ordinateur ou à deux en local. |
| **Mecha Survivant** | [`mecha-survivant/mecha-survivant-4.html`](mecha-survivant/mecha-survivant-4.html) | Survie/roguelite en Canvas 2D : vagues d'ennemis, un pouvoir à choisir entre chaque vague, un boss toutes les 5 vagues. |

Chaque jeu s'ouvre directement dans un navigateur. Si `file://` pose problème (selon le navigateur), servir le dossier en local, par exemple avec `python3 -m http.server`.

> Mecha Survivant est un fichier HTML unique et autoportant, décliné en quatre itérations successives (`mecha-survivant.html` → `-4`) ; la dernière est la version courante.
