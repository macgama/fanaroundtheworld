# À quoi servent les Jetons

Demande de Gaël (18 nov. 2026) : « Il faut des ajouts pour que le joueur puisse profiter de
ses Jetons. » Cinq ajouts, faits dans l'ordre choisi par Gaël. Règles communes :

- tout s'achète avec des Jetons gagnés en jouant, jamais avec de l'argent réel ;
- rien ne change un duel (jauge, points, Poussée) : c'est du décor ou du voyage ;
- ce ne sont **pas des skins de FANZZY** (ceux-là restent au PASS et aux événements) ;
  Gaël a validé que les objets du club (matériel, décor du local, souvenirs) s'achètent en Jetons ;
- les tampons achetés avec un Grand Tour ne donnent ni XP de PASS ni mission : le PASS se
  gagne en jouant, pas en Jetons.

## 1. Boutique souvenirs et vitrine du club

`scripts/jeu/souvenirs.gd`, onglet « Vitrine du club » de la Collection, bouton
« BOUTIQUE SOUVENIRS » à l'arrivée au stade.

| Souvenir | Sur place | Par correspondance |
|---|---|---|
| Fanion | 15 | 25 |
| Écharpe du club | 25 | 40 |
| Ballon dédicacé | 40 | 60 |
| Maillot rétro | 60 | 90 |
| Maquette du stade | 120 | 180 |

- Chaque stade tamponné a sa boutique, aux couleurs du club qui reçoit. Un souvenir de
  chaque sorte par stade.
- « Sur place » = le fan club est passé dans ce stade aujourd'hui (match au stade ou
  Grand Tour) ; ensuite, par correspondance, ×1,5 arrondi à 5.
- Séries de la vitrine (primes en Jetons à réclamer) : un stade complet (5 souvenirs) = 40 ;
  paliers 5 / 15 / 30 / 60 / 120 / 250 souvenirs = 20 / 40 / 80 / 150 / 300 / 600.

## 2. Billets selon l'importance du match

`Evenements.facteur_billet`, `Game.billet(mode, match)`. Billet du stade = 25 × le plus
fort des deux facteurs, arrondi à 5 :

| Match | Facteur |
|---|---|
| Championnat, amical, compétition inconnue | ×1 |
| Coupe continentale / mondiale | ×1,6 / ×2,4 |
| Match des nations | ×2 |
| Quart de finale | ×2 |
| Derby | ×2,4 (≈ 60) |
| Grand Choc | ×3 |
| Demi-finale | ×4 |
| Finale (pays / continent / monde) | ×6 / ×9 / ×12 (150 à 300) |

L'écran géant suit le même facteur, plafonné à ×2 ; le pub et la maison ne changent pas.

## 3. Matériel de tribune

`scripts/club/materiel.gd`, écran « Le local du club » (bouton « Local » du fan club),
onglet « Matériel de tribune », avec l'aperçu de la tribune. Dessiné dans notre tribune
en duel et en soir de match (`Duel.Decor._materiel`), aux couleurs de l'équipe soutenue.
Trois niveaux par objet (plus nombreux, plus grands) ; chaque objet peut être rangé.

| Objet | Niveau 1 | Niveau 2 | Niveau 3 |
|---|---|---|---|
| Mur d'écharpes | 150 | 600 | 2 000 |
| Grands drapeaux (sur les côtés) | 200 | 800 | 2 500 |
| Tambours (battent plus vite quand la jauge monte) | 250 | 1 000 | 3 000 |
| Bâche du club (nom du fan club) | 300 | 1 200 | 3 500 |
| Pluie de confettis (quand la jauge dépasse 40) | 400 | 1 600 | 4 500 |

Le milieu de l'écran reste libre pour la piste de rythme et les FANZZY.

## 4. Grand Tour

`scripts/jeu/grand_tour.gd`, bouton « Grand Tour · N stades à tamponner » dans la liste
d'un pays sur la carte (affiché s'il reste au moins 2 stades à tamponner).

- « Week-end des stades » : 3 étapes ; « Grande boucle » : 5 étapes.
- Étapes : stades du pays pas encore tamponnés, en partant du plus proche du fan club puis
  toujours au plus proche.
- Prix : 60 de forfait + 70 par étape + les trajets (barème du trajet le moins cher,
  cagnotte du club comprise). Un week-end ≈ 300 à 450 Jetons.
- Un Grand Tour par jour. À chaque étape : tampon, et boutique souvenirs au prix sur place
  ce jour-là. Le fan club finit à la dernière étape.

## 5. Agrandir le local

`scripts/club/local_club.gd` (règles), `scripts/ui/local_dessin.gd` (le local en coupe),
onglet « Le local ».

| Salle | Construire | Agrandir | Déco |
|---|---|---|---|
| Salle principale | déjà là | | guirlande 100, poster 150, canapé 250, baby-foot 350, écran géant 600 |
| Salle des chants | 300 | 2 000 | partitions 150, micros et enceintes 450, piano 900 |
| Salle des trophées | 400 | 2 500 | mur des tampons 300, vitrine éclairée 500, coupe en or 1 200 |
| Parking du car | 500 | 3 000 | fanions 200, barbecue 400, car aux couleurs du club 1 500 |

La salle des trophées affiche la vraie collection (tampons, souvenirs, succès).

## 6. Guirlande du mois (achat qui revient)

Ajoutée le 18 nov. 2026 avec la baisse des gains (choix de Gaël « les deux, en douceur »).
Une guirlande par mois (fanions et motifs : flocons, cœurs, fleurs, soleils, feuilles,
étoiles), 1 500 Jetons, **en vente seulement pendant son mois**, gardée ensuite. Une seule
à la fois dans la tribune (`Materiel.SAISON`, encadré « Guirlande du mois » de l'onglet
Matériel de tribune).

## Effet sur l'économie

Modèle : `python3 tools/equilibrage/modele_economie.py` (voir [equilibrage.md](equilibrage.md)).
Matériel et local valent 37 750 Jetons en tout.

| Joueur | Tout le matériel et le local acheté | Souvenirs + Grand Tour sur la saison | Réserve en fin de saison (avant ces ajouts) |
|---|---|---|---|
| Occasionnel (20 min) | jour 119 | ≈ 1 700 | 66 000 (84 000) |
| Régulier (1 h) | jour 52 | ≈ 21 000 | 200 000 (260 000) |
| Passionné (3 h) | jour 26 | ≈ 46 000 | 438 000 (525 000) |

Le tableau ci-dessus est d'avant la baisse des gains. Après la baisse (gains ÷ 1,5 environ)
et avec la guirlande du mois, le joueur régulier gagne ≈ 790 Jetons par jour, a tout acheté
vers le jour 75 et finit la saison avec ≈ 114 000 Jetons (voir [equilibrage.md](equilibrage.md)).
