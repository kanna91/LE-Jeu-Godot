extends Ecran
## Écran de combat : une action du joueur (menu_combat.afficher_menu_combat).
##
## Ennemis (qui respirent, avec barre de vie et altérations), barre d'actions,
## héros de dos au premier plan ; héros et gobelins combattant / archer / sorcier animés image par
## image, calés sur les coups (CombatAnime),
## menu des magies, boules de vie et de mana, animations de dégâts. Une
## compétence à ciblage « choix » attend un clic sur ses cibles ; Échap ou clic
## droit annule. L'écran se ferme quand une action est lancée (après les
## animations), quand le tour est passé ou quand il n'y a plus d'ennemi.

const MAGIES_PAR_COLONNE := 9
const LARGEUR_SPRITE := 150
const HAUTEUR_SPRITE := 225
const COULEURS_SPECIAUX := {"mini_boss": Color8(170, 90, 230), "boss": Color8(230, 60, 50)}
const LIBELLES_ACTIONS := {"Coup_d_epee": "Coup d'épée", "Coup de lance": "Coup de lance", "Utiliser un objet": "Objet",
	"Passer son tour": "Passer"}
const AIDES_ACTIONS := {
	"Utiliser un objet": "Boire une potion (1 PA).",
	"Magies": "Ouvre la liste de vos magies.",
	"Passer son tour": "Les ennemis jouent, puis vous récupérez vos PA.",
	"Fuir": "Tenter de fuir le combat. Ratée, la fuite vous coûte le tour.",
}
const SHADER_SILHOUETTE := "shader_type canvas_item;
render_mode blend_add;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(COLOR.rgb, 1.0) * step(0.235, a);
}"

var joueur
var combat
var magie_menu_visible := false
var magies_affichables := []
var ennemis_rects_images := []
var rects_magies := []
var competence_en_cours = null
var cibles_en_cours := []
var nb_cibles_attendues := 0
var type_ciblage = null
var fin_demandee := false
var actions := []
var boutons_actions := []
## Barre d'actions, compacte en bas de l'écran : ligne des PA et de la consigne, puis 5 boutons.
const LARGEUR_BOUTON := 92
const HAUTEUR_BOUTON := 32
const ECART_BOUTONS := 6
var rect_menu_actions := Rect2(Ui.LARGEUR / 2 - 300, Ui.HAUTEUR - 62, 600, 58)
var image_effets := {}
var couche_silhouettes: Control


func preparer(j, c) -> Ecran:
	joueur = j
	combat = c
	magies_affichables = j.magies_apprises.duplicate()
	EffetsCombat.nouveau_combat(c)
	CombatAnime.annuler_attaque_heros()
	fond_ecran = "salles/image_boss.png" if c.donjon.est_salle_boss() else "salles/salle_combat.png"
	_preparer_salle_peinte(c.donjon)
	if not c.possede("positions_ennemis_fixes"):
		c.positions_ennemis_fixes = placer_ennemis(c.ennemis)
	var type_arme = j.get_type_arme()
	var noms: Array
	if type_arme == "Epée":
		noms = ["Coup_d_epee", "Frénésie"]
	elif type_arme == "Lance":
		noms = ["Coup de lance", "Balayage"]
	elif type_arme == "Marteau":
		noms = ["Coup de marteau", "Fracasser"]
	else:
		noms = ["Coup de poing", "Enchainement"]
	actions = [[noms[0], j.competence_de_base.get(noms[0].replace(" ", "_"))], [noms[1], j.competence_de_base.get(noms[1].replace(" ", "_"))],
		["Utiliser un objet", null], ["Magies", null], ["Fuir", null], ["Passer son tour", null]]
	for i in actions.size():
		boutons_actions.append([Rect2(rect_menu_actions.position.x + 8 + i * (LARGEUR_BOUTON + ECART_BOUTONS), rect_menu_actions.position.y + 20,
			LARGEUR_BOUTON, HAUTEUR_BOUTON), actions[i][0]])
	couche_silhouettes = Control.new()
	couche_silhouettes.size = Vector2(Ui.LARGEUR, Ui.HAUTEUR)
	couche_silhouettes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_SILHOUETTE
	var materiau := ShaderMaterial.new()
	materiau.shader = shader
	couche_silhouettes.material = materiau
	couche_silhouettes.draw.connect(_dessiner_silhouettes)
	add_child(couche_silhouettes)
	move_child(couche_silhouettes, couche_lumiere.get_index())
	return self


