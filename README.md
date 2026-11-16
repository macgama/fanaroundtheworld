# FanAroundTheWorld

Jeu PC (Steam) en 2D, fait avec **Godot 4**. Tu diriges un fan club de football,
tu voyages vers les vrais matchs du calendrier, tu collectionnes les stades et
tu affrontes les autres tribunes dans des **duels d'ambiance**.

Le concept complet est dans [docs/GDD.md](docs/GDD.md).

## Lancer le projet

1. Installer [Godot 4.5](https://godotengine.org/download) (version standard, pas besoin de .NET).
2. Ouvrir Godot, cliquer sur **Importer** et choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** pour lancer le jeu.

Le projet utilise le moteur de rendu *Compatibilité* pour tourner sur les petits PC
et, plus tard, sur mobile.

## Le prototype jouable (v0.3)

1. **Écran d'accueil** : **JOUER** (ou **CONTINUER**), **EN LIGNE**, **OPTIONS** (volumes,
   plein écran, revoir le tutoriel, recommencer à zéro) et **QUITTER**. La première fois,
   **crée ton fan club** : nom, deux couleurs, écusson. Tes 3 FANZZY de tribune sont les
   membres fondateurs. **Tutoriel** : ton premier FANZZY t'accompagne dans une bulle
   (fan club, QG, équipes favorites, choix du match, prono, lieu, voyage, tribune, premier
   duel) et un cadre jaune montre le bouton à presser. À la fin : 50 Jetons de bienvenue.
   Il peut être passé à tout moment (voir `scripts/autoload/tutoriel.gd`).
2. **Carte du monde** : les vrais matchs de la semaine (de la veille à J+7), relus
   toutes les 30 min, et le live relu chaque minute. Clique sur un continent, puis sur
   un pays. À gauche, la liste des matchs (filtre par jour ou « Direct »). Molette pour
   zoomer, glisser pour déplacer.
3. Choisis un match : à droite, choisis ton camp et **où suivre le match** (stade,
   écran géant, pub, maison), puis **C'EST PARTI !**
   Dans la même fiche, **Ton pronostic** : un score et l'équipe qui marque en premier,
   gratuit et modifiable jusqu'au coup d'envoi. Le bouton **Pronos** liste tes
   pronostics et ta série (voir `docs/pronostics.md`).
4. Au stade : le car du fan club voyage jusqu'au stade, qui est **tamponné**.
5. **Ta tribune** : choisis tes 3 FANZZY (Chant, Tifo, Ola) et leurs skins.
6. **Duel d'ambiance** (90 s) :
   - **ESPACE** (ou clic sur *Chant*) quand la note bleue arrive dans le cercle ;
   - **T** quand le tifo est chargé ;
   - **O** quand l'ola est prête, puis les **flèches** dans l'ordre ;
   - touches de test : **B** simule un but pour ton équipe, **N** un but adverse.

   Deux autres façons de jouer le duel, avec la même tribune (voir `docs/modes-de-jeu.md`) :
   - **Arène** (2 min) : 3 FANZZY contre 3, vue de dessus. **ZQSD** ou flèches pour bouger,
     la souris pour viser, **clic** pour lancer un ballon de confettis, **clic droit** ou **E**
     pour le super de la famille, **TAB** pour changer de FANZZY. Tiens le mégaphone au
     centre pour remplir ta banderole.
   - **Poussée** (3 min) : pose des supporters avec tes cartes (**clic** sur une carte ou
     **1 à 4**, puis clic dans ta moitié). Ils poussent le ballon et chantent devant la
     tribune d'en face. Un but ou la tribune conquise, et c'est gagné.
   **Contre un vrai joueur** : bouton **CONTRE UN JOUEUR** dans *Ta tribune*, ou **En ligne**
   sur la carte. Un ami sur le même réseau trouve ton salon tout seul (ou tape ton adresse IP) ;
   avec Steam, invitation d'amis et recherche d'adversaire (voir `docs/multijoueur.md`).
7. **Buvette** (bouton en bas de la carte) : petit boulot de vendeur, 60 s pour gagner
   des Jetons. Les FANZZY font la queue avec leur commande :
   - **1 à 4** (ou clic) : poser une boisson, un hot-dog, des frites, une gaufre ;
   - **ENTRÉE** ou **ESPACE** : servir · **RETOUR ARRIÈRE** : vider le plateau ;
   - à 30 s, c'est la mi-temps : le rush. Après 3 services dans la journée, la paye est divisée par deux.
