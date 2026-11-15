# Événements autour des vrais matchs

Certains vrais matchs sont des **fêtes** : derbys, Grand Choc, finales, demi-finales,
quarts de finale et grandes compétitions de sélections. Le jeu les repère tout seul dans
le calendrier du relais, sans rien à préparer à la main chaque semaine.

Logique : `scripts/jeu/evenements.gd` (sans affichage), branchée dans `Game`
(`evenement_de`, `etat_evenement`, `recompense_evenement`). Table des rivalités :
`data/evenements/rivalites.json`. Tests : `tests/test_evenements.gd` et
`res://tests/test_evenements_jeu.tscn -- --hors-ligne`.

## Ce que voit le joueur

- Sur la carte, une **pastille** sur le match (« Derby », « Finale », « Grand Choc »…) et un
  onglet **Fêtes** pour ne voir que les matchs spéciaux du niveau affiché.
- Dans la fiche du match, un **bandeau** : le nom de l'événement (« Derby de Milan »,
  « Soirée de finale »), ce qu'il rapporte et quand la fête commence.
- À la fin d'un duel (ambiance, Arène ou Poussée, hors ligne ou en ligne) : la ligne
  « Bonus Derby de Milan (×1,5) » et, au premier duel sur ce match, la « Prime de la soirée ».
- Une mission de la semaine, **Soirs de fête** : joue 2 duels sur des matchs spéciaux
  (proposée seulement quand le calendrier en contient).

## Comment un match devient une fête

Un match n'a qu'un événement principal, choisi dans cet ordre ; les autres raisons sont
rappelées dans le bandeau (« Et aussi : Derby de Madrid »).

| Événement | Repéré grâce à | Jetons des duels | Prime du 1er duel |
|---|---|---|---|
| Soirée de finale | tour « Final » (pas la petite finale) | ×2 | +400 XP PASS, +50 Jetons |
| Derby | même ville de stade et même pays (teams.json), ou la table | ×1,5 | +250 XP PASS, +30 Jetons |
| Demi-finale | tour « Semi-finals » | ×1,5 | +200 XP PASS, +25 Jetons |
| Grand Choc | la table, ou deux grands clubs (noms fictifs choisis à la main) en coupe continentale ou mondiale | ×1,4 | +200 XP PASS, +25 Jetons |
| Fête des nations | Mondial, Euro, Coupe des Amériques, Coupe d'Afrique, Ligue des Nations (pas les amicaux) | ×1,3 | +150 XP PASS, +20 Jetons |
| Quart de finale | tour « Quarter-finals » | ×1,25 | +100 XP PASS, +15 Jetons |

- **La ville du stade** vient du relais (`city` dans `teams.json`, relu chaque lundi).
  Le derby prend le nom de la ville en français : « Derby de Londres », « Derby d'Istanbul ».
- **La table** `data/evenements/rivalites.json` ajoute les derbys entre villes voisines
  (« Derby de la Ruhr », « Derby du Nord ») et les grands rivaux (« Grand Choc »). Elle sert
  aussi de secours quand la ville manque. Un mod peut ajouter `user://mods/rivalites.json`.
- **Jamais de nom officiel ni de marque** : seulement « Derby de » + un lieu, ou « Grand Choc ».
- Pas de fête pour un match reporté, annulé ou interrompu.

## Quand

La fête dure **de la veille du match (24 h avant le coup d'envoi) à 6 h après**. Avant,
la fiche affiche « La fête commence dans 2 j » ; après, « La fête est finie ». Ce n'est pas
une offre à durée limitée : rien ne s'achète, et un joueur qui rate un derby en retrouve
d'autres chaque semaine (PEGI 7, pas de connexion obligatoire).

## Économie

- Le bonus multiplie seulement les **Jetons** du duel ; l'XP du fan club ne change pas.
- La **prime** (XP de PASS + Jetons fixes) n'est versée qu'une fois par match.
  Les primes reçues sont gardées 10 jours dans la sauvegarde (`evenements.primes`).
- **Jamais de skin contre des Jetons.** Plus tard, un événement pourra offrir un skin
  gratuit, ou un palier du PASS, mais jamais en échange de Jetons.
- Les pronostics gardent leurs récompenses fixes (aucun bonus d'événement, pour rester
  loin de tout ce qui ressemble à une cote).

## Ajouter un événement

1. Un type dans `Evenements.TYPES` (titre, couleur, multiplicateur, prime) et sa place dans `ORDRE`.
2. Sa détection dans `Evenements.detecter`.
3. Un test dans `tests/test_evenements.gd`.