## Fond du combat : la salle peinte de la salle où il a lieu (la même que dans l'exploration), animée
## par sa vidéo (image fixe tant que la première image n'est pas décodée). L'image (3:2) est
## recadrée en 16:9 sur toute la largeur, en gardant surtout le sol. Sans salle peinte (plan sans
## attribution, images absentes) : l'ancienne image (salle_combat.png, image_boss.png).
var fond_peint: Texture2D = null
var video_fond_peint: VideoStreamPlayer = null
var fond_peint_miroir := false
## Part de la hauteur coupée en trop prise en haut de l'image (le reste en bas).
const RECADRAGE_HAUT := 0.75


func _preparer_salle_peinte(donjon) -> void:
	if donjon == null:
		return
	var etage = donjon.salle_actuelle[0]
	if not donjon.plan_donjon.has(etage) or not donjon.plan_donjon[etage].has(str(donjon.salle_actuelle[1])):
		return
	PlanSalles.attribuer(donjon, etage)
	var info: Dictionary = donjon.salle_courante().get("salle_peinte", {})
	var id := String(info.get("image", ""))
	fond_peint_miroir = bool(info.get("miroir", false))
	if id == "":
		return
	var d := SallePeinte.lire_salle(id)
	if String(d.get("fond", "")) == "":
		return
	fond_peint = SallePeinte.texture(SallePeinte.chemin(String(d["fond"])))
	if fond_peint == null:
		return
	fond_ecran = ""
	video_fond_peint = SallePeinte.nouveau_lecteur(String(d.get("decor_video", "")))
	if video_fond_peint != null:
		add_child(video_fond_peint)  # lancée au premier affichage (l'écran n'est pas encore dans l'arbre)


func _dessiner_fond(ci: Control) -> void:
	if fond_peint == null:
		super(ci)
		return
	var tex := fond_peint
	if video_fond_peint != null and video_fond_peint.is_inside_tree() and not video_fond_peint.is_playing():
		video_fond_peint.play()
	if SallePeinte.video_prete(video_fond_peint):
		tex = video_fond_peint.get_video_texture()
	var taille := Vector2(fond_peint.get_size())
	var h := minf(taille.y, taille.x * Ui.HAUTEUR / Ui.LARGEUR)
	var region := Rect2(0, (taille.y - h) * RECADRAGE_HAUT, taille.x, h)
	var k := Vector2(tex.get_size()) / taille
	if fond_peint_miroir:
		ci.draw_set_transform(Vector2(Ui.LARGEUR, 0), 0, Vector2(-1, 1))
	ci.draw_texture_rect_region(tex, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), Rect2(region.position * k, region.size * k))
	ci.draw_set_transform(Vector2.ZERO)


static func taille_sprite(echelle: float) -> Vector2:
	return Vector2(int(LARGEUR_SPRITE * echelle), int(HAUTEUR_SPRITE * echelle))


## Largeur laissée libre au milieu de l'écran, devant le héros (de dos au premier plan, au centre) :
## sans elle, il cachait le bas de l'ennemi placé juste derrière lui.
const ECART_HEROS := 110.0


## Positions des sprites : côte à côte, pieds au même sol (80 % de la hauteur), le groupe centré avec
## ECART_HEROS libre au milieu ; la première moitié du groupe (arrondie au-dessus) à gauche du héros,
## le reste à droite. Un ennemi seul est donc juste à gauche du héros, sauf s'il est marqué ``centre_combat``
## (Chevalier de la mort) : il est alors au milieu, face au héros.
static func placer_ennemis(ennemis: Array) -> Dictionary:
	var positions := {}
	var sol := int(Ui.HAUTEUR * 0.80)
	var a_gauche := ceili(ennemis.size() / 2.0)
	var largeur_gauche := 0.0
	var largeur_droite := 0.0
	for i in ennemis.size():
		var l := taille_sprite(U.ga(ennemis[i], "taille_affichage", 1.0)).x
		if i < a_gauche:
			largeur_gauche += l
		else:
			largeur_droite += l
	var milieu := Ui.LARGEUR / 2.0
	var x := milieu - ECART_HEROS / 2.0 - largeur_gauche
	# Groupe trop large : on le ramène dans l'écran (l'écart rétrécit d'autant)
	x = clampf(x, 0.0, maxf(0.0, Ui.LARGEUR - largeur_gauche - largeur_droite - ECART_HEROS))
	for i in ennemis.size():
		if i == a_gauche:
			x = maxf(x, minf(milieu + ECART_HEROS / 2.0, Ui.LARGEUR - largeur_droite))
		var t := taille_sprite(U.ga(ennemis[i], "taille_affichage", 1.0))
		if ennemis.size() == 1 and U.ga(ennemis[i], "centre_combat", false):
			x = milieu - t.x / 2.0  # seul et face au héros (Chevalier de la mort) : au milieu, il frappe sur lui
		positions[ennemis[i]] = Vector2(x, sol - t.y)
		x += t.x
	return positions


