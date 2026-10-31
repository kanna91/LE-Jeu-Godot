extends SceneTree
## Donjon d'aventure à l'écran (PresencesSalle) : une salle avec des gobelins, un Sans-Visage, un geôlier, un diablotin,
## un pupitre, un râtelier et une cachette. Le héros se cache derrière un pilier (« Caché »), un gobelin le repère
## (« ! », poursuite, « Repéré ! »), le contact lance le combat, E fait parler le diablotin, le geôlier capture le
## héros (réveil au cachot). Captures 92 à 99. À lancer hors écran (override.cfg, voir README).
## « BILAN aventure écran : 0 échec(s) ».

var racine: Control
var echecs := 0


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
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(condition: bool, cas: String) -> void:
	if condition:
		print("ok ", cas)
	else:
		echecs += 1
		print("ÉCHEC ", cas)


func entite(sp: SallePeinte, genre: String) -> Dictionary:
	for e in sp.presences.entites:
		if e["p"]["genre"] == genre or e["p"].get("sous", "") == genre:
			return e
	return {}


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	seed(5)
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte2"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null, null]
	salle["objets"] = []
	salle["objets_image"] = "porte2"
	salle["presences"] = [
		{"id": 901, "genre": "groupe", "etat": "actif", "nombre": 2, "chef": true, "pacifique": false},
		{"id": 902, "genre": "imbattable", "etat": "actif"},
		{"id": 903, "genre": "geolier", "etat": "actif"},
		{"id": 905, "genre": "objet", "sous": "pupitre", "etat": "actif"},
		{"id": 906, "genre": "objet", "sous": "ratelier", "etat": "actif"},
		{"id": 907, "genre": "objet", "sous": "cachette", "contenu": "cle", "etat": "actif"},
		{"id": 908, "genre": "groupe", "etat": "actif", "nombre": 1, "chef": false, "pacifique": true},
	]
	# Diablotin et succube arrivent plus tard : leur salle est « paisible » (pas d'autres ennemis, 2026-10-28)
	Aventure.meta(donjon, 1)["prepare"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	verifier(sp.presences != null and sp.presences.entites.size() == 7, "7 présences affichées")
	sp.presences.geler(1000.0)  # figées pendant la mise en place
	await capturer("92_aventure_salle")
	# Formes de près : chaque présence posée devant le héros
	var x := 150.0
	for e in sp.presences.entites:
		e["pos"] = Vector2(x, 470)
		e["noeud"].position = e["pos"]
		x += 70
	await capturer("93_aventure_formes")
	# Caché : immobile dans l'ombre
	var cache := Vector2.ZERO
	for y in range(380, 500, 3):
		for xx in range(20, 740, 3):
			var q := Vector2(xx, y)
			if sp.libre(q) and sp.dans_ombre(q):
				cache = q
				break
		if cache != Vector2.ZERO:
			break
	verifier(cache != Vector2.ZERO, "il y a de l'ombre dans la salle")
	sp.heros.position = cache
	await attendre(3)
	verifier(sp.heros_cache(), "immobile dans l'ombre : caché")
	await capturer("94_aventure_cache")
	# Un pilier coupe la vue
	# Deux points du sol à la même hauteur, séparés par ce qui n'est pas du sol (un pilier)
	var paire := []
	for y in range(380, 500, 4):
		for xx in range(20, 600, 4):
			var a := Vector2(xx, y)
			var b := Vector2(xx + 160, y)
			if sp.libre(a) and sp.libre(b) and not sp._dans(a.lerp(b, 0.5), "marche"):
				paire = [a, b]
				break
		if not paire.is_empty():
			break
	verifier(not paire.is_empty() and sp.vue_bouchee(paire[0], paire[1]), "un pilier coupe la vue")
	verifier(not sp.vue_bouchee(Vector2(300, 470), Vector2(400, 470)), "vue dégagée sans obstacle")
	# Un gobelin le voit : alerte puis poursuite
	var g := entite(sp, "groupe")
	sp.heros.position = Vector2(380, 470)
	g["pos"] = Vector2(380, 420)
	g["regard"] = Vector2(0, 1)
	g["etat"] = "ronde"
	for e in sp.presences.entites:
		if e != g and e["etat"] != "immobile":
			e["pos"] = Vector2(80, 380)
	sp.presences.gel_jusqu_a = 0.0
	sp.presences._contact_emis = true  # pas de combat pendant l'observation
	await attendre(8)
	verifier(g["etat"] in ["alerte", "poursuite"], "le gobelin repère le héros (%s)" % g["etat"])
	await attendre(50)
	verifier(g["etat"] == "poursuite", "il le poursuit")
	verifier(sp.presences.repere(), "« Repéré ! »")
	await capturer("95_aventure_repere")
	# Contact : combat (joueur automatique, assez de PV pour survivre au test)
	joueur.points_de_vie_max = 900
	joueur.points_de_vie = 900
	sp.presences._contact_emis = false
	await attendre(200)
	verifier(joueur.statistiques.get("combats_gagnes", 0) + joueur.statistiques.get("fuites", 0) >= 1,
		"le contact lance un combat")
	verifier(not nav._ferme, "l'exploration continue après le combat")
	Statistiques.mort = false
	await capturer("96_aventure_apres_combat")
	# Parler au diablotin : il entre dans la salle (les gobelins en partent : salle paisible)
	salle["presences"].append({"id": 904, "genre": "pnj", "sous": "diablotin", "etat": "actif"})
	sp.placer_presences(Aventure.presences(donjon, salle))
	await attendre(5)
	verifier(entite(sp, "groupe").is_empty() and not entite(sp, "geolier").is_empty(),
		"salle du diablotin : les gobelins sont partis, le geôlier reste")
	sp.presences.geler(1000.0)
	var d := entite(sp, "diablotin")
	sp.heros.position = d["pos"] + Vector2(12, 6)
	nav.passage_en_cours = false
	await attendre(3)
	verifier(sp.presences.proche().get("sous", "") == "diablotin", "le diablotin est à portée")
	await capturer("97_aventure_parler")
	await nav._interagir()
	verifier(nav.message_nav != "", "le diablotin répond : %s" % nav.message_nav)
	await capturer("98_aventure_diablotin")
	# Le geôlier capture le héros
	var geolier := entite(sp, "geolier")
	var cachot := String(Aventure.meta(donjon, 1).get("cachot", ""))
	nav.passage_en_cours = false
	await nav._contact(geolier["p"])
	await attendre(30)
	verifier(str(donjon.salle_actuelle[1]) == cachot, "réveil au cachot (salle %s)" % cachot)
	verifier(joueur.inventaire.is_empty(), "héros dépouillé")
	await capturer("99_aventure_cachot")
	# Écran de dialogue (diablotin)
	var dlg = Ecrans._ecran("ecran_dialogue").preparer("Diablotin", "« %s »" % Rencontres.phrase(donjon, "gardien", true),
		["Le gardien de l'étage ?", "Et cet étage ?", "Les ennemis ?", "Partir"], Ecrans.capture(), Rencontres.COULEUR_DIABLOTIN)
	racine.add_child(dlg)
	await capturer("100_aventure_dialogue")
	dlg.queue_free()
	# Succube : la liste des petits pactes
	joueur.points_de_vie_max = 40
	joueur.points_de_vie = 40
	var lignes := []
	for cle in ["voile", "carte", "baiser"]:
		lignes.append("%s (−%d PV max) : %s." % [Aventure.NOMS_PACTES[cle], Aventure.prix_pacte(joueur, cle), Rencontres.EFFETS_PACTES[cle]])
	dlg = Ecrans._ecran("ecran_dialogue").preparer("Succube", "\n".join(lignes), ["Voile", "Carte de chair", "Baiser du geôlier", "Retour"],
		Ecrans.capture(), Rencontres.COULEUR_SUCCUBE)
	racine.add_child(dlg)
	await capturer("101_aventure_succube")
	dlg.queue_free()
	# Baiser du geôlier : le geôlier touche le héros mais ne l'emmène pas
	Aventure.sceller_pacte(donjon, "baiser")
	var ici: Array = donjon.salle_actuelle.duplicate()
	var objets: int = joueur.inventaire.size()
	nav.passage_en_cours = false
	await nav._contact({"id": 950, "genre": "geolier", "etat": "actif"})
	await attendre(10)
	verifier(donjon.salle_actuelle == ici and joueur.inventaire.size() == objets, "baiser : le geôlier ne capture pas")
	verifier(not Aventure.pacte_actif(donjon, "baiser"), "baiser : utilisé")
	# Carte de chair : tout l'étage sur la mini-carte
	Aventure.sceller_pacte(donjon, "carte")
	await capturer("102_aventure_carte_chair")
	# Pacte de mort : le héros meurt et se réveille au cachot
	Aventure.sceller_pacte(donjon, "mort")
	donjon.salle_actuelle = [1, 1]
	joueur.points_de_vie = 0
	Statistiques.lever_mort("combat")
	verifier(nav._apres_action(), "mort : l'action s'arrête")
	await attendre(90)
	verifier(not nav._ferme and not Statistiques.mort, "pacte de mort : la partie continue")
	verifier(joueur.points_de_vie == 1 and str(donjon.salle_actuelle[1]) == cachot, "pacte de mort : 1 PV, au cachot")
	await capturer("103_aventure_pacte_mort")
	# Journal : ce que les diablotins ont appris au héros
	for k in 4:
		await Rencontres.diablotin(donjon, {"genre": "pnj", "sous": "diablotin", "etat": "actif"})
	verifier(not U.ga(joueur, "journal", []).is_empty(), "le journal contient les réponses des diablotins")
	var jnl = Ecrans._ecran("journal").preparer(joueur, Ecrans.capture())
	racine.add_child(jnl)
	await capturer("104_aventure_journal")
	jnl.queue_free()
	print("BILAN aventure écran : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
