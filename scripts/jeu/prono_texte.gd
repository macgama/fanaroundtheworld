class_name PronoTexte
extends RefCounted
## Textes d'affichage d'un pronostic (fiche du match et écran « Mes pronos »).


static func resume(p: Dictionary, dom: String, ext: String) -> String:
	var pb := str(p.get("premier_but", ""))
	var qui := Trad.t("aucun but") if pb == "aucun" else (dom if pb == "home" else ext)
	return Trad.t("%d – %d · 1er but : %s") % [int(p.get("dom", 0)), int(p.get("ext", 0)), qui]


static func etat(p: Dictionary) -> String:
	match str(p.get("etat", "attente")):
		"annule":
			return Trad.t("Match annulé ou reporté : pronostic retiré, ta série ne bouge pas.")
		"gagne", "perdu":
			var sr: Dictionary = p.get("score_reel", {})
			var bouts: Array = []
			bouts.append(Trad.t("résultat ") + ("OK" if p.get("resultat_ok", false) else Trad.t("raté")))
			bouts.append(Trad.t("score exact ") + ("OK" if p.get("score_ok", false) else Trad.t("raté")))
			if str(p.get("premier_but_reel", "")) == "":
				bouts.append(Trad.t("premier but inconnu"))
			else:
				bouts.append(Trad.t("premier but ") + ("OK" if p.get("premier_but_ok", false) else Trad.t("raté")))
			var txt := Trad.t("Score final %d – %d : %s.") % [int(sr.get("home", 0)), int(sr.get("away", 0)), ", ".join(bouts)]
			var j := int(p.get("jetons", 0))
			if j > 0:
				txt += Trad.t(" +%d Jetons") % j
				if float(p.get("multi", 1.0)) > 1.0:
					txt += Trad.t(" (série ×%s)") % Trad.decimal(p["multi"])
			return txt
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if Donnees.en_direct(m):
		return Trad.t("Match en cours : %s") % Donnees.score_texte(m)
	if str(m.get("status", "")) == "FINISHED":  # sans_traduction
		return "Match terminé, résultat bientôt validé."
	if int(p.get("kickoff", 0)) > int(Time.get_unix_time_from_system()):
		return Trad.t("Modifiable jusqu'au coup d'envoi (%s %s).") % [FicheMatch.date_texte(int(p["kickoff"])), FicheMatch.heure_texte(int(p["kickoff"]))]
	return "En attente du résultat."