static func rang_special(ennemi):
	if U.ga(ennemi, "est_boss", false):
		return "boss"
	return "mini_boss" if U.ga(ennemi, "est_mini_boss", false) else null


static func libelle_action(nom: String) -> String:
	return LIBELLES_ACTIONS.get(nom, nom.replace("_", " "))


static func texture_ennemi(ennemi) -> Texture2D:
	return Ui.texture("gobelins/" + str(ennemi.image))


## Un ennemi dans son cadre : image animée (CombatAnime) ou image fixe qui respire.
static func dessiner_ennemi(ci: CanvasItem, ennemi, r: Rect2, teinte := Color(1, 1, 1, 1)) -> void:
	var teinte_propre = U.ga(ennemi, "teinte_combat", null)  # Sans-Visage : silhouette sombre
	if teinte_propre is Color:
		teinte = teinte * teinte_propre
	if not CombatAnime.dessiner_gobelin(ci, ennemi, r, teinte):
		Animations.dessiner_respirant(ci, texture_ennemi(ennemi), r, Animations.phase_de(ennemi), teinte)


func rect_ennemi(ennemi):
	var position = combat.positions_ennemis_fixes.get(ennemi)
	if position == null:
		return null
	return Rect2(position, taille_sprite(U.ga(ennemi, "taille_affichage", 1.0)))


func _annuler() -> void:
	competence_en_cours = null
	cibles_en_cours.clear()
	nb_cibles_attendues = 0
	type_ciblage = null


# ---------------------------------------------------------------------------
# Image
# ---------------------------------------------------------------------------

func _mise_a_jour(_delta: float) -> void:
	Maux.avancer(joueur, _delta)  # l'intoxication continue pendant les combats (pas dans les menus)
	if combat.ennemis.is_empty() or Statistiques.mort:
		fin_demandee = true
	if fin_demandee and not EffetsCombat.en_cours():
		position = Vector2.ZERO
		fermer()
		return
	image_effets = EffetsDessin.calculer(rect_ennemi)
	CombatAnime.mettre_a_jour(joueur)
	couche_silhouettes.queue_redraw()


func _dessiner_barre_speciale(ci: Control, ennemi) -> Rect2:
	var rang = rang_special(ennemi)
	var couleur: Color = COULEURS_SPECIAUX[rang]
	var barre := Rect2(Ui.LARGEUR / 2 - 300, 26, 600, 16)
	Ui.texte(ci, ("BOSS — " if rang == "boss" else "MINI-BOSS — ") + ennemi.nom, Vector2(barre.get_center().x, barre.position.y - 2),
		couleur, 17, true, null, "midbottom")
	var pv := maxf(0.0, EffetsCombat.pv_affiches(ennemi))
	var ratio := pv / maxf(1, ennemi.points_de_vie_max)
	Ui.rect(ci, barre.grow(2), Color8(30, 10, 14), 0, 6)
	Ui.rect(ci, barre, Ui.foncer(couleur, 0.35), 0, 5)
	Ui.rect(ci, Rect2(barre.position, Vector2(int(barre.size.x * ratio), barre.size.y)), couleur, 0, 5)
	Ui.rect(ci, barre.grow(2), Ui.OR if rang == "boss" else Ui.BLANC, 2, 6)
	Ui.texte(ci, "%d / %d" % [int(pv), int(ennemi.points_de_vie_max)], barre.get_center(), Ui.BLANC, 13, true, null, "center")
	return barre


