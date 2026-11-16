# Missions du jour et de la semaine

Bouton **Missions** en haut de la carte (il passe au vert avec le nombre de
récompenses prêtes). Logique : `scripts/jeu/missions.gd`, écran :
`scenes/missions/`, tests : `tests/test_missions.gd` et `tests/test_missions_jeu.tscn`.

## Règles

- **3 missions du jour**, renouvelées à minuit (heure du joueur), et
  **3 missions de la semaine**, renouvelées le lundi à minuit.
- Le tirage dépend seulement de la date : même jour, mêmes missions, jamais
  deux missions sur le même geste quand c'est possible.
- Les missions « fan club » et « équipe favorite » ne sont proposées qu'aux
  joueurs qui ont créé leur club ou choisi un favori.
- Chaque mission rapporte des **Jetons** et de l'**XP de PASS**, à récupérer
  avec le bouton *Récupérer*. Les 3 missions récupérées donnent un bonus
  (jour : +10 Jetons, +50 XP ; semaine : +50 Jetons, +250 XP).
- Une mission du jour pas encore terminée peut être **changée une fois par jour**.
- **Pas de connexion obligatoire** (PEGI 7) : une mission terminée mais oubliée
  est versée automatiquement au renouvellement, et les missions de la semaine
  rapportent le plus, pour qu'un joueur qui passe une ou deux fois par semaine
  avance quand même.

## Barème et PASS

| | Jetons | XP de PASS |
|---|---|---|
| Mission du jour | 10 à 25 | 50 à 75 |
| Mission de la semaine | 50 à 90 | 200 à 300 |

Le PASS compte 100 paliers de 1 000 XP (`Game.xp_pass`, sauvegardé), d'août
à fin mai. Avec les seules missions, un joueur qui vient tous les jours gagne
environ 2 300 XP par semaine, un joueur du week-end environ 1 300 : les
missions font à peu près la moitié du chemin sur la saison, le reste vient
des duels, des nouveaux stades et des pronostics justes (voir `docs/pass.md`).
Pendant le **rattrapage** du PASS (joueur en retard sur le rythme de la saison),
l'XP des missions est doublée.

## Ce qui fait avancer les missions

| Événement | Où | Exemples |
|---|---|---|
| `suivre` (clé = stade, ecran, pub, maison) | arrivée au stade, ou premier duel lancé depuis *Ta tribune* ; un même match ne compte qu'une fois | Suis 3 matchs, Abonné du virage |
| `suivre_pays` (clé = pays) | idem | Tour du monde (3 pays différents) |
| `nouveau_stade` | premier tampon d'un stade | Visite un nouveau stade |
| `duel_joue` / `duel_gagne` (clé = duel, arene, poussee) | fin de partie, hors ligne et en ligne | Gagne un duel, Touche-à-tout |
| `prono` | nouveau pronostic (pas une modification) | Fais 2 pronostics |
| `prono_bon` | pronostic résolu avec le bon résultat | Devin de la semaine |
| `buvette` | service de vendeur terminé | Pilier de la buvette |
| `recolte` | caisse du fan club récoltée | Trésorier du club |
| `favori` | une équipe favorite gagne des points | Soutiens tes couleurs |
| `evenement` (clé = finale, derby, demi, choc, nations, quart) | duel joué pendant un événement (voir `docs/evenements.md`) | Soirs de fête |

Ajouter une mission : une ligne dans `Missions.JOUR` ou `Missions.SEMAINE`.
Ajouter un événement : un appel `Game.noter_mission("evt", "clé")` là où il se produit.
