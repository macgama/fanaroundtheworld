# Animation des FANZZY

Module autonome dans `scenes/fanzzy/`. Il anime n'importe quel FANZZY à partir
de son image, sans découpage ni squelette, et remplit des tribunes entières.

![Démo](animation-fanzzy-demo.gif)

## Pourquoi pas un squelette (Skeleton2D) ?

Les FANZZY sont des images entières (rendus 3D, 520 x 945). Un squelette
demanderait de découper bras, jambes et tête sur **1 664 personnages** et leurs
skins, à la main. On anime donc l'image entière :

- une **grille déformée par un shader** (`fanzzy_deformation.gdshader`) : les
  pieds restent fixes, le buste se plie, s'écrase, s'étire ou ondule ;
- des **mouvements procéduraux** (saut cartoon, balancement, coups de poing sur
  le temps) calés sur le **tempo** commun de la tribune ;
- des **accessoires dessinés** : écharpe aux couleurs du club, notes de
  musique, confettis, nuage de pluie, symboles de colère, étincelles ;
- le **changement d'expression et de pose** (neutre, pousse, joie, depit,
  colere), plus le clignement des yeux.

Avantage : chaque nouveau FANZZY ou skin est animé sans aucun travail.
Limite : entre deux poses, les bras ne bougent pas en continu (on passe d'une
image à l'autre). Si un FANZZY phare mérite mieux, on pourra lui faire plus tard un rig Skeleton2D dédié avec la même interface
(`jouer(action)`).

## Actions

| Action | Expression | Durée par défaut | Effet |
|---|---|---|---|
| `repos` | neutre | boucle | respiration, léger balancement |
| `chanter` | pousse | boucle | balancement en rythme, notes de musique |
| `agiter_echarpe` | pousse | boucle | écharpe du club au-dessus de la tête |
| `applaudir` | joie | boucle | petits rebonds et étincelles à chaque clap |
| `encourager` | pousse | boucle | coups de poing sur le temps |
| `sauter` | joie | boucle | sauts cartoon (écrasé, étiré) |
| `celebrer` | joie | 3 s | grands sauts, éclat, confettis |
| `depit` | depit | 3 s | s'affaisse, se ternit, nuage de pluie |
| `huer` | colere | 2,5 s | tremble de rage, symboles de colère |

## Utilisation

Un FANZZY seul :

```gdscript
var f := FanzzyAnime.creer("MT14")   # évolution e1, skin base
var g := FanzzyAnime.creer("MT14", "e2", "halloween")
f.position = Vector2(400, 900)       # position = entre les pieds
f.scale = Vector2.ONE * 0.3          # les images font 945 px de haut
f.couleurs_echarpe = [Color("1e6bff"), Color("ffffff")]
add_child(f)
f.jouer(&"chanter")                  # en boucle
f.jouer(&"celebrer", 2.0)            # 2 s puis retour au repos
f.jouer(&"sauter", -1, 0.5)          # dans 0,5 s, durée par défaut
```

Une tribune :

```gdscript
var t := TribuneFanzzy.new()
t.fanzzy_ids = ["MT14", "AN22", "AN2"]   # répétés pour remplir les places
t.couleurs = [Color("ffd23f"), Color("1a1a1a")]
t.rangees = 3
t.places_par_rangee = 6
t.bpm = 128          # tempo des chants
t.energie = 0.8      # 0 = calme, 1 = bouillante
add_child(t)

t.reagir(&"but")         # but, but_adverse, occasion, faute, chant, tifo, pression
t.ola()                  # vague de gauche à droite
t.jouer_tous(&"applaudir", 3.0)
```

Pour le duel d'ambiance, il suffit de brancher les événements du duel sur
`reagir()` et de régler `energie` selon la jauge d'ambiance de chaque tribune.

## Où sont cherchées les images

`FanzzyAnime.creer(id, evolution := "e1", skin := "base")` cherche, dans
`assets/fanzzy/sprites/` puis `assets/fanzzy/demo/` :

1. les expressions au format de l'export TheBestFan :
   `<id>/<evolution>/<skin>/<etat>.webp`, avec `etat` parmi `neutre`, `pousse`,
   `joie`, `depit`, `colere` et `cligne` (yeux fermés, facultatif). Si le skin
   n'a pas l'expression, celle du skin `base` est prise ;
2. formats simples acceptés aussi : `<id>/<etat>.webp`, `<id>_<etat>.webp`,
   `<id>-<etat>.webp` ;
3. à défaut d'expressions, la vignette seule `<id>.webp`.

L'expression `neutre` sert d'image de base (même cadrage que les autres, pieds
au même endroit). Il manque une expression ? L'image de base la remplace.
Les expressions sont de vraies poses (bras levés pour `joie`, main sur le
visage pour `depit`, doigt pointé pour `colere`…) : le changement d'action
change donc aussi la posture, et l'animation procédurale s'ajoute par-dessus.

`assets/fanzzy/demo/` contient l'évolution e1, skin base, de 18 FANZZY pour la
démo (5,3 Mo). Les 17 161 expressions complètes (~900 Mo) ne sont pas dans le
dépôt.

## Démo

Ouvrir `scenes/fanzzy/demo_animations.tscn` et lancer la scène (F6). La
séquence tourne en boucle ; les boutons du haut testent chaque action.

Pour en faire une vidéo :

```sh
godot --path . --write-movie demo.avi --fixed-fps 30 --quit-after 985 \
    res://scenes/fanzzy/demo_animations.tscn
```

## Performances

Chaque FANZZY = une grille de 6 x 18 cases (partagée entre images de même
taille) et un matériau. Une tribune de 18 FANZZY tourne sans problème en rendu
Compatibilité. Pour de très grandes foules (plusieurs centaines), il faudra
passer les rangées du fond en sprites simples sans shader.
