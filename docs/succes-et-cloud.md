# Succès Steam et sauvegarde dans Steam Cloud

## Pour le joueur

- **30 succès** à gagner en jouant : duels, fan club, voyages, pronostics, petits
  boulots, collection. Ils s'affichent dans **Collection → Succès**, avec la
  progression de ceux qui restent, et une annonce en haut de l'écran quand on en gagne un.
- Les succès ne rapportent ni Jetons ni skins : ce sont des souvenirs.
- **Sans Steam** (Steam fermé, version de test), le jeu garde les succès dans la
  sauvegarde et les envoie à Steam au prochain lancement avec Steam.
- **Sauvegarde** : toujours sur le PC (`user://sauvegarde.json`) et, si Steam Cloud
  est actif, aussi dans Steam Cloud. Au lancement, le jeu prend la plus récente des
  deux : on retrouve sa partie sur un autre PC. Les Options disent où est la sauvegarde.

## Comment c'est fait

| Fichier | Rôle |
|---|---|
| `scripts/autoload/plateforme.gd` | Autoload « Plateforme », chargé en premier : ouvre Steam une fois (Reseau s'en sert aussi), succès (`debloquer`, `synchroniser_succes`), Steam Cloud (`cloud_ecrire`, `cloud_lire`, `cloud_effacer`) |
| `scripts/jeu/succes.gd` | La liste des succès (id Steam, textes FR/EN, icône, condition) et les règles, sans écran |
| `scripts/jeu/sauvegarde_cloud.gd` | Choix entre la sauvegarde du PC et celle du Cloud (champ `sauve_le`, date unix) |
| `scripts/autoload/game.gd` | `succes` et `stats` dans la sauvegarde ; `etat_succes()` ; vérification à chaque sauvegarde et à chaque `noter_mission` |
| `scenes/collection/collection.gd` | Onglet « Succès » |
| `tools/steam/icones_succes.tscn` | Fabrique les icônes 256×256 dans `docs/steam/succes/` |
| `tests/test_succes.gd`, `tests/test_succes_jeu.tscn` | Tests |

- Chaque action du jeu passe par `Game.noter_mission(evt, clé)` : les succès y
  comptent leurs événements (`Game.stats`, par ex. `duel_gagne:arene`). Le reste vient
  de l'état de la partie (stades, niveau, membres du club…).
- L'écriture dans Steam Cloud est groupée (au plus toutes les 20 s, et en quittant).
- « Recommencer à zéro » efface aussi le fichier du Cloud. Les succès déjà envoyés à
  Steam y restent (Steam ne les retire pas).
- Lancer avec `-- --sans-steam` pour tester le jeu comme si Steam n'était pas là.

## Ajouter un succès

1. Une ligne dans `Succes.LISTE` (id en MAJUSCULES, condition `cle` + `seuil`).
2. Si la condition est nouvelle, l'ajouter dans `Game.etat_succes()`.
3. Refaire les icônes, puis créer le succès dans Steamworks (ci-dessous).

## À faire dans Steamworks (quand le jeu aura son App ID)

Avec l'App ID de test 480, les succès du jeu n'existent pas chez Steam : les appels
échouent sans bruit et seul le suivi dans le jeu compte. Le jour où le jeu a son App ID :

1. Mettre le nouvel App ID dans `steam_appid.txt` et `Plateforme.APP_ID_STEAM`.
2. **Stats & Achievements → Achievements** : créer chaque succès du tableau ci-dessous
   avec exactement le même **API Name**, le nom et la description (français et anglais),
   et les deux icônes : `docs/steam/succes/<ID>.png` (gagné) et `<ID>_gris.png` (pas gagné).
   Aucun n'est caché.
3. **Steam Cloud** : *Byte quota per user* 10 Mo (la sauvegarde fait quelques dizaines
   de Ko), *Number of files allowed per user* 5. Ne pas activer l'Auto-Cloud : le jeu
   écrit lui-même son fichier (`sauvegarde.json`) par l'API.
4. **Publier** les changements Steamworks (Publish), puis tester avec Steam ouvert :
   gagner un succès, vérifier qu'il apparaît dans Steam ; jouer sur un PC, lancer sur
   un autre, vérifier que la partie suit.

## Les 30 succès

| API Name | Nom | Description | Name (EN) | Description (EN) |
|---|---|---|---|---|
| `PREMIER_DUEL` | Premier coup de chant | Joue ton premier duel. | First Chant | Play your first duel. |
| `PREMIERE_VICTOIRE` | Victoire en tribune | Gagne ton premier duel. | Stand Victory | Win your first duel. |
| `VICTOIRES_25` | Tribune redoutée | Gagne 25 duels. | Feared Stand | Win 25 duels. |
| `VICTOIRES_100` | Voix d'or | Gagne 100 duels. | Golden Voice | Win 100 duels. |
| `ARENE_VICTOIRE` | Roi de l'arène | Gagne une partie dans l'Arène. | King of the Arena | Win a match in the Arena. |
| `POUSSEE_VICTOIRE` | Jusqu'au but | Gagne une partie de Poussée. | All the Way | Win a Push match. |
| `EN_LIGNE_VICTOIRE` | Plus fort que les autres | Gagne contre un vrai joueur en ligne. | Louder Than the Rest | Beat a real player online. |
| `EN_LIGNE_10` | Terreur des virages | Gagne 10 parties en ligne. | Terror of the Stands | Win 10 online matches. |
| `CLUB_CREE` | Le club est né | Fonde ton fan club. | A Club Is Born | Found your fan club. |
| `CLUB_QUARTIER` | Club de quartier | Réunis 9 FANZZY dans ton fan club. | Neighbourhood Club | Gather 9 FANZZY in your fan club. |
| `CLUB_LEGENDE` | Légende du virage | Réunis 18 FANZZY dans ton fan club. | Legend of the Stands | Gather 18 FANZZY in your fan club. |
| `FAVORI` | Un cœur, un club | Choisis une équipe favorite. | One Heart, One Club | Pick a favourite team. |
| `NIVEAU_10` | Supporter confirmé | Atteins le niveau 10. | True Supporter | Reach level 10. |
| `NIVEAU_25` | Pilier de tribune | Atteins le niveau 25. | Pillar of the Stand | Reach level 25. |
| `STADE_1` | Premier tampon | Visite ton premier stade. | First Stamp | Visit your first stadium. |
| `STADES_10` | Globe-trotteur | Visite 10 stades. | Globetrotter | Visit 10 stadiums. |
| `STADES_50` | Grand voyageur | Visite 50 stades. | Great Traveller | Visit 50 stadiums. |
| `PAYS_5` | Passeport bien rempli | Visite des stades dans 5 pays. | Stamped Passport | Visit stadiums in 5 countries. |
| `CONTINENTS_3` | Tour du monde | Visite des stades sur 3 continents. | Around the World | Visit stadiums on 3 continents. |
| `CONTINENTS_5` | Fan sans frontières | Visite des stades sur 5 continents. | Fan Without Borders | Visit stadiums on 5 continents. |
| `SUIVI_PARTOUT` | Fan partout | Suis un match au stade, sur écran géant, au pub et à la maison. | Fan Everywhere | Follow a match at the stadium, on a big screen, at the pub and at home. |
| `DERBY` | Toute la ville en parle | Joue un duel sur un derby. | The Whole Town Is Talking | Play a duel on a derby. |
| `FINALE` | Soir de finale | Joue un duel sur une finale. | Final Night | Play a duel on a final. |
| `PRONO_EXACT` | Voyant | Trouve le score exact d'un match. | Fortune Teller | Predict the exact score of a match. |
| `PRONO_SERIE_5` | Série en or | Trouve 5 bons résultats d'affilée. | Golden Streak | Get 5 correct results in a row. |
| `BOULOTS_TOUS` | Touche-à-tout | Essaie chacun des petits boulots. | Jack of All Trades | Try every odd job. |
| `BOULOTS_50` | Gros bosseur | Fais 50 parties de petits boulots. | Hard Worker | Play 50 odd jobs. |
| `MISSIONS_20` | Toujours partant | Récupère 20 récompenses de missions. | Always Up For It | Claim 20 mission rewards. |
| `ALBUM_25` | Album bien garni | Fais entrer 25 FANZZY dans ton album. | Full Album | Add 25 FANZZY to your album. |
| `PRIMES_10` | Chasseur de primes | Réclame 10 primes de collection. | Bounty Hunter | Claim 10 collection rewards. |

Les icônes sont faites à partir des pictogrammes du jeu (8 dessins, couleurs
différentes) ; elles pourront être remplacées par des dessins propres à chaque succès
plus tard sans toucher au code.
