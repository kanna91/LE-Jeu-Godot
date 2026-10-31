extends SceneTree
## Charge (compile) tous les scripts du projet et signale ceux qui échouent.


func _initialize() -> void:
	var erreurs := 0
	for dossier in ["res://scripts/noyau", "res://scripts/logique", "res://scripts/interface", "res://scripts/ecrans", "res://scripts"]:
		for f in DirAccess.get_files_at(dossier):
			if f.ends_with(".gd"):
				var s = load(dossier + "/" + f)
				if s == null or not s.can_instantiate():
					print("ÉCHEC : ", dossier + "/" + f)
					erreurs += 1
	print("Compilation terminée : %d échec(s)" % erreurs)
	quit()