var _pastilles_ennemis := []
var _ennemi_survole = null


func _dessiner(ci: Control) -> void:
	var s := souris()
	ennemis_rects_images.clear()
	_pastilles_ennemis = []
	_ennemi_survole = null
	for ennemi in combat.ennemis:
		if not ennemi.est_vivant() or not combat.positions_ennemis_fixes.has(ennemi):
			continue
		var r: Rect2 = rect_ennemi(ennemi)
		var recul := EffetsCombat.decalage(ennemi)
		dessiner_ennemi(ci, ennemi, Rect2(r.position + recul, r.size))
		ennemis_rects_images.append([r, ennemi])
		if rang_special(ennemi) != null:
			var barre := _dessiner_barre_speciale(ci, ennemi)
			_pastilles_ennemis += Dessins.alterations(ci, ennemi, barre.position.x, barre.end.y + 6, barre.size.x, true)
		else:
			var barre_y := r.position.y - 10
			var barre := Rect2(r.position.x + 14, barre_y, 122, 7)
			var ratio := maxf(0.0, EffetsCombat.pv_affiches(ennemi) / ennemi.points_de_vie_max)
			Ui.rect(ci, barre, Color8(70, 12, 12), 0, 3)
			Ui.rect(ci, Rect2(barre.position, Vector2(int(barre.size.x * ratio), barre.size.y)), Color8(40, 200, 70), 0, 3)
			Ui.rect(ci, barre, Ui.NOIR, 1, 3)
			Ui.texte(ci, ennemi.nom, Vector2(r.position.x + 75, barre_y - 3), Ui.BLANC, 16, true, 146, "midbottom")
			_pastilles_ennemis += Dessins.alterations(ci, ennemi, r.position.x + 2, barre_y - 42, 146, true)
		if r.has_point(s):
			_ennemi_survole = [ennemi, r]
	if image_effets.is_empty():
		CombatAnime.dessiner_heros(ci, joueur)
		return
	# Ennemis vaincus : intacts jusqu'au coup fatal, puis ils se dissolvent (gobelins animés : ils
	# jouent leur mort puis s'effacent)
	var maintenant := EffetsCombat.maintenant()
	for m in image_effets["mourants"]:
		var imp = m[0]
		var r: Rect2 = m[1]
		if imp.debut != null and maintenant >= imp.debut and CombatAnime.dessiner_mourant(ci, imp, r):
			continue
		var tex := texture_ennemi(imp.cible)
		var phase := Animations.phase_de(imp.cible)
		var debut_mort = null if imp.debut == null else imp.debut + EffetsCombat.DEBUT_MORT
		if debut_mort == null or maintenant < debut_mort:
			var d := EffetsCombat.decalage(imp.cible)
			dessiner_ennemi(ci, imp.cible, Rect2(r.position + d, r.size))
			var pv := EffetsCombat.pv_affiches(imp.cible)
			Ui.rect(ci, Rect2(r.position.x, r.position.y - 10, r.size.x, 5), Color8(255, 0, 0))
			Ui.rect(ci, Rect2(r.position.x, r.position.y - 10, int(r.size.x * pv / maxf(1, imp.cible.points_de_vie_max)), 5), Color8(0, 255, 0))
			continue
		var u: float = (maintenant - debut_mort) / EffetsCombat.DUREE_MORT
		if u >= 1:
			continue
		var couleur: Color = EffetsCombat.COULEURS.get(imp.type, Color8(255, 255, 255))
		var k := minf(1, u * 2)
		var teinte := Color(1 - (1 - couleur.r) * k, 1 - (1 - couleur.g) * k, 1 - (1 - couleur.b) * k, pow(1 - u, 1.3))
		Animations.dessiner_respirant(ci, tex, Rect2(r.position + Vector2(0, int(18 * u)), r.size), phase, teinte)
	CombatAnime.dessiner_heros(ci, joueur)
	EffetsDessin.dessiner_formes(ci, image_effets["pinceau"])


func _dessiner_silhouettes() -> void:
	if image_effets.is_empty():
		return
	for sil in image_effets["silhouettes"]:
		dessiner_ennemi(couche_silhouettes, sil[0], sil[1], sil[2])


