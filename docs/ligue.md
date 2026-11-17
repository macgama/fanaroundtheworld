# Ligue des tribunes

Bouton **Ligue** en haut de la carte. Une **saison par mois** de duels en ligne entre fan clubs, avec divisions,
montées et descentes, calée sur les vrais week-ends de match.

## Comment on joue

1. **Saison = un mois.** Chaque week-end du mois (vendredi dans le mois) est une **journée**, du **vendredi 00:00
   au lundi 12:00 (UTC)**, comme le tournoi. 4 ou 5 journées par saison.
2. **5 divisions** : Ligue Espoir (5, départ), Bronze, Argent, Or, Étoile (1). Chaque division est faite de
   **poules de 10 clubs**. Les places libres sont prises par des **clubs du jeu** dont les points avancent tout seuls
   au fil des journées (même calcul dans le jeu et sur le serveur, sans aléatoire).
3. **Duel en ligne** (ambiance, Arène ou Poussée) contre un autre fan club, sur un **vrai match du week-end** :
   l'hôte tire un code de duel, les deux joueurs envoient leur résultat avec ce code, et le duel **compte quand les
   deux résultats concordent** (un gagnant et un perdant, ou deux perdants = nul). Deux « gagnants » : il ne compte
   pour personne. Un duel abandonné ne compte pas (l'autre n'envoie rien).
4. **Personne en ligne ?** On peut défier un club du jeu de sa poule depuis l'écran de la Ligue (3 par journée).
   Ces duels-là ne comptent pas pour le tournoi.
5. **Points** : victoire 3, nul 2, défaite 1, **+1 si le vrai match est en direct**.
   **6 duels par journée**, 2 au plus contre le même club.
6. **Fin du mois** : les 2 premiers de la poule montent, les 2 derniers descendent. Le mois suivant, on repart
   de sa nouvelle division (le serveur la calcule à l'inscription).

## Récompense de fin de saison (au moins 3 duels comptés)

| Division | Jetons | XP PASS |
|---|---|---|
| 1 · Ligue Étoile | 200 | 250 |
| 2 · Ligue Or | 150 | 200 |
| 3 · Ligue Argent | 110 | 160 |
| 4 · Ligue Bronze | 80 | 130 |
| 5 · Ligue Espoir | 50 | 100 |

Champion de poule : +100 Jetons. Montée : +50 Jetons. Jamais de skin. En ligne, le jeu attend le rang final du
serveur avant de verser.

## Code

- `scripts/jeu/ligue.gd` (classe `Ligue`) : calendrier, clubs du jeu, points, plafonds, montées, récompenses.
- `Game.ligue` (sauvegardé), `Game.noter_duel_ligue()` appelé en fin de duel par `duel.gd` et `FinDuel.enregistrer`,
  `Game.bot_ligue()` (duel contre un club du jeu : `Game.params["ligue_bot"]`).
- Réseau entre joueurs : le profil envoie l'identifiant public du classement (`fan`) et le nom de ligue (`lnom`),
  champs facultatifs ; « lancer » envoie le `code` du duel. Pas de changement de version du protocole.
- `EnLigne.synchroniser_ligue()` (toutes les 90 s) : rang final de la saison finie, inscription, résultats, état du
  club (duels confirmés). `EnLigne.rafraichir_ligue()` : la poule pour l'écran.
- `scenes/ligue/` : l'écran. Le salon affiche si le duel comptera pour la Ligue.
- Serveur : `src/ligue.js` du dépôt `macgama/fanaroundtheworld-data`, routes `/ligue/…` du Worker du live, même base
  SQLite que le classement (pas de nouvelle migration). **Il faut redéployer le Worker** ; avant ça, l'écran montre
  une poule d'entraînement et les duels en ligne restent « à confirmer ».

## Tests

```
godot --headless --path . --script tests/test_ligue.gd
godot --headless --path . res://tests/test_ligue_jeu.tscn -- --hors-ligne --maintenant=2026-11-21T15:00:00
godot --headless --path . res://tests/test_ligue_reseau.tscn -- --classement-url=http://localhost:8787/classement/ --maintenant=2026-11-21T15:00:00
```

`--maintenant=` fait comme si on était à ce moment (journée en cours). Le test réseau demande un Worker local décalé
d'autant : `cd worker && npx wrangler dev --var DECALAGE_TEST_S:<secondes>` (deux joueurs A et B, duel confirmé des
deux côtés, club du jeu, poule).

## Limites

- Les résultats viennent des jeux des joueurs : le serveur exige que les deux concordent, mais deux comptes d'un même
  tricheur pourraient s'arranger. Plus tard : compte Steam vérifié.
- Tant qu'il y a peu de joueurs, les poules sont surtout faites de clubs du jeu.
- Pas encore de recherche d'adversaire réservée à la Ligue : on passe par le salon habituel (Steam ou réseau local).
