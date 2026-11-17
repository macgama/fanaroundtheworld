# Foule des tribunes (sprites Quaternius)

Les supporters des tribunes (duel d'ambiance, écran d'accueil, Poussée) sont
des sprites 2D tirés du mannequin de la *Universal Animation Library* de
Quaternius (CC0). Les FANZZY ne sont pas concernés.

## Dans le jeu

`FouleSprites` (`scripts/ui/foule_sprites.gd`) :

    FouleSprites.dessiner(self, pied, hauteur, &"sauter", t, maillot, echarpe, peau, variante)
    var ga := FouleSprites.geste_ambiance(ferveur, graine, temps)  # [geste, t local]

- Quatre calques par image : la base, puis peau, maillot (+ rayures de
  l'écharpe et bonnet) et écharpe (+ pompon) en gris, multipliés par la couleur.
- Gestes : `repos`, `sauter`, `applaudir`, `ola` (joué une fois,
  `FouleSprites.duree(&"ola")`), `echarpe`, `depit`, `danser`.
- Le nœud qui dessine doit avoir `texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`
  (les atlas sont importés avec mipmaps) pour des petits supporters nets.
- Sans les atlas, les écrans gardent l'ancien dessin (pastilles).

Aperçu : `godot --path . res://tools/foule/apercu_foule.tscn`.

## Refaire les images

1. Télécharger la *Universal Animation Library* Standard (gratuite) et prendre
   `Unreal-Godot/UAL1_Standard.glb`.
2. `pip install bpy` (Blender en module Python, 5.x).
3. Pour chaque variante (a, b, c) :

       VARIANTE=a python3 tools/foule/rendre_supporters.py UAL1_Standard.glb rendu_a

4. `python3 tools/foule/assembler_atlas.py rendu_a rendu_b rendu_c assets/foule`

Pour ajouter un geste : écrire une fonction `geste_xxx(i, n)` dans le script
de rendu (les directions de bras sont données dans l'espace de l'armature :
x vers l'extérieur, y négatif vers la caméra, z vers le haut), l'ajouter à
`GESTES`, et sa cadence dans `CADENCE` de `assembler_atlas.py`.