func _dessiner_lumiere(ci: Control) -> void:
	if not image_effets.is_empty():
		EffetsDessin.dessiner_lueurs(ci, image_effets["pinceau"])


func _dessiner_dessus(ci: Control) -> void:
	var s := souris()
	if not image_effets.is_empty():
		for c in image_effets["chiffres"]:
			EffetsDessin.dessiner_chiffre(ci, c[0], c[1], c[2])
	var info_bulle_active := _ennemi_survole != null
	if magie_menu_visible:
		for rm in rects_magies:
			if rm[0].has_point(s):
				info_bulle_active = false
	if info_bulle_active and not fin_demandee:
		FicheEnnemi.dessiner_infobulle(ci, _ennemi_survole[0], joueur, _ennemi_survole[1])
	# Barre d'actions : PA restants, consigne, boutons
	Ui.panneau(ci, rect_menu_actions, 215)
	for i in int(joueur.points_d_action_max):
		var couleur_pa := Color8(255, 210, 60) if i < joueur.points_d_action else Color8(70, 64, 80)
		Ui.cercle(ci, Vector2(rect_menu_actions.position.x + 18 + i * 14, rect_menu_actions.position.y + 11), 5, couleur_pa)
	Ui.texte(ci, "PA", Vector2(rect_menu_actions.position.x + 18 + joueur.points_d_action_max * 14, rect_menu_actions.position.y + 11),
		Ui.OR, 12, true, null, "midleft")
	var consigne := "Survol d'un ennemi : infos · clic : fiche détaillée"
	if competence_en_cours != null and type_ciblage == "choix":
		consigne = "%s : choisissez %d cible(s) — Échap / clic droit : annuler" % [libelle_action(competence_en_cours.nom), nb_cibles_attendues]
	Ui.texte(ci, consigne, Vector2(rect_menu_actions.end.x - 10, rect_menu_actions.position.y + 11), Ui.DETAIL, 11, false,
		rect_menu_actions.size.x - 120, "midright")
	var action_survolee = null
	for ba in boutons_actions:
		var r: Rect2 = ba[0]
		var nom: String = ba[1]
		var survol := r.has_point(s)
		var comp = _competence_action(nom)
		var possible: bool = comp == null or (joueur.points_d_action >= comp.cout_action and Talents.peut_payer(joueur, comp))
		var couleur_bouton := Ui.BOUTON_BLEU if nom == "Magies" else (Ui.BOUTON_ROUGE if nom == "Passer son tour" else
			(Color8(150, 110, 40) if nom == "Fuir" else Ui.BOUTON_NEUTRE))
		if competence_en_cours != null and comp == competence_en_cours:
			couleur_bouton = Color8(150, 110, 40)
		Ui.bouton(ci, r, libelle_action(nom), couleur_bouton, survol, possible, 13)
		if survol and not fin_demandee:
			action_survolee = [nom, comp, r]
	if magie_menu_visible:
		var bouton_magies: Rect2 = boutons_actions[3][0]
		rects_magies.clear()
		if magies_affichables.is_empty():
			Ui.infobulle(ci, "Aucune magie apprise", ["Apprenez-en dans le grimoire (touche M hors combat)."],
				Rect2(bouton_magies.position - Vector2(0, 70), bouton_magies.size), 240)
		for i in magies_affichables.size():
			var magie = magies_affichables[i]
			var colonne := i / MAGIES_PAR_COLONNE
			var rang := i % MAGIES_PAR_COLONNE
			var r := Rect2(bouton_magies.position.x - 40 - colonne * 226, bouton_magies.position.y - 12 - (rang + 1) * 36, 220, 32)
			rects_magies.append([r, magie])
			var assez: bool = Talents.peut_payer(joueur, magie) and joueur.points_d_action >= magie.cout_action and U.ga(joueur, "magie", true)
			var survol := r.has_point(s)
			Ui.rect(ci, r, Ui.LIGNE_SURVOL if survol else Color8(30, 34, 70), 0, 6)
			Ui.rect(ci, r, Ui.BRONZE, 1, 6)
			Ui.texte(ci, magie.nom, Vector2(r.position.x + 10, r.get_center().y), Ui.BLANC if assez else Ui.GRISE, 15, true, 130, "midleft")
			Ui.texte(ci, Talents.libelle_cout(joueur, magie), Vector2(r.end.x - 10, r.get_center().y), Color8(120, 170, 255) if assez else Ui.ROUGE,
				14, false, null, "midright")
			if survol and not fin_demandee:
				action_survolee = [magie.nom, magie, r]
	var pv_affiches := EffetsCombat.pv_affiches(joueur)
	Dessins.sphere(ci, Vector2(60, Ui.HAUTEUR - 60), Color8(200, 0, 0), pv_affiches / joueur.points_de_vie_max,
		"%d/%d" % [int(pv_affiches), int(joueur.points_de_vie_max)])
	Dessins.sphere(ci, Vector2(Ui.LARGEUR - 60, Ui.HAUTEUR - 60), Color8(0, 0, 200), joueur.mana / maxf(1, joueur.mana_max),
		"%d/%d" % [int(joueur.mana), int(joueur.mana_max)])
	var pastilles := Dessins.alterations(ci, joueur, rect_menu_actions.position.x, rect_menu_actions.position.y - 24, rect_menu_actions.size.x)
	if Dessins.infobulle_alterations(ci, pastilles + _pastilles_ennemis, s):
		info_bulle_active = true
	if action_survolee != null and action_survolee[1] != null and not info_bulle_active:
		Ui.infobulle(ci, libelle_action(action_survolee[0]), DescriptionObjet.lignes_competence(action_survolee[1], joueur), action_survolee[2], 290)
	elif action_survolee != null and action_survolee[0] == "Fuir" and not info_bulle_active:
		Ui.infobulle(ci, "Fuir", [AIDES_ACTIONS["Fuir"], "Chance de fuir : %d %%" % roundi(combat.chance_fuite() * 100)],
			action_survolee[2], 260)
	elif action_survolee != null and AIDES_ACTIONS.has(action_survolee[0]) and not info_bulle_active:
		Ui.infobulle(ci, action_survolee[0], [AIDES_ACTIONS[action_survolee[0]]], action_survolee[2], 240)
	position = EffetsDessin.post_traitement(ci, Vector2(60, Ui.HAUTEUR - 60))
	var zones_ennemis := []
	for ri in ennemis_rects_images:
		zones_ennemis.append([["ennemi", ri[1].get_instance_id()], ri[0]])
	if competence_en_cours != null and type_ciblage == "choix":
		definir_zones(zones_ennemis)
	else:
		var z := []
		for ba in boutons_actions:
			z.append([["action", ba[1]], ba[0]])
		if magie_menu_visible:
			for rm in rects_magies:
				z.append([["magie", rm[1].nom], rm[0]])
		definir_zones(z + zones_ennemis, ["action", boutons_actions[0][1]])