8. **Peintre de tifo** (écran *Petits boulots*) : 60 s pour peindre les grandes bâches
   du capo d'après son modèle, de plus en plus grandes :
   - **clic gauche** (en glissant) : pinceau, case par case · **clic droit** : seau (toute la zone d'un coup) ;
   - **1 à 5** : la peinture · **P** / **S** / **TAB** : l'outil · **flèches + ESPACE** : peindre au clavier ;
   - **ENTRÉE** : présenter la bâche. Le capo l'accepte dès 75 % de ressemblance ;
     payée selon la ressemblance, bonus si elle est parfaite. Après 3 services dans la journée, paye ÷ 2.

**Missions** (bouton en haut de la carte) : 3 missions du jour et 3 de la semaine
(« suis 3 matchs », « visite un nouveau stade », « gagne un duel »…) qui rapportent des Jetons
et de l'XP de PASS. Une mission du jour peut être changée une fois par jour, et une mission
terminée mais oubliée est versée automatiquement. Détails dans [docs/missions.md](docs/missions.md).

**Événements** : les derbys, Grand Choc, finales, demi-finales, quarts et matchs des
grandes compétitions de sélections sont repérés tout seuls dans le calendrier. Pastille sur
le match, onglet **Fêtes** dans la liste, bandeau dans la fiche. De la veille du match à 6 h
après, les duels sur ce match rapportent plus de Jetons (×1,25 à ×2) et le premier donne une
prime d'XP de PASS. Détails dans [docs/evenements.md](docs/evenements.md).

**Mes équipes** (bouton *Équipes* en bas de la carte) : choisis **un club favori par pays**
et **une équipe nationale** (ou directement depuis la fiche d'un match : *En faire mon club favori*).
Tes duels, pronos et déplacements pour elles, et les récoltes de ton fan club, leur donnent des
**points de popularité**. Le classement des équipes les plus suivies (clubs du monde, par pays,
sélections) mélange tes points et ceux des autres supporters, simulés en attendant le jeu en ligne.
Un favori peut changer une fois par semaine. Détails dans [docs/equipes-favorites.md](docs/equipes-favorites.md).

**Le fan club** (bouton *Fan Club* en bas de la carte) :

- **Recruter** des FANZZY : gratuit, mais le nombre de places dépend du niveau du club
  (3 au niveau 1, puis +2 par niveau).
- **Cotisations** : chaque membre verse 1 Jeton par heure.
- **Buvette** : à ouvrir puis améliorer avec des Jetons ; elle rapporte double pendant
  3 h après chaque duel.
- **Atelier d'écharpes** : tricote des écharpes à vendre, leur prix monte avec la taille du club.
- **Bonus de taille** : +5 % sur les recettes par membre. La caisse garde 8 h de recettes,
  il faut passer **récolter**.

Sans internet, le jeu garde la dernière semaine téléchargée. La toute première fois
sans réseau, il affiche 16 matchs d'exemple. La partie est sauvegardée dans
`user://sauvegarde.json` (sous Windows : `%APPDATA%\Godot\app_userdata\FanAroundTheWorld`).
Supprime ce fichier pour recommencer à zéro.

## Organisation des dossiers

| Dossier | Contenu |
| --- | --- |
| `scenes/` | Scènes Godot (`.tscn`) et leurs scripts, un sous-dossier par écran (`main/`, `carte/`, `voyage/`, `tribune/`, `duel/`, `pronostics/`, `favoris/`, `classement/`, `club/`, `buvette/`, `tifo/`) |
| `scripts/autoload/` | Scripts globaux chargés au démarrage (`Game` : état du jeu et sauvegarde, `Donnees` : vrais matchs) |
| `scripts/donnees/` | Noms fictifs (`fiction.gd`), placement sur la carte (`geo.gd`), fiche d'un match |
| `scripts/jeu/` | Règles du jeu sans écran (pronostics, équipes favorites et popularité, missions, collection, événements des vrais matchs) |
| `scripts/club/` | Règles du fan club (`fan_club.gd` : membres, cotisations, buvette, écharpes) |
| `scripts/carte/` | La carte du monde dessinée |
| `scripts/buvette/` | Règles du petit boulot de buvette (commandes, paye), sans affichage |
| `scripts/tifo/` | Règles du petit boulot de peintre de tifo (modèles, seau, ressemblance, paye), sans affichage |
| `scripts/reseau/` | Règles du jeu en ligne (messages, jauge partagée) ; le transport est l'autoload `Reseau` |
| `scripts/ui/` | Style commun de l'interface (couleurs, boutons, icônes) |
| `assets/fanzzy/` | Les FANZZY (personnages jouables, avec leurs skins cosmétiques), importés depuis thebestfan.online |
| `assets/stades/` | Images des stades et des tribunes |
| `assets/ui/` | Boutons, cadres, icônes de l'interface |
| `assets/fonts/` | Polices (libres de droits uniquement) |
| `assets/audio/` | Chants (`chants/`) et bruitages (`sfx/`) |
| `data/` | Données JSON : carte (`carte/`), noms fictifs des clubs (`clubs/`), rivalités pour les derbys et Grand Choc (`evenements/`), matchs d'exemple hors ligne (`exemple/`) |
| `tools/` | Scripts de préparation des données (carte du monde, repérage des bras des FANZZY) |
| `mods/` | Format des mods Steam Workshop (noms et couleurs de clubs) |
| `docs/` | Game design et maquettes |
| `tests/` | Tests automatiques (`godot --headless --path . --script tests/test_logique.gd`, `tests/test_pronostics.gd`, `tests/test_club.gd`, `tests/test_supporters.gd`, `tests/test_classement.gd`, `tests/test_buvette.gd`, `tests/test_tifo.gd`, `tests/test_collection.gd`, `tests/test_evenements.gd`, `tests/test_audio.gd`, et le parcours complet : `godot --headless --path . res://tests/test_pronostics_jeu.tscn -- --hors-ligne`, le tutoriel : `res://tests/test_tutoriel.tscn -- --hors-ligne`, le classement en ligne : `res://tests/test_classement_jeu.tscn -- --hors-ligne`, le tour de tous les écrans (chaque bouton pressé, parties au clavier, pause) : `res://tests/test_ecrans.tscn -- --hors-ligne`) |

## Règles du projet

- **Pas de nom ni de logo officiel** : les clubs ont des noms fictifs, la communauté peut les renommer via des mods.
- **FANZZY** : leur famille donne leur geste en duel ; leurs **skins sont purement cosmétiques**.
- **Budget zéro** : uniquement des outils et des ressources gratuits ou libres de droits.
- Le texte du jeu est en français d'abord.

## Crédits

- Carte du monde : Natural Earth (domaine public), via world-atlas. Capitales : paquet countryinfo.
- Polices : Lilita One et Nunito (SIL Open Font License, voir `assets/fonts/`).
- Données de match : voir le champ `attribution` affiché sur l'écran titre.
