# FanAroundTheWorld : document de game design (v0.1)

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

## 3. La boucle de jeu (à valider)

1. **Choisir un match** sur la carte du monde, parmi les vrais matchs du calendrier.
2. **Voyager** jusqu'au stade avec son fan club.
3. **Tamponner le stade** dans sa collection (première visite).
4. **Duel d'ambiance** contre la tribune adverse.
5. **Récompenses** : XP pour le fan club et progression du PASS.
6. Retour au **hub du fan club** pour recruter, améliorer, personnaliser.

## 4. Le duel d'ambiance (cœur du jeu)

Deux tribunes s'affrontent pendant le match. Le joueur enchaîne des actions en rythme :

- **Chants** : suivre le tempo (appuis au bon moment, style jeu de rythme).
- **Tifos** : grandes animations à préparer, qui rapportent beaucoup si elles sont réussies.
- **Olas** : action collective qui demande de bien enchaîner.

Une jauge d'ambiance indique quelle tribune domine. Le **vrai score du match** donne
des bonus ou des malus (exemple : ton équipe marque, ta tribune reçoit un boost).

## 5. Le fan club

- Le fan club a un nom, des couleurs et un niveau.
- Les membres sont des **FANZZY**, petits supporters au style chibi.
- Le hub sert à gérer les membres, préparer les tifos et voir sa collection de stades.

## 6. Les FANZZY

- Skins **purement cosmétiques** : aucun effet sur les duels ni sur les matchs.
- Des centaines de FANZZY existent déjà dans le projet thebestfan.online et seront réutilisés.
- On les obtient avec le PASS, les événements et la progression.

## 7. Le PASS saisonnier

- Inspiré des passes saisonniers des jeux free-to-play : paliers gagnés avec l'XP.
- Une piste gratuite et une piste payante.
- Contenu uniquement cosmétique (FANZZY, écharpes, tifos, décors du hub).
- Une saison du PASS suit une saison de football.

## 8. Les vraies données et les droits

- Calendriers et résultats réels des championnats.
- **Aucun nom de club ni logo officiel** : noms fictifs (exemples des maquettes :
  Paris Capitale, Phocéens, Madrid Royal, Catalans, Munich Bavarois, Dortmund Jaunes,
  Milano Diavoli, Interisti), ligues fictives (Ligue Hexagone, Liga Ibérica,
  Bundes Liga, Serie Azzurra).
- Les joueurs pourront renommer les clubs avec des mods du Steam Workshop.
- Source des données réelles : **à choisir** (doit être gratuite et autoriser l'usage commercial).

## 9. Direction artistique

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

## 10. Questions ouvertes

- Valider la boucle de jeu de la section 3.
- Durée d'un duel d'ambiance (une mi-temps ? un match complet accéléré ?).
- Duel contre d'autres joueurs en ligne, ou solo contre l'IA au lancement ?
- Prix du jeu et prix du PASS.
- Source des données de matchs réels.
