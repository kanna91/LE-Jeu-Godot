extends RefCounted
## Salle d'essai des tests de l'éditeur (porte2) vidée de ce que l'utilisateur y a posé : coffres, fouilles, butins,
## ennemis interdits (2026-11-15 : son coffre et ses squelettes interdits faisaient échouer test_coffres_fouilles,
## test_butin_pose et test_editeur_zones). Chaque test lit d'abord les fichiers d'origine, appelle vider(), puis les
## remet comme avant et appelle nettoyer(). Une copie de secours (« .avant_test ») reste si le test s'arrête en route :
## la remettre à la main à la place du fichier.

const FICHIERS := ["res://donnees/salles_peintes/porte2.json", "res://outils/zones_manuelles/porte2.json"]
const CLES := ["coffres", "fouilles", "butins", "ennemis_interdits"]


static func vider() -> void:
	for chemin in FICHIERS:
		if not FileAccess.file_exists(chemin):
			continue
		var texte := FileAccess.get_file_as_string(chemin)
		var secours := FileAccess.open(chemin + ".avant_test", FileAccess.WRITE)
		secours.store_string(texte)
		secours.close()
		var d = JSON.parse_string(texte)
		if not (d is Dictionary):
			continue
		for cle in CLES:
			d.erase(cle)
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(JSON.stringify(d, " "))
		f.close()


## Efface les copies de secours, une fois les fichiers d'origine remis.
static func nettoyer() -> void:
	for chemin in FICHIERS:
		if FileAccess.file_exists(chemin + ".avant_test"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin + ".avant_test"))
