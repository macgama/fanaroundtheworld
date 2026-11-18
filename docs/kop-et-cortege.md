# Le kop, le recrutement et le cortège

Deux traditions des tribunes, en version familiale : faire grandir son kop, et
marcher ensemble jusqu'au stade. Décidé avec Gaël le 18 nov. 2026 :
recrutement des FANZZY par **rencontres + petit défi**, kop qui **ne baisse
jamais**, cortège **à chaque match au stade** avec une **marche en rythme en
option**.

## 1. Le kop à deux étages

| Étage | Qui | Comment il grandit | Limite |
|---|---|---|---|
| Le noyau | les FANZZY (personnages jouables) | rencontres + défi | places du club (niveau) |
| Le kop | les supporters anonymes (foule Quaternius aux couleurs du club) | duels, cortèges, déplacements | aucune |

### Le compteur du kop (`scripts/club/kop.gd`, classe `Kop`)

Gardé dans `Game.club["kop"]`. Il **ne baisse jamais** : un duel perdu ou un
mauvais choix rapporte simplement moins de monde.

- Club tout neuf : 20 supporters. Sauvegarde d'avant le kop : 20 + 15 par FANZZY
  au-delà des 3 fondateurs.
- Nouveaux supporters (avant bouche-à-oreille) :
  - duel (les trois modes) : 2, +3 si gagné ; ×1,5 au stade, ×0,5 à la maison ;
    × la part du match rejoué (100 / 50 / 25 %, puis rien) ;
  - déplacement : ferveur d'arrivée / 10 ;
  - cortège : la somme des « passants » gagnés en route (+ la marche en rythme).
- **Bouche-à-oreille** : × (1 + kop / 1 000). Un kop de 1 000 attire deux fois
  plus de monde.

| Renommée | Supporters | Bonus de jauge au coup d'envoi |
|---|---|---|
| Petit groupe | 0 | 0 |
| Bande de potes | 50 | +1 |
| Club de quartier | 200 | +2 |
| Tribune entière | 1 000 | +4 |
| Virage plein | 3 000 | +6 |
| Légende du virage | 10 000 | +8 |

Effets :

- **Tribune visible** : en duel d'ambiance, notre tribune est remplie de 30 %
  (club neuf) à 100 % (3 000 supporters) ; les places vides restent vides.
- **Bonus de départ** : la jauge d'ambiance démarre à +bonus (duel hors ligne).
  En Poussée : +1 de ferveur par tranche de 6 points de bonus (3 au plus).
- **Cotisations** : le kop verse 0,017 × √kop Jetons/h dans la caisse
  (0,34 J/h à 400, 1,7 J/h à 10 000 ; baissé d’un tiers le 18 nov.).

### Recruter un FANZZY (`scripts/club/rencontres.gd`, classe `Rencontres`)

On ne choisit plus dans le catalogue : on **rencontre** les FANZZY, puis on les
**convainc** avec un défi de 15 à 20 s (`scenes/recrutement/defi.tscn`).

- Où : au stade après un duel (30 %), devant un écran ou au pub après un duel
  (12 %), en déplacement (50 % à l'arrivée), pendant le cortège (arrêt
  « Un FANZZY vous suit ! », 6 fois sur 10). Chaque lieu favorise des familles
  (×3) : stade → Tifo, Pyro, Fidélité ; cortège → Voix, Percussion,
  Déplacement ; déplacement → Déplacement, Fidélité.
- 3 rencontres en attente au plus. À la création du club (et pour les
  anciennes sauvegardes), 2 FANZZY du quartier attendent déjà.
- Défis par famille :

| Famille | Défi | Réussite |
|---|---|---|
| Voix, Percussion | Chante dans le tempo (taper au tempo) | 6 temps sur 8 |
| Tifo, Déplacement | Refais la mosaïque (mémoire, 3 à 5 couleurs) | 2 manches sur 3 |
| Fidélité, Pyro | Le geste parfait (arrêter le curseur dans la zone) | 3 essais sur 5 |

  Un FANZZY légendaire demande un coup de plus.
- Raté : il reste dans la liste et revient au bout de 30 min. Réussi mais club
  plein : il attend qu'une place se libère.
- **Jamais de Jetons**. Les recrues du PASS (piste gratuite) rejoignent sans défi.

## 2. Le cortège (`scripts/jeu/cortege.gd`, `scenes/cortege/`)

Le déplacement, c'est le trajet de ville à ville ; le cortège, c'est le
**dernier kilomètre à pied**. Après le tampon du stade (écran Voyage), deux
boutons : **PARTIR EN CORTÈGE** ou « Direct en tribune ». Une fois par vrai
match (`Game.corteges_faits`).

- Départ : le local du club (à domicile), ou la gare / le parking des cars / la
  navette de l'aéroport après un déplacement le jour même. Après un déplacement,
  la ferveur du voyage **continue** dans le cortège.
- Ferveur de départ sans déplacement : 25 + 3 par FANZZY (max 24) + 2 par
  palier de renommée.
- 3 arrêts tirés parmi 13 (le café et la mascotte à domicile, la fanfare et
  les habitants à l'extérieur), plus l'arrêt « Un FANZZY vous suit ! ».
  Chaque choix joue sur :
  - la **ferveur** (de -2 à +20) ;
  - les **passants** qui rejoignent le kop ;
  - le **temps** : 55 min avant le coup d'envoi, dont 25 de marche ; certains
    choix en coûtent, d'autres en font gagner ; en retard, -8 de ferveur et pas
    de bonus de départ ;
  - le **chambrage** (bon enfant) : la tribune d'en face, remontée, pousse 15 %
    plus fort pendant le duel d'ambiance.
  Certains choix demandent un FANZZY d'une famille au club ; il reste toujours
  un choix pour tout le monde.
- **Marche en rythme** (en option, activée par défaut ; la case de l'écran de
  départ est mémorisée) : entre deux arrêts, 8 pas à taper au tempo (ESPACE, clic ou doigt) :
  +1 ferveur par pas parfait, +0,5 par pas bien (6 au plus), +1 passant tous
  les 2 pas parfaits.
- Arrivée : nouveaux supporters (bouche-à-oreille compris), Jetons = ferveur / 10,
  XP du PASS = ferveur / 2, XP du club 10 + ferveur / 10, et **bonus de départ**
  du duel = ferveur / 10 (0 à 10), le jour même, pour ce match.

Jamais de Jetons perdus, jamais de skin, pas de fumigènes : des confettis,
des ballons, des lanternes.

## Tests et démo

- `godot --headless --path . --script tests/test_cortege.gd` (règles) ;
  écrans `cortege`, `cortege_auto`, `defi_rythme`, `defi_memoire`,
  `defi_precision` dans `tests/test_ecrans.tscn`.
- Démo : `-- --scene=cortege --match=ex:1 --kop=600 --auto`
  (`--kop=N` crée le club si besoin et règle le kop) ;
  `-- --scene=defi --fanzzy=GD8 --auto` (le FANZZY doit être dans les rencontres).

## Plus tard

- Le gros matériel de tribune (bâche géante…) réservé aux grands kops, quand le
  matériel sera fusionné.
- Le kop dans la Ligue des tribunes et le classement en ligne.
- Mission de la semaine « Faire 2 cortèges » (compteur `stats["cortege"]` prêt),
  succès « recrues » (`stats["recrue"]`).
