extends SceneTree
## Butin posé à la main (onglet « Butin » de l'éditeur, 2026-11-03), catalogue des objets divers / nourriture /
## ingrédients, onglets Nourriture et Ingrédients de l'inventaire et du marchand.
## « BILAN butin posé : 0 échec(s) ». Le test pose du butin sur porte2 dans l'éditeur, l'enregistre, le relit
## dans le jeu, puis remet donnees/salles_peintes/porte2.json et outils/zones_manuelles/porte2.json comme avant.

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(11)
	Sauvegarde.reinitialiser_monde()
	_catalogue()
	_ramasser()
	await _editeur()
	print("BILAN butin posé : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func _catalogue() -> void:
	verifier(ObjetsDivers.noms().size() >= 40, "catalogue chargé (%d objets)" % ObjetsDivers.noms().size())
	for c in ObjetsDivers.CATEGORIES:
		verifier(not ObjetsDivers.noms(c).is_empty(), "catégorie %s remplie" % c)
	var joueur := Personnage.nouveau()
	var MI := load("res://scripts/ecrans/menu_inventaire.gd")
	var rubis = ObjetsDivers.depuis_catalogue("Rubis")
	var pomme = ObjetsDivers.depuis_catalogue("Pomme")
	var carotte = ObjetsDivers.depuis_catalogue("Carotte")
	verifier(rubis.est_divers() and not rubis.est_nourriture() and int(rubis.valeur) == 160, "rubis : objet divers à 160 or (petit 80, grand 240)")
	verifier(pomme.est_nourriture() and int(U.num(pomme, "pv")) == 15, "pomme : nourriture, 15 PV")
	verifier(carotte.est_ingredient() and not carotte.est_nourriture(), "carotte : ingrédient")
	for o in [rubis, pomme, carotte]:
		verifier(joueur.recevoir_objet(o) == null, "%s jamais équipé" % o.nom)
	verifier(MI.objets_de_categorie(joueur, "Divers") == [rubis], "onglet Divers : le rubis seul")
	verifier(MI.objets_de_categorie(joueur, "Nourriture") == [pomme], "onglet Nourriture : la pomme")
	verifier(MI.objets_de_categorie(joueur, "Ingrédients") == [carotte], "onglet Ingrédients : la carotte")
	verifier(MI.BOUTONS_CATEGORIES.has("Nourriture") and MI.BOUTONS_CATEGORIES.has("Ingrédients"), "inventaire : 2 onglets ajoutés")
	verifier(DescriptionObjet.categorie(pomme) == "Nourriture — Fruit", "catégorie lisible : " + DescriptionObjet.categorie(pomme))
	joueur.points_de_vie = joueur.points_de_vie_max - 20
	var msg: String = MI.utiliser_ou_equiper(joueur, pomme)
	verifier(int(joueur.points_de_vie) == int(joueur.points_de_vie_max) - 5 and not pomme in joueur.inventaire, "manger la pomme : +15 PV (%s)" % msg)
	MI.utiliser_ou_equiper(joueur, carotte)
	verifier(carotte in joueur.inventaire, "un ingrédient ne se mange pas")
	var MM := load("res://scripts/ecrans/menu_marchand.gd")
	verifier(MM.SOUS_ONGLETS.has("Nourriture") and MM.SOUS_ONGLETS.has("Ingrédients"), "marchand : 2 onglets ajoutés")
	var m := Marchand.nouveau()
	m.generer_inventaire()
	verifier(not MM.filtrer_objets(m.inventaire, "Nourriture").is_empty() and not MM.filtrer_objets(m.inventaire, "Ingrédients").is_empty(),
		"le marchand vend de la nourriture et des ingrédients")
	verifier(MM.filtrer_objets(m.inventaire, "Divers").all(func(o): return not o.est_nourriture() and not o.est_ingredient()),
		"nourriture et ingrédients hors de « Divers » chez le marchand")


func _ramasser() -> void:
	var cas := [
		[{"categorie": "or", "quantite": 50}, "50 pièces d'or"],
		[{"categorie": "potion", "potion": "mana", "quantite": 2}, "Potion de mana"],
		[{"categorie": "arme", "rang": 3}, ""],
		[{"categorie": "equipement", "objet": "bijou"}, ""],
		[{"categorie": "divers", "objet": "Dent en or"}, "Dent en or"],
		[{"categorie": "nourriture", "quantite": 3}, ""],
		[{"categorie": "ingredient", "objet": "Oignon"}, "Oignon"],
	]
	for c in cas:
		var joueur := Personnage.nouveau()
		var or_avant := int(joueur.piece_or)
		var n_avant: int = joueur.inventaire.size() + joueur.equipements.values().filter(func(x): return x != null).size()
		var msg := Fouille.ramasser(c[0], joueur, 1)
		var n_apres: int = joueur.inventaire.size() + joueur.equipements.values().filter(func(x): return x != null).size()
		var ok: bool = c[1] == "" or msg.contains(c[1])
		if c[0]["categorie"] == "nourriture":
			ok = ok and joueur.inventaire.filter(func(x): return x.est_nourriture()).size() == 3
		if c[0]["categorie"] == "or":
			ok = ok and int(joueur.piece_or) == or_avant + 50
		else:
			ok = ok and n_apres > n_avant
		if c[0]["categorie"] == "arme":
			var armes: Array = joueur.inventaire.filter(func(x): return x.est_arme())
			if joueur.equipements.get("arme") != null:
				armes.append(joueur.equipements["arme"])
			ok = ok and armes.any(func(x): return int(x.rang) == 3)
		verifier(ok, "ramasser %s : %s (objets %d → %d)" % [c[0]["categorie"], msg, n_avant, n_apres])
	# Butin d'une image ajouté aux objets d'une salle du plan, une fois, même pour une salle déjà visitée
	var salle := {"objets": [], "objets_image": "essai_sans_butin"}
	Fouille._ajouter_butins(salle["objets"], "essai_sans_butin")
	verifier(salle["objets"].is_empty(), "image sans butin : rien d'ajouté")


func _editeur() -> void:
	var original := FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json")
	var manuel_avant := FileAccess.file_exists("res://outils/zones_manuelles/porte2.json")
	var manuel_original := FileAccess.get_file_as_string("res://outils/zones_manuelles/porte2.json") if manuel_avant else ""
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed.numero = ed.salles.find("porte2")
	ed._charger()
	var depart: int = ed.salle.donnees["butins"].size()
	ed.choisir_onglet(true)
	verifier(ed.mode_butin and ed.onglets.current_tab == 1, "onglet Butin choisi")
	ed._categorie_choisie(Fouille.CATEGORIES_BUTIN.find("nourriture"))
	var k_objet: int = ObjetsDivers.noms("nourriture").find("Bol de soupe") + 1
	ed.choix_objet.select(k_objet)
	ed._objet_choisi(k_objet)
	ed._regler("quantite", 2)
	var k: int = ed.poser_butin(Vector2(400, 430))
	verifier(ed.salle.donnees["butins"].size() == depart + 1, "butin posé")
	verifier(ed.resume_butin(ed.salle.donnees["butins"][k]) == "2 × Bol de soupe", "résumé : " + ed.resume_butin(ed.salle.donnees["butins"][k]))
	ed._categorie_choisie(Fouille.CATEGORIES_BUTIN.find("or"))  # change le butin choisi
	verifier(ed.salle.donnees["butins"][k]["categorie"] == "or", "le module change le butin choisi")
	ed._annuler()
	verifier(ed.salle.donnees["butins"][k]["categorie"] == "nourriture", "Ctrl+Z annule le changement")
	ed._enregistrer()
	var relu := SallePeinte.lire_salle("porte2")
	verifier(relu.get("butins", []).size() == depart + 1 and relu["butins"][-1]["objet"] == "Bol de soupe", "butin enregistré dans porte2.json")
	# Dans le jeu : la salle du plan reçoit le butin, il s'affiche, se ramasse une fois
	var salle := {}
	var objets := Fouille.objets_salle(salle, "porte2")
	var butins := objets.filter(func(o): return o["type"] == "butin")
	verifier(butins.size() == depart + 1, "butin ajouté aux objets de la salle")
	var affiches := Fouille.a_afficher(objets, "porte2")
	verifier(affiches.size() == objets.size() and affiches[-1]["objet"] == "butin_sac", "butin affiché (image butin_sac)")
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var msg := Fouille.fouiller(butins[-1], joueur, donjon)
	verifier(msg.contains("2 × Bol de soupe") and joueur.inventaire.filter(func(o): return o.nom == "Bol de soupe").size() == 2, "ramassé : " + msg)
	verifier(Fouille.objets_salle(salle, "porte2").filter(func(o): return o["type"] == "butin" and o["fouille"]).size() == 1, "ramassé une fois pour toutes")
	# La vraie salle l'affiche
	var sp := SallePeinte.new()
	root.add_child(sp)
	var a_poser := Fouille.a_afficher(Fouille.objets_salle({}, "porte2"), "porte2")
	sp.charger("porte2", -1, true, a_poser)
	verifier(sp.objets.size() == a_poser.size() and sp.objets[-1]["type"] == "butin", "salle peinte : le butin est posé (miroir compris)")
	var squelettes := a_poser.filter(func(o): return o["type"] != "butin").size()
	verifier(sp.donnees["obstacles"].size() == SallePeinte.lire_salle("porte2")["obstacles"].size() + squelettes,
		"le butin ne bloque pas le passage (pas d'obstacle ajouté)")
	sp.queue_free()
	# Remise en état
	var f := FileAccess.open("res://donnees/salles_peintes/porte2.json", FileAccess.WRITE)
	f.store_string(original)
	f.close()
	if manuel_avant:
		f = FileAccess.open("res://outils/zones_manuelles/porte2.json", FileAccess.WRITE)
		f.store_string(manuel_original)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles/porte2.json"))
	verifier(FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json") == original, "porte2 remise en état")
	ed.queue_free()
