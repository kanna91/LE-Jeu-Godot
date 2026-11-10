extends SceneTree
## Bibliothèque et laboratoire d'alchimie en niveaux à part (2026-11-10, demande de l'utilisateur) : comme les
## cryptes, chacun est un niveau unique séparé du reste du donjon ; chaque entrée du bloc est un passage (porte marquée
## comme celle des cryptes) vers une salle ordinaire de l'étage, et inversement.
## - ni bibliothèque ni laboratoire sur l'étage (la cuisine y reste) ;
## - le niveau a toutes les salles du bloc, avec les liens du bloc, et rien d'autre ;
## - chaque entrée a son passage, relié à une salle de l'étage dont l'image a une porte de ce côté (« passage »),
##   qui ramène à cette entrée ; les passages sont écartés les uns des autres ;
## - refuges : aucun ennemi ; l'enchanteur, l'armurier et l'alchimiste sont posés.
## godot --headless --path . -s tests/test_niveaux_blocs.gd

const DONJONS := 10
var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1110)
	var niveaux := {"bibliotheque": Donjon.NIVEAU_BIBLIOTHEQUE, "laboratoire": Donjon.NIVEAU_LABORATOIRE}
	for k in DONJONS:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		var etage: Dictionary = donjon.plan_donjon[1]
		for id in etage:
			verifier(not (etage[id].get("bloc", "") in niveaux), "salle %s de bloc à part sur l'étage" % id)
		verifier(etage.values().any(func(s): return s.get("bloc", "") == "cuisine"), "la cuisine reste sur l'étage")
		for nom in niveaux:
			var niveau: int = niveaux[nom]
			var b: Dictionary = BlocsSalles.BLOCS[nom]
			verifier(donjon.plan_donjon.has(niveau), "%s : niveau %d créé" % [nom, niveau])
			var salles: Dictionary = donjon.plan_donjon.get(niveau, {})
			verifier(salles.size() == b["salles"].size(), "%s : %d salles (%d)" % [nom, b["salles"].size(), salles.size()])
			var par_cle := {}
			for id in salles:
				par_cle[salles[id]["bloc_salle"]] = id
			for l in b["liens"]:
				verifier(par_cle[l[2]] in salles[par_cle[l[0]]]["connections"], "%s : %s ↔ %s" % [nom, l[0], l[2]])
				verifier(str(salles[par_cle[l[0]]]["salle_peinte"]["sorties"][l[1]]) == par_cle[l[2]], "%s : porte %s → %s" % [nom, l[0], l[2]])
			var positions := []
			for e in b["entrees"]:
				var s: Dictionary = salles[par_cle[e[0]]]
				var lien: Dictionary = s.get("passage_niveau", {})
				verifier(int(s["salle_peinte"].get("passage", -1)) == e[1], "%s : entrée %s marquée passage" % [nom, e[0]])
				verifier(int(lien.get("niveau", 0)) == 1 and etage.has(String(lien.get("salle", ""))), "%s : entrée %s reliée à l'étage" % [nom, e[0]])
				if not etage.has(String(lien.get("salle", ""))):
					continue
				var dehors: Dictionary = etage[String(lien["salle"])]
				var retour: Dictionary = dehors.get("passage_niveau", {})
				verifier(int(retour.get("niveau", 0)) == niveau and String(retour.get("salle", "")) == par_cle[e[0]],
					"%s : la salle %s de l'étage ramène à %s" % [nom, lien["salle"], e[0]])
				verifier(int(dehors.get("salle_peinte", {}).get("passage", -1)) >= 0,
					"%s : la salle %s de l'étage a une porte de passage (image %s)" % [nom, lien["salle"], dehors.get("salle_peinte", {}).get("image", "")])
				verifier(not dehors.has("bloc") and not dehors.has("prison") and not dehors.get("boss", false) and not dehors.get("depart", false),
					"%s : passage dans une salle ordinaire" % nom)
				positions.append(dehors["position"])
			for i in positions.size():
				for j in range(i + 1, positions.size()):
					var ecart: int = absi(positions[i].x - positions[j].x) + absi(positions[i].y - positions[j].y)
					verifier(ecart >= 2, "%s : passages trop proches (%d cases)" % [nom, ecart])
			for id in salles:
				for p in salles[id].get("presences", []):
					verifier(not (p.get("genre", "") in Aventure.ENNEMIS) and not (p.get("genre", "") in Aventure.CHASSEURS),
						"%s : ennemi %s dans %s" % [nom, p.get("genre"), salles[id]["bloc_salle"]])
		var roles := []
		for niveau in niveaux.values():
			for id in donjon.plan_donjon[niveau]:
				for p in donjon.plan_donjon[niveau][id].get("presences", []):
					if p.get("sous", "") == "commis":
						roles.append(p.get("role", ""))
		for pnj in ["enchanteur", "armurier", "alchimiste"]:
			verifier(pnj in roles, "%s posé (donjon %d)" % [pnj, k])
	print("BILAN niveaux des blocs : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
