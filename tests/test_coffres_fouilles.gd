extends SceneTree
## Coffres et points de fouille posés dans l'éditeur de zones (2026-11-11, demande de l'utilisateur) : couches
## « Coffres » (C) et « Fouilles » (F), contenu réglé comme un butin, enregistrés dans le .json de la salle ; dans le
## jeu : coffre affiché (image provisoire) qui arrête le héros, point de fouille invisible, « Ouvrir » ou « Fouiller »,
## tout le contenu reçu une seule fois. Le test travaille sur porte2 puis remet ses deux fichiers comme avant.
## godot --headless --path . -s tests/test_coffres_fouilles.gd

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(1111)
	Sauvegarde.reinitialiser_monde()
	_ouvrir_sans_editeur()
	_hasard_selon_meuble()
	var original := FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json")
	var manuel_avant := FileAccess.file_exists("res://outils/zones_manuelles/porte2.json")
	var manuel_original := FileAccess.get_file_as_string("res://outils/zones_manuelles/porte2.json") if manuel_avant else ""
	await _editeur_et_jeu()
	var f := FileAccess.open("res://donnees/salles_peintes/porte2.json", FileAccess.WRITE)
	f.store_string(original)
	f.close()
	if manuel_avant:
		f = FileAccess.open("res://outils/zones_manuelles/porte2.json", FileAccess.WRITE)
		f.store_string(manuel_original)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles/porte2.json"))
	verifier(FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json") == original, "porte2.json remis comme avant")
	print("BILAN coffres et fouilles : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Ouvrir et fouiller d'après des données d'image écrites à la main.
func _ouvrir_sans_editeur() -> void:
	var d := {"coffres": [{"x": 300, "y": 400, "contenu": [{"categorie": "or", "quantite": 25},
		{"categorie": "divers", "objet": "Dent en or"}]}],
		"fouilles": [{"x": 500, "y": 380, "verbe": "fouiller", "contenu": []}]}
	var objets := []
	Fouille._ajouter_poses(objets, d)
	verifier(objets.size() == 2 and objets[0]["type"] == "coffre" and objets[1]["type"] == "fouille", "un coffre et un point de fouille ajoutés")
	Fouille._ajouter_poses(objets, d)
	verifier(objets.size() == 2, "ajoutés une seule fois")
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var or_avant := int(joueur.piece_or)
	var msg := Fouille.fouiller(objets[0], joueur, donjon)
	verifier(msg.begins_with("Vous ouvrez le coffre.") and int(joueur.piece_or) == or_avant + 25
		and joueur.inventaire.any(func(o): return o.nom == "Dent en or"), "coffre ouvert, tout son contenu reçu : " + msg)
	verifier(Fouille.fouiller(objets[0], joueur, donjon).begins_with("Vous avez déjà"), "un coffre ne s'ouvre qu'une fois")
	verifier(Fouille.fouiller(objets[1], joueur, donjon) == "Vous fouillez : rien d'intéressant.", "point de fouille vide (divers)")
	var biblio := {"type": "fouille", "fouille": false, "definition": {"meuble": "bibliotheque", "verbe": "fouiller", "contenu": []}}
	verifier(Fouille.fouiller(biblio, joueur, donjon) == "Vous fouillez la bibliothèque : rien d'intéressant.", "message avec la sorte de meuble")
	# Retouche dans l'éditeur après une sauvegarde : le contenu suit, un coffre retiré disparaît
	d["coffres"] = []
	Fouille._ajouter_poses(objets, d)
	verifier(objets.size() == 1 and objets[0]["type"] == "fouille", "coffre retiré de l'image : retiré de la salle")


## Tables de butin au hasard selon le meuble : chaque table se tire, souvent rien, jamais trop généreuse.
func _hasard_selon_meuble() -> void:
	for meuble in Fouille.MEUBLES:
		var rien := 0
		var or_total := 0
		var recettes := 0
		for k in 2000:
			var b := Fouille.tirer_selon_meuble(meuble)
			if b.is_empty():
				rien += 1
			elif b["categorie"] == "or":
				or_total += int(b["quantite"])
			elif b["categorie"] == "recette":
				recettes += 1
			if not b.is_empty() and b["categorie"] in ["divers", "nourriture", "ingredient"] and String(b["objet"]) != "":
				verifier(ObjetsDivers.depuis_catalogue(String(b["objet"])) != null, "%s : %s existe" % [meuble, b["objet"]])
		print("%s : rien %d %%, or moyen par fouille %.1f, recettes %.1f %%" % [meuble, rien / 20, or_total / 2000.0, recettes / 20.0])
		verifier(rien >= 800 and rien <= 1400, "%s : souvent rien (%d %%)" % [meuble, rien / 20])
		verifier(or_total / 2000.0 < 2.0, "%s : peu d'or (%.1f par fouille)" % [meuble, or_total / 2000.0])
		verifier(recettes <= 100, "%s : recettes rares" % meuble)
	# Une fouille « au hasard » donne au plus un objet ; une recette de bibliothèque est une recette d'enchantement
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var avant: int = joueur.inventaire.size()
	var or_avant := int(joueur.piece_or)
	for k in 30:
		Fouille.fouiller({"type": "fouille", "fouille": false, "definition": {"meuble": "tonneau", "verbe": "fouiller", "hasard": true, "contenu": []}}, joueur, donjon)
	verifier(joueur.inventaire.size() - avant <= 30 and int(joueur.piece_or) - or_avant <= 30 * 4, "30 tonneaux : au plus un objet chacun")
	var msg := Fouille.ramasser({"categorie": "recette", "objet": "", "artisan": "enchanteur"}, joueur, 1)
	var id: String = AmeliorationsArmes.recettes_connues(joueur)[-1]
	verifier(AmeliorationsArmes.lire_recette(id)[0] == "enchanteur" and msg.contains("L'enchanteresse"), "recette d'enchantement : " + msg)


func _editeur_et_jeu() -> void:
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed.numero = ed.salles.find("porte2")
	ed._charger()
	# Coffre : 40 pièces d'or, puis une potion de soin ajoutée
	ed.choisir_couche("coffres")
	verifier(ed.couche_active() == "coffres", "couche active : coffres")
	ed._categorie_choisie(Fouille.CATEGORIES_BUTIN.find("or"))
	ed._regler("quantite", 40)
	var k: int = ed.poser_contenant(Vector2(420, 430))
	verifier(ed.salle.donnees["coffres"].size() == 1 and ed.salle.donnees["coffres"][k]["contenu"].size() == 1, "coffre posé avec un objet")
	ed._ajouter_contenu()
	ed._categorie_choisie(Fouille.CATEGORIES_BUTIN.find("potion"))
	ed._objet_choisi(ed.POTIONS.find("pv"))
	var contenu: Array = ed.salle.donnees["coffres"][k]["contenu"]
	verifier(contenu.size() == 2 and contenu[0]["categorie"] == "or" and contenu[1]["categorie"] == "potion"
		and contenu[1]["potion"] == "pv", "contenu : 40 or + potion de soin")
	verifier(ed.resume_contenant(ed.salle.donnees["coffres"][k]) == "Coffre : 2 objets", "résumé : " + ed.resume_contenant(ed.salle.donnees["coffres"][k]))
	ed._retirer_contenu()
	verifier(ed.salle.donnees["coffres"][k]["contenu"].size() == 1, "objet retiré du contenu")
	ed._annuler()
	verifier(ed.salle.donnees["coffres"][k]["contenu"].size() == 2, "Ctrl+Z remet l'objet")
	# Point de fouille : « Ouvrir », un ingrédient
	ed.choisir_couche("fouilles")
	verifier(ed.couche_active() == "fouilles" and ed.contenant_choisi == -1, "couche Fouilles choisie")
	ed._verbe_choisi(Fouille.VERBES.find("ouvrir"))
	ed._meuble_choisi(Fouille.MEUBLES.find("tonneau"))
	ed._categorie_choisie(Fouille.CATEGORIES_BUTIN.find("ingredient"))
	var k_oignon: int = ObjetsDivers.noms("ingredient").find("Oignon") + 1
	ed._objet_choisi(k_oignon)
	var j: int = ed.poser_contenant(Vector2(600, 360))
	var point: Dictionary = ed.salle.donnees["fouilles"][j]
	verifier(bool(point["hasard"]) and point["contenu"].is_empty(), "nouveau point de fouille : au hasard, rien de réglé à la main")
	verifier(ed.resume_contenant(point) == "Tonneau — Ouvrir : au hasard", "résumé : " + ed.resume_contenant(point))
	ed._hasard_coche(false)
	ed._ajouter_contenu()
	verifier(point["verbe"] == "ouvrir" and point["meuble"] == "tonneau" and point["contenu"][0]["objet"] == "Oignon"
		and not point["hasard"], "point de fouille « Ouvrir », tonneau, un oignon réglé à la main, sans hasard")
	verifier(ed.resume_contenant(point) == "Tonneau — Ouvrir : Oignon", "résumé : " + ed.resume_contenant(point))
	ed._enregistrer()
	var relu := SallePeinte.lire_salle("porte2")
	verifier(relu.get("coffres", []).size() == 1 and relu.get("fouilles", []).size() == 1, "enregistrés dans porte2.json")
	var manuel = JSON.parse_string(FileAccess.get_file_as_string("res://outils/zones_manuelles/porte2.json"))
	verifier(manuel is Dictionary and manuel.has("coffres") and manuel.has("fouilles"), "aussi dans zones_manuelles")
	ed._charger()
	verifier(ed.salle.donnees["coffres"].size() == 1 and ed.salle.donnees["fouilles"][0]["verbe"] == "ouvrir", "relus par l'éditeur")
	ed.queue_free()
	# Dans le jeu
	var salle := {}
	var objets := Fouille.objets_salle(salle, "porte2")
	var coffres := objets.filter(func(o): return o["type"] == "coffre")
	var fouilles := objets.filter(func(o): return o["type"] == "fouille")
	verifier(coffres.size() == 1 and fouilles.size() == 1, "la salle du plan reçoit le coffre et le point de fouille")
	var affiches := Fouille.a_afficher(objets, "porte2")
	var sp := SallePeinte.new()
	root.add_child(sp)
	var obstacles_sans := 0
	sp.charger("porte2", -1, false, [])
	obstacles_sans = sp.donnees["obstacles"].size()
	await process_frame
	sp.charger("porte2", -1, false, affiches)
	verifier(sp.objets.size() == affiches.size(), "salle peinte : tous les objets posés (%d)" % sp.objets.size())
	var i_coffre := -1
	var i_fouille := -1
	for i in sp.objets.size():
		if sp.objets[i]["type"] == "coffre":
			i_coffre = i
		if sp.objets[i]["type"] == "fouille":
			i_fouille = i
	verifier(i_coffre >= 0 and sp.objets[i_coffre]["texture"] != null, "coffre affiché (image provisoire)")
	verifier(i_fouille >= 0 and sp.objets[i_fouille]["texture"] == null, "point de fouille invisible")
	verifier(sp.donnees["obstacles"].size() > obstacles_sans, "le coffre arrête le héros")
	sp.heros.position = sp.pied_objet(i_fouille)
	verifier(sp.objet_proche() == i_fouille, "héros au pied du meuble : le point de fouille est à portée")
	verifier(sp.objets[i_fouille].get("verbe", "") == "ouvrir" and sp.objets[i_fouille].get("nom_meuble", "") == "le tonneau",
		"le point de fouille propose « Ouvrir le tonneau »")
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var or_avant := int(joueur.piece_or)
	var msg := Fouille.fouiller(coffres[0], joueur, donjon)
	verifier(int(joueur.piece_or) == or_avant + 40 and joueur.inventaire.filter(func(o): return o.nom.contains("Potion de soin")).size() == 1,
		"coffre : 40 or et UNE potion de soin (le nombre de l'or n'est pas repris) : " + msg)
	msg = Fouille.fouiller(fouilles[0], joueur, donjon)
	verifier(msg.begins_with("Vous ouvrez le tonneau.") and joueur.inventaire.filter(func(o): return o.nom == "Oignon").size() == 1, "point de fouille : " + msg)
	sp.marquer_fouille(i_fouille)
	verifier(sp.objet_proche() != i_fouille, "fouillé : plus proposé")
	sp.queue_free()
