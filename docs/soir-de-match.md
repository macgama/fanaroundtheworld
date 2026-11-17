# Soir de match

Vivre un vrai match en direct, but après but, avec sa tribune de FANZZY.

## Comment on y entre

- **Ta tribune** : le bouton rouge **SOIR DE MATCH** apparaît quand le match est en direct,
  à la mi-temps, ou commence dans moins de 30 minutes (`SoireeMatch.ouverte`).
  On garde le lieu choisi sur la carte : stade, écran géant, pub ou maison. Le décor, le
  son d'ambiance et le gain (×1,5 au stade … ×0,6 à la maison) suivent ce lieu.
- **Alerte « BUT ! »** : quand une équipe favorite marque (ou encaisse) pendant un match en
  direct, une alerte apparaît en haut de l'écran, où qu'on soit dans le jeu (sauf déjà
  dans un match). **Vivre le match** ouvre la soirée à la maison (gratuit).

Entrer dans la soirée compte comme « suivre le match » (missions, popularité), comme le
premier duel lancé depuis *Ta tribune*.

## Pendant le match

- Le score vient du relais (`live.json`, relu chaque minute par `Donnees`). L'écran compare
  chaque nouvelle lecture avec la précédente (`SoireeMatch.detecter`) : plusieurs buts
  d'un coup sont tous joués, un score qui baisse est un **but annulé** (arbitrage vidéo).
  Aucun changement du Worker n'a été nécessaire.
- La minute affichée avance toute seule entre deux lectures (au plus 3 minutes).
- **Ferveur** (0 à 100) : elle retombe doucement (sauf mi-temps et avant-match). Les
  réactions la relancent : **1** *Allez !*, **2** *Applaudir*, **3** *Écharpe* (chacune a un
  temps de recharge). Elle multiplie les gains du prochain but, de ×0,8 à ×1,2.
- **Fil des buts** à droite : minute, équipe, score. Gardé 3 jours (on peut revenir).

## À chaque but : la mini-ambiance

La tribune explose (ou encaisse), puis on a 10 secondes pour choisir :

| Touche | Mini-ambiance | Réussite |
|---|---|---|
| ESPACE | **Chant du club** : les 4 premières mesures du chant composé dans le créateur de chants (ou le chant par défaut), avec les paroles en karaoké | parfaits + 0,6 × biens, sur le nombre de notes |
| T | **Tifo** : 3 pans à lever ; maintenir T (ou le clic), relâcher dans la zone dorée | écart au centre de la zone, 0,3 ou plus = raté |
| O | **Ola** : 6 flèches en 6 secondes | flèches justes − ½ par erreur, petit bonus de vitesse |

Résultat en étoiles (0 à 3) ; le tifo se déploie, l'ola traverse la tribune.
Un but adverse ouvre **« Relève la tribune ! »** : même choix, gains divisés par deux.

## Gains (`SoireeMatch.recompense`)

- But pour ton équipe : Jetons = (6 + 10 × réussite) × gain du lieu × ferveur.
  XP du fan club 10 à 30, XP du PASS 20 à 50.
- But adverse : (3 + 5 × réussite) × gain du lieu × ferveur, XP divisées par deux.
- **Prime « soirée complète »** : présent au coup de sifflet final depuis au moins 30 min :
  10 Jetons × gain du lieu, 30 XP, 60 XP de PASS. Une fois par match.
- Exemple : 3 buts au stade avec de belles ambiances ≈ 60 à 80 Jetons pour la soirée.
- Mission de la semaine **« Soirs de match »** : vivre 3 buts avec une mini-ambiance.

Garde-fous :
- seuls les buts vus pendant la soirée comptent (le score à l'arrivée sert de départ) ;
- un but ne paie qu'une fois (clé = score juste après, « 2-1 ») : un but annulé puis
  redonné ne repaie pas ; au plus 6 buts payés par match ;
- rien sans mini-ambiance jouée : rester devant l'écran sans rien faire ne rapporte pas ;
- aucun Jeton n'est vendu ni misé ; aucun nom de joueur réel n'est affiché.

## Démo hors ligne

Sans réseau ni cache (matchs d'exemple) ou avec `--simuler`, des buts sont simulés toutes
les 25 à 45 s, sans gains. **B** / **N** y simulent un but pour toi / pour l'adversaire.
Pratique pour une démo Steam ou une vidéo.

    godot --path . -- --hors-ligne --scene=soiree --match=ex:1 --mode=pub --simuler

## Fichiers

- `scripts/jeu/soiree_match.gd` : règles (détection, gains, réussite, état sauvegardé).
- `scenes/soiree/soiree.gd` : l'écran (décor du duel `Duel.Decor`, FANZZY `Duel.Marionnette`,
  tifo `Duel.Banniere`, flèches `Duel.Fleche`, chant via `ChantLecteur`).
- `scripts/autoload/game.gd` : `soirees` (sauvegarde), `recompenser_but_soiree`,
  `prime_fin_soiree`, alerte des buts des équipes favorites.
- Tests : `tests/test_soiree.gd` (règles), `tests/test_soiree_jeu.tscn` (faux live, avec
  `--captures=dossier` pour des captures), écran `soiree` dans `tests/test_ecrans.gd`.
