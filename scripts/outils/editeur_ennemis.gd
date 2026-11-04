class_name EditeurEnnemis
extends PanelContainer
## Éditeur des données des ennemis (2026-11-04, demande de l'utilisateur), ouvert depuis l'éditeur de zones (menu
## Données › Ennemis, ou F4). Données : DonneesEnnemis (``donnees/ennemis.json``, ``donnees/competences_editees.json``).
##
## Onglets :
## - **Compétences** : façonner une compétence (nom, description, coûts, cibles, coups, types de dégâts,
##   multiplicateur de dégâts, altérations qu'elle inflige et leur chance, tours en plus) ; en créer une nouvelle
##   (copie de celle choisie) ; remettre une compétence d'origine.
## - **Altérations** : durée et cumul maximal de chaque altération.
## - **Ennemis** : PV et compétences de chaque sorte d'ennemi (les distribuer).
## - **IA** : les règles jouées dans l'ordre (compétence, chance, jusqu'à 2 conditions, cible).
## - **Butin** : objets lâchés à la mort, chacun avec sa chance, pris dans la liste de tous les objets du jeu.
## Enregistrer : Ctrl+S ou le bouton ; Fermer (Échap) enregistre aussi ce qui a été modifié.

signal ferme

const TYPES_DEGATS := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre",
	"lumière", "poison"]
const POTIONS := ["", "pv", "mana", "mixte"]
const NOMS_POTIONS := ["Au hasard", "Soin", "Mana", "Régénération"]
const EQUIPEMENTS := ["", "armure", "bijou"]
const NOMS_EQUIPEMENTS := ["Au hasard", "Armure", "Bijou"]
const COULEUR_TITRE := Color(1, 0.85, 0.5)

var sortes := {}  # copie de travail : sorte → {pv, competences, ia, butin}
var editions := {}  # copie de travail : {competences, alterations}
var modifie := false
var onglets: TabContainer
var etat: Label
var _maj := false
var _noms_competences := {}  # nom de classe → nom affiché

# Onglet Compétences
var liste_competences: ItemList
var filtre: LineEdit
var fiche_competence: VBoxContainer
var competence_choisie := ""
# Onglet Altérations
var liste_alterations: ItemList
var fiche_alteration: VBoxContainer
var alteration_choisie := ""
# Onglets par ennemi
var choix_sorte := {}  # onglet → OptionButton
var sorte_choisie := "combattant"
var boite_ennemi: VBoxContainer
var boite_ia: VBoxContainer
var boite_butin: VBoxContainer


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 1.0)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var th := Theme.new()
	th.default_font_size = 13
	theme = th
	var colonne := VBoxContainer.new()
	add_child(colonne)
	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var titre := Label.new()
	titre.text = "Données des ennemis"
	titre.add_theme_font_size_override("font_size", 17)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	haut.add_child(_bouton("Enregistrer (Ctrl+S)", enregistrer))
	haut.add_child(_bouton("Fermer (Échap)", fermer))
	onglets = TabContainer.new()
	onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(onglets)
	_onglet_competences()
	_onglet_alterations()
	boite_ennemi = _onglet_sorte("Ennemis")
	boite_ia = _onglet_sorte("IA")
	boite_butin = _onglet_sorte("Butin")
	onglets.tab_changed.connect(func(_k): _remplir_onglet())
	etat = Label.new()
	etat.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	colonne.add_child(etat)
	charger()


# ---------------------------------------------------------------------------
# Outils d'interface
# ---------------------------------------------------------------------------

