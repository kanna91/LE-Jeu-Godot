extends SceneTree
## Quêtes des prisonniers (QuetesPrisonniers, donnees/prisonniers.json, 2026-11-02) : les trois quêtes de
## l'utilisateur jouées de bout en bout sur la logique (sans écran).
## - posées une fois chacune, dans des cellules de prison de l'étage 1 ;
## - le vieux magicien : soupe posée en cuisine, répliques, don → karma +1 et un sort, trois réveils, « GARDE ! »
##   (un élite entre), élite vaincu → malédiction (karma −2, le chevalier entre), puis « AHAHAHAHA ! » (combat) ;
## - le prisonnier malade : potion de soin, nourriture, clé sur un élite (direction donnée), cellule ouverte → il
##   était l'élite : un élite+ (PV × 1,5, « Faux prisonnier+ ») surgit à sa place ;
## - Mariane : amulette sur un élite (des catacombes s'il y en a), objet équipable (intelligence +2, mana +1,
##   sagesse −1), rendue même équipée → un anneau rare (rang 4 à l'étage 1), elle disparaît.
## « BILAN quêtes prisonniers : 0 échec(s) ».   godot --headless --path . -s tests/test_quetes_prisonniers.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(3)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	Aventure.preparer_etage(donjon, 1)
	var salles: Dictionary = donjon.plan_donjon[1]
	var places := {}
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.has("quete"):
				verifier(not places.has(p["quete"]), "quête %s posée deux fois" % p["quete"])
				places[p["quete"]] = [p, str(i)]
				verifier(PlanSalles.est_prison(String(salles[i]["salle_peinte"]["image"])), "%s hors d'une prison" % p["quete"])
	verifier(places.size() == 3, "3 quêtes posées à l'étage 1 (%d)" % places.size())
	print("Quêtes posées : ", places.keys())
	if places.has("magicien"):
		_magicien(donjon, places["magicien"])
	if places.has("malade"):
		_malade(donjon, places["malade"])
	if places.has("mariane"):
		_mariane(donjon, places["mariane"])
	print("BILAN quêtes prisonniers : %d échec(s)" % echecs)
	quit()


func _texte(res: Dictionary) -> String:
	return " | ".join(res["lignes"])


func _objets_poses(donjon, nom: String) -> Array:
	var liste := []
	for i in donjon.plan_donjon[1]:
		for p in donjon.plan_donjon[1][i].get("presences", []):
			if p.get("sous") == "objet_quete" and p.get("objet") == nom and p.get("etat") == "actif":
				liste.append([p, str(i)])
	return liste


func _porteur(donjon, nom: String) -> Array:
	for i in donjon.plan_donjon[1]:
		for p in donjon.plan_donjon[1][i].get("presences", []):
			if nom in p.get("objets_quete", []):
				return [p, str(i)]
	return []


