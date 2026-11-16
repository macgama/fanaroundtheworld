# Tournoi des fan clubs du week-end

Bouton **Tournoi** en haut de la carte (et dans le fan club). Chaque week-end, du **vendredi 00:00 au lundi 12:00 (UTC)**,
les fan clubs des joueurs s'affrontent sur les vrais matchs du week-end.

## Comment on joue

1. **Inscription** (gratuite, il faut un fan club) : un nom de tournoi fait de deux mots des listes du jeu
   (« Kop du Tonnerre ») et deux couleurs. Pas de texte libre : le classement reste familial sans modération.
2. Chaque **duel contre l'ordinateur** (ambiance, Arène ou Poussée) joué sur un **match du week-end** compte comme un duel
   contre un autre fan club. Le serveur tire l'adversaire parmi les clubs inscrits (le moins attaqué, de niveau proche) ;
   sans réseau ou sans club libre, c'est un « club du jeu ». Son nom remplace « Tribune X » en haut du duel.
3. **Points** : victoire 3, défaite 1, +1 au stade, +1 sur un match spécial (derby, finale, Grand Choc…).
4. **7 duels au plus**, chacun sur un match différent et contre un club différent.
   Rejouer un match ne rapporte aucun point de tournoi, et ses Jetons suivent la règle des matchs rejoués (100 %, 50 %, 25 %, puis 0).
5. **Tribune solide** : quand un club perd contre le tien, +1 point (6 au plus par week-end).
6. Les duels en ligne contre un vrai joueur ne comptent pas (ils ont leur salon).

## Récompenses (le lundi, bouton « Récupérer »)

| Points | Palier | Jetons | XP PASS |
|---|---|---|---|
| 5 | Tribune engagée | 30 | 100 |
| 12 | Tribune solide | 60 | 200 |
| 20 | Tribune en feu | 100 | 300 |
| 28 | Tribune de légende | 150 | 400 |

Bonus de classement, seulement s'il y a au moins 10 clubs classés : 1er +150, 2e +100, 3e +75, top 10 +40, top 25 % +20 Jetons.
En ligne, le jeu attend le rang final avant de verser. Hors ligne, seul le palier compte.
Mission de la semaine « Esprit de compétition » : 3 duels de tournoi (60 Jetons, 300 XP PASS).

## Code

- `scripts/jeu/tournoi.gd` (classe `Tournoi`) : règles sans écran ni réseau (fenêtre, duels, récompenses, clubs du jeu).
- `Game.tournoi` (sauvegardé) ; `Game.noter_duel_tournoi()` appelé en fin de duel par `duel.gd` et `FinDuel.enregistrer`.
- `EnLigne.synchroniser_tournoi()` : inscription, résultats en attente, tirage de l'adversaire, rang (toutes les 90 s).
- `scenes/tournoi/` : l'écran (ton club, classement, matchs du week-end, tes duels, règles).
- Serveur : `src/tournoi.js` du dépôt `macgama/fanaroundtheworld-data`, routes `/tournoi/…` du Worker du live,
  même base SQLite que le classement. **Il faut redéployer le Worker** pour que le tournoi passe en ligne ;
  avant ça, le jeu joue contre les clubs du jeu (classement d'entraînement).

## Tests

```
godot --headless --path . --script tests/test_tournoi.gd
godot --headless --path . res://tests/test_tournoi_jeu.tscn -- --hors-ligne
godot --headless --path . res://tests/test_tournoi_reseau.tscn -- --classement-url=http://localhost:8787/classement/
```

Le dernier demande un Worker local (`cd worker && npx wrangler dev`) et un week-end en cours ; sinon il ne fait rien.

## Limites

- Résultats calculés par le jeu (comme le reste) : le serveur recalcule les points et limite les duels, mais ne vérifie pas
  que le match existe ni qu'il a été gagné. Plus tard : compte Steam vérifié.
- Le club adverse est joué par l'ordinateur avec la difficulté habituelle (son niveau n'y change rien pour l'instant).
