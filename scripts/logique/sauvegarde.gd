class_name Sauvegarde
extends RefCounted
## Sauvegarde et chargement des parties.
##
## Une partie (héros, donjon, état global des ennemis et des objets) est écrite
## dans ``user://sauvegardes/<nom>.sav`` : un résumé lisible seul, puis la partie.
## Les objets du jeu (Dyn) sont enregistrés par leur script et leur dictionnaire
## d'attributs ; les références partagées (lanceur d'une altération...) sont
## conservées. Trois emplacements, plus une sauvegarde temporaire (« Continuer »).

const DOSSIER := "user://sauvegardes"
const TEMPORAIRE := "temporaire"
const EMPLACEMENTS := ["emplacement_1", "emplacement_2", "emplacement_3"]
const VERSION := 1


static func chemin(nom: String) -> String:
	return "%s/%s.sav" % [DOSSIER, nom]


static func existe(nom: String) -> bool:
	return FileAccess.file_exists(chemin(nom))


static func supprimer(nom: String) -> void:
	if existe(nom):
		DirAccess.remove_absolute(chemin(nom))


# ---------------------------------------------------------------------------
# Encodage des objets
# ---------------------------------------------------------------------------

static func _encoder(v, table: Dictionary, objets: Dictionary):
	if v is Talent:
		return {"__talent": v.ident}
	if v is Dyn:
		var id: int = v.get_instance_id()
		if not table.has(id):
			table[id] = null  # réservé avant l'encodage (références circulaires)
			var donnees
			if v is ArbreDeTalent:
				donnees = {"__arbre": v.etat_sauvegarde()}
			else:
				donnees = _encoder(v._d, table, objets)
			table[id] = {"script": v.get_script().resource_path, "d": donnees}
		return {"__ref": id}
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _encoder(v[k], table, objets)
		return d
	if v is Array:
		var a := []
		for e in v:
			a.append(_encoder(e, table, objets))
		return a
	if v is Callable or v is Object:
		return null
	return v


static func _decoder(v, instances: Dictionary):
	if v is Dictionary:
		if v.size() == 1 and v.has("__ref"):
			return instances.get(v["__ref"])
		if v.size() == 1 and v.has("__talent"):
			return Talents.noeuds().get(v["__talent"])
		var d := {}
		for k in v:
			d[k] = _decoder(v[k], instances)
		return d
	if v is Array:
		var a := []
		for e in v:
			a.append(_decoder(e, instances))
		return a
	return v


static func _ecrire_objets(racine) -> Dictionary:
	var table := {}
	var encode = _encoder(racine, table, {})
	return {"racine": encode, "objets": table}


static func _lire_objets(donnees: Dictionary):
	var instances := {}
	var table: Dictionary = donnees["objets"]
	for id in table:
		var script = load(table[id]["script"])
		instances[id] = script.new()
	for id in table:
		var d = table[id]["d"]
		if d is Dictionary and d.has("__arbre"):
			instances[id].restaurer(d["__arbre"])
		else:
			instances[id]._d = _decoder(d, instances)
	return _decoder(donnees["racine"], instances)


# ---------------------------------------------------------------------------
# Sauvegardes
# ---------------------------------------------------------------------------

## Enregistre la partie en cours (écrite à côté puis renommée).
static func sauvegarder(nom: String, joueur, donjon) -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var etage = donjon.salle_actuelle[0]
	var salle = donjon.salle_actuelle[1]
	var entete := {"version": VERSION, "date": Time.get_unix_time_from_system(), "nom": joueur.nom, "niveau": joueur.niveau,
		"etage": etage, "salle": salle, "pv": int(joueur.points_de_vie), "pv_max": int(joueur.points_de_vie_max),
		"or": int(joueur.piece_or)}
	var partie := _ecrire_objets({"joueur": joueur, "donjon": donjon})
	partie["bonus_globaux"] = Ennemis.bonus_globaux.duplicate()
	partie["compteur_etage_objet"] = Objet.compteur_etage_objet
	var provisoire := chemin(nom) + ".tmp"
	var fichier := FileAccess.open(provisoire, FileAccess.WRITE)
	if fichier == null:
		push_error("Impossible d'écrire la sauvegarde " + nom)
		return
	fichier.store_var(entete)
	fichier.store_var(partie)
	fichier.close()
	DirAccess.rename_absolute(provisoire, chemin(nom))


## Résumé d'une sauvegarde sans charger la partie (null si absente ou illisible).
static func resume(nom: String):
	if not existe(nom):
		return null
	var fichier := FileAccess.open(chemin(nom), FileAccess.READ)
	if fichier == null:
		return null
	var entete = fichier.get_var()
	return entete if entete is Dictionary else null


## Recharge une partie : [héros, donjon].
static func charger(nom: String, fenetre = null) -> Array:
	var fichier := FileAccess.open(chemin(nom), FileAccess.READ)
	fichier.get_var()
	var partie: Dictionary = fichier.get_var()
	Ennemis.bonus_globaux.clear()
	Ennemis.bonus_globaux.merge(partie["bonus_globaux"])
	Objet.compteur_etage_objet = partie["compteur_etage_objet"]
	var racine: Dictionary = _lire_objets(partie)
	var donjon = racine["donjon"]
	donjon.fenetre = fenetre
	var joueur = racine["joueur"]
	for cle in Objets.EMPLACEMENTS_EQUIPEMENT:
		if not joueur.equipements.has(cle):
			joueur.equipements[cle] = null
	return [joueur, donjon]


## Remet à zéro l'état global partagé par toutes les parties (avant une nouvelle partie).
static func reinitialiser_monde() -> void:
	for cle in Ennemis.bonus_globaux:
		Ennemis.bonus_globaux[cle] = 0
	Objet.compteur_etage_objet = 1
