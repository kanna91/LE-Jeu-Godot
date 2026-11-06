extends SceneTree
## Captures de l'onglet Altérations de l'éditeur des ennemis (2026-11-06) : composées classées par type (Brûlure),
## briques primaires (Dégâts à chaque tour), créateur (copie de Corruption), fiche de compétence (Trait de l'ombre).
## Sans enregistrer.
## tests/captures/editeur_alterations_type.png, _briques.png, _createur.png. Hors écran (override.cfg, voir README).


func _initialize() -> void:
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func capturer(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)


func lancer() -> void:
	var ed := EditeurEnnemis.new()
	ed.size = Vector2(1280, 720)
	root.add_child(ed)
	await process_frame
	ed.onglets.current_tab = 1
	ed.choix_classement.select(1)
	ed.classer_par_type = true
	ed._remplir_liste_alterations()
	ed.choisir_alteration("brulure")
	await attendre(8)
	capturer("editeur_alterations_type")
	ed.vue_alterations = 0
	ed.choix_vue_alterations.select(0)
	ed._remplir_liste_alterations()
	ed.choisir_brique("degats_par_tour")
	await attendre(8)
	capturer("editeur_alterations_briques")
	ed.creer_alteration("corruption")
	await attendre(8)
	capturer("editeur_alterations_createur")
	ed.onglets.current_tab = 0
	ed.choisir_competence("Trait_des_Ombres")
	await attendre(8)
	capturer("editeur_competence")
	ed.fiche_competence.get_parent().scroll_vertical = 420
	await attendre(8)
	capturer("editeur_competence_degats")
	print("BILAN capture altérations : 0 échec(s)")
	quit()
