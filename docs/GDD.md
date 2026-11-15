# FanAroundTheWorld : document de game design (v0.2)

> Version courte, à compléter au fil du projet. Les points marqués **à valider**
> ne sont pas encore décidés.

## 1. Le pitch

Tu crées ton fan club de football et tu le fais grandir. Tu suis les **vrais matchs**
de la saison (calendrier et résultats réels), tu voyages de stade en stade pour
les collectionner, et dans chaque stade tu affrontes la tribune adverse dans un
**duel d'ambiance** : chants en rythme, tifos, olas.

Le ton est fun et coloré, entre Pokémon (collection, voyage), Fortnite (PASS, skins)
et Brawl Stars (style cartoon, parties courtes).

## 2. Fiche technique

| | |
| --- | --- |
| Genre | Gestion de fan club + collection + jeu de rythme |
| Moteur | Godot 4 (2D) |
| Plateformes | PC (Steam) d'abord, mobile plus tard |
| Sport au lancement | Football uniquement |
| Modèle | Jeu payant + PASS saisonnier |
| Langue | Français d'abord |

## 3. La boucle de jeu (validée)

1. **Choisir un match** sur la carte du monde, parmi les vrais matchs du calendrier.
2. **Choisir où le suivre** : au stade, sur écran géant, au pub ou à la maison.
3. Au stade : **voyager** jusqu'au stade avec son fan club et **tamponner le stade**
   dans sa collection (première visite).
4. **Duel d'ambiance** contre la tribune adverse.
5. **Récompenses** : Jetons, XP pour le fan club et progression du PASS.
6. Retour au **hub du fan club** pour recruter, améliorer, personnaliser.

### 3.1 La carte du monde en trois niveaux

| Niveau | Compétitions montrées | Repères sur la carte |
| --- | --- | --- |
| Monde | Compétitions mondiales : sélections, Mondial, amicaux, Mondial des clubs | un repère par continent (nombre de matchs) + les stades des matchs mondiaux |
| Continent | Compétitions continentales : coupes d'Europe, Copa Libertad… | un repère par pays + les stades des matchs de coupe continentale |
| Pays | Championnat (et plus tard la coupe nationale) | un repère par stade qui reçoit un match |

On passe d'un niveau à l'autre en cliquant sur un continent, puis sur un pays.
Un fil d'Ariane (Monde › Europe › France) permet de remonter.

Limite actuelle : les données ne donnent pas encore la ville des stades. Le prototype
place chaque stade à un endroit fixe tiré au hasard dans le pays. Le relais de données
pourra publier la ville (API-Football la fournit) pour placer les stades au bon endroit.
Les coupes nationales ne sont pas encore suivies par le relais.

### 3.2 Où suivre le match

| Lieu | Coût en Jetons | Gains du duel | Tampon du stade |
| --- | --- | --- | --- |
| Au stade | billet + trajet (selon la distance) | ×1,5 | oui |
| Écran géant (fan zone) | petit | ×1,2 | non |
| Au pub | très petit | ×1,0 | non |
| À la maison | gratuit | ×0,6 | non |

Suivre le match ailleurs qu'au stade évite le trajet et le billet. Le duel change de
décor (fan zone, pub, salon) et la tribune adverse est plus petite.

## 4. Le duel d'ambiance (cœur du jeu)

Deux tribunes s'affrontent pendant le match. Le joueur enchaîne des actions en rythme :

- **Chants** : suivre le tempo (appuis au bon moment, style jeu de rythme).
- **Tifos** : grandes animations à préparer, qui rapportent beaucoup si elles sont réussies.
- **Olas** : action collective qui demande de bien enchaîner.

Une jauge d'ambiance indique quelle tribune domine. Le **vrai score du match** donne
des bonus ou des malus (exemple : ton équipe marque, ta tribune reçoit un boost).

### 4.1 Le duel du prototype

- Durée : 90 secondes, une seconde par minute de match.
- **Chant** (ESPACE ou clic) : des notes glissent vers un cercle, il faut appuyer au bon
  moment (« parfait », « bien », « raté »). Le combo multiplie les points.
