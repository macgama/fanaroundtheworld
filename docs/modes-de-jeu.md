# Modes de jeu du duel

Depuis l'écran **Ta tribune**, trois façons de jouer le même match, avec les trois mêmes
FANZZY. Le ton reste familial : on chante, on lance des confettis, on agite des drapeaux,
et personne ne se bagarre. Un supporter « battu » va s'asseoir ou se secouer au banc.
Les gains (Jetons + XP du fan club) suivent les mêmes règles dans les trois modes :
`scripts/duel/fin_duel.gd`.

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

## Animation

Les deux modes réutilisent `FanzzyAnime` (image entière déformée par shader) avec trois
nouvelles actions : `marcher`, `courir` (petits bonds, buste penché selon `cap`, bras qui
balancent) et `lancer` (élan puis détente). Ça marche pour tous les FANZZY sans rien
redessiner. Étape suivante possible : un squelette 2D par silhouette, ou des planches
d'animation générées, pour des cycles de marche plus riches.

## Tester sans jouer

    godot --path . -- --scene=arene --match=ex:1 --auto
    godot --path . -- --scene=poussee --match=ex:1 --auto --vitesse=4

`--auto` fait jouer ton camp par l'IA, `--vitesse` accélère la partie.
Tests des règles : `godot --headless --path . --script tests/test_modes.gd`.
