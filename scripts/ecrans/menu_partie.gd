class_name MenuPartie
extends RefCounted
## Fonctions communes aux écrans de gestion de la partie.

const CAUSES := {"combat": "Tombé au combat", "piège": "Tué par un piège"}


## Date lisible d'une sauvegarde : « 01/10/2026 à 14:05 ».
static func date(horodatage) -> String:
	var decalage: int = Time.get_time_zone_from_system().get("bias", 0) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(horodatage) + decalage)
	return "%02d/%02d/%04d à %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


## Résumé d'une sauvegarde sur une ligne, ou « Emplacement vide ».
static func texte_resume(resume) -> String:
	if resume == null:
		return "Emplacement vide"
	return "Niveau %d · Étage %d, salle %d · %d/%d PV · %d PO · le %s" % [resume["niveau"], resume["etage"], resume["salle"],
		resume["pv"], resume["pv_max"], resume["or"], date(resume["date"])]


## Colonne de boutons centrée : {libellé: Rect2}.
static func boutons_colonne(libelles: Array, centre_x: float, y: float, largeur := 300, hauteur := 44, ecart := 12) -> Dictionary:
	var boutons := {}
	for i in libelles.size():
		boutons[libelles[i]] = Rect2(centre_x - largeur / 2, y + i * (hauteur + ecart), largeur, hauteur)
	return boutons


## Bouton survolé (clé du dictionnaire), ou null.
static func bouton_sous(boutons: Dictionary, pos: Vector2):
	for nom in boutons:
		if boutons[nom].has_point(pos):
			return nom
	return null