func _competence_action(nom: String):
	for a in actions:
		if a[0] == nom:
			return a[1]
	return null


# ---------------------------------------------------------------------------
# Entrées
# ---------------------------------------------------------------------------

func ouvrir_fiche(ennemi = null) -> void:
	var vivants := []
	for ri in ennemis_rects_images:
		vivants.append(ri[1])
	if vivants.is_empty():
		return
	if ennemi == null:
		ennemi = vivants[0]
		for ri in ennemis_rects_images:
			if ri[0].has_point(souris()):
				ennemi = ri[1]
				break
	await Ecrans.fiche_ennemi(vivants, vivants.find(ennemi), joueur)


## Compétence d'arme (les deux premiers boutons) : le héros jouera l'attaque de son arme ;
## magie : le lancer de sort. L'animation est calée sur son premier coup.
func _preparer_animation(comp) -> void:
	if comp == null:
		return
	if comp == actions[0][1] or comp == actions[1][1]:
		CombatAnime.demander_attaque_heros(joueur)
	elif comp in magies_affichables:
		CombatAnime.demander_sort_heros()


## Compétence à cibles choisies : attend les clics sur les ennemis. Une seule cible à choisir et un
## seul ennemi vivant : il est choisi tout de suite.
func _attendre_cibles(comp) -> void:
	var vivants: Array = combat.ennemis.filter(func(e): return e.est_vivant() and combat.positions_ennemis_fixes.has(e))
	if comp.type_ciblage == "choix" and int(comp.nombre_cible) == 1 and vivants.size() == 1:
		print("Cible unique : %s" % vivants[0].nom)
		_preparer_animation(comp)
		combat.logique_menu_combat(comp.nom, comp, vivants)
		_annuler()
		fin_demandee = true
		return
	competence_en_cours = comp
	nb_cibles_attendues = comp.nombre_cible
	type_ciblage = comp.type_ciblage
	print("%s prêt, sélectionnez %d cible(s)" % [libelle_action(comp.nom), nb_cibles_attendues])


