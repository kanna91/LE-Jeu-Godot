class_name Talent
extends Dyn
## Nœud du sphérier : un talent et ses bonus.
## Attributs : ident, nom, stats, genre, branche, sous_branche, x, y, description.


static func depuis_donnees(n: Dictionary) -> Talent:
	var t := Talent.new()
	t._d["ident"] = n["ident"]
	t._d["nom"] = n["nom"]
	t._d["stats"] = n["stats"]
	t._d["genre"] = n["genre"]
	t._d["branche"] = n["branche"]
	t._d["sous_branche"] = n["sous_branche"]
	t._d["x"] = float(n["x"])
	t._d["y"] = float(n["y"])
	t._d["description"] = n["description"]
	return t


## Ajoute les bonus du talent au personnage (une seule fois, à l'apprentissage).
func appliquer(personnage) -> void:
	var stats: Dictionary = _d["stats"]
	for attribut in stats:
		personnage.set(attribut, U.ga(personnage, attribut, 0) + U.entiers(stats[attribut]))


## Le talent comporte un malus (valeur négative ou contrainte de talent clé).
func a_un_malus() -> bool:
	var stats: Dictionary = _d["stats"]
	for a in ["talent_sans_critique_physique", "talent_magie_du_sang", "talent_sans_potion_pv"]:
		if U.vrai(stats.get(a)):
			return true
	for v in stats.values():
		if v < 0:
			return true
	return false


func _to_string() -> String:
	return "<Talent %s : %s>" % [_d.get("ident"), _d.get("nom")]
