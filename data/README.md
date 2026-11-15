# Données du jeu

Données au format JSON, lues par le jeu au démarrage.

- `carte/pays.json` : pays (nom français, capitale, continent) et lien compétition → pays ou continent.
- `carte/formes.json` : contours des pays (Natural Earth 1:50m, domaine public).
  Les deux fichiers sont générés par `tools/prepare_pays.py`.
- `clubs/noms_fictifs.json` : noms fictifs choisis à la main, par identifiant d'équipe.
  Les autres clubs reçoivent un nom inventé automatiquement (toujours le même).
  Un mod peut ajouter `user://mods/noms_fictifs.json` (même format).
- `exemple/matchs.json` : 16 matchs d'exemple, utilisés seulement sans réseau ni cache.

Les vrais matchs viennent du relais `macgama/fanaroundtheworld-data` (voir `docs/donnees-foot.md`).
