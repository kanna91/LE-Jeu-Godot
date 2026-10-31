extends SceneTree
## Un ennemi n'est soigné qu'une fois par combat (compétence de soin ou potion) ; le héros a 1 PA.
## godot --headless --path godot -s tests/test_soins.gd


func _initialize() -> void:
	Ecrans.auto = true
	seed(5)
	var echecs := 0
	var heros := Personnage.nouveau()
	if heros.points_d_action_max != 1 or heros.points_d_action != 1:
		print("ÉCHEC : le héros a %d PA." % heros.points_d_action_max)
		echecs += 1
	var donjon := Donjon.nouveau(heros)
	var chaman = Gobelin.nouveau(donjon).generer_chaman_gobelin(donjon)
	var blesse = Gobelin.nouveau(donjon).generer_combattant_gobelin(donjon)
	var combat := Combat.nouveau(heros, null, [chaman, blesse], donjon)
	var soin = chaman._competence("Soin")
	chaman.mana = 999
	for essai in 2:
		blesse.points_de_vie = 1
		chaman.points_d_action = 1
		combat.lancer(soin, chaman, donjon, heros, [blesse])
		print("Soin n° %d : %s a %s PV" % [essai + 1, blesse.nom, blesse.points_de_vie])
		if essai == 0 and blesse.points_de_vie <= 1:
			print("ÉCHEC : le premier soin n'a rien rendu.")
			echecs += 1
		if essai == 1 and blesse.points_de_vie != 1:
			print("ÉCHEC : le second soin a été appliqué.")
			echecs += 1
	if blesse.peut_etre_soigne():
		echecs += 1
		print("ÉCHEC : l'ennemi soigné n'est pas marqué.")
	# Potion : marque l'ennemi, et l'IA ne la boit plus une fois soigné.
	var buveur = Gobelin.nouveau(donjon).generer_combattant_gobelin(donjon)
	buveur.inventaire.append(Consommable.creer_potion("pv", 1))
	buveur.utiliser_consommable(buveur.trouver_consommable())
	if buveur.peut_etre_soigne():
		echecs += 1
		print("ÉCHEC : la potion ne compte pas comme un soin.")
	# Un ennemi gelé (1 PA) perd son tour : l'écran l'affiche (« Tour perdu (Gel) »).
	var gele = Gobelin.nouveau(donjon).generer_combattant_gobelin(donjon)
	var combat_gel := Combat.nouveau(heros, null, [gele], donjon)
	EffetsCombat.nouveau_combat(combat_gel)
	Alterations.appliquer_alterations(gele, "gel", heros, 100)
	var pv_heros = heros.points_de_vie
	combat_gel.tour_ennemis()
	var textes := []
	for imp in EffetsCombat.file:
		if imp.texte != null:
			textes.append(imp.texte[0])
	print("Ennemi gelé : textes affichés %s ; PV du héros %s → %s" % [textes, pv_heros, heros.points_de_vie])
	if not ("Tour perdu (Gel)" in textes) or heros.points_de_vie != pv_heros:
		echecs += 1
		print("ÉCHEC : tour perdu non affiché, ou l'ennemi gelé a joué.")
	print("BILAN soins : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
