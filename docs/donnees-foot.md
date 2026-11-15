# Données foot réelles (calendriers, résultats, live)

Le jeu ne contacte jamais API-Football directement. Les données sont récupérées par le relais du dépôt [macgama/fanaroundtheworld-data](https://github.com/macgama/fanaroundtheworld-data), qui publie des fichiers JSON communs à tous les joueurs.

| Fichier | Adresse | Mise à jour |
|---|---|---|
| Index (jours disponibles, mention de la source) | `https://macgama.github.io/fanaroundtheworld-data/index.json` | toutes les 3 h |
| Compétitions | `https://macgama.github.io/fanaroundtheworld-data/competitions.json` | toutes les 3 h |
| Matchs d'un jour (UTC) | `https://macgama.github.io/fanaroundtheworld-data/days/AAAA-MM-JJ.json` | toutes les 3 h |
| Live | `https://fanaroundtheworld-live.gael-manigley.workers.dev/live.json` | chaque minute pendant les matchs |

## Côté jeu (Godot)

- Au démarrage, charger `index.json`, puis les jours utiles.
- Pendant un match suivi, relire `live.json` toutes les 60 s au plus. Remplacer chaque match du jour par sa version live, avec le même `id`.
- Les noms réels des équipes (`home.name`, `away.name`) ne sont jamais affichés tels quels. Une table de correspondance par `home.id` et `away.id` donne les noms fictifs du jeu, que les mods Workshop peuvent remplacer.
- Afficher dans les crédits le texte du champ `attribution` de `index.json`.

Le format complet des données est décrit dans le README du dépôt de données.
