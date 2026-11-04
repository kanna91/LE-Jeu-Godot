extends SceneTree
## Commis, viande des loups et menu « Dialogues » de l'éditeur (2026-11-04, demandes de l'utilisateur) :
## - tous les textes que le jeu demande à ``Dialogues`` existent dans donnees/dialogues.json ;
## - un commis dans la cuisine (rôle « cuisine ») et un dans le cellier droit (« cellier ») du bloc cuisine, à leur
##   place fixe ; une ancienne partie sans commis les reçoit à la lecture de la salle ; leurs animations se chargent ;
## - un loup fouillé donne 1 viande crue (ingrédient), deux loups 2 ; un corps sans loup n'en donne pas ;
## - menu Dialogues : personnages des deux fichiers, modifier un texte, ajouter / supprimer une ligne, enregistrer
##   (les fichiers sont remis comme avant à la fin).
## godot --headless --path . -s tests/test_commis_dialogues.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
	print(("ok " if condition else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(1104)
	_textes()
	_commis()
	await _loups()
	await _editeur()
	print("BILAN commis et dialogues : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func _textes() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/logique/rencontres.gd")
	var re := RegEx.new()
	re.compile('Dialogues\\.(texte|liste|table)\\("([^"]+)"')
	var vus := 0
	for m in re.search_all(source):
		var chemin := m.get_string(2)
		if chemin.ends_with("/"):
			continue  # préfixe complété dans le code : vérifié plus bas
		vus += 1
		verifier(Dialogues.valeur(chemin) != null, "texte présent : " + chemin)
	verifier(vus > 30, "textes du jeu lus dans dialogues.json (%d)" % vus)
	var dynamiques := []
	for c in ["cruel", "mefiant", "bon", "neutre"]:
		dynamiques.append("diablotin/accueil/" + c)
	for c in ["affaires", "chevalier", "etage", "autre"]:
		dynamiques.append("diablotin/sujets/" + c)
	for c in ["geolier", "pupitre", "cachette", "chevalier", "succube", "cle_boss", "cle_boss_corps", "verrou", "gardien_faible", "gardien_fort"]:
		dynamiques.append("diablotin/etage/" + c)
	for c in ["geolier", "verrou", "pupitre", "cachette", "chevalier"]:
		dynamiques.append("rumeurs/etage/" + c)
	for c in ["salle_secrete", "coffre"]:
		dynamiques.append("diablotin/mensonges/" + c)
	for c in ["deja_scelle", "aucun_chevalier", "pas_assez_de_vie", "alors"]:
		dynamiques.append("succube/" + c)
	for c in Aventure.NOMS_PACTES:
		dynamiques.append("succube/effets_pactes/" + c)
	for role in ["cuisine", "cellier"]:
		for c in ["nom", "presentation", "boutons", "explications", "fin"]:
			dynamiques.append("commis_%s/%s" % [role, c])
	for chemin in dynamiques:
		verifier(Dialogues.valeur(chemin) != null, "texte présent : " + chemin)
	verifier(Dialogues.texte("diablotin/affaires/coffre", {"direction": "ICI"}).contains("ICI"), "mots entre accolades remplacés")
	verifier(Rencontres.infos_chevalier().size() == 14 and Rencontres.infos_chevalier()[0][0] == "tranchant", "chevalier : 14 informations, dans l'ordre")
	verifier(Rencontres.ennemi_de("astuce/geolier") == "Geôlier" and Rencontres.ennemi_de("astuce/ombre") == "", "conseils sur un ennemi")
	verifier(Dialogues.liste("commis_cuisine/explications").size() >= 5 and Dialogues.liste("commis_cellier/explications").size() >= 3,
		"explications des commis")


func _commis() -> void:
	Sauvegarde.reinitialiser_monde()
	var donjon := Donjon.nouveau(Personnage.nouveau())
	donjon.salle_actuelle = [1, 1]
	Aventure.preparer_etage(donjon, 1)
	var trouves := {}
	for i in donjon.plan_donjon[1]:
		var s: Dictionary = donjon.plan_donjon[1][i]
		for p in s.get("presences", []):
			if p.get("sous", "") == "commis":
				var image := String(s["salle_peinte"]["image"])
				trouves[p["role"]] = image
				var attendu: Array = Aventure.COMMIS[image]["pos"]
				verifier(absf(float(p["pos"][1]) - float(attendu[1])) < 0.5 and p["genre"] == "pnj", "commis %s à sa place" % p["role"])
	verifier(trouves.get("cuisine", "") == "bloc_cuisine_cuisine", "commis de la cuisine dans la cuisine")
	verifier(trouves.get("cellier", "") == "bloc_cuisine_cellier_d", "commis du cellier dans le cellier droit")
	verifier(trouves.size() == 2, "deux commis par étage")
	# Ancienne partie : la salle n'a pas de commis, il arrive à la lecture de la salle
	for i in donjon.plan_donjon[1]:
		var s: Dictionary = donjon.plan_donjon[1][i]
		if String(s.get("salle_peinte", {}).get("image", "")) == "bloc_cuisine_cuisine":
			s["presences"] = s["presences"].filter(func(q): return q.get("sous", "") != "commis")
			donjon.salle_actuelle = [1, int(i)]
			var liste := Aventure.presences(donjon, s)
			verifier(liste.any(func(q): return q.get("sous", "") == "commis"), "ancienne partie : commis ajouté à la lecture")
			Aventure.presences(donjon, s)
			verifier(s["presences"].filter(func(q): return q.get("sous", "") == "commis").size() == 1, "un seul commis, même relu")
			verifier(Aventure.action(liste.filter(func(q): return q.get("sous", "") == "commis")[0]) == "Parler", "on parle au commis (E)")
	for role in ["cuisine", "cellier"]:
		var images := PresencesSalle.images_commis(role)
		verifier(images.size() == 145 and images[0] is Texture2D, "animation du commis %s (%d images)" % [role, images.size()])


func _loups() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	donjon.salle_actuelle = [1, 1]
	var compter := func(): return joueur.inventaire.filter(func(o): return o.nom == "Viande crue").size()
	var avant: int = compter.call()
	var msg := Fouille.fouiller_corps(joueur, donjon, false, [Creatures.membre("loup"), {"classe": "gobelin", "sous_classe": "archer"}])
	verifier(compter.call() == avant + 1 and msg.contains("1 viande crue"), "un loup fouillé : 1 viande crue (%s)" % msg)
	var o = joueur.inventaire.filter(func(x): return x.nom == "Viande crue")[0]
	verifier(o.est_ingredient(), "la viande crue est un ingrédient")
	msg = Fouille.fouiller_corps(joueur, donjon, false, [Creatures.membre("loup"), Creatures.membre("loup")])
	verifier(compter.call() == avant + 3 and msg.contains("2 viandes crues"), "deux loups : 2 viandes crues (%s)" % msg)
	Fouille.fouiller_corps(joueur, donjon, false, [{"classe": "gobelin", "sous_classe": "guerrier"}])
	verifier(compter.call() == avant + 3, "pas de loup : pas de viande")
	# Par l'écran du corps (Aventure.cadavre), en mode automatique
	Ecrans.auto = true
	var corps := {"genre": "objet", "sous": "cadavre", "etat": "actif", "ames": 1, "fouille": false,
		"membres": [Creatures.membre("loup")]}
	for _k in 30:
		if corps["fouille"]:
			break
		corps["etat"] = "actif"
		await Aventure.cadavre(donjon, corps)
	verifier(corps["fouille"] and compter.call() == avant + 4, "corps de loup fouillé dans le jeu : viande crue")
	# Commis en mode automatique : la conversation se termine
	for role in ["cuisine", "cellier"]:
		var r = await Rencontres.commis(donjon, {"role": role})
		verifier(r is String, "conversation du commis %s" % role)
	Ecrans.auto = false


func _editeur() -> void:
	var originaux := {}
	for f in EditeurDialogues.FICHIERS:
		originaux[f] = FileAccess.get_file_as_string("res://donnees/" + f)
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed.ouvrir_dialogues()
	await process_frame
	var d: EditeurDialogues = ed.dialogues
	verifier(d.visible, "menu Dialogues ouvert")
	var noms: Array = d.personnages.map(func(q): return q["nom"])
	for n in ["Commis de la cuisine", "Commis du cellier", "Diablotin", "Succube", "Quête : Vieux magicien", "Quête : Mariane"]:
		verifier(n in noms, "personnage dans le menu : " + n)
	# Commis de la cuisine : choisir la 1re ligne des explications et la modifier
	var k: int = noms.find("Commis de la cuisine")
	d.liste.select(k)
	d._personnage_choisi(k)
	var item = d._trouver(d.arbre.get_root(), "dialogues.json", ["commis_cuisine", "explications", 0])
	verifier(item != null, "ligne 1 des explications dans l'arbre")
	item.select(0)
	verifier(d.choisi.get("texte", false) and d.edition.editable, "texte choisi, modifiable")
	d.edition.text = "« Essai de l'éditeur. »"
	d._texte_modifie()
	verifier(d.donnees["dialogues.json"]["commis_cuisine"]["explications"][0] == "« Essai de l'éditeur. »", "texte modifié")
	var n_avant: int = d.donnees["dialogues.json"]["commis_cuisine"]["explications"].size()
	d.ajouter_ligne()
	verifier(d.donnees["dialogues.json"]["commis_cuisine"]["explications"].size() == n_avant + 1
		and d.donnees["dialogues.json"]["commis_cuisine"]["explications"][1] == "" and d.choisi["chemin"] == ["commis_cuisine", "explications", 1],
		"ligne ajoutée après la ligne choisie, et choisie")
	d.edition.text = "Nouvelle ligne"
	d._texte_modifie()
	d.supprimer_ligne()
	verifier(d.donnees["dialogues.json"]["commis_cuisine"]["explications"].size() == n_avant, "ligne supprimée")
	# Quête : répliques modifiables, identifiants absents de l'arbre
	k = noms.find("Quête : Mariane")
	d.liste.select(k)
	d._personnage_choisi(k)
	verifier(d._trouver(d.arbre.get_root(), "prisonniers.json", ["quetes", 2, "presentation"]) != null, "quête : présentation dans l'arbre")
	verifier(d._trouver(d.arbre.get_root(), "prisonniers.json", ["quetes", 2, "debut"]) == null, "quête : identifiants cachés")
	verifier(d._trouver(d.arbre.get_root(), "prisonniers.json", ["quetes", 2, "etapes", "amulette", "texte", 0]) != null, "quête : répliques dans l'arbre")
	# Enregistrer, relire dans le jeu
	d.enregistrer()
	verifier(Dialogues.texte("commis_cuisine/explications/0") == "« Essai de l'éditeur. »", "enregistré : le jeu lit le nouveau texte")
	var texte_p := FileAccess.get_file_as_string("res://donnees/prisonniers.json")
	var relu = JSON.parse_string(texte_p)
	verifier(relu is Dictionary and int(relu["quetes"][0]["couleur"][0]) == 150 and not texte_p.contains("150.0"),
		"prisonniers.json : nombres entiers gardés")
	d.fermer()
	verifier(not d.visible, "menu fermé")
	ed.queue_free()
	await process_frame
	for f in originaux:
		var fichier := FileAccess.open("res://donnees/" + f, FileAccess.WRITE)
		fichier.store_string(originaux[f])
		fichier.close()
	Dialogues.recharger()
