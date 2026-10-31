extends SceneTree
## Donjon d'aventure (Aventure, Rencontres) : peuplement des étages, ennemis sans récompense, imbattables invulnérables,
## fuite, capture par un geôlier (confiscation), clés et salles verrouillées, personnages, sauvegarde.
## godot --headless --path godot -s tests/test_aventure.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	_lancer()


func _lancer() -> void:
	Ecrans.auto = true
	seed(42)
	Sauvegarde.reinitialiser_monde()
	_peuplement()
	_salles_paisibles()
	_recompenses()
	_imbattable_et_fuite()
	_capture()
	_arme_gardee()
	_cles_et_objets()
	await _personnages()
	_pactes()
	await _diablotins()
	await _glossaire_du_compte()
	_nouveautes_31_octobre()
	_sauvegarde()
	await _combat_fuite()
	print("BILAN aventure : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Salles avec un diablotin ou une succube : ni groupe ni porteur (chevalier et geôliers seulement), même après une
## capture ; les groupes écartés vont ailleurs (aucun perdu) ; un groupe qui poursuit le héros ne l'y suit pas.
func _salles_paisibles() -> void:
	var paisibles := 0
	var intrus := 0
	var perdus := 0
	for k in 20:
		var joueur := Personnage.nouveau()
		var donjon := Donjon.nouveau(joueur)
		var m := Aventure.meta(donjon, 1)
		Aventure.preparer_etage(donjon, 1)
		var salles: Dictionary = donjon.plan_donjon[1]
		var groupes := 0
		for i in salles:
			for p in salles[i].get("presences", []):
				if p["genre"] == "groupe":
					groupes += 1
		# Une capture crée des porteurs : jamais dans une salle paisible
		joueur.inventaire = [Arme.nouvelle("Epée", "arme", "Epée"), Arme.nouvelle("Lance", "arme", "Lance"),
			Arme.nouvelle("Marteau", "arme", "Marteau"), Arme.nouvelle("Epée", "arme", "Epée")]
		var geolier := {}
		for i in salles:
			for p in salles[i].get("presences", []):
				if p["genre"] == "geolier":
					geolier = p
		Aventure.capturer(donjon, geolier)
		var groupes_apres := 0
		for i in salles:
			var paisible := Aventure.salle_paisible(salles[i])
			if paisible:
				paisibles += 1
			for p in salles[i].get("presences", []):
				if p["genre"] == "groupe":
					groupes_apres += 1
				if paisible and p["genre"] in ["groupe", "porteur", "boss"]:
					intrus += 1
		perdus += groupes - groupes_apres
		if m.is_empty():
			pass
	print("  salles paisibles : %d sur 20 étages, intrus %d, groupes perdus %d" % [paisibles, intrus, perdus])
	verifier(paisibles >= 20 * 7 and intrus == 0, "diablotin ou succube : aucun autre ennemi dans leur salle")
	verifier(perdus == 0, "les groupes écartés vont dans d'autres salles (aucun perdu)")


func _compter(donjon, etage: int) -> Dictionary:
	var compte := {}
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			var cle: String = p["genre"] + ("/" + p["sous"] if p.has("sous") else "")
			compte[cle] = compte.get(cle, 0) + 1
	return compte


func _peuplement() -> void:
	var totaux := {}
	for k in 30:
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for etage in [1, 2]:
			if not donjon.plan_donjon.has(etage):
				donjon.generer_etage(etage)
			var c := _compter(donjon, etage)
			for cle in c:
				totaux[cle] = totaux.get(cle, 0) + c[cle]
			var salles: Dictionary = donjon.plan_donjon[etage]
			var m := Aventure.meta(donjon, etage)
			verifier(m.get("prepare", false), "étage préparé")
			verifier(c.get("boss", 0) == 1, "un boss par étage")
			verifier(c.get("geolier", 0) == Aventure.GEOLIERS_PAR_ETAGE, "geôliers par étage")
			verifier(c.get("imbattable", 0) == Aventure.CHEVALIERS_PAR_ETAGE, "un Chevalier de la mort à l'étage %d" % etage)
			verifier(salles.has(String(m.get("cachot", ""))) and salles[m["cachot"]].get("cachot", false), "salle du cachot")
			# Cachot loin du gardien : au moins aussi loin que la moitié des salles de l'étage
			var boss_id := ""
			for i in salles:
				if salles[i].get("boss", false):
					boss_id = i
			var db := Aventure.distances_depuis(salles, boss_id)
			var plus_pres := 0
			for i in salles:
				if db.get(i, 0) < db.get(String(m["cachot"]), 0):
					plus_pres += 1
			verifier(plus_pres >= salles.size() / 2, "cachot loin du gardien (%d salles plus près du gardien sur %d)" % [plus_pres, salles.size()])
			verifier(c.get("pnj/diablotin", 0) == 7, "7 diablotins à l'étage %d (%d)" % [etage, c.get("pnj/diablotin", 0)])
			var verrous := 0
			for i in salles:
				if salles[i].get("verrouillee", false):
					verrous += 1
					verifier(salles[i].get("type") == "bonus", "seules les salles bonus sont verrouillées")
				var s: Dictionary = salles[i]
				if s.get("depart", false) or s.get("cachot", false) or s.get("type") == "bonus":
					for p in s.get("presences", []):
						verifier(not (p["genre"] in ["groupe", "imbattable", "geolier"]), "pas d'ennemi au départ, au cachot ni en salle bonus")
			var cles := 0
			for i in salles:
				for p in salles[i].get("presences", []):
					if p.get("sous") == "cachette" and p.get("contenu") == "cle":
						cles += 1
			verifier(cles >= verrous, "assez de clés cachées pour les salles verrouillées (%d / %d)" % [cles, verrous])
			verifier(c.get("pnj/diablotin", 0) >= 1, "au moins un diablotin")
			verifier(c.get("pnj/succube", 0) == (1 if etage % 2 == 1 else 0), "une succube un étage sur deux (étage %d)" % etage)
			verifier(c.get("objet/pupitre", 0) <= 1 and c.get("objet/ratelier", 0) == 1, "au plus un pupitre, un râtelier")
	print("Présences sur 60 étages : %s" % totaux)


func _recompenses() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var or_avant = joueur.piece_or
	var inv_avant: int = joueur.inventaire.size()
	for k in 20:
		var g := Gobelin.nouveau(donjon, 1).generer_gobelin(donjon, 1)
		g.points_de_vie = 0
		g.mort_au_combat(donjon)
	verifier(joueur.piece_or == or_avant, "aucun or des ennemis")
	verifier(joueur.inventaire.size() == inv_avant, "aucun butin des ennemis ordinaires")
	var chef = Aventure.ennemis_de(donjon, {"genre": "groupe", "nombre": 1, "chef": true})[0]
	chef.points_de_vie = 0
	chef.mort_au_combat(donjon)
	verifier(joueur.inventaire.size() + joueur.equipements.values().filter(func(x): return x != null).size() > inv_avant, "le chef lâche un équipement")
	# Les gobelins affrontés sont ceux dessinés dans la salle (membres tirés une fois, gardés dans la présence)
	for genre in ["groupe", "porteur", "boss"]:
		for _essai in 10:
			var p := {"genre": genre, "nombre": randi_range(1, 3), "chef": randf() < 0.5}
			var tires := Aventure.membres(p).duplicate(true)
			var memes := true
			for _fois in 2:
				var liste := Aventure.ennemis_de(donjon, p)
				memes = memes and liste.size() == tires.size()
				for k in mini(liste.size(), tires.size()):
					memes = memes and liste[k].sous_classe == tires[k]["sous_classe"] and liste[k].image == tires[k]["image"]
			verifier(memes, "%s : le combat oppose les gobelins dessinés dans la salle" % genre)


func _imbattable_et_fuite() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var e = Aventure.creer_imbattable(donjon)
	var combat := Combat.nouveau(joueur, null, [e], donjon)
	var pv = e.points_de_vie
	verifier(pv == 300 and e.nom == "Chevalier de la mort", "Chevalier de la mort : 300 PV")
	EffetsCombat.critique = false
	for k in 20:
		var avant = e.points_de_vie
		Degats.recevoir(["tranchant", "feu", "ombre"][k % 3], e, 500, 0, 0, combat)
		verifier(avant - e.points_de_vie in [1, 2], "Chevalier : un coup ramené à 1 ou 2 dégâts (%d)" % (avant - e.points_de_vie))
	EffetsCombat.critique = true
	var avant_crit = e.points_de_vie
	Degats.recevoir("tranchant", e, 500, 0, 0, combat)
	verifier(avant_crit - e.points_de_vie == 3, "Chevalier : 3 dégâts sur un critique")
	EffetsCombat.critique = false
	verifier(Formules.des_type(e, "tranchant") == [[12, 2]] and Formules.des_type(e, "ombre") == [[6, 2]], "Chevalier : frappe 12d2 tranchant + 6d2 ombre")
	verifier(e.competences.size() == 1 and e.competences[0].type_degats == ["tranchant", "ombre"], "Chevalier : une lame tranchant et ombre")
	verifier(CombatAnime.type_gobelin(e) == "chevalier", "Chevalier : ses propres animations de combat, pas celles du gobelin")
	# Chaque coup qui touche : Usure une fois sur deux, 6d2 de mana retirés (demande de l'utilisateur, 2026-10-27)
	var touches := 0
	var usures := 0
	var pertes := []
	for _i in 400:
		var h := Personnage.nouveau()
		h.points_de_vie_max = 9999
		h.points_de_vie = 9999
		h.mana_max = 99
		h.mana = 99
		var k := Aventure.creer_imbattable(donjon)
		var cb := Combat.nouveau(h, null, [k], donjon)
		cb.infliger_degats(k, k.competences[0], h, h)
		if h.points_de_vie < 9999:
			touches += 1
			pertes.append(99 - h.mana)
			if h.a_l_alteration("usure"):
				usures += 1
	var p_usure := float(usures) / maxi(1, touches)
	print("  Chevalier : %d coups touchés sur 400, Usure %d %%, mana retiré %d à %d" % [touches, roundi(p_usure * 100), pertes.min(), pertes.max()])
	verifier(p_usure >= 0.42 and p_usure <= 0.75, "Chevalier : Usure environ une fois sur deux (et parfois par le tranchant)")
	verifier(pertes.min() >= 6 and pertes.max() <= 12, "Chevalier : 6d2 de mana retirés à chaque coup qui touche")
	# Chasseurs : le chevalier part du milieu de l'étage, tous errent, un combat les attire, le vacarme rapproche le
	# chevalier (téléporté à 3 salles) et dirige les geôliers vers la salle du bruit
	var etage := 2
	if not donjon.plan_donjon.has(etage):
		donjon.generer_etage(etage)
	donjon.salle_actuelle = [etage, 1]
	Aventure.preparer_etage(donjon, etage)
	var salles: Dictionary = donjon.plan_donjon[etage]
	# Coffre du gardien (2026-10-30) : classe du gardien tirée avec l'étage, coffre ancien avec l'armure anti-boss
	var m_gardien := Aventure.meta(donjon, etage)
	var coffres := []
	var gardiens := []
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.get("sous") == "coffre_gardien":
				coffres.append(p)
			if p["genre"] == "boss":
				gardiens.append(p)
	verifier(coffres.size() == 1 and m_gardien.has("boss_type_degats"), "un coffre ancien par étage")
	verifier(gardiens.size() == 1 and gardiens[0].has("membres"), "classe du gardien tirée avec l'étage")
	if coffres.size() == 1 and gardiens.size() == 1:
		var mb: Dictionary = gardiens[0]["membres"][0]
		var t: String = coffres[0]["type_degats"]
		verifier(t == Gobelin.type_degats_principal(mb["classe"], mb["sous_classe"]), "le coffre suit le type de dégâts du gardien (%s, %s)" % [mb["sous_classe"], t])
		var anti = GenerationObjets.generer_anti_boss(t, 2)
		verifier(U.num(anti, "resistance_" + t) == 6 and is_equal_approx(U.num(anti, "resistance_pct_" + t), 0.20)
			and String(anti.nom).ends_with("anti-" + t), "armure anti-boss : +6 et 20 %% contre %s (%s)" % [t, anti.nom])
	# Objets : une seule option, plus de régénération, d'esquive, de critique, de PV ni de résistance spécifique
	var une_option := true
	for _k in 300:
		var o = GenerationObjets.generer_objet()
		if not U.ga(o, "option", "") in ["caracteristique", "defense", "degats", "penetration"]:
			une_option = false
		for attr in ["regen_de_points_de_vie", "regen_de_mana", "chance_esquive", "chance_de_toucher", "chance_de_coup_critique",
				"points_de_vie_max", "resistance_feu", "resistance_tranchant", "resistance_pct_feu", "pourcentage_degats_feu"]:
			if U.num(o, attr) != 0:
				une_option = false
	verifier(une_option, "objets générés : une seule option, sans statistiques retirées")
	# Donjon complet dès le départ (5 étages), quartier des prisons opposé au gardien, cachot dans une cellule (2026-10-30)
	var neuf = Donjon.nouveau(Personnage.nouveau())
	verifier(neuf.plan_donjon.size() == Donjon.NOMBRE_ETAGES, "les %d étages existent dès le départ" % Donjon.NOMBRE_ETAGES)
	var prisons_ok := true
	var cachots_ok := true
	for et in neuf.plan_donjon:
		var sl: Dictionary = neuf.plan_donjon[et]
		var q := PlanSalles.quartier_prisons(sl)
		for i in sl:
			if PlanSalles.est_prison(String(sl[i]["salle_peinte"]["image"])) and not q.has(String(i)):
				prisons_ok = false
		var cachot := String(Aventure.meta(neuf, et).get("cachot", ""))
		if cachot == "" or not PlanSalles.est_prison(String(sl[cachot]["salle_peinte"]["image"])) or not q.has(cachot):
			cachots_ok = false
	verifier(prisons_ok, "toutes les prisons sont dans le quartier opposé au gardien")
	verifier(cachots_ok, "le cachot est une cellule du quartier des prisons")
	var chevalier := {}
	var depart_chevalier := ""
	for c in Aventure.chasseurs(donjon, etage):
		if c[0]["genre"] == "imbattable":
			chevalier = c[0]
			depart_chevalier = c[1]
	var ecart_milieu: int = Aventure.distances_depuis(salles, depart_chevalier).values().max()
	var ecart_min := 1 << 20
	for i in Aventure.salles_ordinaires(donjon, etage):
		ecart_min = mini(ecart_min, Aventure.distances_depuis(salles, i).values().max())
	verifier(ecart_milieu == ecart_min, "le chevalier part du milieu de l'étage (%d salles au plus de tout)" % ecart_milieu)
	# Errance : en 10 minutes de jeu, chacun visite plusieurs salles, jamais celle du gardien
	var visitees := {}
	var ici := ""
	for i in Aventure.salles_ordinaires(donjon, etage):
		var dist_c: int = Aventure.distances_depuis(salles, i).get(depart_chevalier, 0)
		if dist_c >= 6:
			ici = i
			break
	donjon.salle_actuelle = [etage, int(ici)]
	for t in 600:
		for c in Aventure.avancer_chasseurs(donjon, 1.0):
			pass
		for c in Aventure.chasseurs(donjon, etage):
			verifier(not salles[c[1]].get("boss", false), "jamais dans la salle du gardien")
			if not visitees.has(c[0]["id"]):
				visitees[c[0]["id"]] = {}
			visitees[c[0]["id"]][c[1]] = true
	for id in visitees:
		verifier(visitees[id].size() >= 5, "un chasseur erre de salle en salle (%d salles en 10 min)" % visitees[id].size())
	print("Errance (10 min) : salles visitées par chasseur %s" % str(visitees.values().map(func(v): return v.size())))
	# Combat : tous se dirigent vers la salle du héros et finissent par y entrer
	var loin := ""
	for i in Aventure.salles_ordinaires(donjon, etage):
		var plus_pres := 1 << 20
		for c in Aventure.chasseurs(donjon, etage):
			plus_pres = mini(plus_pres, Aventure.distances_depuis(salles, i).get(c[1], 0))
		if plus_pres >= 4:
			loin = i
			break
	if loin != "":
		donjon.salle_actuelle = [etage, int(loin)]
		Aventure.attirer(donjon)
		var entres := {}
		for t in 400:
			for c in Aventure.avancer_chasseurs(donjon, 1.0):
				entres[c[0]["id"]] = c[0].get("cherche", false)
		verifier(entres.size() == Aventure.chasseurs(donjon, etage).size(), "combat : tous les chasseurs arrivent dans la salle (%d/%d)" % [
			entres.size(), Aventure.chasseurs(donjon, etage).size()])
		verifier(entres.values().all(func(v): return v), "combat : ils savent où est le héros en entrant")
	# Vacarme : chevalier loin (> 3 salles) téléporté à exactement 3 salles ; geôliers non téléportés, dirigés vers le bruit
	var bruit_ici := ""
	for i in Aventure.salles_ordinaires(donjon, etage):
		if Aventure.distances_depuis(salles, i).get(Aventure.chasseurs(donjon, etage)[0][1], 0) > 6:
			bruit_ici = i
			break
	if bruit_ici != "":
		donjon.salle_actuelle = [etage, int(bruit_ici)]
		var avant := {}
		for c in Aventure.chasseurs(donjon, etage):
			c[0].erase("but")
			avant[c[0]["id"]] = c[1]
		var dist := Aventure.distances_depuis(salles, bruit_ici)
		var etait_loin: bool = dist.get(avant[chevalier["id"]], 0) > Aventure.ECART_VACARME
		verifier(Aventure.vacarme(donjon) == 1, "vacarme : le chevalier est alerté")
		for c in Aventure.chasseurs(donjon, etage):
			verifier(str(c[0].get("but", "")) == bruit_ici or c[1] == bruit_ici, "vacarme : %s se dirige vers le bruit" % c[0]["genre"])
			if c[0]["genre"] == "imbattable" and etait_loin:
				verifier(dist[c[1]] == Aventure.ECART_VACARME, "vacarme : chevalier téléporté à 3 salles (%d)" % dist[c[1]])
			elif c[0]["genre"] == "geolier":
				verifier(c[1] == avant[c[0]["id"]], "vacarme : le geôlier ne se téléporte pas")
	verifier(Aventure.duree_salle({"genre": "geolier"}) == 6.0, "geôlier : 6 s par salle")
	verifier(int(Aventure.duree_salle(chevalier)) == 9, "chevalier : environ 9 s par salle (%.1f)" % Aventure.duree_salle(chevalier))
	var un := Aventure.chance_fuite(joueur, [Gobelin.nouveau(donjon).generer_gobelin()])
	var trois := Aventure.chance_fuite(joueur, [Gobelin.nouveau(donjon).generer_gobelin(), Gobelin.nouveau(donjon).generer_gobelin(),
		Gobelin.nouveau(donjon).generer_gobelin()])
	verifier(un > trois, "plus d'ennemis, fuite plus dure")
	verifier(Aventure.chance_fuite(joueur, Aventure.ennemis_de(donjon, {"genre": "boss"})) == Aventure.FUITE_BOSS, "fuite d'un boss")
	var reussies := 0
	for k in 2000:
		var c := Combat.nouveau(joueur, null, [Gobelin.nouveau(donjon).generer_gobelin()], donjon)
		if c.tenter_fuite():
			reussies += 1
			verifier(c.issue == "fuite", "issue « fuite »")
	print("Fuite contre un gobelin : %.1f %% (attendu %.1f %%)" % [reussies / 20.0, un * 100])
	verifier(absf(reussies / 2000.0 - un) < 0.04, "fréquence de la fuite")


func _capture() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	joueur.piece_or = 77
	var nb_objets: int = joueur.inventaire.size()
	for v in joueur.equipements.values():
		if v != null:
			nb_objets += 1
	var etage := 1
	var geolier := {}
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p["genre"] == "geolier":
				geolier = p
	verifier(not geolier.is_empty(), "il y a un geôlier")
	var arme = joueur.arme_equipee
	var message: String = Aventure.capturer(donjon, geolier)
	verifier(message != "", "message de capture")
	# La lance de test (« god mode ») n'est jamais confisquée (demande de l'utilisateur, 2026-10-29)
	verifier(joueur.inventaire.size() == 1 and Arme.est_lance_de_test(joueur.inventaire[0]), "la lance de test reste dans le sac")
	verifier(joueur.piece_or == 0, "héros dépouillé")
	for v in joueur.equipements.values():
		verifier(v == null, "plus rien d'équipé")
	var m := Aventure.meta(donjon, etage)
	verifier(str(donjon.salle_actuelle[1]) == String(m["cachot"]), "réveil au cachot")
	var retrouves := 0
	var or_retrouve := 0
	var geoliers := 0
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p.get("sous") == "coffre_confisque" or p["genre"] == "porteur":
				retrouves += p.get("objets", []).size()
				or_retrouve += int(p.get("or", 0))
			if p["genre"] == "geolier":
				geoliers += 1
				verifier(i != m["cachot"], "le geôlier n'est pas au cachot")
	verifier(geoliers == Aventure.GEOLIERS_PAR_ETAGE, "les geôliers ne sont pas dupliqués")
	verifier(or_retrouve == 77, "l'or est dans le coffre des confiscations")
	verifier(retrouves <= nb_objets, "pas d'objet en trop")
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			for o in p.get("objets", []):
				verifier(not Arme.est_lance_de_test(o), "la lance de test n'est ni au coffre ni chez un porteur")
	print("Capture : %d objet(s) sur %d récupérables (coffre + porteurs)" % [retrouves, nb_objets])
	# Le coffre rend tout
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p.get("sous") == "coffre_confisque":
				Aventure.utiliser_objet(donjon, p)
	verifier(joueur.piece_or == 77, "le coffre rend l'or")
	verifier(arme == null or joueur.arme_equipee == arme, "l'arme est toujours dans le coffre et rééquipée")


## L'arme portée n'est jamais perdue ni confiée à un porteur : elle est toujours dans le coffre des confiscations.
func _arme_gardee() -> void:
	for k in 40:
		var joueur := Personnage.nouveau()
		var donjon := Donjon.nouveau(joueur)
		var arme = joueur.arme_equipee
		var geolier := {}
		for i in donjon.plan_donjon[1]:
			for p in donjon.plan_donjon[1][i].get("presences", []):
				if p["genre"] == "geolier":
					geolier = p
		Aventure.capturer(donjon, geolier)
		var dans_coffre := false
		for i in donjon.plan_donjon[1]:
			for p in donjon.plan_donjon[1][i].get("presences", []):
				if p.get("sous") == "coffre_confisque" and arme in p.get("objets", []):
					dans_coffre = true
		verifier(arme == null or dans_coffre, "l'arme est dans le coffre des confiscations")


func _cles_et_objets() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var verrouillee := ""
	for i in donjon.plan_donjon[1]:
		if donjon.plan_donjon[1][i].get("verrouillee", false):
			verrouillee = i
	if verrouillee == "":
		print("(pas de salle verrouillée à l'étage 1 avec cette graine)")
		return
	verifier(Aventure.verrouillee(donjon, verrouillee), "salle verrouillée")
	verifier(not Aventure.ouvrir_verrou(donjon, verrouillee)[0], "pas de clé : porte fermée")
	Aventure.utiliser_objet(donjon, {"genre": "objet", "sous": "cachette", "contenu": "cle", "etat": "actif"})
	verifier(joueur.cles == 1, "une clé trouvée")
	verifier(Aventure.ouvrir_verrou(donjon, verrouillee)[0] and joueur.cles == 0, "la clé ouvre la porte")
	verifier(not Aventure.verrouillee(donjon, verrouillee), "salle ouverte")
	var a_apprendre: int = joueur.nouvelle_magie_a_apprendre
	var connus: int = joueur.magies_apprises.size()
	var msg: String = Aventure.utiliser_objet(donjon, {"genre": "objet", "sous": "pupitre", "etat": "actif"})
	print("Grimoire : %s" % msg)
	verifier(joueur.magies_apprises.size() == connus + 1, "le grimoire apprend un sort")
	verifier(joueur.nouvelle_magie_a_apprendre == a_apprendre, "plus de point de magie à choisir")
	var appris = joueur.magies_apprises[-1]
	var investis := 0
	for niveau in appris.ameliorations_possibles:
		for o in niveau:
			investis += Competence.points_investis(o)
	verifier(investis == Aventure.POINTS_LIVRE[0] + Aventure.POINTS_LIVRE[1], "le sort appris est déjà amélioré (%d points)" % investis)
	verifier(Aventure._palier(appris) <= 1, "palier adapté à l'étage 1")
	var p := {"genre": "objet", "sous": "ratelier", "etat": "actif"}
	var avant: int = joueur.inventaire.size()
	Aventure.utiliser_objet(donjon, p)
	verifier(p["etat"] == "utilise", "râtelier utilisé")
	verifier(Aventure.utiliser_objet(donjon, p) == "Le râtelier est vide.", "râtelier vide ensuite")


func _personnages() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	for sous in ["diablotin", "gobelin_blesse", "prisonnier", "autel", "succube"]:
		for k in 10:
			var p := {"genre": "pnj", "sous": sous, "etat": "actif"}
			var r: Array = await Rencontres.parler(donjon, p)
			verifier(String(r[0]) != "", "message de %s" % sous)
	for sujet in ["gardien", "etage", "ennemis"]:
		verifier(Rencontres.phrase(donjon, sujet, true) != "" and Rencontres.phrase(donjon, sujet, false) != "", "phrases %s" % sujet)
	print("Exemple de diablotin (vrai) : %s" % Rencontres.phrase(donjon, "gardien", true))
	print("Exemple de diablotin (faux) : %s" % Rencontres.phrase(donjon, "gardien", false))


## Pactes de la succube : prix en PV max (pour toujours), effets, usage unique du baiser et du pacte de mort.
func _pactes() -> void:
	var joueur := Personnage.nouveau()
	joueur._d["points_de_vie_max"] = 40
	joueur._d["points_de_vie"] = 40
	var donjon := Donjon.nouveau(joueur)
	var etage := 1
	# Voile (25 %) : 40 -> 30
	verifier(Aventure.pacte_impossible(donjon, "voile") == "", "voile possible")
	var msg := Aventure.sceller_pacte(donjon, "voile")
	verifier(joueur.points_de_vie_max == 30 and joueur.points_de_vie == 30, "voile : 25 %% des PV max retirés (%d)" % joueur.points_de_vie_max)
	verifier(Aventure.pacte_actif(donjon, "voile") and Aventure.pacte_impossible(donjon, "voile") == "déjà scellé", "voile actif pour l'étage")
	joueur.calculer_stats()
	verifier(joueur.points_de_vie_max == 30, "les PV max cédés ne reviennent pas au recalcul des statistiques")
	# Carte de chair : tout l'étage connu
	Aventure.sceller_pacte(donjon, "carte")
	verifier(Carte.etats_salles(donjon, etage).size() == donjon.plan_donjon[etage].size(), "carte de chair : toutes les salles connues")
	verifier(not Carte.carte_de_chair(donjon, 2), "carte de chair : seulement pour cet étage")
	# Baiser du geôlier : usage unique, le geôlier part ailleurs
	Aventure.sceller_pacte(donjon, "baiser")
	var geolier := {}
	var salle_geolier := ""
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p["genre"] == "geolier":
				geolier = p
				salle_geolier = i
	donjon.salle_actuelle = [etage, int(salle_geolier)]
	verifier(Aventure.consommer_pacte(joueur, "baiser"), "baiser : la capture échoue")
	verifier(Aventure.repousser_geolier(donjon, geolier) != "", "message du baiser")
	verifier(not donjon.plan_donjon[etage][salle_geolier]["presences"].has(geolier), "le geôlier quitte la salle")
	verifier(not Aventure.consommer_pacte(joueur, "baiser"), "baiser : une seule fois")
	# Apaisement (50 %) : un Sans-Visage de moins
	Aventure.ajouter_menace(donjon, etage, "imbattable")
	var avant := Aventure.sans_visage_etage(donjon).size()
	var pv := int(joueur.points_de_vie_max)
	Aventure.sceller_pacte(donjon, "apaisement")
	verifier(Aventure.sans_visage_etage(donjon).size() == avant - 1, "apaisement : un Chevalier de la mort de moins")
	verifier(joueur.points_de_vie_max == pv - int(ceil(pv * 0.5)), "apaisement : 50 %% des PV max retirés")
	verifier(Aventure.sans_visage_etage(donjon).is_empty() == (Aventure.pacte_impossible(donjon, "apaisement") == "aucun Chevalier de la mort ici"), "apaisement impossible sans Chevalier de la mort")
	# Pacte de mort : la mort est annulée une fois, réveil au cachot avec 1 PV et ses affaires
	joueur._d["points_de_vie_max"] = 40
	joueur._d["points_de_vie"] = 40
	Aventure.sceller_pacte(donjon, "mort")
	var objets: int = joueur.inventaire.size()
	joueur._d["points_de_vie"] = 0
	Statistiques.lever_mort("combat")
	verifier(Aventure.relever_par_pacte(donjon), "pacte de mort : relevé")
	verifier(not Statistiques.mort and joueur.points_de_vie == 1, "pacte de mort : vivant, 1 PV")
	verifier(str(donjon.salle_actuelle[1]) == String(Aventure.meta(donjon, etage)["cachot"]), "pacte de mort : réveil au cachot")
	verifier(joueur.inventaire.size() == objets, "pacte de mort : rien de perdu")
	Statistiques.lever_mort("combat")
	verifier(not Aventure.relever_par_pacte(donjon) and Statistiques.mort, "pacte de mort : une seule fois")
	Statistiques.mort = false
	# Pas assez de vie
	joueur._d["points_de_vie_max"] = 1
	verifier(Aventure.pacte_impossible(donjon, "mort") == "pas assez de vie", "refus quand il ne reste pas assez de vie")
	verifier(int(joueur.statistiques.get("pactes", 0)) == 5, "pactes comptés dans les statistiques")
	print("Exemple de pacte : %s" % msg)


## Diablotins : vrais, jamais deux fois la même information dans la partie, notées au journal ; le Chevalier de la
## mort expliqué dans l'ordre ; les affaires confisquées retrouvées.
func _diablotins() -> void:
	# Tirage fixé ici : avec 40 conversations, environ 3 % des tirages ne donnent aucun mensonge (1 réponse « Cet
	# étage ? » sur 3) ; sans graine propre, ce test dépendait du hasard consommé par les tests précédents.
	seed(2027)
	Compte.vider()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	verifier(Rencontres.infos_diablotin(donjon, "chevalier")[0][1] == Rencontres.INFOS_CHEVALIER[0][1], "chevalier : première information d'abord")
	verifier(Rencontres.infos_diablotin(donjon, "affaires").is_empty(), "pas d'affaires à retrouver avant une capture")
	var geolier := {}
	for i in donjon.plan_donjon[1]:
		for p in donjon.plan_donjon[1][i].get("presences", []):
			if p["genre"] == "geolier":
				geolier = p
	Aventure.capturer(donjon, geolier)
	verifier(not Rencontres.infos_diablotin(donjon, "affaires").is_empty(), "après une capture : où sont les affaires")
	for k in 40:
		var p := {"genre": "pnj", "sous": "diablotin", "etat": "actif"}
		await Rencontres.diablotin(donjon, p)
	var textes := []
	for e in U.ga(joueur, "journal", []):
		textes.append(e["texte"])
	var uniques := {}
	for t in textes:
		uniques[t] = true
	verifier(textes.size() > 5, "le journal se remplit (%d entrées)" % textes.size())
	verifier(uniques.size() == textes.size(), "aucune information dite deux fois")
	var ordre := []
	var textes_chevalier := Rencontres.INFOS_CHEVALIER.map(func(i): return i[1])
	for t in textes:
		if t in textes_chevalier:
			ordre.append(textes_chevalier.find(t))
	var trie := ordre.duplicate()
	trie.sort()
	verifier(ordre == trie, "le chevalier est expliqué dans l'ordre")
	# Mensonges : seulement sur l'étage (donjon), jamais sur les ennemis ni les affaires ; pas de contradiction
	var mensonges := 0
	var sujets_vrais := {}
	for e in U.ga(joueur, "journal", []):
		if e.get("mensonge", false):
			mensonges += 1
			verifier(e["sujet"].begins_with("Étage"), "mensonge rangé avec l'étage : %s" % e["texte"])
	for cle in donjon.diablotins_dits:
		if cle.begins_with("mensonge/"):
			for vrai in ["pupitre", "cachette"]:
				if cle.ends_with("/" + vrai):
					sujets_vrais[vrai] = true
	verifier(mensonges >= 1, "les diablotins mentent parfois sur le donjon (%d mensonges)" % mensonges)
	for e in U.ga(joueur, "journal", []):
		if not e.get("mensonge", false):
			verifier(not ("Les livres du savoir" in e["texte"] and sujets_vrais.has("pupitre")), "pas de vérité après un mensonge (pupitre)")
	var lot := []
	for k in 300:
		var d := Donjon.nouveau(Personnage.nouveau())
		lot.append(Rencontres.repondre(d, "etage")[0].begins_with("mensonge/"))
	var part := float(lot.count(true)) / maxf(1, lot.size())
	verifier(part > 0.22 and part < 0.45, "environ 1 réponse sur 3 sur l'étage est un mensonge (%.0f %%)" % (part * 100))
	print("Journal après 40 diablotins : %d entrées dont %d mensonges" % [textes.size(), mensonges])


## Glossaire du compte (2026-10-31) : les informations sur les ennemis y vont et survivent à une nouvelle partie ;
## un diablotin ne les redit jamais, même dans une autre partie ; le Chevalier, un élément à la fois.
func _glossaire_du_compte() -> void:
	Compte.vider()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var info := Rencontres.repondre(donjon, "chevalier")
	verifier(info[0] == "chevalier/" + Rencontres.INFOS_CHEVALIER[0][0], "chevalier : un élément à la fois, dans l'ordre")
	verifier(Compte.glossaire().get(Rencontres.NOM_CHEVALIER, []).size() == 1, "l'information sur le chevalier va au glossaire")
	for i in Rencontres.INFOS_CHEVALIER:
		verifier(not ("lames, pointes, masses" in i[1]), "plus de liste de résistances d'un coup")
		verifier(not ("blessure" in i[1] or "plafond" in i[0]), "la limite de dégâts du chevalier reste secrète")
	verifier(not Rencontres.info_ennemi_valide("chevalier/plafond"), "information retirée : plus montrée au glossaire")
	# Nouvelle partie (le héros est mort) : le glossaire reste, l'information n'est pas redite
	var joueur2 := Personnage.nouveau()
	var donjon2 := Donjon.nouveau(joueur2)
	verifier(Compte.glossaire().get(Rencontres.NOM_CHEVALIER, []).size() == 1, "le glossaire survit à une nouvelle partie")
	var suivante := Rencontres.infos_diablotin(donjon2, "chevalier")
	verifier(not suivante.is_empty() and suivante[0][0] == "chevalier/" + Rencontres.INFOS_CHEVALIER[1][0],
		"nouvelle partie : le diablotin passe à l'information suivante")
	for k in 30:
		await Rencontres.diablotin(donjon2, {"genre": "pnj", "sous": "diablotin", "etat": "actif"})
	var vus := {}
	var doublons := 0
	for ennemi in Compte.glossaire():
		for e in Compte.glossaire()[ennemi]:
			if vus.has(e["cle"]):
				doublons += 1
			vus[e["cle"]] = true
	verifier(doublons == 0, "aucune information sur un ennemi apprise deux fois (%d)" % doublons)
	var dits_ennemis := 0
	for e in U.ga(joueur2, "journal", []):
		if e["texte"] == info[1]:
			dits_ennemis += 1
	verifier(dits_ennemis == 0, "l'information de la partie précédente n'est jamais redite")
	# Geôlier et gobelins : leurs conseils vont aussi au glossaire
	var connus := Compte.glossaire().keys()
	verifier(connus.has(Rencontres.NOM_CHEVALIER), "glossaire : Chevalier de la mort (%s)" % str(connus))
	Compte.vider()


## Demandes du 2026-10-31 : statistiques du Chevalier cachées, salles pièges désactivées, potions de niveau 1 à 40,
## coffre des confiscations à 3 salles au plus du cachot, catégorie « Divers » (et clés) dans l'inventaire.
func _nouveautes_31_octobre() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	# Chevalier : « ??? » partout, aucun chiffre
	var chevalier := Aventure.creer_imbattable(donjon)
	var fiche := FicheEnnemi.contenu_fiche(chevalier, joueur)
	var chiffres := 0
	for l in fiche:
		var r := RegEx.create_from_string("\\d")
		if r.search(String(l[0])) != null:
			chiffres += 1
	verifier(chiffres == 0, "fiche du chevalier : aucun chiffre (%d lignes chiffrées)" % chiffres)
	verifier("???" in String(fiche[1][0]), "fiche du chevalier : PV « ??? »")
	var gobelin := Gobelin.nouveau(donjon, 1).generer_gobelin(donjon, 1)
	verifier(not FicheEnnemi.stats_cachees(gobelin), "les gobelins gardent leur fiche")
	# Salles pièges désactivées
	verifier(Donjon.CHANCE_PIEGE == 0.0, "salles pièges désactivées")
	# Potions de niveau 1 : 40 PV / 40 mana ; celles des ennemis restent en pourcentage
	joueur.points_de_vie_max = 200
	joueur.points_de_vie = 100
	Consommable.creer_potion("pv", 1).utiliser(joueur)
	verifier(int(joueur.points_de_vie) == 140, "potion de soin niv.1 : +40 PV (%d)" % int(joueur.points_de_vie))
	joueur.mana_max = 200
	joueur.mana = 100
	Consommable.creer_potion("mana", 1).utiliser(joueur)
	verifier(int(joueur.mana) == 140, "potion de mana niv.1 : +40 mana (%d)" % int(joueur.mana))
	verifier(DescriptionObjet.effet_consommable(Consommable.creer_potion("pv", 1)) == "Rend 40 PV", "potion niv.1 décrite « Rend 40 PV »")
	verifier(not U.vrai(Consommable.creer_potion("pv", 1, true).effet.get("fixe", false)), "potion d'un ennemi : en pourcentage")
	verifier(not U.vrai(Consommable.creer_potion("pv", 2).effet.get("fixe", false)), "potion niv.2 : en pourcentage")
	# Coffre des confiscations : à 3 salles au plus du cachot (sur 20 captures)
	var loin := 0
	for k in 20:
		var j := Personnage.nouveau()
		var d := Donjon.nouveau(j)
		j.piece_or = 50
		j.inventaire.append(Arme.nouvelle("Epée", "arme", "Epée"))
		var geolier := {}
		for i in d.plan_donjon[1]:
			for p in d.plan_donjon[1][i].get("presences", []):
				if p["genre"] == "geolier":
					geolier = p
		Aventure.capturer(d, geolier)
		var cachot := str(d.salle_actuelle[1])
		var dist := Aventure.distances_depuis(d.plan_donjon[1], cachot)
		for i in d.plan_donjon[1]:
			for p in d.plan_donjon[1][i].get("presences", []):
				if p.get("sous") == "coffre_confisque" and p.get("etat") == "actif":
					if int(dist.get(i, 99)) > Aventure.COFFRE_PRES_DU_CACHOT or d.plan_donjon[1][i].get("verrouillee", false):
						loin += 1
	verifier(loin == 0, "coffre des confiscations à 3 salles au plus du cachot, jamais fermé à clé (%d trop loin)" % loin)
	# Catégorie « Divers » et clés
	var MI := load("res://scripts/ecrans/menu_inventaire.gd")
	var babiole := ObjetsDivers.creer("Cuillère d'essai", "argenterie", 25, "Objet d'essai.")  # catalogue vide pour l'instant
	joueur.recevoir_objet(babiole)
	verifier(babiole.est_divers() and joueur.equipements.values().find(babiole) == -1, "objet divers : jamais équipé")
	verifier(MI.objets_de_categorie(joueur, "Divers") == [babiole], "objet divers rangé dans « Divers »")
	verifier(MI.objets_de_categorie(joueur, "Consommables").find(babiole) == -1, "objet divers hors des consommables")
	joueur._d["cles"] = 2
	verifier(MI.compte_categorie(joueur, "Divers") == 3, "les clés comptent dans « Divers »")
	verifier(DescriptionObjet.categorie(babiole) == "Divers — Argenterie", "catégorie lisible de l'objet divers")
	var MM := load("res://scripts/ecrans/menu_marchand.gd")
	verifier(MM.SOUS_ONGLETS.has("Divers") and MM.filtrer_objets([babiole], "Divers") == [babiole], "le marchand a la catégorie « Divers »")
	verifier(Marchand.prix_vente(babiole) == 25, "objet divers revendu à sa valeur")


func _sauvegarde() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var avant := _compter(donjon, 1)
	Sauvegarde.sauvegarder("test_aventure", joueur, donjon)
	var charge = Sauvegarde.charger("test_aventure")
	verifier(_compter(charge[1], 1) == avant, "présences gardées par la sauvegarde")
	verifier(Aventure.meta(charge[1], 1).get("prepare", false), "réglages d'étage gardés")
	Sauvegarde.supprimer("test_aventure")


## Combat réel contre un groupe : le héros (auto) gagne ou fuit ; un combat contre le Sans-Visage ne se gagne pas.
func _combat_fuite() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var combat := Combat.nouveau(joueur, null, Aventure.ennemis_de(donjon, {"genre": "groupe", "nombre": 1}), donjon)
	await combat.mener_combat()
	verifier(combat.issue in ["victoire", "defaite"], "issue d'un combat sans fuite : %s" % combat.issue)
	Statistiques.mort = false
	var c2 := Combat.nouveau(joueur, null, [Aventure.creer_imbattable(donjon)], donjon)
	joueur.points_de_vie = joueur.points_de_vie_max
	await c2.mener_combat()
	verifier(c2.issue != "victoire", "on ne bat pas le Sans-Visage")
	Statistiques.mort = false
