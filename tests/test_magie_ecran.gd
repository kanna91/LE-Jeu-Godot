extends SceneTree
## Écran de combat : un sort sans choix de cible (Soin, sur soi) lancé depuis « Magies » termine le tour
## du héros (1 PA) — il ne peut pas le relancer avant que les ennemis aient rejoué.
## godot --headless --path godot -s tests/test_magie_ecran.gd

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


func clic(pos: Vector2) -> void:
	Ecrans.pile[-1]._traiter([{"type": "clic", "pos": pos, "bouton": 1, "double": false}])
	await attendre(3)


func lancer() -> void:
	seed(12)
	var echecs := 0
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	joueur.magies_apprises.append(Competences.creer("Soin"))
	joueur.mana_max = 999
	joueur.mana = 999
	var donjon := Donjon.nouveau(joueur)
	var gobelin = Gobelin.nouveau(donjon).generer_combattant_gobelin(donjon)
	gobelin.points_de_vie_max = 9999
	gobelin.points_de_vie = 9999
	var combat := Combat.nouveau(joueur, null, [gobelin], donjon)
	combat.mener_combat()
	await attendre(10)
	var soins := 0
	var tours_ennemis := 0
	for essai in 3:
		var ecran = Ecrans.pile[-1]
		if not (ecran is Ecran) or ecran.get_script().resource_path.get_file() != "menu_combat.gd":
			print("ÉCHEC : l'écran de combat n'est pas ouvert (essai %d)." % (essai + 1))
			echecs += 1
			break
		var mana_avant: int = joueur.mana
		var pv_gobelin_pa = gobelin.points_d_action
		for ba in ecran.boutons_actions:
			if ba[1] == "Magies":
				await clic(ba[0].get_center())
		await attendre(3)
		var cible_rect = null
		for rm in ecran.rects_magies:
			if rm[1].nom_classe == "Soin":
				cible_rect = rm[0]
		if cible_rect == null:
			print("ÉCHEC : le sort Soin n'apparaît pas dans le menu Magies.")
			echecs += 1
			break
		# Deux clics rapides sur le sort : un seul soin doit partir.
		await clic(cible_rect.get_center())
		if Ecrans.pile[-1] == ecran:
			await clic(cible_rect.get_center())
		if joueur.mana < mana_avant:
			soins += 1
		var lancers: int = (mana_avant - joueur.mana) / maxi(1, Competences.creer("Soin").cout_mana)
		print("Essai %d : %d soin(s) lancé(s) par ce clic, écran fermé : %s" % [essai + 1, lancers, ecran.fin_demandee])
		if lancers != 1 or not ecran.fin_demandee:
			print("ÉCHEC : plusieurs soins dans le même tour, ou l'écran reste ouvert.")
			echecs += 1
		# Animations, puis tour des ennemis et nouvel écran de combat.
		for i in 600:
			await attendre(1)
			var haut = Ecrans.pile[-1] if not Ecrans.pile.is_empty() else null
			if haut != ecran and haut is Ecran and haut.get_script().resource_path.get_file() == "menu_combat.gd":
				break
	print("BILAN magie écran : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
