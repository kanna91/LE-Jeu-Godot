extends Ecran
## Cuisine (touche K en exploration, 2026-11-03 ; règles : Cuisine, CUISINE.md).
## À gauche les ingrédients du sac (clic : dans la marmite, 4 au plus ; le bouillon s'ajoute en plus) ; au milieu la
## marmite, la préparation (sans feu, grillé, bouilli, mijoté / four : grisée avec sa raison si impossible ici),
## « Cuisiner », et le feu (brandon pris à une torche, feu de camp, seau rempli à la cuisine) ; à droite les recettes
## connues. Les valeurs des ingrédients restent cachées.

const ZONE_INGREDIENTS := Rect2(20, 84, 300, 380)
const ZONE_MARMITE := Rect2(336, 84, 300, 176)
const ZONE_RECETTES := Rect2(652, 84, 288, 380)
const HAUTEUR_LIGNE := 34
const BOUTON_CUISINER := Rect2(336, 314, 300, 38)
const BOUTON_QUITTER := Rect2(Ui.LARGEUR - 140, Ui.HAUTEUR - 50, 120, 34)
const BOUTONS_FEU := {"brandon": Rect2(336, 362, 300, 30), "feu": Rect2(336, 398, 300, 30), "seau": Rect2(336, 434, 300, 30)}

var joueur
var ctx: Dictionary
var marmite: Array = []
var bouillon = null
var preparation := "grille"
var boutons_prep := {}
var lignes: Array = []
var defilement_recettes := 0.0
var message := ""
var couleur_message := Ui.OR
var message_fin := 0.0


func preparer(j, contexte: Dictionary) -> Ecran:
	fond_ecran = "menu_inventaire.png"
	joueur = j
	ctx = contexte
	for i in Cuisine.PREPARATIONS.size():
		boutons_prep[Cuisine.PREPARATIONS[i]] = Rect2(336 + i * 76, 270, 72, 34)
	var possibles := Cuisine.possibilites(joueur, ctx)
	for p in ["mijote", "bouilli", "grille", "sans_feu"]:
		if possibles[p] == "":
			preparation = p
			break
	return self


## Ingrédients du sac pas encore dans la marmite, regroupés : [[nom, objets], ...].
func ingredients_du_sac() -> Array:
	var groupes := {}
	var ordre := []
	for o in joueur.inventaire:
		if o in marmite or o == bouillon:
			continue
		if Cuisine.ingredient_de(o) == "" and String(o.nom) != "Bouillon":
			continue
		if not groupes.has(o.nom):
			groupes[o.nom] = []
			ordre.append(o.nom)
		groupes[o.nom].append(o)
	var l := []
	for n in ordre:
		l.append([n, groupes[n]])
	return l


func _mise_a_jour(_delta: float) -> void:
	lignes = []
	var groupes := ingredients_du_sac()
	for i in groupes.size():
		lignes.append([groupes[i], Rect2(ZONE_INGREDIENTS.position.x + 6, ZONE_INGREDIENTS.position.y + 32 + i * HAUTEUR_LIGNE,
			ZONE_INGREDIENTS.size.x - 12, HAUTEUR_LIGNE - 4)])


func _rect_marmite(k: int) -> Rect2:
	return Rect2(ZONE_MARMITE.position.x + 6, ZONE_MARMITE.position.y + 30 + k * 28, ZONE_MARMITE.size.x - 12, 26)


func _texte_feu() -> String:
	var morceaux := []
	if bool(ctx.get("cuisine", false)):
		morceaux.append("foyer de la cuisine (eau à volonté)")
	var f := Cuisine.feu(joueur, ctx.get("salle", {}))
	if not f.is_empty():
		morceaux.append("feu de camp (%d plat(s), %s)" % [int(Cuisine.donnees()["feu_de_camp"]["plats"]) - int(f.get("plats", 0)),
			Maux.duree_lisible(Cuisine.feu_restant(joueur, f))])
	if bool(ctx.get("torche", false)):
		morceaux.append("torche à portée (griller)")
	return "Feu : " + (", ".join(morceaux) if not morceaux.is_empty() else "aucun")


func _actions_feu() -> Dictionary:
	var a := {}
	if bool(ctx.get("torche", false)) and Cuisine.combustible(joueur) != null:
		a["brandon"] = "Allumer du bois à la torche"
	if Cuisine.feu(joueur, ctx.get("salle", {})).is_empty() and not bool(ctx.get("cuisine", false)) and (Cuisine.objet(joueur, "Brandon allumé") != null \
			or (Cuisine.combustible(joueur) != null and Cuisine.objet(joueur, "Amadou") != null and Cuisine.objet(joueur, "Silex") != null)):
		a["feu"] = "Faire un feu de camp ici"
	if bool(ctx.get("cuisine", false)) and Cuisine.seau(joueur) != null and Cuisine.eau(joueur) < 10:
		a["seau"] = "Remplir le seau"
	return a


