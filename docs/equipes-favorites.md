# Équipes favorites et popularité

## Le choix

- **Un club favori par pays** (autant de pays que tu veux) et **une équipe nationale**.
- Choix dans l'écran **Mes équipes** (bouton *Équipes* de la carte) ou depuis la fiche d'un match
  (*En faire mon club favori*). Dans la fiche, ton favori est choisi d'office comme camp supporté.
- Un favori peut être changé (ou retiré) **une fois par semaine**. Les points déjà donnés restent à l'équipe.
- Les sélections de jeunes et féminines ne comptent pas comme équipe nationale.
- La liste des clubs vient du relais (`teams.json`, relu chaque lundi) et des matchs déjà vus.
  Noms et écussons sont toujours les versions fictives du jeu.

## Gagner de la popularité pour ses équipes

| Action | Points |
|---|---|
| Duel (ambiance, Arène, Poussée) pour ton favori | 10, +10 si gagné, × lieu (stade ×1,5, écran ×1,2, pub ×1, maison ×0,6) |
| Partir suivre son match (une fois par match) | stade 20, écran géant 8, pub 5, maison 2 |
| Pronostic sur son match | 3, +7 bon résultat, +10 score exact |
| Récolte du fan club | +1 par tranche de 10 Jetons récoltés, pour chaque favori (30 max) |

Plafond : 200 points par équipe et par jour. Les Jetons du joueur ne changent pas.

## Le classement

Trois vues : clubs du monde, clubs d'un pays, sélections. Score = points des autres supporters +
tes points. Les autres supporters viennent du **classement en ligne** (voir [classement.md](classement.md)) ;
sans réseau, ils sont simulés (`Supporters.base_communaute`).
