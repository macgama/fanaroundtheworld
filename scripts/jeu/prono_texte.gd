class_name PronoTexte
extends RefCounted
## Textes d'affichage d'un pronostic (fiche du match et écran « Mes pronos »).


static func resume(p: Dictionary, dom: String, ext: String) -> String:
	var pb := str(p.get("premier_but", ""))
	var qui := "aucun but" if pb == "aucun" else (dom if pb == "home" else ext)
	return "%d – %d · 1er but : %s" % [int(p.get("dom", 0)), int(p.get("ext", 0)), qui]


static func etat(p: Dictionary) -> String:
	match str(p.get("etat", "attente")):
		"annule":
			return "Match annulé ou reporté : pronostic retiré, ta série ne bouge pas."
		"gagne", "perdu":
			var sr: Dictionary = p.get("score_reel", {})
			var bouts: Array = []
			bouts.append("résultat " + ("OK" if p.get("resultat_ok", false) else "raté"))
			bouts.append("score exact " + ("OK" if p.get("score_ok", false) else "raté"))
			if str(p.get("premier_but_reel", "")) == "":
				bouts.append("premier but inconnu")
			else:
				bouts.append("premier but " + ("OK" if p.get("premier_but_ok", false) else "raté"))
			var txt := "Score final %d – %d : %s." % [int(sr.get("home", 0)), int(sr.get("away", 0)), ", ".join(bouts)]
			var j := int(p.get("jetons", 0))
			if j > 0:
				txt += " +%d Jetons" % j
				if float(p.get("multi", 1.0)) > 1.0:
					txt += " (série ×%s)" % str(p["multi"])
			return txt
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if Donnees.en_direct(m):
		return "Match en cours : %s" % Donnees.score_texte(m)
	if str(m.get("status", "")) == "FINISHED":
		return "Match terminé, résultat bientôt validé."
	if int(p.get("kickoff", 0)) > int(Time.get_unix_time_from_system()):
		return "Modifiable jusqu'au coup d'envoi (%s %s)." % [FicheMatch.date_texte(int(p["kickoff"])), FicheMatch.heure_texte(int(p["kickoff"]))]
	return "En attente du résultat."