- **Tifo** (T) : se charge avec les bons chants. Une fois plein, grosse bannière et gros boost.
- **Ola** (O) : disponible toutes les 20 s. Il faut taper 4 flèches dans l'ordre à temps.
- La tribune adverse pousse en continu, et lance régulièrement un chant plus fort.
- Vrai score : +8 % d'ambiance par but d'avance (jusqu'à +24 %), même chose en malus.
  Un vrai but pendant le duel fait exploser la tribune (+15), un but adverse coûte 10.
- Fin : victoire si la jauge penche de ton côté. Jetons et XP selon la performance,
  ×1,3 si ton équipe gagne vraiment le match.

### 4.2 La tribune de FANZZY

Trois postes, chacun tenu par un FANZZY d'une famille :

| Poste | Familles | Effets possibles |
| --- | --- | --- |
| Chant | Voix, Percussion | rythme plus tolérant, points de chant, points des « parfait » |
| Tifo | Tifo, Fidélité | charge du tifo, résistance à la tribune adverse |
| Ola | Pyro, Déplacement | temps pour l'ola, points des « parfait », combo gardé après une erreur |

Le FANZZY apporte le geste de sa famille et ses petits bonus (repris des `mods` du
catalogue thebestfan). Ses variantes sont des **skins purement cosmétiques**.

### 4.3 Nouvelles actions

Les nouvelles actions de duel (nouveaux chants, tifos, chorégraphies) se débloquent
**par la progression** (niveau du fan club, PASS gratuit), jamais avec les Jetons :
un joueur riche en Jetons ne doit pas écraser les autres.

### 4.4 Animation

- Prototype : les FANZZY sont animés comme des marionnettes (respiration, saut au bon
  chant, tremblement au raté, vague pendant l'ola). La foule est dessinée et saute selon
  la jauge.
- Prochaine étape : un squelette 2D commun (Skeleton2D de Godot) pour tous les FANZZY,
  et les 5 expressions déjà dessinées (neutre, pousse, joie, dépit, colère) affichées
  selon l'action : pousse pendant le chant, joie après un parfait ou un but, dépit après
  un raté, colère quand l'adversaire marque.

## 5. Le fan club

- Le fan club a un nom, des couleurs et un niveau.
- Les membres sont des **FANZZY**, petits supporters au style chibi.
- Le hub sert à gérer les membres, préparer les tifos et voir sa collection de stades.

### 5.1 Gestion du club (prototype v0.3)

- **Création** : nom, deux couleurs, écusson dessiné à partir des initiales. Les trois
  FANZZY de la tribune sont les membres fondateurs.
- **Recrutement** : gratuit (pas de FANZZY contre des Jetons). Le nombre de places suit
  le niveau du club : 3 au niveau 1, puis 2 de plus par niveau. On peut renvoyer un membre
  qui n'est pas dans la tribune.
- **Recettes**, en Jetons, qui tombent en continu dans la caisse du club :
  - cotisations : 1 Jeton par heure et par membre ;
  - buvette (5 niveaux, de 3 à 21 Jetons/h) : double pendant 3 h après un duel ;
  - atelier d'écharpes (5 niveaux, de 1 à 6 écharpes/h, stock limité) : prix de vente
    2 Jetons + 1 par tranche de 3 membres.
- **Bonus de taille** : +5 % sur les cotisations et la buvette par membre au-delà du premier.
  Renommée : Petit groupe, Bande de potes, Club de quartier, Tribune entière, Légende du virage.
- La caisse garde **8 h** de recettes : il faut revenir récolter (pas de gain infini hors ligne).
- Ouvrir et améliorer la buvette et l'atelier coûte des Jetons : c'est de l'équipement.

## 6. Les FANZZY

- Les FANZZY sont des **personnages jouables** : leur famille (Voix, Percussion, Tifo,
  Fidélité, Pyro, Déplacement) donne leur geste en duel et de petits bonus.
- Leurs **variantes sont des skins purement cosmétiques** : aucun effet sur les duels.
- Des centaines de FANZZY existent déjà dans le projet thebestfan.online et seront réutilisés
  (le prototype en utilise un échantillon de 18, avec 3 skins chacun).
- On les obtient avec le PASS, les événements et la progression.

## 7. L'économie : les Jetons

Les **Jetons** se gagnent en jouant et servent aux billets, aux trajets et à l'équipement.
Ils ne s'achètent pas et ne donnent jamais de skins.

D'où viennent les Jetons :

- **Duels d'ambiance** : selon la performance, avec un bonus si ton équipe gagne vraiment.
- **Pronostics** sur les vrais matchs, **gratuits et sans mise** : résultat, score exact,
  équipe qui marque en premier, et une série de bons pronos qui multiplie les gains
  (détails dans `docs/pronostics.md`).
- **Missions** du jour et de la semaine : « suis 3 matchs », « visite un nouveau stade ».
- **Le fan club** : cotisations des membres, buvette, vente d'écharpes faites maison.
  Plus le club grandit, plus ça rapporte.
- **Petits boulots de supporter** en mini-jeux rapides : vendeur à la buvette, peintre
  de tifos, chauffeur du bus des supporters.
- **Collection** : compléter une série de tampons de stades ou de FANZZY donne une prime.

À quoi ils servent : billets, trajets, équipement (écharpes, drapeaux, tambours…).
Les nouvelles actions de duel se débloquent par la progression, pas avec les Jetons.
Les skins s'obtiennent seulement par le PASS ou les événements.

Pas de boutique en argent réel en plus du PASS pour le moment.

Prototype : 150 Jetons au départ, coût du billet et du trajet, gains à la fin du duel.

Premier petit boulot jouable : **vendeur à la buvette** (60 s). Les FANZZY font la queue
avec une commande (boisson, hot-dog, frites, gaufre) et une jauge de patience. Commande
juste : 1 Jeton (+1 par tranche de 3 articles), +1 de pourboire si le service est rapide,
+1 toutes les 5 commandes justes d'affilée. Erreur ou client lassé : rien et la série
repart à zéro. À 30 s, la mi-temps : le rush (commandes plus grosses, moins de patience).
Un bon service rapporte autour de 25 à 45 Jetons, moins qu'un bon duel au stade ; au-delà
de 3 services dans la journée, la paye est divisée par deux pour que le petit boulot
complète les duels sans les remplacer. Chaque client servi donne aussi 2 XP au fan club.

## 8. Le PASS saisonnier

- Inspiré des passes saisonniers des jeux free-to-play : paliers gagnés avec l'XP.
- Une piste gratuite et une piste payante.
- Contenu uniquement cosmétique : skins de FANZZY, écharpes, tifos, décors du hub.
- Une saison du PASS suit une saison de football.

## 9. Les vraies données et les droits

- Calendriers et résultats réels, **suivis minute par minute** dès le lancement (buts, cartons, mi-temps influencent le duel en direct).
- Couverture visée au lancement : tous les championnats de première division de tous les pays, les compétitions continentales et internationales de clubs, et les matchs des équipes nationales.
- **Aucun nom de club ni logo officiel** : noms fictifs (exemples des maquettes :
  Paris Capitale, Phocéens, Madrid Royal, Catalans, Munich Bavarois, Dortmund Jaunes,
  Milano Diavoli, Interisti), ligues fictives (Ligue Hexagone, Liga Ibérica,
  Liga Germania, Serie Azzurra).
- Les joueurs pourront renommer les clubs avec des mods du Steam Workshop.
- Source des données réelles : API-Football, via le relais `macgama/fanaroundtheworld-data`
  (voir [donnees-foot.md](donnees-foot.md)).

## 10. Direction artistique

- 2D cartoon épais : contours noirs, formes rondes.
- Police : Lilita One (libre).
- Palette : bleu `#1e6bff`, rose `#ff3d7f`, jaune `#ffd23f`, vert `#3ddc84`, violet `#8b5cff`.
- Interface pensée pour la souris et pour le tactile (mobile plus tard).

Maquettes v1 dans [docs/maquettes/](maquettes/) :

- Carte du monde : `2D_1_carte_du_monde.png`
- Hub du fan club : `2D_2_hub_fan_club.png`
- Collection FANZZY : `2D_3_collection_fanzzy.png`
- PASS saison : `2D_4_pass_saison.png`
- Stade, duel d'ambiance (test 3D) : `3D_stade_duel_ambiance.png`

## 11. Questions ouvertes

- Durée d'un duel d'ambiance : 90 s dans le prototype, à valider en jouant.
- Duel contre d'autres joueurs en ligne, ou solo contre l'IA au lancement ?
- Prix du jeu et prix du PASS.
- Ville réelle des stades (à ajouter au relais de données).
- Prix des billets et trajets, gains des duels : à équilibrer en jouant.
