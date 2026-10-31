extends SceneTree
## Combat animé (CombatAnime) : le héros de dos, un gobelin combattant, un archer et un sorcier.
## Pour chaque arme (épée, lance, marteau), puis une magie (Étincelle ardente : lancer de sort) : le héros et les gobelins bougent dès l'ouverture du
## combat (attente du guerrier à 250 ms par image), attaque du héros (clic sur le premier bouton, puis sur
## la cible si besoin), vérifie que l'animation d'attaque démarre et que son image d'impact tombe sur
## le premier coup, que la cible réagit (touché, sauf coup raté), puis que les gobelins jouent leur
## attaque calée sur leurs coups, démarrée EffetsCombat.PAUSE_RIPOSTE après le dernier coup du héros.
## Enfin, contre un chaman seul puis un féticheur seul, un sort à cible unique le vise sans clic,
## il riposte (un de ses deux lancers) puis meurt. Captures 31 à 42 dans tests/captures/.
## Affiche « BILAN combat animé : 0 échec(s) » si tout est correct.
## Lancer avec un override.cfg qui place la fenêtre hors écran et sans focus (voir README).

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


## Attend l'instant voulu, plus deux images pour que l'écran ait traité cet instant.
func attendre_jusqu_a(instant: float) -> void:
	while EffetsCombat.maintenant() < instant:
		await process_frame
	await attendre(2)


