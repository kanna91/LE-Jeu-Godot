extends SceneTree
## Emplacements des objets à fouiller (donnees/objets_salles.json) : pour chaque image et son miroir, tous
## les emplacements occupés à la fois (objet le plus large permis : le cas le plus encombrant), on parcourt
## le sol depuis le point de départ et l'on vérifie que :
## - chaque sortie reste atteignable (aucun objet ne bloque un passage) ;
## - chaque objet a un point atteignable à portée de fouille ;
## - le pied de chaque objet posé au sol est sur le sol de la salle, hors des sorties.
## godot --headless --path godot -s tests/test_emplacements.gd

var echecs := 0
const PAS := 3


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


## Objet le plus large permis par l'emplacement (type × variantes).
func plus_large(place: Dictionary) -> Dictionary:
	var meilleur := {}
	var largeur := -1.0
	for t in place["types"]:
		for v in range(1, Fouille.VARIANTES + 1):
			var tex := SallePeinte.texture(SallePeinte.chemin("images/objets_salles/%s_%d.png" % [t, v]))
			var l: float = SallePeinte.TAILLES[t] * tex.get_width() / tex.get_height()
			if l > largeur:
				largeur = l
				meilleur = place.duplicate()
				meilleur["type"] = t
				meilleur["objet"] = "%s_%d" % [t, v]
	return meilleur


func _initialize() -> void:
	var places_total := 0
	for image in SallePeinte.salles_disponibles():
		var places := Fouille.emplacements(image)
		verifier(not places.is_empty(), "%s : aucun emplacement" % image)
		places_total += places.size()
		var objets := []
		for p in places:
			objets.append(plus_large(p))
		for miroir in [false, true]:
			var nom: String = String(image) + (" (miroir)" if miroir else "")
			var s := SallePeinte.new()
			root.add_child(s)
			s.charger(image, -1, miroir, objets)
			s.portes = []
			# Parcours du sol depuis le départ
			var depart := Vector2(s.donnees["depart"][0], s.donnees["depart"][1])
			var vus := {}
			var file := [Vector2i(roundi(depart.x / PAS), roundi(depart.y / PAS))]
			vus[file[0]] = true
			var tete := 0
			while tete < file.size():
				var c: Vector2i = file[tete]
				tete += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					var n: Vector2i = c + d
					if vus.has(n) or n.x < 0 or n.y < 0 or n.x * PAS > 768 or n.y * PAS > 512:
						continue
					if s.libre(Vector2(n * PAS)):
						vus[n] = true
						file.append(n)
			# Sorties atteignables
			for i in s.donnees["sorties"].size():
				var poly: PackedVector2Array = s.donnees["sorties"][i]
				var ok := false
				for c in vus:
					if Geometry2D.is_point_in_polygon(Vector2(c * PAS), poly):
						ok = true
						break
				verifier(ok, "%s : sortie %d (%s) bloquée" % [nom, i, s.nom_sortie(i)])
			# Objets : pied sur le sol hors des sorties, et accessibles pour la fouille
			for i in s.objets.size():
				var o: Dictionary = s.objets[i]
				var pied := s.pied_objet(i)
				if not o.get("mur", false):
					var centre := Vector2(s.fond.get_width() - o["x"] if miroir else o["x"], o["y"])
					verifier(s._dans(centre, "marche"), "%s : %s %d hors du sol" % [nom, o["type"], i])
					verifier(s._sortie_sous(centre) < 0, "%s : %s %d posé sur une sortie" % [nom, o["type"], i])
				var portee: float = s.hauteur(pied.y) * SallePeinte.PORTEE_FOUILLE + o["largeur"] * 0.35
				var atteint := false
				for c in vus:
					if Vector2(c * PAS).distance_to(pied) < portee * 0.9:
						atteint = true
						break
				verifier(atteint, "%s : %s %d hors de portée de fouille" % [nom, o["type"], i])
			s.free()
	print("%d emplacements vérifiés" % places_total)
	print("BILAN emplacements : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