func _magicien(donjon, place: Array) -> void:
	var p: Dictionary = place[0]
	var joueur = donjon.personnage
	donjon.salle_actuelle = [1, int(place[1])]
	var r := QuetesPrisonniers.ecouter(donjon, p)
	print("magicien 1 : ", _texte(r))
	verifier("bol de soupe" in _texte(r), "magicien : demande de soupe")
	var soupes := _objets_poses(donjon, "Bol de soupe")
	verifier(soupes.size() == 1 and String(donjon.plan_donjon[1][soupes[0][1]].get("bloc_salle", "")) == "cuisine",
		"magicien : soupe posée dans la cuisine")
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier("un bon bol de soupe" in _texte(r) and r["donner"] == "", "magicien : réplique sans soupe")
	verifier(QuetesPrisonniers.ecouter(donjon, p)["lignes"] == ["« … »"], "magicien : dernière réplique qui reste")
	# Le héros ramasse la soupe
	Aventure.utiliser_objet(donjon, soupes[0][0])
	verifier(QuetesPrisonniers.objet_demande(joueur, {"objet": "Bol de soupe"}) != null, "magicien : soupe ramassée")
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier(r["donner"] == "Bol de soupe", "magicien : bouton Donner")
	var karma := Karma.valeur(joueur)
	var sorts: int = joueur.magies_apprises.size()
	r = QuetesPrisonniers.donner(donjon, p)
	print("magicien don : ", _texte(r))
	verifier(Karma.valeur(joueur) == karma + 1, "magicien : karma +1")
	verifier(joueur.magies_apprises.size() == sorts + 1, "magicien : un sort appris")
	verifier(QuetesPrisonniers.objet_demande(joueur, {"objet": "Bol de soupe"}) == null, "magicien : soupe donnée")
	for mot in ["zzzZZzz", "laisser dormir", "DU VENT"]:
		r = QuetesPrisonniers.ecouter(donjon, p)
		verifier(mot in _texte(r) and r["suites"].is_empty(), "magicien : réveil « %s »" % mot)
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier("GARDE" in _texte(r) and r["suites"].size() == 1, "magicien : GARDE ! et un élite")
	var elite: Dictionary = r["suites"][0].get("faire_entrer", {})
	verifier(elite.get("elite", false) and elite.get("evenement_victoire") == "magicien_garde_vaincu", "magicien : élite qui attaque")
	verifier(elite in donjon.salle_courante()["presences"], "magicien : l'élite est dans la salle")
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier(_texte(r) == "« GARDE ! GARDE ! »" and r["suites"].is_empty(), "magicien : GARDE répété, pas d'autre élite")
	Aventure.apres_victoire(donjon, elite)
	r = QuetesPrisonniers.ecouter(donjon, p)
	print("magicien maudit : ", _texte(r))
	verifier("MAUDIT" in _texte(r), "magicien : malédiction")
	verifier(Karma.valeur(joueur) == karma - 1, "magicien : karma −2 (+1 −2)")
	verifier(r["suites"].size() == 1 and r["suites"][0].get("faire_entrer", {}).get("genre") == "imbattable", "magicien : le chevalier entre")
	var chevalier: Dictionary = r["suites"][0]["faire_entrer"]
	verifier(chevalier in donjon.salle_courante()["presences"], "magicien : chevalier dans la salle")
	for k in 2:
		r = QuetesPrisonniers.ecouter(donjon, p)
		verifier("AHAHAHAHA" in _texte(r) and r["suites"].size() == 1 and r["suites"][0].has("combat"), "magicien : rire et combat (%d)" % k)


func _malade(donjon, place: Array) -> void:
	var p: Dictionary = place[0]
	var joueur = donjon.personnage
	donjon.salle_actuelle = [1, int(place[1])]
	var r := QuetesPrisonniers.ecouter(donjon, p)
	verifier("soin" in _texte(r), "malade : demande de soin")
	var vus := []
	for k in 4:
		vus.append(_texte(QuetesPrisonniers.ecouter(donjon, p)))
	verifier(vus[0] == vus[3] and vus[0] != vus[1], "malade : répliques en boucle")
	joueur.recevoir_objet(Consommable.creer_potion("pv", 1))
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier(r["donner"].begins_with("Potion de soin"), "malade : propose la potion (%s)" % r["donner"])
	r = QuetesPrisonniers.donner(donjon, p)
	verifier("faim" in _texte(r), "malade : faim après la potion")
	var soupes := _objets_poses(donjon, "Bol de soupe")
	verifier(not soupes.is_empty(), "malade : nourriture posée")
	Aventure.utiliser_objet(donjon, soupes[0][0])
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier(r["donner"] == "Bol de soupe", "malade : la soupe compte comme nourriture")
	r = QuetesPrisonniers.donner(donjon, p)
	print("malade clé : ", _texte(r))
	verifier(not "{direction}" in _texte(r) and "salle" in _texte(r), "malade : direction de l'élite donnée")
	var porteur := _porteur(donjon, "Clé de la cellule")
	verifier(not porteur.is_empty() and porteur[0].get("elite", false), "malade : un élite porte la clé")
	if porteur.is_empty():
		return
	verifier(not "{direction}" in _texte(QuetesPrisonniers.ecouter(donjon, p)), "malade : direction répétée")
	# L'élite est vaincu, son corps fouillé
	donjon.salle_actuelle = [1, int(porteur[1])]
	var corps := Aventure.laisser_cadavre(donjon, porteur[0])
	verifier("Clé de la cellule" in corps.get("objets_quete", []), "malade : la clé passe sur le corps")
	verifier("Clé de la cellule" in QuetesPrisonniers.prendre_objets(joueur, corps), "malade : clé trouvée sur le corps")
	donjon.salle_actuelle = [1, int(place[1])]
	r = QuetesPrisonniers.ecouter(donjon, p)
	verifier(r["donner"] == "Clé de la cellule", "malade : propose la clé")
	r = QuetesPrisonniers.donner(donjon, p)
	print("malade libre : ", _texte(r))
	verifier(p["etat"] != "actif", "malade : il est parti")
	var g: Dictionary = r["suites"][0].get("faire_entrer", {}) if not r["suites"].is_empty() else {}
	verifier(g.get("renforce", false), "malade : un élite+ attaque")
	verifier(r["suites"][0].get("depuis") == p["pos"], "malade : l'élite+ surgit à la place du prisonnier")
	verifier("élite gobelin" in _texte(r), "malade : il était l'élite")
	var normal: Gobelin = Aventure.ennemis_de(donjon, {"genre": "groupe", "elite": true, "membres": [Aventure.membres(g)[0]]})[0]
	var renforce: Gobelin = Aventure.ennemis_de(donjon, g)[0]
	print("élite %d PV, élite+ %d PV (%s)" % [normal.points_de_vie_max, renforce.points_de_vie_max, renforce.nom])
	verifier(renforce.nom == "Faux prisonnier+" and renforce.points_de_vie_max > normal.points_de_vie_max, "malade : élite+ plus solide (%s)" % renforce.nom)