func capturer(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(condition: bool, message: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC : ", message)


func ecran_combat():
	var e = Ecrans.pile[-1] if not Ecrans.pile.is_empty() else null
	return e if e != null and e.has_method("rect_ennemi") else null


## Premier coup planifié d'une attaque animée d'une des sources données.
func coup_anime(sources: Array):
	for imp in EffetsCombat.file:
		if imp.source in sources and imp.debut != null and imp.anim_source != "":
			return imp
	return null


## Menu Magies puis Étincelle ardente (cible choisie automatiquement s'il ne reste qu'un ennemi).
func lancer_etincelle(ecran, etincelle) -> void:
	ecran._traiter([{"type": "clic", "pos": ecran.boutons_actions[3][0].get_center(), "bouton": 1}])
	await attendre(3)
	var rm = ecran.rects_magies.filter(func(r): return r[1].nom == etincelle.nom)
	ecran._traiter([{"type": "clic", "pos": rm[0][0].get_center(), "bouton": 1}])
	await attendre(3)


func lancer() -> void:
	seed(5)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 999
	joueur.points_de_vie = 999
	var donjon := Donjon.nouveau(joueur)
	Ecrans.menu_navigation(joueur, donjon)
	await attendre(5)
	var n := 31
	var etincelle := Competences.creer("Etincelle_ardente")
	joueur.magies_apprises.append(etincelle)
	for cas in [["Epée", "attaque"], ["Lance", "attaque"], ["Marteau", "attaque"], ["Epée", "sort"]]:
		var arme: String = cas[0]
		var anim_heros: String = cas[1]
		var nom: String = arme.to_lower().replace("é", "e") if anim_heros == "attaque" else "sort"
		joueur.mana_max = 999
		joueur.mana = 999
		joueur.equiper_item(Arme.nouvelle(arme, "arme", arme))
		verifier(CombatAnime.arme_heros(joueur) != "", "arme %s sans animation" % arme)
		var ennemis := []
		for cs in [["guerrier", "combattant"], ["guerrier", "archer"], ["mage", "sorcier"]]:
			var g = Gobelin.nouveau(donjon)._completer(cs[0], cs[1])
			g.points_de_vie_max = 500
			g.points_de_vie = 500
			ennemis.append(g)
			verifier(CombatAnime.type_gobelin(g) != "", "%s sans animation" % cs[1])
		var combat := Combat.nouveau(joueur, null, ennemis, donjon)
		combat.mener_combat()
		await attendre(30)
		var ecran = ecran_combat()
		# Dès l'ouverture du combat, le héros et chaque gobelin animé bougent (attente / garde).
		var combattants := [joueur] + ennemis
		var avant := combattants.map(func(c): return CombatAnime.image_courante(c)[1])
		await create_timer(0.6).timeout
		for i in combattants.size():
			if combattants[i] == joueur and CombatAnime.image_courante(joueur)[2]["images"] == 1:
				continue   # lance : pas d'idle fourni, garde d'une seule image
			verifier(CombatAnime.image_courante(combattants[i])[1] != avant[i],
				"%s : %s reste figé au début du combat" % [arme, combattants[i].nom])
		# Respiration du guerrier ralentie (MS_ATTENTE de outils/importer_animations.py).
		var attente: Dictionary = CombatAnime.donnees()["gobelins"]["guerrier"]["anims"]["attente"]
		verifier(int(attente["ms"][0]) == 250, "attente du guerrier à %s ms par image au lieu de 250" % attente["ms"][0])
		if arme == "Epée" and anim_heros == "attaque":
			capturer("%02d_combat_anime_garde" % n)
			n += 1
		# Attaque : premier bouton (ou Magies puis la première magie), puis la cible du milieu si
		# la compétence en demande une.
		if anim_heros == "sort":
			ecran._traiter([{"type": "clic", "pos": ecran.boutons_actions[3][0].get_center(), "bouton": 1}])
			await attendre(3)
			var rm = ecran.rects_magies.filter(func(r): return r[1].nom == etincelle.nom)
			ecran._traiter([{"type": "clic", "pos": rm[0][0].get_center(), "bouton": 1}])
		else:
			ecran._traiter([{"type": "clic", "pos": ecran.boutons_actions[0][0].get_center(), "bouton": 1}])
		await attendre(2)
		if ecran.competence_en_cours != null:
			ecran._traiter([{"type": "clic", "pos": ecran.rect_ennemi(ennemis[1]).get_center(), "bouton": 1}])
		await attendre(3)
		var imp = coup_anime([joueur])
		verifier(imp != null, "%s : aucun coup du héros calé sur son animation" % arme)
		if imp != null:
			var defn: Dictionary = CombatAnime.donnees()["heros"]["sort"] if anim_heros == "sort" 				else CombatAnime.donnees()["heros"]["armes"][CombatAnime.arme_heros(joueur)]["attaque"]
			# Instant de départ de l'attaque (en cours ou programmée) + temps jusqu'à l'image d'impact.
			var e: Dictionary = CombatAnime._etats[joueur]
			var depart = e["debut"] if e["anim"] == anim_heros else null
			for p in e["prochaines"]:
				if p[1] == anim_heros:
					depart = p[0]
			verifier(depart != null, "%s : le héros ne joue pas %s" % [arme, anim_heros])
			var avance := 0.0
			for i in int(defn["impact"]):
				avance += float(defn["ms"][i]) / 1000.0
			if depart != null:
				print("%s (%s) : premier coup %s (%s) sur %s ; image %d de l'animation à %.3f s, coup à %.3f s" % [
					arme, anim_heros, imp.type, imp.montant, imp.cible.nom, defn["impact"], depart + avance, imp.debut])
				verifier(absf(depart + avance - imp.debut) < 0.005, "%s : l'impact ne tombe pas sur l'image %d" % [arme, defn["impact"]])
			await attendre_jusqu_a(imp.debut)
			var reaction: String = CombatAnime.image_courante(imp.cible)[0]
			verifier(imp.type == "rate" or reaction in ["touche", "mort"], "%s : la cible ne réagit pas (%s)" % [arme, reaction])
			capturer("%02d_combat_anime_%s_impact" % [n, nom])
			n += 1
		# Tour des ennemis : leurs attaques s'affichent au début de l'écran suivant.
		var riposte = null
		for k in 900:
			riposte = coup_anime(ennemis)
			if riposte != null:
				break
			await attendre(1)
		verifier(riposte != null, "%s : aucun gobelin ne joue d'attaque calée sur son coup" % arme)
		if riposte != null:
			var src = riposte.source
			# Pause avant la riposte : son animation démarre PAUSE_RIPOSTE après le dernier coup du héros.
			var defn_r = CombatAnime._definition(src, riposte.anim_source)[0]
			var depart_r: float = riposte.debut - CombatAnime._duree(defn_r, int(defn_r["impact"]))
			print("%s : riposte animée %.2f s après le dernier coup du héros" % [arme, depart_r - EffetsCombat.dernier_coup_heros])
			verifier(depart_r >= EffetsCombat.dernier_coup_heros + EffetsCombat.PAUSE_RIPOSTE - 0.005,
				"%s : la riposte démarre %.2f s après le coup du héros (pause %.1f s attendue)" % [
					arme, depart_r - EffetsCombat.dernier_coup_heros, EffetsCombat.PAUSE_RIPOSTE])
			await attendre_jusqu_a(riposte.debut - 0.12)
			var etat := CombatAnime.image_courante(src)
			print("%s : riposte de %s (%s), image %d juste avant l'impact" % [arme, src.nom, etat[0], etat[1]])
			verifier(etat[0] == riposte.anim_source, "%s : %s ne joue pas %s" % [arme, src.nom, riposte.anim_source])
			if arme == "Epée" and anim_heros == "attaque":
				capturer("%02d_combat_anime_riposte_%s" % [n, src.sous_classe])
				n += 1
			await attendre_jusqu_a(riposte.debut + 0.1)
			verifier(CombatAnime.image_courante(joueur)[0] == "touche" or riposte.type == "rate" or riposte.montant <= 0,
				"%s : le héros ne réagit pas au coup reçu" % arme)
			if arme == "Epée" and anim_heros == "attaque":
				capturer("%02d_combat_anime_heros_touche" % n)
				n += 1
		# Fin du combat : plus d'ennemi, l'écran se ferme.
		combat._d["ennemis"].clear()
		for k in 600:
			if ecran_combat() == null:
				break
			await attendre(1)
		await attendre(5)
	# Un chaman seul, puis un féticheur seul : un sort à cible unique le prend pour cible sans clic,
	# il riposte avec un de ses deux lancers (capturé peu avant l'impact), puis meurt (capturé).
	for cs in [["soutien", "chaman"], ["mage", "feticheur"]]:
		var seul = Gobelin.nouveau(donjon)._completer(cs[0], cs[1])
		verifier(CombatAnime.type_gobelin(seul) == cs[1], "%s sans animation" % cs[1])
		seul.points_de_vie_max = 500
		seul.points_de_vie = 500
		joueur.mana = 999
		var combat_seul := Combat.nouveau(joueur, null, [seul], donjon)
		combat_seul.mener_combat()
		await attendre(30)
		var ecran = ecran_combat()
		verifier(etincelle.type_ciblage == "choix" and int(etincelle.nombre_cible) == 1, "Étincelle ardente n'est pas à cible unique")
		await lancer_etincelle(ecran, etincelle)
		verifier(ecran.competence_en_cours == null, "%s seul : le sort attend encore une cible" % cs[1])
		var coup = coup_anime([joueur])
		verifier(coup != null and coup.cible == seul, "%s seul : il n'est pas pris pour cible automatiquement" % cs[1])
		if coup != null and cs[1] == "chaman":
			await attendre_jusqu_a(coup.debut)
			capturer("%02d_combat_anime_cible_unique" % n)
			n += 1
		var lancer = null
		for k in 900:
			lancer = coup_anime([seul])
			if lancer != null:
				break
			await attendre(1)
		verifier(lancer != null, "le %s ne joue pas de lancer calé sur son coup" % cs[1])
		if lancer != null:
			await attendre_jusqu_a(lancer.debut - 0.25)
			print("%s : %s, image %d peu avant l'impact" % [cs[1], lancer.anim_source, CombatAnime.image_courante(seul)[1]])
			verifier(CombatAnime.image_courante(seul)[0] == lancer.anim_source, "le %s ne joue pas %s" % [cs[1], lancer.anim_source])
			capturer("%02d_combat_anime_%s_%s" % [n, cs[1], lancer.anim_source])
			n += 1
		# Coup fatal au tour suivant : animation de mort.
		var suivant = null
		for k in 900:
			suivant = ecran_combat()
			if suivant != null and suivant != ecran and not EffetsCombat.en_cours():
				break
			suivant = null
			await attendre(1)
		verifier(suivant != null, "%s : pas de nouveau tour" % cs[1])
		if suivant != null:
			seul.points_de_vie = 1
			Alterations.retirer_tout(joueur)   # Silence du féticheur : plus de magie
			Alterations.retirer_tout(seul)     # Protection, etc. : le coup doit tuer
			await lancer_etincelle(suivant, etincelle)
			var fatal = coup_anime([joueur])
			verifier(fatal != null and fatal.mortel, "%s : le coup n'est pas mortel" % cs[1])
			if fatal != null:
				await attendre_jusqu_a(fatal.debut + 0.7)
				verifier(CombatAnime.image_courante(seul)[0] == "mort", "%s : pas d'animation de mort" % cs[1])
				capturer("%02d_combat_anime_%s_mort" % [n, cs[1]])
				n += 1
		combat_seul._d["ennemis"].clear()
		for k in 600:
			if ecran_combat() == null:
				break
			await attendre(1)
		await attendre(5)
	print("BILAN combat animé : %d échec(s)" % echecs)
	quit()
