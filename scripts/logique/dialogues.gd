class_name Dialogues
extends RefCounted
## Textes des personnages (2026-11-04, demande de l'utilisateur : pouvoir modifier tous les dialogues dans l'éditeur
## de zones, bouton « Dialogues »). Ils sont dans ``donnees/dialogues.json`` (diablotin, succube, commis, gobelin
## blessé, prisonnier enchaîné, autel, gobelins pacifiques, rumeurs) ; les prisonniers des cellules et leurs quêtes
## restent dans ``donnees/prisonniers.json``. Un chemin « diablotin/accueil/neutre » désigne un texte ; les mots entre
## accolades ({direction}, {pv}...) sont remplacés par ``valeurs``.

const FICHIER := "dialogues.json"
static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = U.charger_json(FICHIER)
		_donnees = lu if lu is Dictionary else {}
	return _donnees


## Relit le fichier (après une modification dans l'éditeur, ou dans les tests).
static func recharger() -> void:
	_donnees = {}


## Valeur brute au ``chemin`` (« a/b/c ») : texte, liste ou dictionnaire (null si absente).
static func valeur(chemin: String):
	var v = donnees()
	for morceau in chemin.split("/"):
		if v is Dictionary and v.has(morceau):
			v = v[morceau]
		elif v is Array and morceau.is_valid_int() and int(morceau) < v.size():
			v = v[int(morceau)]
		else:
			return null
	return v


## Texte au ``chemin``, avec ses {mots} remplacés par ``valeurs`` (« » s'il manque : signalé dans la console).
static func texte(chemin: String, valeurs := {}) -> String:
	var v = valeur(chemin)
	if not (v is String):
		push_warning("Dialogue introuvable : " + chemin)
		return ""
	return remplir(v, valeurs)


static func remplir(t: String, valeurs: Dictionary) -> String:
	for cle in valeurs:
		t = t.replace("{%s}" % cle, str(valeurs[cle]))
	return t


## Liste de textes au ``chemin`` ([] si absente).
static func liste(chemin: String) -> Array:
	var v = valeur(chemin)
	return v if v is Array else []


## Dictionnaire {clé : texte} au ``chemin`` ({} si absent), dans l'ordre du fichier.
static func table(chemin: String) -> Dictionary:
	var v = valeur(chemin)
	return v if v is Dictionary else {}
