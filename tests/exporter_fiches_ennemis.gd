extends SceneTree
## Relève les vraies valeurs des ennemis du jeu pour leurs fiches techniques (outils/fiches_ennemis.py) :
## pour chaque sous-classe de gobelin, N tirages au premier étage (bornes des caractéristiques et des statistiques),
## leurs compétences (coût, dés, dégâts moyens contre le héros de départ, altérations, ciblage), et le Chevalier de
## la mort. Écrit user://fiches_ennemis.json (chemin affiché). Lancé par outils/fiches_ennemis.py :
##   Godot --headless --path . -s tests/exporter_fiches_ennemis.gd

const N := 300
const SOUS_CLASSES := [["guerrier", "combattant"], ["guerrier", "lancier"], ["guerrier", "defenseur"],
	["guerrier", "archer"], ["mage", "sorcier"], ["mage", "feticheur"], ["soutien", "chaman"]]
const STATS := ["points_de_vie_max", "endurance", "force", "dextérité", "intelligence", "sagesse", "armure",
	"chance_esquive", "chance_de_toucher", "chance_de_coup_critique", "degats_critique", "chance_de_coup_critique_magique",
	"degats_critique_magiques", "chance_de_parer", "mana_max", "regen_de_mana", "puissance_magique", "resistance_magique",
	"resistance_elementaire", "points_d_action_max"]
## Compétences que l'IA choisit (Ennemis.mecanique_ennemis) : elle va les chercher même si elles ne sont pas dans la
## liste de départ (Ennemis._competence).
const IA := {"combattant": ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre"], "lancier": ["Coup_de_lance", "Perforation", "Rafale_de_lance"],
	"archer": ["Précision", "Tir", "Tir_precis", "Tir_empoisonne"],
	"defenseur": ["Coup_de_gourdin", "Protection", "Grand_coup_de_gourdin"],
	"sorcier": ["Boule_de_feu", "Trait_des_Ombres", "Projectile_des_ombres", "Coup_de_baton"],
	"feticheur": ["Caresse_des_ombres", "Enflammer", "Silence", "Projectile_des_ombres", "Soin_mineur"],
	"chaman": ["Soin_mineur", "Recupe", "Boule_de_feu"]}
## Résistances et vulnérabilités en pourcentage, au format des fiches : {type: points} (négatif = faiblesse).
static func _pourcentages(e) -> Dictionary:
	var p := Degats.pourcentages(e)
	var res := {}
	for t in p["resistances"]:
		res[t] = roundf(p["resistances"][t] * 100)
	for t in p["vulnerabilites"]:
		res[t] = res.get(t, 0.0) - roundf(p["vulnerabilites"][t] * 100)
	return res


