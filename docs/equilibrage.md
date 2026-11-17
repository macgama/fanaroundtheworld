# Équilibrage : Jetons, cartes de la Poussée, niveau et PASS

Premier passage d'équilibrage, le 17 nov. 2026. Deux outils, à relancer après chaque
changement de règle :

- `python3 tools/equilibrage/modele_economie.py` (`--avant` pour les anciens réglages) :
  trois joueurs moyens jouent une saison du PASS (1er août → 30 mai) ; Jetons gagnés par
  source, dépenses, niveau du fan club, paliers du PASS.
- `godot --headless --path . res://tools/equilibrage/simuler_poussee.tscn -- --hors-ligne`
  (`--duels=N --parties=N`) : duels de cartes à Ferveur égale, puis parties complètes
  IA contre IA.

Règles de Gaël respectées : Jetons gagnés en jouant pour billets, trajets et équipement ;
actions de duel débloquées par le niveau, jamais par les Jetons ; skins jamais contre des
Jetons ; même match rejoué : 100 %, 50 %, 25 %, puis 0 le reste du jour ; pronostics sans mise.

## Ce qui n'allait pas

| Constat (avant) | Chiffre du modèle |
|---|---|
| Le fan club rapportait presque tout | 75 % des Jetons d'un joueur régulier (1 h par jour), ≈ 2 000 Jetons par jour |
| Un joueur régulier finissait le PASS en 3 mois | palier 100 au jour 85 (28 % de la saison) ; un passionné au jour 39 |
| Niveau du fan club : plus rien à gagner après une semaine | niveau 25 au 5e jour pour un joueur régulier ; tout se débloque au niveau 6 |
| Arène et Poussée payaient moitié moins par minute que le duel d'ambiance | 17 Jetons/min (ambiance), 10 (Arène), 8 (Poussée) |
| Petit Tambour trop fort, Chorale trop faible | à Ferveur égale : Tambour +17 points, Chorale −19 (tableau plus bas) |
| Petits boulots : 15 parties à plein tarif par jour (3 par boulot) | plus rentables par minute que les duels, sans billet |
| Voyages lointains bon marché | l'autre bout du monde : 80 × 1,5 = 120 Jetons de trajet au plus |

## Ce qui a changé

| Où | Avant | Après |
|---|---|---|
| Cotisation (`FanClub.COTISATION_HEURE`) | 1 Jeton/h par membre | 0,25 |
| Bonus de taille (`BONUS_PAR_MEMBRE`) | +5 % par membre | +2 % |
| Buvette du local (Jetons/h, niv. 1 → 5) | 3, 6, 10, 15, 21 | 1, 1,5, 2, 3, 4 |
| Atelier (écharpes/h, niv. 1 → 5) | 1, 2, 3, 4, 6 | 0,5, 0,75, 1, 1,25, 1,5 |
| Prix d'une écharpe | 2 + 1 par 3 membres | 1 + 1 par 6 membres |
| Stock d'écharpes | 6 + 6 par niveau d'atelier | 6 + 4 par niveau |
| Prix des améliorations du local | inchangés (3 180 Jetons en tout) | |
| Places du fan club | 3 + 2 par niveau | 3 + 2 par niveau jusqu'au niveau 5, puis 1 par niveau |
| XP par niveau du fan club (`Game.xp_pour_niveau`) | 200 à chaque niveau | 200 jusqu'au niveau 6 (démo et déblocages inchangés), puis +100 à chaque niveau |
| Jetons d'Arène / de Poussée (`FinDuel.FACTEUR_JEU`) | ×1 | ×1,3 / ×1,6 |
| Petits boulots (`ListeBoulots.part_du_jour`) | plein tarif 3 parties par boulot, puis ÷ 2 | plein tarif 2 parties, ÷ 2 jusqu'à la 5e, puis ÷ 4 |
| Billet au stade | 20 | 25 |
| Trajet (`Deplacement.cout_base`) | distance / 120 + 5, plafond 80 | distance / 80 + 5, plafond 150 |
| XP de PASS d'un duel | 50 + 25 perf + 25 victoire | 12 + 6 perf + 6 victoire |
| XP de PASS : nouveau stade, prono juste / exact | 200 ; 30 / 100 | 100 ; 15 / 50 |
| XP de PASS : missions, primes d'événement, tournoi, Ligue, soirs de match | | toutes ÷ 2 |
| XP de PASS à l'arrivée d'un déplacement | ferveur × 2 | ferveur |
| Cartes de la Poussée | voir plus bas | |

Ce qui ne change pas : les Jetons des duels d'ambiance, le rejeu 100/50/25/0, les
pronostics, les primes de collection, les Jetons du PASS, les 1 000 XP par palier.

## Les trois joueurs du modèle

Joueur moyen : 50 % de réussite, 55 % de victoires. Les profils (nombre de duels, de
boulots, de récoltes, de stades) sont dans `PROFILS`.

| | Occasionnel (20 min, 5 j/7) | Régulier (1 h, 6 j/7) | Passionné (3 h, 7 j/7) |
|---|---|---|---|
| Jetons par jour joué, avant → après | 1 268 → 519 | 2 620 → 1 077 | 4 292 → 1 898 |
| Part du fan club, avant → après | 77 % → 40 % | 75 % → 33 % | 67 % → 22 % |
| Local au maximum | 7e → 11e jour | 3e → 5e jour | 2e → 3e jour |
| Niveau 10 du fan club | 5e → 9e jour | 2e → 3e jour | 1er jour |
| Niveau 25 (succès) | 16e → 75e jour | 5e → 25e jour | 2e → 8e jour |
| PASS après 1 mois | palier 14 → 8 | 36 → 13 | 77 → 27 |
| PASS en fin de saison | 100 au jour 217 → palier 78 | 100 au jour 85 → 100 au jour 231 (avril) | 100 au jour 39 → 100 au jour 112 (fin novembre) |

