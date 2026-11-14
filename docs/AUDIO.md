# Le son de FanAroundTheWorld

Tout ce qui sonne dans le jeu, d'où ça vient, et comment s'en servir dans un
écran. Inventaire détaillé de l'ancien projet : [audio/inventaire-thebestfan.md](audio/inventaire-thebestfan.md).

## 1. D'où viennent les sons (et pourquoi)

| Ce qui est dans le dépôt | Origine | Droits |
|---|---|---|
| `assets/audio/sfx/*.wav` (32 sons) | Calculés par `tools/audio/generer_sons.py` à partir de bruit et d'oscillateurs | Au projet, aucune licence à suivre |
| `assets/audio/ambiances/*.ogg` (6 boucles) | Idem : stade calme, stade chaud, stade en ferveur, pub, maison, écran géant | Au projet |
| `assets/audio/musique/*.ogg` (2) | « The Final Turn », création de Gaël, reprise de TheBestFan (boucle des menus, victoire) | À Gaël |

**Ce qui n'est pas repris : les 98 sons Artlist de TheBestFan** (cartes, épreuves,
clubs, boosters, rumeur et clameur). Lecture de la licence Artlist au 14 novembre 2026 :

- Les **sons du catalogue Artlist** (la rumeur, la clameur du but) ne couvrent
  pas un jeu vendu : les formats de la licence Pro sont « Video clips,
  Advertisements, Films, Series, Podcasts, Animations, Presentations, Slides »,
  et les jeux ne sont cités que dans l'accord Enterprise sur mesure
  (« App, Software, games and their end-users »).
- Les **générations IA faites sur Artlist** (les sons des vidéos Veo des cartes
  et épreuves) : Artlist « ne revendique pas la propriété » du résultat et n'en
  restreint pas l'usage commercial, mais la page ne parle pas des jeux, ne
  garantit pas que le résultat soit original, et un résultat semblable peut
  sortir pour quelqu'un d'autre.
- Le dépôt est **public** : y mettre ces fichiers, ce serait les redistribuer.

