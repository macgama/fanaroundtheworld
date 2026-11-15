# Collection : carnet de voyage et album des FANZZY

Écran `scenes/collection/` (clic sur le compteur de tampons, en haut à droite de la carte).
Règles sans écran dans `scripts/jeu/collection.gd` (classe `Collection`), état sauvegardé
dans `Game.collection`, tests : `godot --headless --path . --script tests/test_collection.gd`.

## Carnet de voyage

Aller voir un match **au stade** tamponne le stade du club qui reçoit (`Game.tampons`).
Le tampon garde maintenant le pays, le continent et la compétition.

| Série | Paliers | Prime (Jetons) |
|---|---|---|
| Stades différents | 1 · 5 · 10 · 25 · 50 · 100 | 20 · 50 · 100 · 200 · 400 · 800 |
| Pays visités | 2 · 5 · 10 · 20 | 40 · 120 · 250 · 500 |
| Continents | 2 · 3 · 5 | 100 · 200 · 500 |
| Championnat complet (tous les stades d'une ligue, liste du relais `teams.json`) | 1 par ligue | 15 par stade (ex. 18 clubs = 270) |

Seuls les paliers atteints et le suivant sont affichés, et seulement les ligues où tu as déjà un tampon.

## Album des FANZZY

Un FANZZY entre dans l'album quand il **joue un duel dans ta tribune** (duel d'ambiance,
Arène, Poussée, en ligne ou non : branché dans `Game.noter_duel_club()`).

| Série | Prime |
|---|---|
| Famille complète | 80 |
| Série du catalogue complète (La Tribune, Les Terraces…) | 60 |
| Album complet | 300 |

**Garde-robe** : chaque skin porté en duel est noté (ronds sous la carte du FANZZY).
Elle ne donne **jamais** de Jetons : les skins restent cosmétiques et viennent du PASS et des
événements, jamais des Jetons.

Chaque prime se réclame une seule fois, à la main (bouton jaune). La carte affiche « N primes ! »
à côté du compteur de tampons quand des primes attendent.
