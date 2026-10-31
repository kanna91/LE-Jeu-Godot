class_name Reference
extends Dyn
## Combattant de référence de l'équilibrage (equilibrage.py : Reference) : toute
## statistique absente vaut 0 (1 pour un ``pourcentage_*``), et il ne meurt jamais.


static func nouvelle(stats: Dictionary) -> Reference:
	var r := Reference.new()
	for cle in stats:
		r._d[cle] = stats[cle]
	r._d["alteration"] = {}
	r._d["magie"] = true
	return r


static func _defaut(nom: String):
	return 1.0 if nom.begins_with("pourcentage_") else 0


func _get(propriete):
	if _d.has(propriete):
		return _d[propriete]
	var nom := String(propriete)
	if nom.begins_with("__") or nom == "script":
		return null
	return _defaut(nom)


func lire(nom: String, _defaut_ignore = null):
	if _d.has(nom):
		return _d[nom]
	return _defaut(nom)


func possede(nom: String) -> bool:
	return not nom.begins_with("__")


func est_vivant() -> bool:
	return true


## Copie indépendante (altérations comprises).
func copie() -> Reference:
	var autre := Reference.new()
	autre._d = _d.duplicate()
	var alterations := {}
	for k in _d["alteration"]:
		alterations[k] = _d["alteration"][k].duplicate()
	autre._d["alteration"] = alterations
	return autre