Ce n'est pas un avis juridique. Pour les reprendre un jour, il faut une réponse
écrite d'Artlist (ventes ou support) disant qu'un jeu Steam est couvert. Sources :
[licence Artlist](https://artlist.io/help-center/privacy-terms/artlist-license),
[FAQ IA d'Artlist](https://help.artlist.io/hc/en-us/articles/33210293103005-AI-Image-and-Video-FAQs).

**Pour compléter plus tard** : sons CC0 uniquement (Kenney, Freesound filtré
sur « Creative Commons 0 », Sonniss GDC pour les bundles libres de droits), un
par un, avec la source notée dans le catalogue (`"origine": "cc0"`, et l'URL).
Le test `tests/test_audio.gd` refuse toute autre origine que `synthese`,
`gael` ou `cc0`.

**Les règles héritées de TheBestFan** : du rythme, des bruits et des accords
tenus, **jamais un air connu** (les chants de supporters reprennent souvent des
airs protégés) ; et le son ne porte jamais seul une information, l'écran la
montre aussi.

## 2. Les bus (`default_bus_layout.tres`)

Godot charge ce fichier tout seul au démarrage.

| Bus | Ce qui y passe | Réglage |
|---|---|---|
| Master | tout | limiteur (plafond −0,5 dB) : un but pendant un chant et une carte ne saturent pas |
| Musique | « The Final Turn » | −6 dB |
| Ambiance | rumeur du lieu | |
| Chants | tambours, claps, « hey » des chants | compresseur doux |
| Effets | moments (but, ola, tifo, sifflets) | |
| Interface | parfait, bien, raté, combo, clics | −3 dB |

Le menu des options règle chaque bus avec `Sons.regler_volume("Musique", 0.5)`
(curseur de 0 à 1, au carré : à mi-course on entend la moitié).

## 3. Les fichiers de données

- `data/audio/catalogue_sons.json` : chaque son (fichier, bus, volume,
  variation de hauteur, origine), les **groupes** (« tambour » tire un des trois
  tambours au hasard), les ambiances et les **lieux** (stade, pub, maison,
  écran géant, chacun à trois intensités), les musiques.
- `data/audio/chants.json` : les huit chants du duel. Une piste par voix, un
  caractère par pas : `X` fort, `x` normal, `o` léger, `.` rien. Voix : `T`
  tambour, `C` claps, `S` caisse claire, `H` « hey », `G` cri de groupe, et
  `J` **les appuis attendus du joueur**. Exemple, le contretemps :

  ```json
  "pistes": {"T": "x...x...x...x...", "C": "..x...x...x...x.", "J": "..x...x...x...x."}
  ```

  `bpm_par_mesure` et `bpm_max` font accélérer un chant (le grand clap).

## 4. Le code (`scripts/audio/`)

| Fichier | Rôle | Dépend de |
|---|---|---|
| `rythme.gd` (`Rythme`) | grille des temps, notes du joueur, fenêtres de jugement, latence | rien |
| `banque_sons.gd` (`BanqueSons`) | lecture du catalogue, tirage dans un groupe, chargement des flux | rien |
| `chant_lecteur.gd` (`ChantLecteur`) | nœud qui joue un chant et juge les appuis | les deux du dessus |
| `sons.gd` | autoload « Sons » : effets, ambiances avec fondu, musique, volumes | `BanqueSons` |

Fenêtres par défaut, les mêmes que le prototype du duel : **parfait ±55 ms,
bien ±130 ms**, raté jusqu'à ±286 ms, au-delà l'appui ne vise pas cette note.
`tolerance` les élargit (bonus d'équipe « tempoWindow », accessibilité).

Le jugement se fait **sur ce que le joueur entend** : la latence de sortie
(`AudioServer.get_output_latency()`) est retranchée, et `calibrage` permet un
réglage manuel par joueur.

### Brancher dans le duel

1. Déclarer l'autoload dans `project.godot` :

   ```ini
   [autoload]
   Sons="*res://scripts/audio/sons.gd"
   ```

2. Dans la scène du duel :

   ```gdscript
   var chant := ChantLecteur.new()

   func _ready() -> void:
       add_child(chant)
       chant.tolerance = mods["tempoWindow"]       # fenêtres élargies par l'équipe
       chant.appui_juge.connect(_sur_appui)
       chant.note_manquee.connect(func(_i, _t): _rate(false))
       chant.lancer("contretemps", 0.0, 16)       # BPM du chant, 16 mesures
       Sons.ambiance("stade", 2)

   func _unhandled_input(e: InputEvent) -> void:
       if e.is_action_pressed("ui_accept"):
           chant.juger_appui()                     # émet appui_juge

   func _sur_appui(r: Dictionary) -> void:
       match r.note:
           "parfait": Sons.jouer("ui_parfait")
           "bien": Sons.jouer("ui_bien")
           "rate": Sons.jouer("ui_rate")

   func _process(_d: float) -> void:
       for n in chant.notes_a_venir(2.0):          # dessiner la piste
           var x := (n.t - chant.temps_entendu())  # secondes avant la note
   ```

3. Les moments : `Sons.jouer("clameur_but")`, `Sons.jouer("ola")`,
   `Sons.jouer("tifo")`, `Sons.jouer("sifflet_fin")`, `Sons.jouer("deception")`
   (but adverse), `Sons.jouer("sifflets_foule")` (chant adverse).

4. Suivre le match ailleurs qu'au stade : `Sons.ambiance("pub", 1)`,
   `Sons.ambiance("maison", 1)`, `Sons.ambiance("ecran_geant", 2)`.

Sans `ChantLecteur`, `Rythme` seul suffit pour une piste gérée à la main :
`Rythme.depuis_chant(Rythme.chant("tempo"), 0.0, debut).notes_joueur(16)`.

## 5. Écouter et tester

- **Banc d'écoute** : `scenes/demo_audio/demo_audio.tscn` (F6 dans l'éditeur).
  Tous les sons, les ambiances, la musique, et chaque chant à jouer en rythme
  avec Espace, avec l'écart en millisecondes.
- **Tests sans écran** :

  ```sh
  godot --headless --path . --import
  godot --headless --path . --script tests/test_audio.gd          # calculs, catalogue, bus
  godot --headless --path . --script tests/test_chant_lecteur.gd  # un chant joué en vrai, 3 s
  ```

- **Refaire les sons** : `pip install numpy scipy` puis
  `python3 tools/audio/generer_sons.py` (ffmpeg nécessaire pour les ambiances).
  La graine est fixe : mêmes fichiers à chaque fois. `--seul tambour_1` pour
  n'en refaire qu'un.
