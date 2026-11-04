extends SceneTree
## Captures des commis et du menu Dialogues (2026-11-04) : commis de la cuisine et cuisinière (183) et du cellier (184) dans leur
## salle, héros à côté (« Parler (E) »), dialogue du commis de la cuisine (185), menu « Dialogues » de l'éditeur (186).
## Rien n'est enregistré. Fenêtre hors écran (override.cfg, voir README) : godot --path . -s tests/capture_commis.gd

var racine: Control


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func capturer(nom: String) -> void:
	await attendre(4)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(4)
	Sauvegarde.reinitialiser_monde()
	Compte.vider()
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	donjon.salle_actuelle = [1, 1]
	Aventure.preparer_etage(donjon, 1)
	Ecrans.auto = true
	for image in ["bloc_cuisine_cuisine", "bloc_cuisine_cellier_d"]:
		for i in donjon.plan_donjon[1]:
			if String(donjon.plan_donjon[1][i].get("salle_peinte", {}).get("image", "")) == image:
				donjon.salle_actuelle = [1, int(i)]
		var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
		Ecrans.pile.append(nav)
		racine.add_child(nav)
		await attendre(30)
		var pos: Array = Aventure.COMMIS[image][0]["pos"]
		nav.salle_peinte.heros.position = Vector2(float(pos[0]) + 60, float(pos[1]) + 40)
		await attendre(20)
		await capturer("183_commis_cuisine" if image == "bloc_cuisine_cuisine" else "184_commis_cellier")
		Ecrans.pile.erase(nav)
		nav.queue_free()
		await attendre(2)
	Ecrans.auto = false
	var lignes := Dialogues.liste("commis_cuisine/explications")
	var dlg = Ecrans._ecran("ecran_dialogue").preparer(Dialogues.texte("commis_cuisine/nom"), String(lignes[1]), ["…", "Partir"],
		Ecrans.capture(), Rencontres.COULEUR_COMMIS)
	racine.add_child(dlg)
	await capturer("185_commis_dialogue")
	dlg.queue_free()
	await attendre(2)
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await attendre(2)
	ed.ouvrir_dialogues()
	var d = ed.dialogues
	var k: int = d.personnages.map(func(q): return q["nom"]).find("Commis de la cuisine")
	d.liste.select(k)
	d._personnage_choisi(k)
	var item = d._trouver(d.arbre.get_root(), "dialogues.json", ["commis_cuisine", "explications", 1])
	item.select(0)
	await capturer("186_editeur_dialogues")
	print("fin")
	Compte.vider()
	quit()
