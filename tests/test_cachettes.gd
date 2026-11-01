extends SceneTree
## Cachettes (zones « cachettes » de l'éditeur, 2026-11-01) : dans une cachette, le héros n'est ni vu ni entendu,
## il est « caché » ; un ennemi qui le poursuivait de loin perd sa trace, n'entre pas dans la cachette et ne lance
## pas de combat ; celui qui le poursuivait tout près quand il y est entré (PROCHE_CACHETTE) peut l'y suivre.
## godot --headless --path . -s tests/test_cachettes.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
	print(("ok " if condition else "ÉCHEC ") + cas)


func _initialize() -> void:
	var salle := SallePeinte.new()
	root.add_child(salle)
	salle.charger("porte5", -1, false)
	await process_frame
	var h: Vector2 = salle.heros.position
	# Une cachette autour du héros
	salle.donnees["cachettes"] = [PackedVector2Array([h + Vector2(-40, -20), h + Vector2(40, -20), h + Vector2(40, 15), h + Vector2(-40, 15)])]
	verifier(salle.heros_en_cachette() and salle.heros_cache(), "dans la cachette : le héros est caché")
	salle.placer_presences([{"id": 1, "genre": "groupe", "etat": "actif", "nombre": 1, "membres": [{}]},
		{"id": 2, "genre": "groupe", "etat": "actif", "nombre": 1, "membres": [{}]}])
	var pr: PresencesSalle = salle.presences
	var loin: Dictionary = pr.entites[0]
	var pres: Dictionary = pr.entites[1]
	# Hors de la cachette d'abord : le héros est loin de la zone, les deux le poursuivent
	salle.heros.position = h + Vector2(0, 60)
	pr._suivre_cachette()
	loin["etat"] = "poursuite"
	pres["etat"] = "poursuite"
	loin["pos"] = salle.heros.position + Vector2(-330, -40)
	pres["pos"] = salle.heros.position + Vector2(0, -50)
	# Le héros entre dans la cachette : seul l'ennemi tout près l'a vu
	salle.heros.position = h
	pres["pos"] = h + Vector2(65, 0)
	pr._suivre_cachette()
	verifier(pres.get("vu_entrer", false), "l'ennemi tout près l'a vu entrer")
	verifier(not loin.get("vu_entrer", false), "l'ennemi lointain ne l'a pas vu entrer")
	verifier(pr._percoit(pres), "celui qui l'a vu entrer le perçoit encore")
	verifier(not pr._percoit(loin), "l'autre ne le voit ni ne l'entend")
	# L'ennemi lointain n'entre pas dans la cachette
	loin["pos"] = h + Vector2(-70, 0)
	var avant: Vector2 = loin["pos"]
	for k in 60:
		pr._avancer(loin, h, 0.7, 1.0 / 60.0, true)
	verifier(not salle.dans_cachette(loin["pos"]) and loin["pos"] != avant, "l'ennemi lointain s'approche mais s'arrête au bord (%s → %s)" % [str(avant), str(loin["pos"])])
	# Il perd sa trace (recherche) au lieu de rester à l'affût
	loin["etat"] = "poursuite"
	loin["t"] = 0.0
	for k in 400:
		pr._comportement(loin, 1.0 / 60.0)
	verifier(loin["etat"] != "poursuite", "l'ennemi lointain perd sa trace (%s)" % loin["etat"])
	# Celui qui l'a vu entrer peut y entrer
	pres["pos"] = h + Vector2(65, 0)
	for k in 30:
		pr._avancer(pres, h, 0.7, 1.0 / 60.0, true)
	verifier(salle.dans_cachette(pres["pos"]), "l'ennemi qui l'a vu entrer le suit dans la cachette (%s → %s)" % [str(h + Vector2(65, 0)), str(pres["pos"])])
	# Le héros sort : plus de privilège
	salle.heros.position = h + Vector2(0, 80)
	pr._suivre_cachette()
	verifier(not pres.has("vu_entrer"), "hors de la cachette : plus de « vu entrer »")
	print("BILAN cachettes : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
