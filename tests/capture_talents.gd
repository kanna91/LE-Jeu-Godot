extends SceneTree
## Captures du sphérier et du marchand (curseur virtuel uniquement).

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
	seed(5)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var _donjon := Donjon.nouveau(joueur)
	joueur.points_de_talent = 6
	Ecrans.menu_talents(joueur)
	var ecran = Ecrans.pile[-1]
	await attendre(40)
	await capturer("20_talents")
	var racine_t = Talents.noeuds()[Talents.RACINE]
	for v in Talents.spherier()["voisins"][Talents.RACINE]:
		joueur.debloquer_talent(Talents.noeuds()[v])
		break
	ecran.viser("Centre")
	await attendre(60)
	ecran.apprendre(Talents.noeuds()[Talents.spherier()["voisins"][Talents.RACINE].keys()[1]])
	await attendre(12)
	await capturer("21_talents_centre")
	ecran.bilan_ouvert = true
	await capturer("22_talents_bilan")
	ecran.fermer()
	await attendre(2)
	var m := Marchand.nouveau()
	m.generer_inventaire()
	joueur.piece_or = 300
	Ecrans.menu_marchand(null, m, joueur)
	await capturer("23_marchand")
	Manette.mode_manette = true
	Manette.pos = Vector2(200, 135)
	await capturer("24_marchand_survol")
	Manette.mode_manette = false
	print("fin")
	quit()
