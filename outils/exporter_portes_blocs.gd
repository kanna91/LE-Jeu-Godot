extends SceneTree
## Écrit les portes de toutes les salles des blocs (BlocsSalles.BLOCS), avec et sans miroir, dans un .json pour
## outils/assembler_blocs.py (2026-11-10). godot --headless --path . -s outils/exporter_portes_blocs.gd -- <sortie.json>

func _initialize() -> void:
	var r := {}
	for nom in BlocsSalles.BLOCS:
		var b: Dictionary = BlocsSalles.BLOCS[nom]
		r[nom] = {}
		for cle in b["salles"]:
			var s: Dictionary = b["salles"][cle]
			r[nom][cle] = {"image": s["image"], "n": PlanSalles.directions(s["image"], false),
				"m": PlanSalles.directions(s["image"], true), "miroir": bool(s.get("miroir", false)),
				"pos": [s["position"].x, s["position"].y]}
	var args := OS.get_cmdline_user_args()
	var f := FileAccess.open(args[0] if args.size() > 0 else "user://portes_blocs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
	quit()
