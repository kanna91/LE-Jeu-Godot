extends SceneTree
## Régression : redescendre d'un étage ne doit pas refaire combattre le boss de l'étage inférieur,
## et remonter ne doit pas relancer de rencontre dans la salle de départ déjà visitée.
## godot --headless --path godot -s tests/test_descente.gd


func _initialize() -> void:
	lancer()


func lancer() -> void:
	Ecrans.auto = true
	seed(7)
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 100000
	joueur.points_de_vie = 100000
	var donjon := Donjon.nouveau(joueur)
	var echecs := 0
	# Donjon d'aventure : on ne monte pas tant que le boss (présence « boss » de sa salle) est vivant.
	donjon.salle_actuelle = [1, donjon.salle_boss(1)]
	await donjon.monter_etage()
	if donjon.salle_actuelle[0] != 1:
		print("ÉCHEC : on monte alors que le boss de l'étage est vivant.")
		echecs += 1
	# Le boss de l'étage 1 est vaincu : on monte.
	for p in donjon.salle_courante().get("presences", []):
		if p["genre"] == "boss":
			p["etat"] = "vaincu"
	await donjon.monter_etage()
	if donjon.salle_actuelle[0] != 2:
		print("ÉCHEC : le boss vaincu, on ne monte pas.")
		echecs += 1
	await donjon.descendre_etage()
	if not donjon.boss_vaincu(1):
		print("ÉCHEC : le boss de l'étage 1 est réapparu en redescendant.")
		echecs += 1
	if not donjon.est_salle_boss():
		print("ÉCHEC : la descente n'arrive pas dans la salle du boss.")
		echecs += 1
	await donjon.monter_etage()
	if donjon.salle_actuelle[0] != 2:
		print("ÉCHEC : on ne remonte pas à l'étage 2 (boss de l'étage 1 déjà vaincu).")
		echecs += 1
	print("BILAN descente : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