func _dessiner(ci: Control) -> void:
	var s := souris()
	Ui.texte(ci, "Cuisine", Vector2(20, 12), DescriptionObjet.COULEUR_TITRE, 24, true)
	var s_eau := ("%d L" % Cuisine.eau(joueur)) if Cuisine.seau(joueur) != null else "pas de seau"
	Ui.texte(ci, "%s   ·   Eau : %s   ·   Marmite : %s" % [_texte_feu(), s_eau, "oui" if Cuisine.objet(joueur, "Marmite") != null else "non"],
		Vector2(20, 50), Ui.TEXTE, 14, false, Ui.LARGEUR - 40)
	# Ingrédients
	Ui.panneau(ci, ZONE_INGREDIENTS)
	Ui.texte(ci, "Ingrédients (clic : dans la marmite)", ZONE_INGREDIENTS.position + Vector2(10, 6), DescriptionObjet.COULEUR_TITRE, 15, true)
	if lignes.is_empty():
		Ui.texte(ci, "Rien à cuisiner dans votre sac.", ZONE_INGREDIENTS.position + Vector2(10, 36), Ui.DETAIL, 14)
	for l in lignes:
		var r: Rect2 = l[1]
		if r.end.y > ZONE_INGREDIENTS.end.y:
			break
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if r.has_point(s) else Ui.LIGNE, 0, 5)
		Ui.texte(ci, String(l[0][0]), r.position + Vector2(10, 6), Ui.BLANC, 15, true, r.size.x - 60)
		Ui.texte(ci, "×%d" % l[0][1].size(), Vector2(r.end.x - 8, r.position.y + 6), Color8(255, 255, 0), 15, true, null, "topright")
	# Marmite
	Ui.panneau(ci, ZONE_MARMITE)
	Ui.texte(ci, "Dans la marmite (clic : retirer)", ZONE_MARMITE.position + Vector2(10, 6), DescriptionObjet.COULEUR_TITRE, 15, true)
	for k in Cuisine.MAX_INGREDIENTS:
		var r := _rect_marmite(k)
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if r.has_point(s) and k < marmite.size() else Ui.LIGNE, 0, 5)
		Ui.texte(ci, String(marmite[k].nom) if k < marmite.size() else "— vide —", r.position + Vector2(10, 4),
			Ui.BLANC if k < marmite.size() else Ui.GRISE, 14, k < marmite.size())
	var rb := _rect_marmite(Cuisine.MAX_INGREDIENTS)
	Ui.texte(ci, ("+ Bouillon (clic : retirer)" if bouillon != null else "Bouillon : aucun (il s'ajoute en plus)"), rb.position + Vector2(10, 4),
		Ui.VERT if bouillon != null else Ui.GRISE, 13)
	# Préparations
	var possibles := Cuisine.possibilites(joueur, ctx)
	var raison := ""
	for p in boutons_prep:
		var r: Rect2 = boutons_prep[p]
		var ok: bool = possibles[p] == ""
		Ui.onglet(ci, r, {"sans_feu": "Sans feu", "grille": "Grillé", "bouilli": "Bouilli", "mijote": "Mijoté"}[p], p == preparation, r.has_point(s) and ok, 13)
		if not ok:
			Ui.rect(ci, r, Color8(0, 0, 0, 140), 0, 6)
			if r.has_point(s):
				raison = possibles[p]
	if raison == "" and possibles.get(preparation, "") != "":
		raison = possibles[preparation]
	var pret: bool = not marmite.is_empty() and possibles.get(preparation, "?") == ""
	Ui.bouton(ci, BOUTON_CUISINER, "Cuisiner (%s)" % Cuisine.nom_preparation(preparation).to_lower(), Ui.BOUTON_VERT, BOUTON_CUISINER.has_point(s), pret)
	if raison != "":
		Ui.texte(ci, raison, Vector2(BOUTON_CUISINER.position.x, BOUTON_CUISINER.end.y + 2), Ui.ROUGE, 12, false, 300)
	var actions := _actions_feu()
	var k := 0
	var zones_feu := []
	for cle in actions:
		var r: Rect2 = BOUTONS_FEU.values()[k]
		Ui.bouton(ci, r, actions[cle], Ui.BOUTON_NEUTRE, r.has_point(s), true, 14)
		zones_feu.append([["feu", cle], r])
		k += 1
	# Recettes connues
	Ui.panneau(ci, ZONE_RECETTES)
	var connues := Cuisine.connues(joueur)
	Ui.texte(ci, "Recettes connues (%d)" % connues.size(), ZONE_RECETTES.position + Vector2(10, 6), DescriptionObjet.COULEUR_TITRE, 15, true)
	var y := ZONE_RECETTES.position.y + 32 - defilement_recettes
	for nom in connues:
		var r := Cuisine.recette_nommee(nom)
		if r.is_empty():
			continue
		if y > ZONE_RECETTES.position.y + 24 and y < ZONE_RECETTES.end.y - 30:
			Ui.texte(ci, "%s — %s" % [nom, Cuisine.nom_preparation(r["preparation"]).to_lower()], Vector2(ZONE_RECETTES.position.x + 10, y), Ui.OR, 14, true, ZONE_RECETTES.size.x - 20)
			Ui.texte(ci, Cuisine.texte_recette(r), Vector2(ZONE_RECETTES.position.x + 18, y + 17), Ui.DETAIL, 12, false, ZONE_RECETTES.size.x - 28)
		y += 38
	Ui.texte(ci, "Molette : faire défiler", Vector2(ZONE_RECETTES.position.x + 10, ZONE_RECETTES.end.y - 20), Ui.GRISE, 11)
	if message != "" and Animations.temps() < message_fin:
		Ui.texte(ci, message, Vector2(24, Ui.HAUTEUR - 44), couleur_message, 14, true, BOUTON_QUITTER.position.x - 40)
	Ui.rect(ci, BOUTON_QUITTER, Color8(200, 50, 50), 0, 6)
	Ui.texte(ci, "Quitter", BOUTON_QUITTER.get_center(), Ui.BLANC, 16, true, null, "center")
	var z := []
	for l in lignes:
		z.append([["ingredient", l[0][0]], l[1]])
	for i in marmite.size():
		z.append([["marmite", i], _rect_marmite(i)])
	for p in boutons_prep:
		z.append([["prep", p], boutons_prep[p]])
	z.append([["cuisiner"], BOUTON_CUISINER])
	z += zones_feu
	z.append([["quitter"], BOUTON_QUITTER])
	definir_zones(z, ["ingredient", lignes[0][0][0]] if not lignes.is_empty() else ["quitter"])


