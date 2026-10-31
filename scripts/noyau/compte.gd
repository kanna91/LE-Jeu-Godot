class_name Compte
extends RefCounted
## Ce que le joueur garde d'une partie à l'autre, même après une mort (demande de l'utilisateur, 2026-10-31) :
## le **glossaire** des ennemis (ce que les diablotins ont appris au joueur sur eux). Enregistré dans
## ``user://compte.json``, à côté des sauvegardes mais indépendant d'elles : une nouvelle partie ne l'efface pas.
##
## ``glossaire`` : {nom de l'ennemi : [{"cle", "texte"}, ...]} dans l'ordre où le joueur l'a appris ;
## ``dits`` : {clé : vrai}, les informations sur les ennemis déjà données (un diablotin ne les redit jamais,
## même dans une autre partie).
##
## Pendant les tests (script lancé avec ``-s`` : la boucle principale a un script), rien n'est écrit sur le disque :
## le compte reste en mémoire, pour ne jamais toucher celui du joueur.

const CHEMIN := "user://compte.json"

static var _d := {}
static var _charge := false


static func _en_test() -> bool:
	var boucle = Engine.get_main_loop()
	return boucle != null and boucle.get_script() != null


static func _donnees() -> Dictionary:
	if not _charge:
		_charge = true
		_d = {}
		if not _en_test() and FileAccess.file_exists(CHEMIN):
			var f := FileAccess.open(CHEMIN, FileAccess.READ)
			var lu = JSON.parse_string(f.get_as_text()) if f != null else null
			if lu is Dictionary:
				_d = lu
		if not (_d.get("glossaire") is Dictionary):
			_d["glossaire"] = {}
		if not (_d.get("dits") is Dictionary):
			_d["dits"] = {}
	return _d


static func _enregistrer() -> void:
	if _en_test():
		return
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_donnees(), "  "))


## Vrai si l'information ``cle`` sur un ennemi a déjà été apprise (dans n'importe quelle partie).
static func connu(cle: String) -> bool:
	return _donnees()["dits"].has(cle)


## Ajoute au glossaire une information sur ``ennemi`` (une seule fois par clé), puis enregistre le compte.
static func apprendre(ennemi: String, cle: String, texte: String) -> void:
	var d := _donnees()
	if d["dits"].has(cle):
		return
	d["dits"][cle] = true
	if not (d["glossaire"].get(ennemi) is Array):
		d["glossaire"][ennemi] = []
	d["glossaire"][ennemi].append({"cle": cle, "texte": texte})
	_enregistrer()


## Le glossaire : {ennemi : [{"cle", "texte"}, ...]}.
static func glossaire() -> Dictionary:
	return _donnees()["glossaire"]


## Oublie tout le compte (tests seulement : en jeu, le compte ne s'efface jamais).
static func vider() -> void:
	_d = {"glossaire": {}, "dits": {}}
	_charge = true
