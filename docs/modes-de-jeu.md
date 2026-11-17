# Modes de jeu du duel

Depuis l'écran **Ta tribune**, trois façons de jouer le même match, avec les trois mêmes
FANZZY. Le ton reste familial : on chante, on lance des confettis, on agite des drapeaux,
et personne ne se bagarre. Un supporter « battu » va s'asseoir ou se secouer au banc.
Les gains (Jetons + XP du fan club) suivent les mêmes règles dans les trois modes :
`scripts/duel/fin_duel.gd`.

- **Rejouer le même match** (choix de Gaël, 16 nov.) : le même jour, un match rapporte 100 % des
  Jetons au 1er duel, 50 % au 2e, 25 % au 3e, puis plus rien (l'XP ne change pas). On peut
  rejouer pour le plaisir sans pouvoir farmer. Compteur : `Game.duels_par_match`.
- **Échap** pendant une partie : pause contre l'IA (Reprendre / Abandonner). En ligne, le jeu
  continue et « Abandonner » donne la victoire par forfait à l'adversaire. Abandonner ne
  rapporte rien.
- **Billet** : au stade, le voyage tamponne le stade, donc le billet n'est plus remboursé.
  Pour l'écran géant, le pub ou la maison, le match compte comme suivi (missions, popularité)
  au lancement du premier duel ; repartir de *Ta tribune* avant rembourse le billet.

| Mode | Genre | Durée | Victoire |
|---|---|---|---|
| Duel d'ambiance | rythme | 90 s | jauge d'ambiance |
| Arène | action vue de dessus, 3 contre 3 | 2 min | banderole à 100 % (mégaphone) |
| Poussée | stratégie, cartes | 3 min | un but, ou la tribune adverse conquise |

## Arène (`scenes/arene/`, règles `scripts/duel/arene_regles.gd`)

- Tu diriges un FANZZY, l'IA joue les deux autres et l'équipe adverse.
- Ballons de confettis : 3 en réserve, un revient toutes les 0,9 s. Un FANZZY plein de
  confettis retourne 3 s à son banc.
- Le **mégaphone** au centre remplit la banderole de l'équipe qui le tient seule.
- Le **super** dépend de la famille du FANZZY et se charge en touchant :

| Famille | Super | Effet |
|---|---|---|
| Voix | Onde de chant | repousse les adversaires devant toi |
| Percussion | Roulement de tambour | étourdit autour de toi |
| Tifo | Grand tifo | mur qui arrête les ballons 4 s |
| Fidélité | Écharpe de soutien | nettoie les confettis des alliés proches |
| Pyro | Fumigène coloré | nuage qui ralentit les adversaires |
| Déplacement | Sprint | tu cours et lances plus vite 3 s |

- Débloqué par le niveau du fan club (jamais avec des Jetons) : **roulade** (ESPACE,
  niveau 3), **tir chargé** (maintenir le clic, niveau 5).

## Poussée (`scenes/poussee/`, règles `scripts/duel/poussee_regles.gd`)

- La **Ferveur** remonte de 1 toutes les 2 s (deux fois plus vite la dernière minute), 10 au maximum.
- Main de 4 cartes, la suivante est affichée. Les unités se posent dans ta moitié, les
  effets partout.
- Les supporters poussent le ballon vers le but adverse, chantent contre les supporters
  d'en face et chantent devant la tribune adverse, qui change de couleur à mesure qu'elle
  est conquise.

| Carte | Coût | Rôle |
|---|---|---|
| Petit Tambour | 2 | rapide, pousse le ballon |
| Porte-Drapeau | 3 | costaud, gros pousseur |
| Lanceur de serpentins | 3 | chante de loin |
| Chorale | 5 | trois chanteurs |
| Mascotte géante | 6 | ne vise que la tribune |
| Canon à confettis | 4 | défend une zone 30 s |
| Fumigène | 3 | effet : ralentit les adversaires (niveau 2) |
| Ola | 2 | effet : alliés plus rapides et plus forts (niveau 4) |

Chaque carte est jouée par un FANZZY de la famille indiquée dans les règles : les tiens
d'abord, sinon le catalogue. Le skin reste cosmétique.

## Animation : squelette 2D automatique

Les FANZZY sont des images d'une seule pièce (1 664 personnages, 2 610 skins). Plutôt
que de les redécouper à la main, `SqueletteFanzzy` (`scenes/fanzzy/squelette_fanzzy.gd`)
lit chaque silhouette au chargement (une dizaine de millisecondes par image) et y retrouve
les hanches (le vide entre les jambes), les deux jambes, les bords du torse, les épaules
et les mains (en suivant chaque bras qui pend le long du corps).

`FanzzyAnime` dessine alors la même image en cinq morceaux découpés par le shader,
façon papier découpé : le corps, deux jambes (derrière) et deux bras (devant), chacun
tourné autour de son articulation, avec un genou qui se replie et un coude. Les morceaux
se chevauchent aux articulations, sans étirer l'image. Actions : `marcher`, `courir`,
`lancer`, `danser`, plus les jambes dans `sauter` et `celebrer`.

- Aucun fichier à produire : chaque nouveau FANZZY ou skin est animé tout seul.
- Un bras mal lu (cape, parapluie, bras posé sur le ventre) reste immobile ; une
  silhouette sans jambes visibles (macareux, glacière) garde ses jambes fixes.
- Contrôle visuel : `godot --headless --path . --script tools/fanzzy/voir_squelettes.gd -- planche.png`
  (ajouter un dossier d'export `etats/` et un nombre pour vérifier d'autres skins).
  Sur 45 skins tirés de l'export complet : jambes trouvées 45 fois, bras 66 fois sur 90.
- Démo : `res://scenes/fanzzy/demo_squelette.tscn`. `squelette_actif = false` rend
  l'animation d'avant.

## Tester sans jouer

    godot --path . -- --scene=arene --match=ex:1 --auto
    godot --path . -- --scene=poussee --match=ex:1 --auto --vitesse=4

`--auto` fait jouer ton camp par l'IA, `--vitesse` accélère la partie.
Tests : `tests/test_modes.gd` (règles) et `tests/test_squelette.gd` (squelette 2D).

## Adversaire ordi : trois niveaux

Options → « Adversaire ordi » : **Facile**, **Normal** (par défaut), **Difficile**
(`Reglages.difficulte()`, réglages dans `scripts/duel/ia_niveau.gd`). Dans l'Arène,
tes deux coéquipiers ordi jouent au même niveau que l'adversaire : c'est toi qui fais
la différence. En ligne, les FANZZY ordi de l'Arène jouent en Normal.

- **Facile** : l'ancienne IA, plus lente. Arène : vise le plus proche, mal et tard.
  Poussée : défend quand le ballon entre chez lui, sinon joue une carte au hasard.
- **Normal / Difficile** : Arène (`_ia` dans `scenes/arene/arene.gd`) : choisit sa cible
  (affaiblie, au mégaphone, en vue), vise là où elle va, esquive les ballons (roulade si
  débloquée), un porteur tient le mégaphone et les autres le couvrent, recule pour
  souffler. Poussée (`scripts/duel/ia_poussee.gd`) : note chaque carte pour pousser le
  ballon, défendre (la bonne réponse : canon ou chorale contre la mascotte, fumigène sur
  un groupe, sans dépenser plus que l'attaque adverse) ou attaquer par vagues (gros
  supporter devant, chanteurs derrière, Ola sur le groupe), garde sa Ferveur tant que
  rien ne presse et protège une avance en fin de match.
- Difficile réagit plus vite, vise plus juste, esquive plus, ne gaspille pas ses
  ballons de loin et attend une Ferveur presque pleine pour attaquer.

Matchs simulés ordi contre ordi (`tests/sim_ia.tscn`, ~6 s par match) :

    godot --headless --path . --fixed-fps 30 res://tests/sim_ia.tscn -- --hors-ligne \
      --jeu=poussee --n=24 --a=difficile --b=normal

Résultats du 17 nov. 2026 (48 matchs par paire, camps échangés) : Poussée, Normal bat
Facile 75 % du temps, Difficile bat Normal ~60 % ; Arène, Normal bat Facile 24 sur 24,
Difficile bat Normal 77 %. Démo : `--difficulte=<niveau>` (adversaire),
`--difficulte-moi=<niveau>` (ton camp avec `--auto`). Tests : `tests/test_ia.gd`.