func _initialize() -> void:
	seed(12345)
	Sauvegarde.reinitialiser_monde()
	Objet.compteur_etage_objet = 1
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	var sortie := {"gobelins": {}, "chevalier": {}, "communs": {
		"pv_par_endurance": Ennemis.PV_PAR_ENDURANCE, "multiplicateur_degats": Ennemis.MULTIPLICATEUR_DEGATS_ENNEMIS,
		"mini_boss": Ennemis.MINI_BOSS, "boss": Ennemis.BOSS, "heros_pv": heros.points_de_vie_max,
		"heros_armure": heros.armure, "heros_resistance_magique": U.num(heros, "resistance_magique"),
		"vitesse_ronde": PresencesSalle.VITESSE_RONDE, "vitesse_poursuite": PresencesSalle.VITESSE_POURSUITE,
		"vue": PresencesSalle.VUE, "angle_vue": PresencesSalle.ANGLE_VUE, "perte": PresencesSalle.PERTE,
		"ouie": [PresencesSalle.OUIE_COURSE, PresencesSalle.OUIE_MARCHE, PresencesSalle.OUIE_CACHE],
		"duree_recherche": PresencesSalle.DUREE_RECHERCHE, "chance_suivre": Aventure.CHANCE_SUIVRE,
		"groupes_par_salle": Aventure.GROUPES_PAR_SALLE, "chance_elite": Zones.reglages("")["chance_elite"],
		"chance_pacifique": Zones.reglages("")["chance_pacifique"], "ennemis_par_etage": Donjon.ENNEMIS_PAR_ETAGE,
		"chevaliers": Aventure.CHEVALIERS_PAR_ETAGE, "geoliers": Aventure.GEOLIERS_PAR_ETAGE,
		"diablotins": Aventure.DIABLOTINS_PAR_ETAGE, "mensonge": Rencontres.CHANCE_MENSONGE,
		"confiscation": Aventure.CONFISCATION, "objets_par_porteur": Aventure.OBJETS_PAR_PORTEUR,
		"duree_salle": Aventure.DUREE_SALLE, "traversee": Aventure.TRAVERSEE, "vitesse_salle": Aventure.VITESSE_SALLE,
		"ecart_vacarme": Aventure.ECART_VACARME, "traque": Aventure.TRAQUE_SALLES, "pactes": Aventure.PACTES,
		"noms_pactes": Aventure.NOMS_PACTES, "etages_succube": Aventure.ETAGES_SUCCUBE,
		"fuite": [Aventure.FUITE_BASE, Aventure.FUITE_PAR_DEXTERITE, Aventure.FUITE_PAR_ENNEMI, Aventure.FUITE_BORNES],
		"fuite_boss": Aventure.FUITE_BOSS, "faiblesse_boss": -roundi(Aventure.FAIBLESSE_BOSS * 100), "force_boss": roundi(Aventure.FORCE_BOSS * 100),
		"chance_soin_ia": Ennemis.CHANCE_SOIN_IA,
		"marche_geolier": PresencesSalle.vitesse_marche("geolier", {"genre": "geolier"}),
		"marche_chevalier": PresencesSalle.vitesse_marche("chevalier", {"genre": "imbattable"}), "taille_gobelin": PresencesSalle.TAILLE_GOBELIN}}
	for cs in SOUS_CLASSES:
		var bornes := {}
		var res := {}
		for _i in N:
			var g := Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, cs)
			for s in STATS:
				var v := float(U.num(g, s))
				if not bornes.has(s):
					bornes[s] = [v, v]
				bornes[s] = [minf(bornes[s][0], v), maxf(bornes[s][1], v)]
			res.merge(_pourcentages(g), true)
		var g := Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, cs)
		var comps := []
		var vues := []
		for c in g.competences:
			var fiche := _competence(g, c, heros)
			fiche["ia"] = c.nom_classe in IA.get(cs[1], [])
			fiche["depart"] = true
			comps.append(fiche)
			vues.append(c.nom_classe)
		for nom in IA.get(cs[1], []):
			if not nom in vues:
				var fiche := _competence(g, Competences.creer(nom), heros)
				fiche["ia"] = true
				fiche["depart"] = false
				comps.append(fiche)
		# Compétences que l'IA va chercher sans les avoir dans sa liste de départ (Ennemis._competence)
		sortie["gobelins"][cs[1]] = {"classe": cs[0], "stats": bornes, "resistances": res, "competences": comps,
			"secours": Ennemis.ATTAQUES_DE_SECOURS.get(cs[1], []), "images": Ennemis.IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(cs[1], []),
			"anime": CombatAnime.type_gobelin(g), "orientation": Ennemis.ORIENTATION_PAR_CLASSE.get(cs[0], "")}
	sortie["creatures"] = {}
	for sorte in Creatures.SORTES:
		var bornes := {}
		for _i in N:
			var e := Creatures.creer(donjon, sorte)
			for st in STATS:
				var v := float(U.num(e, st))
				if not bornes.has(st):
					bornes[st] = [v, v]
				bornes[st] = [minf(bornes[st][0], v), maxf(bornes[st][1], v)]
		var e := Creatures.creer(donjon, sorte)
		var res := _pourcentages(e)
		sortie["creatures"][sorte] = {"stats": bornes, "resistances": res, "competences": [_competence(e, e.competences[0], heros)],
			"type_ennemi": e.type_ennemi, "image": e.image}
	sortie["communs"]["chance_groupe_squelettes"] = _part(Zones.reglages("")["ennemis"], "squelette")
	sortie["communs"]["chance_feticheur_squelettes"] = Zones.reglages("")["chance_feticheur"]
	sortie["communs"]["chance_loup"] = Zones.reglages("")["chance_loup"]
	sortie["communs"]["zones"] = Zones.donnees()
	sortie["communs"]["vitesse_squelettes"] = Aventure.VITESSE_SQUELETTES
	sortie["communs"]["chevalier_des"] = Aventure.CHEVALIER["des"]
	sortie["communs"]["chevalier_usure"] = Aventure.CHEVALIER["usure"]
	sortie["communs"]["chevalier_vol_mana"] = Aventure.CHEVALIER["vol_mana"]
	var k := Aventure.creer_imbattable(donjon)
	var stats_k := {}
	for s in STATS:
		stats_k[s] = float(U.num(k, s))
	sortie["chevalier"] = {"stats": stats_k, "competences": [_competence(k, k.competences[0], heros)],
		"anime": CombatAnime.type_gobelin(k)}
	var f := FileAccess.open("user://fiches_ennemis.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sortie, " "))
	f.close()
	print("FICHES ", ProjectSettings.globalize_path("user://fiches_ennemis.json"))
	quit()


func _competence(lanceur, c, heros) -> Dictionary:
	var des := {}
	for t in c.type_degats:
		var d := Formules.des_type(lanceur, t, c)
		if not d.is_empty():
			des[t] = Formules.texte(d)
	var degats := []
	for e in Formules.estimer_degats(lanceur, c, heros, false):
		degats.append([e[0], snappedf(e[1], 0.1), snappedf(e[2], 0.1)])
	var alt := {}
	var ta = U.ga(c, "type_alteration", {})
	if ta is Dictionary:
		for nom in ta:
			if float(ta[nom]) > 0:
				alt[nom] = ta[nom]
	return {"nom": c.nom, "classe": c.nom_classe, "pa": c.cout_action, "mana": c.cout_mana,
		"type": c.type_competence, "attaque": c.type_attaque, "types_degats": c.type_degats, "des": des,
		"degats": degats, "ciblage": c.type_ciblage, "cibles": c.nombre_cible,
		"coups": U.num(c, "nombre_attaque"), "alterations": alt, "description": str(U.ga(c, "description", ""))}


## Part d'une sorte dans une table {sorte: poids} (zones.json).
func _part(table: Dictionary, sorte: String) -> float:
	var total := 0.0
	for k in table:
		total += float(table[k])
	return float(table.get(sorte, 0)) / total if total > 0 else 0.0