func _dire(t: String, couleur := Ui.OR) -> void:
	message = t
	couleur_message = couleur
	message_fin = Animations.temps() + 4


## Met un ingrédient du sac dans la marmite (le bouillon va à part, un seul).
func ajouter(nom: String) -> void:
	for l in ingredients_du_sac():
		if l[0] != nom:
			continue
		var o = l[1][0]
		if String(o.nom) == "Bouillon":
			if bouillon != null:
				_dire("Un seul bouillon par plat.", Ui.ROUGE)
			else:
				bouillon = o
			return
		if marmite.size() >= Cuisine.MAX_INGREDIENTS:
			_dire("La marmite est pleine (%d ingrédients au plus)." % Cuisine.MAX_INGREDIENTS, Ui.ROUGE)
			return
		marmite.append(o)
		return


## Cuisine ce qu'il y a dans la marmite avec la préparation choisie.
func lancer_cuisson() -> void:
	var r := Cuisine.cuisiner(joueur, ctx, marmite, bouillon, preparation)
	_dire(r[0], Ui.OR if r[1] != null else Ui.ROUGE)
	if r[1] != null:
		marmite = []
		bouillon = null


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] in [KEY_ESCAPE, KEY_K]:
		fermer()
	elif ev["type"] == "molette":
		defilement_recettes = clampf(defilement_recettes - ev["sens"] * 30, 0, maxf(0, Cuisine.connues(joueur).size() * 38 - 320))
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		var pos: Vector2 = ev["pos"]
		for l in lignes:
			if l[1].has_point(pos):
				ajouter(l[0][0])
				return
		for i in marmite.size():
			if _rect_marmite(i).has_point(pos):
				marmite.remove_at(i)
				return
		if bouillon != null and _rect_marmite(Cuisine.MAX_INGREDIENTS).has_point(pos):
			bouillon = null
			return
		var possibles := Cuisine.possibilites(joueur, ctx)
		for p in boutons_prep:
			if boutons_prep[p].has_point(pos):
				if possibles[p] == "":
					preparation = p
				else:
					_dire(possibles[p], Ui.ROUGE)
				return
		if BOUTON_CUISINER.has_point(pos):
			if marmite.is_empty():
				_dire("La marmite est vide.", Ui.ROUGE)
			else:
				lancer_cuisson()
			return
		var actions := _actions_feu()
		var k := 0
		for cle in actions:
			if BOUTONS_FEU.values()[k].has_point(pos):
				match cle:
					"brandon":
						_dire(Cuisine.allumer_brandon(joueur, ctx))
					"feu":
						_dire(Cuisine.faire_feu(joueur, ctx))
					"seau":
						_dire(Cuisine.remplir_seau(joueur, ctx))
				return
			k += 1
		if BOUTON_QUITTER.has_point(pos):
			fermer()
