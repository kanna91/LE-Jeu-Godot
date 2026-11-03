extends SceneTree
## Sonde : écrit les plans de quelques étages et du niveau des cryptes (positions, liens, rôles) dans
## user://sonde_plans.json, pour les dessiner (outil de contrôle, 2026-11-03).


func _initialize() -> void:
	seed(7)
	var sortie := []
	for k in 4:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for niveau in [1, Donjon.NIVEAU_CRYPTES]:
			var salles := []
			for id in donjon.plan_donjon[niveau]:
				var s: Dictionary = donjon.plan_donjon[niveau][id]
				var p: Vector2i = s["position"]
				var role := "prison_" + String(s["prison_salle"]) if s.has("prison_salle") else ("acces" if s.has("acces_prison") else ("depart" if s.get("depart", false) else ("boss" if s.get("boss", false) else ("entree" if s.has("passage_niveau") else ""))))
				salles.append({"id": id, "x": p.x, "y": p.y, "liens": s["connections"], "role": role,
					"image": s.get("salle_peinte", {}).get("image", ""), "sans_porte": s.get("salle_peinte", {}).get("sans_porte", []).size()})
			sortie.append({"donjon": k, "niveau": niveau, "salles": salles})
	var f := FileAccess.open("user://sonde_plans.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sortie))
	f.close()
	print(ProjectSettings.globalize_path("user://sonde_plans.json"))
	quit()