func _bouton(t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _etiquette(t: String, couleur := Color(0.8, 0.78, 0.85), taille := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	return l


func _nombre(valeur: float, mini: float, maxi: float, pas: float, action: Callable, suffixe := "") -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = mini
	sb.max_value = maxi
	sb.step = pas
	sb.value = valeur
	sb.suffix = suffixe
	sb.custom_minimum_size = Vector2(88, 0)
	sb.value_changed.connect(func(v):
		if not _maj:
			action.call(v))
	return sb


func _liste_deroulante(textes: Array, choisi: int, action: Callable, largeur := 150.0) -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.fit_to_longest_item = false
	ob.custom_minimum_size = Vector2(largeur, 0)
	ob.clip_text = true
	for t in textes:
		ob.add_item(String(t))
	if choisi >= 0 and choisi < textes.size():
		ob.select(choisi)
	ob.item_selected.connect(func(k):
		if not _maj:
			action.call(k))
	return ob


func _ligne(parent: Control, titre: String, controle: Control) -> void:
	var h := HBoxContainer.new()
	var l := _etiquette(titre)
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	h.add_child(controle)
	parent.add_child(h)


func _vider(boite: Control) -> void:
	for c in boite.get_children():
		boite.remove_child(c)
		c.queue_free()


func _change(texte := "") -> void:
	modifie = true
	etat.text = (texte + " — " if texte != "" else "") + "modifié (Ctrl+S pour enregistrer)"


## Nom affiché d'une compétence : « Nom (Nom_de_classe) ».
func nom_competence(classe: String) -> String:
	if not _noms_competences.has(classe):
		var nom := ""
		var e = editions["competences"].get(classe, {})
		if e is Dictionary:
			nom = String(e.get("nom", ""))
		if nom == "":
			var c := Competences.creer(base_competence(classe), true)
			nom = c.nom if c != null else classe
		_noms_competences[classe] = nom
	return "%s (%s)" % [_noms_competences[classe], classe]


## Compétence du jeu dont ``classe`` est la copie (elle-même si ce n'est pas une nouvelle compétence).
func base_competence(classe: String) -> String:
	var e = editions["competences"].get(classe, {})
	if e is Dictionary and e.has("base"):
		return String(e["base"])
	return classe


## Compétences, sorts et nouvelles compétences de l'éditeur.
func toutes_les_competences() -> Array:
	var noms: Array = Competences.classes_de_competences().duplicate() + Competences.classes_de_sorts()
	for n in editions["competences"]:
		if not n in noms:
			noms.append(n)
	noms.sort()
	return noms


func noms_alterations() -> Array:
	var noms: Array = Alterations.defs().keys()
	noms.sort_custom(func(a, b): return Alterations.libelle(a) < Alterations.libelle(b))
	return noms


# ---------------------------------------------------------------------------
# Chargement, enregistrement
# ---------------------------------------------------------------------------

func charger() -> void:
	sortes = DonneesEnnemis.donnees()["sortes"].duplicate(true)
	editions = DonneesEnnemis.editions().duplicate(true)
	_noms_competences = {}
	modifie = false
	etat.text = "Données des ennemis chargées"
	_remplir_liste_competences()
	_remplir_liste_alterations()
	_remplir_onglet()


func enregistrer() -> String:
	var erreur := DonneesEnnemis.enregistrer({"sortes": sortes}, editions)
	if erreur != "":
		etat.text = "ÉCHEC : " + erreur
		return etat.text
	modifie = false
	etat.text = "Enregistré : donnees/ennemis.json et donnees/competences_editees.json (valables aux prochains combats)"
	return etat.text


func fermer() -> void:
	if modifie:
		enregistrer()
	visible = false
	ferme.emit()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey) or not ev.pressed:
		return
	if ev.ctrl_pressed and ev.keycode == KEY_S:
		enregistrer()
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Onglet Compétences
# ---------------------------------------------------------------------------

func _onglet_competences() -> void:
	var corps := HBoxContainer.new()
	corps.name = "Compétences"
	onglets.add_child(corps)
	var gauche := VBoxContainer.new()
	gauche.custom_minimum_size = Vector2(250, 0)
	corps.add_child(gauche)
	filtre = LineEdit.new()
	filtre.placeholder_text = "Chercher une compétence…"
	filtre.text_changed.connect(func(_t): _remplir_liste_competences())
	gauche.add_child(filtre)
	liste_competences = ItemList.new()
	liste_competences.size_flags_vertical = Control.SIZE_EXPAND_FILL
	liste_competences.item_selected.connect(func(k): choisir_competence(String(liste_competences.get_item_metadata(k))))
	gauche.add_child(liste_competences)
	var b := HBoxContainer.new()
	gauche.add_child(b)
	b.add_child(_bouton("Nouvelle (copie)", nouvelle_competence))
	b.add_child(_bouton("D'origine", remettre_competence))
	var defile := ScrollContainer.new()
	defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	fiche_competence = VBoxContainer.new()
	fiche_competence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(fiche_competence)


func _remplir_liste_competences() -> void:
	if liste_competences == null:
		return
	liste_competences.clear()
	var f := filtre.text.strip_edges().to_lower()
	for c in toutes_les_competences():
		var t := nom_competence(c)
		if f != "" and not f in t.to_lower():
			continue
		var marque := " ✎" if editions["competences"].has(c) else ""
		liste_competences.add_item(t + marque)
		liste_competences.set_item_metadata(liste_competences.item_count - 1, c)
		if c == competence_choisie:
			liste_competences.select(liste_competences.item_count - 1)


## Valeur d'un champ de la compétence : réglage de l'éditeur, sinon valeur d'origine.
func valeur_competence(classe: String, champ: String, origine):
	var e = editions["competences"].get(classe, {})
	if e is Dictionary and e.has(champ):
		return e[champ]
	return origine.get(champ) if origine != null else null


func _regler_competence(classe: String, champ: String, valeur) -> void:
	if not editions["competences"].has(classe):
		editions["competences"][classe] = {}
	editions["competences"][classe][champ] = valeur
	if champ == "nom":
		_noms_competences.erase(classe)
	_change("%s : %s" % [classe, champ])


func choisir_competence(classe: String) -> void:
	competence_choisie = classe
	_vider(fiche_competence)
	var base := base_competence(classe)
	var origine := Competences.creer(base, true)
	if base == classe:
		base = ""
	if origine == null:
		fiche_competence.add_child(_etiquette("Compétence inconnue : " + classe))
		return
	_maj = true
	fiche_competence.add_child(_etiquette(nom_competence(classe) + ("   — copie de " + base if base != "" else ""), COULEUR_TITRE, 15))
	var nom := LineEdit.new()
	nom.text = String(valeur_competence(classe, "nom", origine))
	nom.custom_minimum_size = Vector2(300, 0)
	nom.text_changed.connect(func(t): _regler_competence(classe, "nom", t))
	_ligne(fiche_competence, "Nom affiché", nom)
	var desc := LineEdit.new()
	desc.text = String(valeur_competence(classe, "description", origine))
	desc.custom_minimum_size = Vector2(420, 0)
	desc.text_changed.connect(func(t): _regler_competence(classe, "description", t))
	_ligne(fiche_competence, "Description", desc)
	_ligne(fiche_competence, "Coût en mana", _nombre(float(valeur_competence(classe, "cout_mana", origine)), 0, 99, 1,
		func(v): _regler_competence(classe, "cout_mana", int(v))))
	_ligne(fiche_competence, "Coût en PA", _nombre(float(valeur_competence(classe, "cout_action", origine)), 0, 5, 1,
		func(v): _regler_competence(classe, "cout_action", int(v))))
	_ligne(fiche_competence, "Nombre de cibles", _nombre(float(valeur_competence(classe, "nombre_cible", origine)), 1, 9, 1,
		func(v): _regler_competence(classe, "nombre_cible", int(v))))
	_ligne(fiche_competence, "Nombre de coups", _nombre(float(valeur_competence(classe, "nombre_attaque", origine)), 1, 9, 1,
		func(v): _regler_competence(classe, "nombre_attaque", int(v))))
	_ligne(fiche_competence, "Dégâts (multiplicateur)", _nombre(float(valeur_competence(classe, "multiplicateur_degats", origine)),
		0, 5, 0.05, func(v): _regler_competence(classe, "multiplicateur_degats", v), " ×"))
	# Types de dégâts
	fiche_competence.add_child(_etiquette("Types de dégâts (chacun lance ses dés)", COULEUR_TITRE))
	var grille := GridContainer.new()
	grille.columns = 6
	fiche_competence.add_child(grille)
	var types: Array = Array(valeur_competence(classe, "type_degats", origine)).duplicate()
	for t in TYPES_DEGATS:
		var cb := CheckBox.new()
		cb.text = t
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = t in types
		cb.toggled.connect(func(on):
			var liste: Array = Array(valeur_competence(classe, "type_degats", origine)).duplicate()
			if on and not t in liste:
				liste.append(t)
			elif not on:
				liste.erase(t)
			_regler_competence(classe, "type_degats", liste))
		grille.add_child(cb)
	# Altérations
	fiche_competence.add_child(_etiquette("Altérations infligées (chance à chaque coup qui touche)", COULEUR_TITRE))
	var alts: Dictionary = Dictionary(valeur_competence(classe, "type_alteration", origine)).duplicate()
	var noms := noms_alterations()
	var libelles := noms.map(func(n): return Alterations.libelle(n))
	for nom_alt in alts:
		var h := HBoxContainer.new()
		var canon := Alterations.nom_canonique(String(nom_alt))
		var ancien := String(nom_alt)
		h.add_child(_liste_deroulante(libelles, noms.find(canon), func(k): _changer_alteration(classe, origine, ancien, noms[k]), 220))
		h.add_child(_nombre(float(alts[nom_alt]), 0, 100, 1, func(v): _chance_alteration(classe, origine, ancien, v), " %"))
		h.add_child(_bouton("✕", func(): _retirer_alteration(classe, origine, ancien)))
		fiche_competence.add_child(h)
	fiche_competence.add_child(_bouton("Ajouter une altération", func(): _ajouter_alteration(classe, origine)))
	_ligne(fiche_competence, "Tours en plus (altérations)", _nombre(float(valeur_competence(classe, "duree_bonus", origine)), 0, 9, 1,
		func(v): _regler_competence(classe, "duree_bonus", int(v))))
	# Qui l'utilise
	var qui := []
	for s in DonneesEnnemis.SORTES:
		if classe in sortes.get(s, {}).get("competences", []):
			qui.append(DonneesEnnemis.NOMS[s])
	var l := _etiquette("Ennemis qui la connaissent : " + (", ".join(qui) if not qui.is_empty() else "aucun (onglet Ennemis pour la donner)"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fiche_competence.add_child(l)
	_maj = false


func _alterations_de(classe: String, origine) -> Dictionary:
	return Dictionary(valeur_competence(classe, "type_alteration", origine)).duplicate()


func _changer_alteration(classe: String, origine, ancien: String, nouveau: String) -> void:
	var alts := _alterations_de(classe, origine)
	var chance = alts.get(ancien, 25)
	alts.erase(ancien)
	alts[nouveau] = chance
	_regler_competence(classe, "type_alteration", alts)
	choisir_competence.call_deferred(classe)


func _chance_alteration(classe: String, origine, nom: String, chance: float) -> void:
	var alts := _alterations_de(classe, origine)
	alts[nom] = chance
	_regler_competence(classe, "type_alteration", alts)


func _retirer_alteration(classe: String, origine, nom: String) -> void:
	var alts := _alterations_de(classe, origine)
	alts.erase(nom)
	_regler_competence(classe, "type_alteration", alts)
	choisir_competence.call_deferred(classe)


func _ajouter_alteration(classe: String, origine) -> void:
	var alts := _alterations_de(classe, origine)
	for n in noms_alterations():
		if not alts.has(n):
			alts[n] = 25
			break
	_regler_competence(classe, "type_alteration", alts)
	choisir_competence.call_deferred(classe)


## Nouvelle compétence : copie de la compétence choisie, sous un nouveau nom de classe.
func nouvelle_competence() -> String:
	var base := base_competence(competence_choisie if competence_choisie != "" else "Coup_d_epee")
	var k := 1
	while toutes_les_competences().has("%s_%d" % [base, k]):
		k += 1
	var classe := "%s_%d" % [base, k]
	var copie := {}
	if editions["competences"].get(competence_choisie) is Dictionary:
		copie = editions["competences"][competence_choisie].duplicate(true)
	copie["base"] = base
	var origine := Competences.creer(base, true)
	copie["nom"] = String(copie.get("nom", origine.nom if origine != null else base)) + " " + str(k + 1)
	editions["competences"][classe] = copie
	_noms_competences.erase(classe)
	competence_choisie = classe
	_change("nouvelle compétence " + classe)
	_remplir_liste_competences()
	choisir_competence(classe)
	return classe


## Remet la compétence choisie d'origine (une nouvelle compétence est supprimée, et retirée des ennemis).
func remettre_competence() -> void:
	var classe := competence_choisie
	if classe == "" or not editions["competences"].has(classe):
		return
	var nouvelle: bool = editions["competences"][classe].has("base")
	editions["competences"].erase(classe)
	_noms_competences.erase(classe)
	if nouvelle:
		for s in sortes:
			sortes[s]["competences"].erase(classe)
		competence_choisie = ""
		_vider(fiche_competence)
	_change(("%s supprimée" if nouvelle else "%s remise d'origine") % classe)
	_remplir_liste_competences()
	if not nouvelle:
		choisir_competence(classe)


# ---------------------------------------------------------------------------
# Onglet Altérations
# ---------------------------------------------------------------------------

func _onglet_alterations() -> void:
	var corps := HBoxContainer.new()
	corps.name = "Altérations"
	onglets.add_child(corps)
	liste_alterations = ItemList.new()
	liste_alterations.custom_minimum_size = Vector2(250, 0)
	liste_alterations.item_selected.connect(func(k): choisir_alteration(String(liste_alterations.get_item_metadata(k))))
	corps.add_child(liste_alterations)
	fiche_alteration = VBoxContainer.new()
	fiche_alteration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(fiche_alteration)


func _remplir_liste_alterations() -> void:
	if liste_alterations == null:
		return
	liste_alterations.clear()
	for n in noms_alterations():
		var d := Alterations.definition(n)
		liste_alterations.add_item("%s%s  (%s)%s" % ["+ " if d.get("nature") == "bonus" else "", Alterations.libelle(n), n,
			" ✎" if editions["alterations"].has(n) else ""])
		liste_alterations.set_item_metadata(liste_alterations.item_count - 1, n)


func choisir_alteration(nom: String) -> void:
	alteration_choisie = nom
	_vider(fiche_alteration)
	_maj = true
	var d := Alterations.definition(nom)
	var e: Dictionary = editions["alterations"].get(nom, {})
	fiche_alteration.add_child(_etiquette("%s — %s" % [Alterations.libelle(nom), "bonus" if d.get("nature") == "bonus" else "malus"], COULEUR_TITRE, 15))
	var desc := _etiquette(String(d.get("description", "")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fiche_alteration.add_child(desc)
	# Durée d'origine : celle des définitions sans réglage (relue de l'éditeur si besoin)
	_ligne(fiche_alteration, "Durée (tours)", _nombre(float(e.get("duree", d.get("duree", 1))), 1, 20, 1,
		func(v): _regler_alteration(nom, "duree", int(v))))
	_ligne(fiche_alteration, "Cumul maximal", _nombre(float(e.get("cumul_max", d.get("cumul_max", 1))), 1, 10, 1,
		func(v): _regler_alteration(nom, "cumul_max", int(v))))
	var qui := []
	for c in toutes_les_competences():
		var e_c = editions["competences"].get(c, {})
		if e_c is Dictionary and e_c.get("type_alteration", {}).has(nom):
			qui.append(nom_competence(c))
		elif BasesCompetences.BASES.get(c, {}).get("alterations", {}).has(nom):
			qui.append(nom_competence(c))
	var l := _etiquette("Compétences qui l'infligent : " + (", ".join(qui) if not qui.is_empty() else "aucune réglée ici"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fiche_alteration.add_child(l)
	fiche_alteration.add_child(_bouton("Remettre d'origine", func():
		editions["alterations"].erase(nom)
		_change(nom + " remise d'origine")
		_remplir_liste_alterations()
		choisir_alteration(nom)))
	fiche_alteration.add_child(_etiquette("Les durées réglées ici valent pour tout le jeu (héros compris), aux prochains combats.", Color(0.65, 0.65, 0.7), 12))
	_maj = false


func _regler_alteration(nom: String, champ: String, valeur: int) -> void:
	if not editions["alterations"].has(nom):
		editions["alterations"][nom] = {}
	editions["alterations"][nom][champ] = valeur
	_change("%s : %s" % [nom, champ])


# ---------------------------------------------------------------------------
# Onglets par ennemi (Ennemis, IA, Butin)
# ---------------------------------------------------------------------------

func _onglet_sorte(titre: String) -> VBoxContainer:
	var corps := VBoxContainer.new()
	corps.name = titre
	onglets.add_child(corps)
	var haut := HBoxContainer.new()
	corps.add_child(haut)
	haut.add_child(_etiquette("Ennemi :", COULEUR_TITRE))
	var noms := DonneesEnnemis.SORTES.map(func(s): return DonneesEnnemis.NOMS[s])
	var ob := _liste_deroulante(noms, 0, func(k): choisir_sorte(DonneesEnnemis.SORTES[k]), 200)
	haut.add_child(ob)
	choix_sorte[titre] = ob
	var defile := ScrollContainer.new()
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	var boite := VBoxContainer.new()
	boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(boite)
	return boite


func choisir_sorte(s: String) -> void:
	sorte_choisie = s
	_remplir_onglet()


func _remplir_onglet() -> void:
	if onglets == null or sortes.is_empty():
		return
	_maj = true
	for t in choix_sorte:
		choix_sorte[t].select(DonneesEnnemis.SORTES.find(sorte_choisie))
	_maj = false
	match onglets.get_current_tab_control().name:
		"Ennemis":
			_remplir_ennemi()
		"IA":
			_remplir_ia()
		"Butin":
			_remplir_butin()


func donnees_sorte() -> Dictionary:
	return sortes[sorte_choisie]


# --- Ennemis : PV et compétences

func _remplir_ennemi() -> void:
	_vider(boite_ennemi)
	_maj = true
	var d := donnees_sorte()
	var pv: Array = d.get("pv", [50, 60])
	boite_ennemi.add_child(_etiquette("Points de vie au premier étage (par 10 ; élite × 2,5, boss × 6)", COULEUR_TITRE))
	var h := HBoxContainer.new()
	h.add_child(_etiquette("de"))
	h.add_child(_nombre(float(pv[0]), 10, 990, 10, func(v): _regler_pv(0, v)))
	h.add_child(_etiquette("à"))
	h.add_child(_nombre(float(pv[1]), 10, 990, 10, func(v): _regler_pv(1, v)))
	boite_ennemi.add_child(h)
	boite_ennemi.add_child(_etiquette("Compétences qu'il connaît (l'IA ne joue que celles-ci)", COULEUR_TITRE))
	var liste: Array = d.get("competences", [])
	for c in liste:
		var l := HBoxContainer.new()
		var t := _etiquette("• " + nom_competence(String(c)))
		t.custom_minimum_size = Vector2(380, 0)
		l.add_child(t)
		var classe := String(c)
		l.add_child(_bouton("Façonner", func():
			onglets.current_tab = 0
			competence_choisie = classe
			_remplir_liste_competences()
			choisir_competence(classe)))
		l.add_child(_bouton("✕ Retirer", func(): retirer_competence_sorte(classe)))
		boite_ennemi.add_child(l)
	if Creatures.SORTES.has(sorte_choisie):
		boite_ennemi.add_child(_etiquette("Coup_d_epee est son attaque propre (%s, dés fixes)." % Creatures.SORTES[sorte_choisie]["attaque"], Color(0.65, 0.65, 0.7), 12))
	var ajout := HBoxContainer.new()
	var toutes := toutes_les_competences().filter(func(c): return not c in liste)
	var choix := _liste_deroulante(toutes.map(func(c): return nom_competence(c)), 0, func(_k): pass, 380)
	ajout.add_child(choix)
	ajout.add_child(_bouton("Donner cette compétence", func():
		if choix.selected >= 0:
			donner_competence_sorte(String(toutes[choix.selected]))))
	boite_ennemi.add_child(ajout)
	_maj = false


func _regler_pv(k: int, v: float) -> void:
	var pv: Array = Array(donnees_sorte().get("pv", [50, 60])).duplicate()
	pv[k] = int(v)
	if pv[0] > pv[1]:
		pv[1 - k] = int(v)
	donnees_sorte()["pv"] = pv
	_change("PV de " + DonneesEnnemis.NOMS[sorte_choisie])


func donner_competence_sorte(classe: String) -> void:
	var liste: Array = donnees_sorte()["competences"]
	if not classe in liste:
		liste.append(classe)
		_change("%s donnée à %s" % [classe, DonneesEnnemis.NOMS[sorte_choisie]])
	_remplir_ennemi.call_deferred()


func retirer_competence_sorte(classe: String) -> void:
	donnees_sorte()["competences"].erase(classe)
	_change("%s retirée à %s" % [classe, DonneesEnnemis.NOMS[sorte_choisie]])
	_remplir_ennemi.call_deferred()


# --- IA : règles

func _remplir_ia() -> void:
	_vider(boite_ia)
	_maj = true
	var regles: Array = donnees_sorte()["ia"]
	var aide := _etiquette("À chaque action, les règles sont essayées dans l'ordre : la première dont la chance passe, dont les conditions sont vraies " \
		+ "et dont la compétence est utilisable (PA, mana, silence) est jouée. Si aucune ne passe : son attaque de secours.", Color(0.7, 0.7, 0.75), 12)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite_ia.add_child(aide)
	var comps: Array = Array(donnees_sorte()["competences"]).duplicate()
	for r in regles:
		if not String(r.get("competence", "")) in comps:
			comps.append(String(r.get("competence", "")))
	var noms_comps := comps.map(func(c): return nom_competence(String(c)))
	var conds: Array = ["—"] + DonneesEnnemis.CONDITIONS.keys()
	var textes_conds := conds.map(func(c): return "(aucune)" if c == "—" else DonneesEnnemis.CONDITIONS[c])
	var noms_alt := noms_alterations()
	var libelles_alt := noms_alt.map(func(n): return Alterations.libelle(n))
	var cibles: Array = DonneesEnnemis.CIBLES.keys()
	for k in regles.size():
		var r: Dictionary = regles[k]
		var cadre := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.11, 0.1, 0.14)
		st.set_content_margin_all(4)
		st.set_corner_radius_all(4)
		cadre.add_theme_stylebox_override("panel", st)
		boite_ia.add_child(cadre)
		var v := VBoxContainer.new()
		cadre.add_child(v)
		var l1 := HBoxContainer.new()
		v.add_child(l1)
		l1.add_child(_etiquette("%d." % (k + 1), COULEUR_TITRE))
		l1.add_child(_liste_deroulante(noms_comps, comps.find(String(r.get("competence", ""))),
			func(i): _regler_regle(r, "competence", comps[i]), 290))
		l1.add_child(_etiquette("chance"))
		l1.add_child(_nombre(float(r.get("chance", 100)), 0, 100, 1, func(x): _regler_regle(r, "chance", int(x)), " %"))
		l1.add_child(_liste_deroulante(cibles.map(func(c): return DonneesEnnemis.CIBLES[c]), cibles.find(String(r.get("cible", "auto"))),
			func(i): _regler_regle(r, "cible", cibles[i]), 170))
		l1.add_child(_bouton("↑", func(): deplacer_regle(k, -1)))
		l1.add_child(_bouton("↓", func(): deplacer_regle(k, 1)))
		l1.add_child(_bouton("✕", func(): retirer_regle(k)))
		var si: Array = r.get("si", [])
		var l2 := HBoxContainer.new()
		v.add_child(l2)
		for j in 2:
			l2.add_child(_etiquette("si" if j == 0 else "et"))
			var cond: Array = si[j] if j < si.size() and si[j] is Array else ["—", ""]
			var nom_cond := String(cond[0])
			var valeur := str(cond[1]) if cond.size() > 1 else ""
			l2.add_child(_liste_deroulante(textes_conds, maxi(0, conds.find(nom_cond)), func(i): _regler_condition(r, j, conds[i], ""), 250))
			if nom_cond in DonneesEnnemis.CONDITIONS_A_ALTERATION:
				var canon := Alterations.nom_canonique(valeur)
				l2.add_child(_liste_deroulante(libelles_alt, noms_alt.find(canon), func(i): _regler_condition(r, j, nom_cond, noms_alt[i]), 140))
			elif nom_cond in DonneesEnnemis.CONDITIONS_A_NOMBRE:
				l2.add_child(_nombre(float(valeur) if valeur.is_valid_float() else 5.0, 0, 99, 1, func(x): _regler_condition(r, j, nom_cond, str(int(x)))))
	boite_ia.add_child(_bouton("Ajouter une règle", ajouter_regle))
	_maj = false


func _regler_regle(r: Dictionary, champ: String, valeur) -> void:
	r[champ] = valeur
	_change("IA de " + DonneesEnnemis.NOMS[sorte_choisie])


func _regler_condition(r: Dictionary, j: int, condition: String, valeur: String) -> void:
	var si: Array = r.get("si", []).duplicate(true)
	while si.size() <= j:
		si.append(["—", ""])
	if condition in DonneesEnnemis.CONDITIONS_A_ALTERATION and valeur == "":
		valeur = String(si[j][1]) if si[j].size() > 1 and Alterations.defs().has(Alterations.nom_canonique(str(si[j][1]))) else "saignement"
	if condition in DonneesEnnemis.CONDITIONS_A_NOMBRE and valeur == "":
		valeur = "5"
	si[j] = [condition, valeur]
	r["si"] = si.filter(func(c): return String(c[0]) != "—")
	_change("IA de " + DonneesEnnemis.NOMS[sorte_choisie])
	_remplir_ia.call_deferred()


func ajouter_regle() -> void:
	var comps: Array = donnees_sorte()["competences"]
	donnees_sorte()["ia"].append({"competence": comps[0] if not comps.is_empty() else "Coup_d_epee", "chance": 100})
	_change("règle ajoutée")
	_remplir_ia.call_deferred()


func retirer_regle(k: int) -> void:
	donnees_sorte()["ia"].remove_at(k)
	_change("règle retirée")
	_remplir_ia.call_deferred()


func deplacer_regle(k: int, sens: int) -> void:
	var regles: Array = donnees_sorte()["ia"]
	var j := k + sens
	if j < 0 or j >= regles.size():
		return
	var r = regles[k]
	regles[k] = regles[j]
	regles[j] = r
	_change("règle déplacée")
	_remplir_ia.call_deferred()


# --- Butin

func _remplir_butin() -> void:
	_vider(boite_butin)
	_maj = true
	var aide := _etiquette("Objets lâchés à la mort de l'ennemi : chacun a sa chance ; le héros le reçoit tout de suite. " \
		+ "Objet « au hasard » : tiré dans sa catégorie ; rang 0 : selon l'étage ; or 0 : montant au hasard.", Color(0.7, 0.7, 0.75), 12)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite_butin.add_child(aide)
	var butins: Array = donnees_sorte()["butin"]
	var cats: Array = Fouille.CATEGORIES_BUTIN
	for k in butins.size():
		var b: Dictionary = butins[k]
		var c := String(b.get("categorie", "or"))
		var h := HBoxContainer.new()
		boite_butin.add_child(h)
		h.add_child(_liste_deroulante(cats.map(func(x): return Fouille.NOMS_BUTIN[x]), cats.find(c), func(i):
			b["categorie"] = cats[i]
			b["objet"] = ""
			b["potion"] = ""
			_change("butin")
			_remplir_butin.call_deferred(), 120))
		if c == "potion":
			h.add_child(_liste_deroulante(NOMS_POTIONS, POTIONS.find(String(b.get("potion", ""))), func(i): _regler_butin(b, "potion", POTIONS[i]), 230))
		elif c == "equipement":
			h.add_child(_liste_deroulante(NOMS_EQUIPEMENTS, EQUIPEMENTS.find(String(b.get("objet", ""))), func(i): _regler_butin(b, "objet", EQUIPEMENTS[i]), 230))
		elif c in ["divers", "nourriture", "ingredient"]:
			var noms: Array = ["Au hasard"] + ObjetsDivers.noms(c)
			h.add_child(_liste_deroulante(noms, maxi(0, noms.find(String(b.get("objet", "")))), func(i): _regler_butin(b, "objet", "" if i == 0 else noms[i]), 230))
		else:
			var vide := Control.new()
			vide.custom_minimum_size = Vector2(230, 0)
			h.add_child(vide)
		h.add_child(_etiquette("or" if c == "or" else "nombre"))
		h.add_child(_nombre(float(b.get("quantite", 0 if c == "or" else 1)), 0, 9999, 1, func(x): _regler_butin(b, "quantite", int(x))))
		if c in ["arme", "equipement"]:
			h.add_child(_etiquette("rang"))
			h.add_child(_nombre(float(b.get("rang", 0)), 0, 6, 1, func(x): _regler_butin(b, "rang", int(x))))
		h.add_child(_etiquette("chance"))
		h.add_child(_nombre(float(b.get("chance", 25)), 0, 100, 1, func(x): _regler_butin(b, "chance", x), " %"))
		h.add_child(_bouton("✕", func(): retirer_butin(k)))
	boite_butin.add_child(_bouton("Ajouter un objet", ajouter_butin))
	_maj = false


func _regler_butin(b: Dictionary, champ: String, valeur) -> void:
	b[champ] = valeur
	_change("butin de " + DonneesEnnemis.NOMS[sorte_choisie])


func ajouter_butin() -> void:
	donnees_sorte()["butin"].append({"categorie": "potion", "objet": "", "potion": "", "quantite": 1, "rang": 0, "chance": 25})
	_change("objet ajouté au butin")
	_remplir_butin.call_deferred()


func retirer_butin(k: int) -> void:
	donnees_sorte()["butin"].remove_at(k)
	_change("objet retiré du butin")
	_remplir_butin.call_deferred()