func _lancer_direct(comp) -> void:
	var finales: Array = combat.choisir_cible(joueur, comp, comp.type_ciblage, comp.nombre_cible)
	combat.lancer(comp, joueur, combat.donjon, joueur, finales)


func _evenement(ev: Dictionary) -> void:
	if fin_demandee:
		return
	if ev["type"] == "touche":
		if ev["touche"] == KEY_ESCAPE:
			if magie_menu_visible:
				magie_menu_visible = false
			elif competence_en_cours != null:
				print("Action annulée via Échap.")
				_annuler()
		elif ev["touche"] == KEY_I:
			await ouvrir_fiche()
		return
	if ev["type"] != "clic":
		return
	var pos: Vector2 = ev["pos"]
	if ev["bouton"] == 3:
		_annuler()
		magie_menu_visible = false
		print("Action annulée. Vous pouvez choisir une autre compétence.")
		return
	if ev["bouton"] != 1:
		return
	var clic_magie = null
	if magie_menu_visible:
		for rm in rects_magies:
			if rm[0].has_point(pos):
				clic_magie = rm[1]
				break
	if clic_magie != null:
		pass
	elif competence_en_cours != null and type_ciblage == "choix":
		for ri in ennemis_rects_images:
			if ri[0].has_point(pos):
				cibles_en_cours.append(ri[1])
				print("Cible sélectionnée : %s" % ri[1].nom)
				nb_cibles_attendues -= 1
				if nb_cibles_attendues <= 0:
					_preparer_animation(competence_en_cours)
					combat.logique_menu_combat(competence_en_cours.nom, competence_en_cours, cibles_en_cours.duplicate())
					_annuler()
					fin_demandee = true
				break
	else:
		for ri in ennemis_rects_images:
			if ri[0].has_point(pos):
				await ouvrir_fiche(ri[1])
				return
	for ba in boutons_actions:
		if not ba[0].has_point(pos):
			continue
		var nom_action: String = ba[1]
		print("Action choisie : %s" % nom_action)
		if nom_action == "Magies":
			magie_menu_visible = not magie_menu_visible
		elif nom_action == "Utiliser un objet":
			var objet = await Ecrans.choisir_objet_combat(joueur)
			if objet != null:
				joueur.utiliser_objet_inventaire(objet.nom)
				combat.verification_des_vivants()
				combat.epuise()
				position = Vector2.ZERO
				fermer()
				return
		elif nom_action == "Fuir":
			if not combat.tenter_fuite():
				combat.passer_son_tour()  # fuite ratée : les ennemis jouent
			fin_demandee = true
		elif nom_action == "Passer son tour":
			combat.logique_menu_combat(nom_action)
			combat.tour_ennemis()
			combat.passer_son_tour()
			fin_demandee = true
		else:
			var comp = _competence_action(nom_action)
			var ok = combat.logique_menu_combat(nom_action, comp)
			if not ok:
				break
			competence_en_cours = comp
			if comp.type_ciblage in ["aléatoire", "toute", "all", "self"]:
				_preparer_animation(comp)
				_lancer_direct(comp)
				competence_en_cours = null
				fin_demandee = true
			else:
				_attendre_cibles(comp)
		break
	if clic_magie != null:
		var magie = clic_magie
		var ok = combat.logique_menu_combat(magie.nom, magie)
		if ok and magie.type_ciblage in ["aléatoire", "toute", "all", "self"]:
			_preparer_animation(magie)
			_lancer_direct(magie)
			competence_en_cours = null
			magie_menu_visible = false
			# L'action est faite : on rend la main au combat (tour des ennemis, PA rendus à tous).
			fin_demandee = true
		else:
			magie_menu_visible = false
			if ok:
				_attendre_cibles(magie)