Jetons par minute de jeu (joueur moyen, au pub, billet déduit, menus compris) :

| | Avant | Après |
|---|---|---|
| Duel d'ambiance (1 min 30) | 16,9 | 16,9 |
| Arène (2 min) | 10,4 | 14,0 |
| Poussée (3 min) | 8,2 | 13,9 |
| Petit boulot, plein tarif / ensuite | 18,7 / 9,3 | 18,7 (2 parties par boulot) / 9,3, puis 4,7 |

Le duel d'ambiance garde un peu d'avance : sa part « performance » monte plus haut
(un duel parfait rapporte plus), c'est le mode phare.

## Cartes de la Poussée

### Duels à Ferveur égale

Chaque case : un groupe de la carte de la ligne contre un groupe de la carte de la colonne,
pour le même budget de Ferveur (12, 15, 18, 20), sans ballon, 20 s, chaque camp à gauche
puis à droite. Valeur : % de la Ferveur posée encore debout, ligne / colonne. Bilan :
écart moyen ; une carte équilibrée est proche de 0. La Mascotte (elle ne vise que la
tribune) et les effets (Fumigène, Ola) ne se mesurent pas ainsi.

Avant :

| | Tambour | Drapeau | Serpentins | Chorale | Canon | Bilan |
|---|---|---|---|---|---|---|
| Tambour | 7/7 | 28/0 | 35/0 | 31/2 | 0/6 | **+17** |
| Drapeau | 0/28 | 25/25 | 35/0 | 32/0 | 5/1 | +9 |
| Serpentins | 0/37 | 0/35 | 3/3 | 24/5 | 0/11 | −13 |
| Chorale | 1/32 | 0/32 | 5/23 | 4/5 | 0/10 | **−19** |
| Canon | 8/0 | 2/5 | 11/0 | 10/0 | 33/33 | +6 |

Changements : Petit Tambour 70 → 65 d'entrain et 12 → 11 de puissance ; Lanceur de
serpentins 75 → 95 d'entrain et 14 → 16 de puissance ; Chorale 55 → 70 d'entrain par
chanteur. Après (24 essais par case) :

| | Tambour | Drapeau | Serpentins | Chorale | Canon | Bilan |
|---|---|---|---|---|---|---|
| Tambour | 7/7 | 9/6 | 11/3 | 9/20 | 0/10 | −2 |
| Drapeau | 5/9 | 25/25 | 6/0 | 19/6 | 5/1 | +4 |
| Serpentins | 2/11 | 0/6 | 7/7 | 11/10 | 0/6 | −4 |
| Chorale | 20/10 | 6/19 | 11/11 | 3/4 | 0/6 | −2 |
| Canon | 9/0 | 1/5 | 6/0 | 6/0 | 33/33 | +4 |

Le Porte-Drapeau garde un petit avantage en duel, mais il chante peu fort contre la
tribune ; c'est le pousseur de ballon. Les coûts en Ferveur ne changent pas.

### Parties complètes IA contre IA

100 parties par ligne : un jeu privé d'une carte (à gauche) contre le jeu complet, IA des
deux côtés. Si retirer la carte fait perdre, elle compte ; si ça fait gagner, l'IA la joue
mal. Le témoin (jeu complet contre jeu complet) montre le bruit : environ ±7 points.

| Jeu sans… | Victoires avant | Victoires après |
|---|---|---|
| (témoin) | 51 % | 44 % |
| Petit Tambour | 30 % | 45 % |
| Porte-Drapeau | 28 % | 35 % |
| Lanceur de serpentins | 26 % | 19 % |
| Chorale | 32 % | 33 % |
| Mascotte géante | 23 % | 24 % |
| Canon à confettis | 67 % | 75 % |
| Fumigène | 58 % | 50 % |
| Ola | 48 % | 38 % |

Le Petit Tambour n'est plus la carte indispensable. Deux défauts restent, qui viennent de
l'IA et pas des cartes : elle place mal le Canon (le retirer la fait gagner) et ne joue
l'Ola et le Fumigène qu'en défense. Le Lanceur de serpentins pèse lourd en partie
complète parce qu'il chante aussi contre la tribune de loin ; à surveiller quand l'IA
sera revue.

## Ce qui reste à faire

- **Les Jetons s'accumulent encore** : un joueur régulier gagne ≈ 1 000 Jetons par jour et
  en dépense ≈ 60 en billets et trajets (dans le modèle, il va au stade 4 fois par
  semaine) ; le local est payé en 5 jours. Il manque des achats d'« équipement » prévus
  au GDD (écharpes, drapeaux, tambours…), qui ne doivent être ni des skins ni un avantage
  en duel. Question posée à Gaël.
- Mesurer les vraies réussites des joueurs (les profils sont des estimations) : nombre de
  duels par session, réussite moyenne, durée des menus.
- L'IA de la Poussée ne joue jamais l'Ola en attaque et peu le Fumigène : à revoir avec
  le chantier « joueurs contrôlés par l'ordi ».
- Arène : pas encore de banc d'essai (les supers par famille ne sont pas comparés).
