# Classement en ligne

Bouton **Classement** en haut de la carte (avec ton rang de la semaine). Trois listes, chacune
**cette semaine** (remise à zéro le lundi, 00:00 UTC) ou **depuis le début** :

- **Fans** : les 50 meilleurs joueurs, avec leur équipe la plus soutenue. Si tu n'es pas dans le top, ta ligne est ajoutée en bas.
- **Clubs** et **Sélections** : les équipes qui ont reçu le plus de points, avec leur nombre de fans.

L'écran **Mes équipes** utilise les mêmes points (les autres supporters ne sont plus simulés dès que le serveur a répondu).

## Les points

Ce sont les points de popularité que tu donnes à tes équipes favorites (voir [equipes-favorites.md](equipes-favorites.md)) :
duels, matchs suivis, pronostics, récoltes du fan club. Les Jetons n'y sont pour rien et on ne peut rien acheter pour monter.

## Familial et sans données personnelles

- Le **nom de fan** est fait de deux mots choisis dans des listes du jeu et d'un numéro (« Tambour Joyeux 42 »).
  Le serveur ne reçoit que trois numéros : aucun texte libre, donc rien à modérer.
- L'identité est un identifiant et une clé secrète tirés au hasard (fichier `user://classement.json`, à part de la sauvegarde).
  Pas d'e-mail, pas de nom, pas de compte Steam pour l'instant.
- Case **Apparaître dans le classement des fans** : décochée, ton nom n'est pas affiché, mais tes points comptent toujours pour tes équipes.

## Comment ça marche

- `scripts/jeu/classement_fans.gd` : règles sans réseau (identité, pseudo, file d'envoi, points des autres).
- `scripts/autoload/en_ligne.gd` (autoload `EnLigne`) : envoie la file `Game.supporters.a_envoyer` toutes les 90 s,
  relit `equipes.json` toutes les 5 min, les fans à l'ouverture de l'écran. Hors ligne, la file attend.
- `Game.supporters.envoye` : points déjà comptés par le serveur, pour ne pas compter deux fois les tiens dans Mes équipes.
- `scenes/classement/` : l'écran.
- Serveur : le Worker Cloudflare du live (`macgama/fanaroundtheworld-data`, `src/classement.js`), stockage SQLite d'un
  Durable Object, offre gratuite. Il refait les contrôles du jeu : barème par action, 200 points par équipe et par jour,
  1 000 par fan et par jour, points de moins de 8 jours, un envoi toutes les 20 s au plus, 10 nouveaux fans par adresse et par jour.

## Tests

```
godot --headless --path . --script tests/test_classement.gd
godot --headless --path . res://tests/test_classement_jeu.tscn -- --hors-ligne
```

Avec un Worker local (`cd worker && npx wrangler dev` dans le dépôt de données) :
`res://tests/test_classement_jeu.tscn -- --classement-url=http://localhost:8787/classement/` fait un vrai envoi.

## Limites

- Pas encore d'anti-triche fort : un joueur qui modifie le jeu peut envoyer jusqu'au plafond chaque jour (200 points par équipe).
  Plus tard : relier l'identité au compte Steam (ticket d'authentification vérifié par le serveur, il faut le vrai App ID).
- Sauvegarde perdue = nouvelle identité (les anciens points restent aux équipes).