func _mariane(donjon, place: Array) -> void:
	var p: Dictionary = place[0]
	var joueur = donjon.personnage
	donjon.salle_actuelle = [1, int(place[1])]
	var r := QuetesPrisonniers.ecouter(donjon, p)
	verifier("amulette" in _texte(r), "mariane : amulette volée")
	var porteur := _porteur(donjon, "Amulette de Mariane")
	verifier(not porteur.is_empty(), "mariane : un élite porte l'amulette")
	if porteur.is_empty():
		return
	var image := String(donjon.plan_donjon[1][porteur[1]]["salle_peinte"]["image"])
	print("mariane : amulette dans la salle %s (%s)" % [porteur[1], image])
	QuetesPrisonniers.ecouter(donjon, p)
	verifier("refuse de vous parler" in _texte(QuetesPrisonniers.ecouter(donjon, p)), "mariane : refuse de parler")
	var int_avant := int(U.num(joueur, "intelligence"))
	QuetesPrisonniers.prendre_objets(joueur, {"objets_quete": ["Amulette de Mariane"]})
	var amulette = QuetesPrisonniers.objet_demande(joueur, {"objet": "Amulette de Mariane"})
	verifier(amulette is Armure and int(U.num(amulette, "intelligence")) == 2 and int(U.num(amulette, "sagesse")) == -1
		and int(U.num(amulette, Caracteristiques.MANA)) == 1, "mariane : amulette int +2, mana +1, sagesse −1")
	var equipee: bool = amulette in joueur.equipements.values()
	print("mariane : amulette %s, intelligence %d → %d" % ["équipée" if equipee else "dans le sac", int_avant, int(U.num(joueur, "intelligence"))])
	var objets_avant: int = joueur.inventaire.size()
	r = QuetesPrisonniers.donner(donjon, p)
	print("mariane merci : ", _texte(r))
	verifier(QuetesPrisonniers.objet_demande(joueur, {"objet": "Amulette de Mariane"}) == null, "mariane : amulette rendue")
	verifier(int(U.num(joueur, "intelligence")) == int_avant, "mariane : bonus de l'amulette retiré")
	verifier("Vous recevez" in _texte(r) and p["etat"] != "actif", "mariane : anneau reçu, elle disparaît")
	var anneau = null
	for o in QuetesPrisonniers.objets_du_heros(joueur):
		if U.ga(o, "type_armure", "") == "anneau":
			anneau = o
	verifier(anneau != null and int(anneau.rang) == 4 and "rare" in String(anneau.nom), "mariane : anneau rare (rang 4) à l'étage 1")
	var _n := objets_avant
