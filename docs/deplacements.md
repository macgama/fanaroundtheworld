# Déplacements à l'extérieur

Pour suivre un vrai match **au stade**, le fan club n'arrive plus par magie : il
organise son déplacement. Règles : `scripts/jeu/deplacement.gd` (classe
`Deplacement`, sans écran, testée par `tests/test_deplacement.gd`). Écran :
`scenes/deplacement/`.

## Déroulé

1. **Fiche du match** (carte) → « Au stade » → **ORGANISER LE DÉPLACEMENT**
   (à partir de 30 km ; plus près, on va directement au stade).
2. **Organiser** : le convoi (les membres du fan club, au moins les 3 FANZZY de
   la tribune), le transport, l'itinéraire. Le prix s'affiche ; on paie au
   départ (billet 20 + trajet). Retour possible tant qu'on n'est pas parti.
3. **En route** : le convoi avance sur la carte et s'arrête à chaque événement.
   2 ou 3 choix (clic ou touches 1, 2, 3). La ferveur monte ou baisse, et
   certains choix font perdre du temps.
4. **Arrivée** : bilan (ferveur, à l'heure ou pas, prime), puis le tampon du
   stade comme avant, et « Ta tribune ».

## Transports et itinéraires

| Transport | Vitesse | Prix | Distance | Ferveur au départ | Événements |
|---|---|---|---|---|---|
| Car du fan club | 75 km/h | ×0,8 | jusqu'à 2 500 km | +10 | +1 |
| Train des supporters | 170 km/h | ×1,25 | jusqu'à 2 200 km | +5 | — |
| Vol charter | 750 km/h (+1 h 30) | ×1,5 | dès 800 km | — | — |

| Itinéraire | Distance | Prix | Durée | Événements |
|---|---|---|---|---|
| Direct | ×1 | ×1 | ×1 | 1 |
| Petites routes / Trains régionaux | ×1,12 | ×0,6 | ×1,45 | 2 |
| Route panoramique / Ligne touristique | ×1,3 | ×1,1 | ×1,2 | 2 + l'étape |

L'avion ne fait que du direct. Prix de base = ancien barème du trajet
(`distance / 120 + 5`, entre 5 et 80), minimum 3 Jetons.

**Cagnotte du club** : -3 % sur le trajet par membre au-delà de 3, jusqu'à -30 %.
La fiche du match affiche « dès X » (trajet le moins cher).

**Étape** de la balade : la ville d'un club connu (ou une capitale) proche du
milieu du trajet, un peu à l'écart de la route ; sinon « Halte panoramique ».

## Ferveur du convoi (0 à 100)

- Départ : 20 + transport + 3 par FANZZY (max +24) + 5 par FANZZY de la famille
  Déplacement (max +15) + 8 si on soutient l'équipe qui joue à l'extérieur.
- Événements : de -4 à +22 selon le choix. 16 événements + l'étape, tirés
  d'après le match, le transport, l'itinéraire et le jour.
- Certains choix demandent un FANZZY d'une famille dans le convoi (Voix,
  Percussion, Tifo, Fidélité, Déplacement) : recruter varié ouvre de
  meilleurs choix. Il reste toujours un choix possible pour tout le monde.
- Retard de plus de 60 min : arrivée pile au coup d'envoi, -10 de ferveur.

## Récompenses à l'arrivée

- Jetons : ferveur / 4 (+ Jetons gagnés en route : quiz, radio, carte postale…).
- XP du PASS : ferveur × 2. XP du fan club : 20 + ferveur / 5.
- **Bonus des duels** : les Jetons des duels de ce match, le jour même, sont
  multipliés par ×1,00 à ×1,20 selon la ferveur (ligne « Ferveur du
  déplacement » dans le panneau de fin, dans les trois modes). Le bonus
  s'applique après la règle du match rejoué (100 / 50 / 25 %).

Jamais de Jetons perdus en route, jamais de skin : uniquement Jetons et XP.

## Tests et démo

- `godot --headless --path . --script tests/test_deplacement.gd`
- Écrans « deplacement » et « voyage_bilan » dans `tests/test_ecrans.tscn`.
- Démo : `-- --scene=deplacement --match=ex:1 --camp=away --auto --depuis=4.85,45.76`
  (`--depuis=lon,lat` change le point de départ du fan club, `--auto` part en
  balade et choisit tout seul).

## Plus tard

- Déplacement en ligne à plusieurs fan clubs (même convoi, vote des choix).
- Mission de la semaine « Faire 2 déplacements » et succès Steam associé
  (le compteur `stats["deplacement"]` existe déjà).
