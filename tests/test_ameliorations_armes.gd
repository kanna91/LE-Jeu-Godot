extends SceneTree
## Améliorations des armes (armurier, alchimiste, enchanteur ; règles de l'utilisateur, 2026-11-09) :
## - recettes : 4 d'armurier, 27 d'alchimie (poison limité à 1d4), 24 d'enchantement ; apprises en ramassant le butin ;
## - au plus 3 améliorations d'armurier et 3 en tout chez l'alchimiste et l'enchanteur (mélange libre) ;
## - armurier : dés du type de l'arme, seulement pour ses attaques (Coup de marteau, Frénésie...) ;
## - alchimiste : dés pour les attaques de l'arme, jamais pour les sorts ; enchanteur : dés pour les sorts seulement ;
## - un type que la compétence fait déjà s'ajoute à ses dés, un autre devient un coup à part (types_en_plus) ;
## - prix payé en or, refus sans recette ou sans or ; les 3 PNJ sont posés dans leurs salles.
## godot --headless --path . -s tests/test_ameliorations_armes.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1109)
	_recettes()
	_limites()
	_des_combat()
	_achat()
	_ramassage()
	_placement()
	print("BILAN améliorations d'armes : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func _heros_avec(type_arme: String) -> Personnage:
	var j := Personnage.nouveau()
	var arme = GenerationObjets.generer_objet("arme", 1, type_arme)
	arme._d["de_bonus"] = {}  # sans dé bonus tiré au hasard : dés attendus exacts
	j.equiper_item(arme)
	return j


func _recettes() -> void:
	var toutes := AmeliorationsArmes.toutes_les_recettes()
	verifier(toutes.size() == 55, "55 recettes (%d)" % toutes.size())
	verifier(toutes.filter(func(x): return x.begins_with("armurier")).size() == 4, "4 recettes d'armurier")
	verifier(not ("alchimiste:poison:6" in toutes), "pas de poison 1d6")
	verifier("alchimiste:poison:4" in toutes, "poison 1d4 existe")
	verifier(not ("enchanteur:poison:2" in toutes), "l'enchanteur ne fait pas de poison")
	for id in toutes:
		verifier(AmeliorationsArmes.id_depuis_nom(AmeliorationsArmes.nom_recette(id)) == id, "nom ↔ identifiant " + id)


func _limites() -> void:
	var j := _heros_avec("Marteau")
	var arme = j.arme_equipee
	for f in [2, 2, 4]:
		verifier(AmeliorationsArmes.ameliorer(arme, "armurier", "contondant", f), "armurier 1d%d" % f)
	verifier(not AmeliorationsArmes.ameliorer(arme, "armurier", "contondant", 2), "4e amélioration d'armurier refusée")
	verifier(AmeliorationsArmes.ameliorer(arme, "alchimiste", "poison", 3), "alchimie poison 1d3")
	verifier(not AmeliorationsArmes.ameliorer(arme, "alchimiste", "poison", 6), "poison 1d6 refusé")
	verifier(AmeliorationsArmes.ameliorer(arme, "enchanteur", "feu", 3), "enchantement feu 1d3")
	verifier(AmeliorationsArmes.ameliorer(arme, "enchanteur", "feu", 3), "enchantement feu 1d3 (2e)")
	verifier(not AmeliorationsArmes.ameliorer(arme, "alchimiste", "feu", 2), "4e amélioration magique refusée")
	# Exemple de l'utilisateur : marteau 1d2 ×2 + 1d4, poison 1d3, feu des sorts 2d3
	var r := AmeliorationsArmes.resume(arme)
	verifier("1d4 + 2d2 contondant" in r and "1d3 poison" in r and "2d3 feu" in r, "résumé : " + r)


func _des_combat() -> void:
	var j := _heros_avec("Marteau")
	var arme = j.arme_equipee
	for f in [2, 2, 4]:
		AmeliorationsArmes.ameliorer(arme, "armurier", "contondant", f)
	AmeliorationsArmes.ameliorer(arme, "alchimiste", "poison", 3)
	AmeliorationsArmes.ameliorer(arme, "enchanteur", "feu", 3)
	AmeliorationsArmes.ameliorer(arme, "enchanteur", "feu", 3)
	var marteau := Competences.creer("Coup_de_marteau")
	var fracasser := Competences.creer("Fracasser")
	var boule := Competences.creer("Boule_de_feu")
	var ombres := Competences.creer("Murmure_des_ombres")
	var poing := Competences.creer("Coup_de_poing")
	verifier(AmeliorationsArmes.est_sort(j, boule) and AmeliorationsArmes.est_sort(j, ombres), "sorts de départ reconnus")
	verifier(not AmeliorationsArmes.est_sort(j, marteau), "Coup de marteau n'est pas un sort")
	# Armurier : sur les attaques du marteau seulement
	verifier(Formules.des_type(j, "contondant", marteau) == [[6, 2], [1, 4], [2, 2]],
		"Coup de marteau : 6d2 + 1d4 + 2d2 (%s)" % [Formules.des_type(j, "contondant", marteau)])
	verifier(Formules.des_type(j, "contondant", fracasser) == [[8, 2], [1, 4], [2, 2]], "Fracasser aussi")
	verifier(AmeliorationsArmes.des(j, poing, "contondant").is_empty(), "Coup de poing : pas d'armurier")
	verifier(AmeliorationsArmes.des(j, boule, "contondant").is_empty(), "sort : pas d'armurier")
	# Alchimie : poison en coup à part sur le marteau, jamais sur les sorts
	verifier(AmeliorationsArmes.types_en_plus(j, marteau) == [["poison", [[1, 3]]]],
		"Coup de marteau : +1d3 poison à part (%s)" % [AmeliorationsArmes.types_en_plus(j, marteau)])
	verifier(AmeliorationsArmes.des(j, boule, "poison").is_empty(), "sort : pas de poison de l'alchimiste")
	# Enchantement : feu des sorts ajouté aux dés de Boule de feu, coup à part sur Murmure des ombres, rien au marteau
	verifier(Formules.des_type(j, "feu", boule) == [[8, 2], [2, 3]], "Boule de feu : 8d2 + 2d3 (%s)" % [Formules.des_type(j, "feu", boule)])
	verifier(AmeliorationsArmes.types_en_plus(j, boule).is_empty(), "Boule de feu : pas de coup à part")
	verifier(AmeliorationsArmes.types_en_plus(j, ombres) == [["feu", [[2, 3]]]], "Murmure des ombres : +2d3 feu à part")
	verifier(AmeliorationsArmes.des(j, marteau, "feu").is_empty(), "marteau : pas de feu de l'enchanteur")
	# Estimation : le poison apparaît dans les dégâts du Coup de marteau
	var cible := Personnage.nouveau()
	var types := Formules.estimer_degats(j, marteau, cible).map(func(x): return x[0])
	verifier("poison" in types and "contondant" in types, "estimation du Coup de marteau : %s" % [types])
	# Combat : le coup inflige bien du poison (cible sans armure)
	var combat := Combat.nouveau(j, null, [cible], null)
	var avant: float = cible.points_de_vie
	j._d["chance_de_toucher"] = 10.0
	cible._d["chance_esquive"] = 0.0
	cible._d["chance_de_parer"] = 0.0
	combat.infliger_degats(j, marteau, cible, j)
	verifier(cible.points_de_vie < avant, "le Coup de marteau blesse")
	# Frénésie : reconnue comme attaque d'épée (nom de classe « Frenesie », corrigé le 2026-11-09)
	var e := _heros_avec("Epée")
	verifier(Formules.est_attaque_arme(e, Competences.creer("Frenesie")), "Frénésie est une attaque d'épée")
	# Ennemis : jamais d'améliorations
	verifier(AmeliorationsArmes.des(null, marteau, "contondant").is_empty(), "sans lanceur : rien")


func _achat() -> void:
	var j := _heros_avec("Lance")
	var arme = j.arme_equipee
	j.piece_or = 0
	verifier(AmeliorationsArmes.acheter(j, arme, "armurier", "perforant", 4) != "", "sans recette : refusé")
	AmeliorationsArmes.apprendre(j, "armurier:4")
	verifier(AmeliorationsArmes.connait(j, "armurier:4"), "recette apprise")
	verifier(AmeliorationsArmes.acheter(j, arme, "armurier", "perforant", 4) != "", "sans or : refusé")
	var p := AmeliorationsArmes.prix("armurier", 4)
	verifier(p > 0, "prix de 1d4 lu dans le .json (%d)" % p)
	j.piece_or = p + 5
	verifier(AmeliorationsArmes.acheter(j, arme, "armurier", "perforant", 4) == "", "achat fait")
	verifier(j.piece_or == 5, "or payé (%d restant)" % j.piece_or)
	verifier(AmeliorationsArmes.armurier_de(arme) == [4], "arme améliorée")
	verifier(Rencontres.recettes_artisan(j, "armurier").size() == 1 and Rencontres.recettes_artisan(j, "alchimiste").is_empty(),
		"recettes par PNJ")


func _ramassage() -> void:
	var j := Personnage.nouveau()
	var m := Fouille.ramasser({"categorie": "recette", "objet": "Recette d'alchimie (feu 1d3)"}, j, 1)
	verifier(AmeliorationsArmes.connait(j, "alchimiste:feu:3"), "recette ramassée apprise (%s)" % m)
	Fouille.ramasser({"categorie": "recette", "objet": ""}, j, 1)
	verifier(AmeliorationsArmes.recettes_connues(j).size() == 2, "recette au hasard apprise")
	verifier("recette" in Fouille.CATEGORIES_BUTIN, "catégorie Recette dans l'éditeur")


func _placement() -> void:
	var roles := []
	for image in Aventure.COMMIS:
		for c in Aventure.COMMIS[image]:
			roles.append(c["role"])
			verifier(FileAccess.file_exists("res://donnees/salles_peintes/%s.json" % image), "image %s existe" % image)
	# Dans un donjon généré, chaque PNJ est posé dans sa salle (si le bloc de l'image est sur l'étage)
	var trouves := []
	for k in 3:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for etage in donjon.plan_donjon:
			for i in donjon.plan_donjon[etage]:
				for p in donjon.plan_donjon[etage][i].get("presences", []):
					if p.get("sous", "") == "commis" and not (p.get("role", "") in trouves):
						trouves.append(p.get("role", ""))
	print("PNJ trouvés dans les donjons générés : ", trouves)
	for pnj in AmeliorationsArmes.PNJ:
		verifier(pnj in roles, pnj + " posé dans une salle")
		if not (pnj in trouves):
			# Pas un échec de ce test : le bloc de sa salle ne se construit pas (liens de blocs_salles.gd vers une
			# porte qui n'existe plus sur l'image, bug connu le 2026-11-09 pour la bibliothèque et le bloc cuisine)
			print("ATTENTION ", pnj, " absent des donjons générés : son bloc de salles ne se construit pas")
		verifier(Dialogues.texte(pnj + "/presentation") != "", pnj + " a ses dialogues")
	# Artisans et leurs aides (2026-11-11) : image détourée, dialogues, posés dans les donjons générés
	verifier(Dialogues.texte("armurier/nom") == "Forgeron", "l'armurier est devenu le forgeron")
	verifier(AmeliorationsArmes.id_depuis_nom("Recette d'armurier (1d3)") == AmeliorationsArmes.id_depuis_nom("Recette de forge (1d3)")
		and AmeliorationsArmes.id_depuis_nom("Recette de forge (1d3)") != "", "recette de forge (l'ancien nom marche encore)")
	for role in ["armurier", "alchimiste", "enchanteur", "apprenti_forgeron", "apprenti_alchimiste", "bibliothecaire", "assistante"]:
		verifier(PresencesSalle.image_artisan(role) != null, role + " a son image")
		verifier(role in trouves, role + " posé dans les donjons générés")
	for role in ["apprenti_forgeron", "apprenti_alchimiste", "bibliothecaire", "assistante"]:
		verifier(Dialogues.texte("commis_%s/presentation" % role) != "" and Dialogues.liste("commis_%s/explications" % role).size() >= 2,
			role + " a ses dialogues")
