extends SceneTree
## Outil : part du sol de chaque salle où le héros est caché derrière le premier plan (SallePeinte.point_cache).
## godot --path godot -s tests/sonde_cachettes.gd (hors écran)

func _initialize() -> void:
	var racine := Control.new()
	root.add_child(racine)
	var sp := SallePeinte.new()
	racine.add_child(sp)
	for image in SallePeinte.salles_disponibles():
		for miroir in [false, true]:
			sp.charger(image, -1, miroir)
			var libres := 0
			var caches := 0
			var exemple := Vector2.ZERO
			for y in range(300, 512, 3):
				for x in range(0, 768, 3):
					var q := Vector2(x, y)
					if sp.libre(q):
						libres += 1
						if sp.point_cache(q) or sp.dans_ombre(q):
							caches += 1
							exemple = q
			print("%s%s : %d points libres, %d cachés (%.1f %%) ex. %s" % [image, " miroir" if miroir else "", libres, caches,
				100.0 * caches / maxf(1, libres), exemple])
	quit()
