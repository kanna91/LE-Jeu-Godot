class_name EditeurEnnemis
extends PanelContainer
## Éditeur des données des ennemis (2026-11-04, demande de l'utilisateur), ouvert depuis l'éditeur de zones (menu
## Données › Ennemis, ou F4). Données : DonneesEnnemis (``donnees/ennemis.json``, ``donnees/competences_editees.json``).
##
## Onglets :
## - **Compétences** : façonner une compétence (nom, description, coûts, cibles, coups, types de dégâts,
##   multiplicateur de dégâts, altérations qu'elle inflige et leur chance, tours en plus) ; en créer une nouvelle
##   (copie de celle choisie) ; remettre une compétence d'origine.
## - **Altérations** (2026-11-06) : trois vues — briques primaires (BriquesAlterations), altérations composées (celles du
##   jeu, réglables brique par brique, « Remettre d'origine »), altérations personnalisées — classées par nom ou par type
##   (améliorations, malus, dégâts) ; le créateur règle nom, nature, durée, cumul et morceaux (briques avec leurs valeurs,
##   altérations citées avec une puissance en %).
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
var classer_par_type := false  # liste des altérations rangée par type (2026-11-06)
var choix_classement: OptionButton
var choix_vue_alterations: OptionButton
var filtre_alterations: LineEdit
var vue_alterations := 1  # 0 briques primaires, 1 composées, 2 personnalisées
var _cache_brutes := {}
var _cache_definitions := {}
var _refs := []  # héros de départ et gobelin combattant de l'aperçu des dégâts
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
	_cache_brutes = {}
	_cache_definitions = {}
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
	var b := brutes_travail()
	var noms: Array = b.keys()
	noms.sort_custom(func(x, y): return String(b[x].get("libelle", x)) < String(b[y].get("libelle", y)))
	return noms


# ---------------------------------------------------------------------------
# Chargement, enregistrement
# ---------------------------------------------------------------------------

func charger() -> void:
	sortes = DonneesEnnemis.donnees()["sortes"].duplicate(true)
	editions = DonneesEnnemis.editions().duplicate(true)
	if not (editions.get("alterations_personnalisees") is Dictionary):
		editions["alterations_personnalisees"] = {}
	_cache_brutes = {}
	_cache_definitions = {}
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


const FACES_DES := [2, 3, 4, 6, 8, 10, 12, 20]
const NOMS_TYPES_DEGATS := {"tranchant": "Tranchant", "perforant": "Perforant", "contondant": "Contondant", "feu": "Feu",
	"froid": "Froid", "foudre": "Foudre", "arcane": "Arcane", "chaos": "Chaos", "ombre": "Ombre", "lumière": "Lumière (soin)",
	"poison": "Poison"}


## Titre de section : un espace, le titre, un trait.
func _section(parent: Control, titre: String, aide := "") -> void:
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 6)
	parent.add_child(espace)
	var l := _etiquette(titre, COULEUR_TITRE, 15)
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	parent.add_child(HSeparator.new())


## Ligne réglage avec une bulle d'aide.
func _ligne_aide(parent: Control, titre: String, controle: Control, aide: String) -> void:
	_ligne(parent, titre, controle)
	var h: Control = parent.get_child(parent.get_child_count() - 1)
	h.tooltip_text = aide
	controle.tooltip_text = aide
	h.get_child(0).mouse_filter = Control.MOUSE_FILTER_PASS
	h.get_child(0).tooltip_text = aide


## Compétence telle qu'elle serait jouée avec les réglages en cours (copie de travail, pas encore enregistrée).
func competence_travail(classe: String):
	var comp := Competences.creer(base_competence(classe), true)
	if comp != null:
		DonneesEnnemis.appliquer_competence(comp, classe, editions)
	return comp


## Lanceurs et cibles de l'aperçu : héros de départ, gobelin combattant (créés une fois).
func _references() -> Array:
	if _refs.is_empty():
		var heros := Personnage.nouveau()
		var gobelin = Gobelin.nouveau(null)._completer("guerrier", "combattant")
		_refs = [heros, gobelin]
	return _refs


## Aperçu des dégâts : [texte ennemi → héros, texte héros → gobelin].
func apercu_degats(classe: String) -> String:
	var comp = competence_travail(classe)
	if comp == null or Array(comp.type_degats).is_empty():
		return "Pas de dégâts (compétence de soutien)."
	var refs := _references()
	var lignes := []
	for paire in [[refs[1], refs[0], "Lancée par un gobelin sur le héros de départ"], [refs[0], refs[1], "Lancée par le héros de départ sur un gobelin"]]:
		var total := 0.0
		var details := []
		for r in Formules.estimer_degats(paire[0], comp, paire[1]):
			total += absf(float(r[2]))
			details.append("%s %s" % [U.g(absf(float(r[2]))), r[0]])
		var coups := maxi(1, int(comp.nombre_attaque))
		lignes.append("%s : ≈ %s par coup%s (%s)" % [paire[2], U.g(snappedf(total, 0.1)),
			(" × %d coups = %s" % [coups, U.g(snappedf(total * coups, 0.1))]) if coups > 1 else "", ", ".join(details)])
	return "\n".join(lignes) + "\nMoyennes s'il touche, défenses de la cible comprises."


func _maj_apercu(classe: String) -> void:
	var l := fiche_competence.get_node_or_null("Apercu")
	if l != null:
		l.text = apercu_degats(classe)


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
	fiche_competence.add_child(_etiquette(nom_competence(classe) + ("   — copie de " + base if base != "" else ""), COULEUR_TITRE, 17))
	var apercu := _texte(apercu_degats(classe), Color(0.9, 0.9, 0.7))
	apercu.name = "Apercu"
	fiche_competence.add_child(apercu)
	# Identité
	_section(fiche_competence, "Identité")
	var nom := LineEdit.new()
	nom.text = String(valeur_competence(classe, "nom", origine))
	nom.custom_minimum_size = Vector2(300, 0)
	nom.text_changed.connect(func(t): _regler_competence(classe, "nom", t))
	_ligne_aide(fiche_competence, "Nom affiché", nom, "Le nom que voit le joueur (combat, fiches).")
	var desc := LineEdit.new()
	desc.text = String(valeur_competence(classe, "description", origine))
	desc.custom_minimum_size = Vector2(460, 0)
	desc.text_changed.connect(func(t): _regler_competence(classe, "description", t))
	_ligne_aide(fiche_competence, "Description", desc, "Texte de la fiche de la compétence.")
	# Coûts et ciblage
	_section(fiche_competence, "Coûts et ciblage")
	_ligne_aide(fiche_competence, "Coût en mana", _nombre(float(valeur_competence(classe, "cout_mana", origine)), 0, 99, 1,
		func(v): _regler_competence(classe, "cout_mana", int(v))), "Mana payé à chaque lancer.")
	_ligne_aide(fiche_competence, "Coût en PA", _nombre(float(valeur_competence(classe, "cout_action", origine)), 0, 5, 1,
		func(v): _regler_competence(classe, "cout_action", int(v))), "Points d'action dépensés (le héros et la plupart des ennemis en ont 1 par tour).")
	var regler_nombre_cible := func(v):
		_regler_competence(classe, "nombre_cible", int(v))
		_maj_apercu(classe)
	_ligne_aide(fiche_competence, "Nombre de cibles", _nombre(float(valeur_competence(classe, "nombre_cible", origine)), 1, 9, 1,
		regler_nombre_cible), "Combien de cibles différentes sont touchées.")
	var regler_nombre_attaque := func(v):
		_regler_competence(classe, "nombre_attaque", int(v))
		_maj_apercu(classe)
	_ligne_aide(fiche_competence, "Nombre de coups", _nombre(float(valeur_competence(classe, "nombre_attaque", origine)), 1, 9, 1,
		regler_nombre_attaque), "Coups portés à chaque cible (chacun lance ses dés et peut infliger ses altérations).")
	# Dégâts
	_section(fiche_competence, "Dégâts", "Pour chaque type coché : dés + dégâts fixes + part des PV max de la cible, puis les bonus du lanceur (caractéristiques, objets), puis le multiplicateur.")
	var grille := GridContainer.new()
	grille.columns = 6
	fiche_competence.add_child(grille)
	var types: Array = Array(valeur_competence(classe, "type_degats", origine)).duplicate()
	for t in TYPES_DEGATS:
		var cb := CheckBox.new()
		cb.text = NOMS_TYPES_DEGATS.get(t, t)
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = t in types
		cb.toggled.connect(func(on):
			var liste: Array = Array(valeur_competence(classe, "type_degats", origine)).duplicate()
			if on and not t in liste:
				liste.append(t)
			elif not on:
				liste.erase(t)
			_regler_competence(classe, "type_degats", liste)
			choisir_competence.call_deferred(classe))
		grille.add_child(cb)
	var refs := _references()
	for t in types:
		fiche_competence.add_child(_ligne_degats(classe, origine, String(t), refs))
	var regler_facteur := func(v):
		_regler_competence(classe, "facteur_degats", v)
		_maj_apercu(classe)
	_ligne_aide(fiche_competence, "Multiplicateur des dégâts", _nombre(float(valeur_competence(classe, "facteur_degats", {"facteur_degats": 1.0})),
		0, 10, 0.05, regler_facteur, " ×"),
		"Multiplie les dégâts de tous les types de la compétence (1 = normal, 1,5 = +50 %, 0,5 = moitié).")
	# Altérations
	_section(fiche_competence, "Altérations infligées", "Chance d'infliger chaque altération à chaque coup qui touche.")
	var alts: Dictionary = Dictionary(valeur_competence(classe, "type_alteration", origine)).duplicate()
	var noms := noms_alterations()
	var libelles := noms.map(func(n): return libelle_alteration(n))
	for nom_alt in alts:
		var h := HBoxContainer.new()
		var canon := Alterations.nom_canonique(String(nom_alt))
		var ancien := String(nom_alt)
		var liste_alt := _liste_deroulante(libelles, noms.find(canon), func(k): _changer_alteration(classe, origine, ancien, noms[k]), 260)
		var d_alt := definition_travail(canon)
		liste_alt.tooltip_text = BriquesAlterations.decrire(d_alt) if not d_alt.is_empty() else ""
		h.add_child(liste_alt)
		h.add_child(_nombre(float(alts[nom_alt]), 0, 100, 1, func(v): _chance_alteration(classe, origine, ancien, v), " %"))
		h.add_child(_bouton("✕", func(): _retirer_alteration(classe, origine, ancien)))
		h.tooltip_text = liste_alt.tooltip_text
		fiche_competence.add_child(h)
	fiche_competence.add_child(_bouton("Ajouter une altération", func(): _ajouter_alteration(classe, origine)))
	_ligne_aide(fiche_competence, "Tours en plus (altérations)", _nombre(float(valeur_competence(classe, "duree_bonus", origine)), 0, 9, 1,
		func(v): _regler_competence(classe, "duree_bonus", int(v))), "Les altérations infligées durent ce nombre de tours en plus.")
	# Qui l'utilise
	_section(fiche_competence, "Utilisation")
	var qui := []
	for s in DonneesEnnemis.SORTES:
		if classe in sortes.get(s, {}).get("competences", []):
			qui.append(DonneesEnnemis.NOMS[s])
	fiche_competence.add_child(_texte("Ennemis qui la connaissent : " + (", ".join(qui) if not qui.is_empty() else "aucun (onglet Ennemis pour la donner)")))
	_maj = false


## Ligne des dégâts d'un type : dés (par défaut ou réglés), dégâts fixes, part des PV max de la cible.
func _ligne_degats(classe: String, origine, t: String, refs: Array) -> Control:
	var ligne := HFlowContainer.new()
	var nom_t := _etiquette(String(NOMS_TYPES_DEGATS.get(t, t)), Color(0.75, 1, 0.8))
	nom_t.custom_minimum_size = Vector2(110, 0)
	ligne.add_child(nom_t)
	var des_regles: Dictionary = Dictionary(valeur_competence(classe, "des_degats", {"des_degats": {}})).duplicate(true)
	var regles: bool = des_regles.has(t)
	var defaut_heros := Formules.des_competence(refs[0], origine, t)
	var defaut_ennemi := Formules.des_competence(refs[1], origine, t)
	var texte_defaut := "par défaut : héros %s, ennemis %s" % [_texte_des(defaut_heros, t, false), _texte_des(defaut_ennemi, t, true)]
	var choix := CheckBox.new()
	choix.text = "dés réglés"
	choix.focus_mode = Control.FOCUS_NONE
	choix.button_pressed = regles
	choix.tooltip_text = "Décoché : les dés du jeu (%s). Coché : les dés choisis ici, pour le héros comme pour les ennemis." % texte_defaut
	ligne.add_child(choix)
	var defaut_affiche: Array = defaut_heros if not defaut_heros.is_empty() else Formules.DES_TYPES.get(t, [[1, 4]])
	var valeur: Array = des_regles.get(t, defaut_affiche[0] if not defaut_affiche.is_empty() else [1, 4])
	var n := _nombre(float(valeur[0]), 0, 30, 1, func(_v): pass)
	n.custom_minimum_size = Vector2(64, 0)
	var faces := _liste_deroulante(FACES_DES.map(func(f): return "d%d" % f), FACES_DES.find(int(valeur[1])), func(_k): pass, 70)
	var maj_des := func():
		if _maj:
			return
		var d: Dictionary = Dictionary(valeur_competence(classe, "des_degats", {"des_degats": {}})).duplicate(true)
		if choix.button_pressed:
			d[t] = [int(n.value), FACES_DES[maxi(0, faces.selected)]]
		else:
			d.erase(t)
		_regler_competence(classe, "des_degats", d)
		n.editable = choix.button_pressed
		faces.disabled = not choix.button_pressed
		_maj_apercu(classe)
	n.value_changed.connect(func(_v): maj_des.call())
	faces.item_selected.connect(func(_k): maj_des.call())
	choix.toggled.connect(func(_on): maj_des.call())
	n.editable = regles
	faces.disabled = not regles
	ligne.add_child(n)
	ligne.add_child(faces)
	ligne.add_child(_etiquette("+ fixe"))
	var fixes: Dictionary = Dictionary(valeur_competence(classe, "degats_fixes", {"degats_fixes": {}}))
	var regler_fixe := func(v):
		var d: Dictionary = Dictionary(valeur_competence(classe, "degats_fixes", {"degats_fixes": {}})).duplicate()
		if v == 0:
			d.erase(t)
		else:
			d[t] = v
		_regler_competence(classe, "degats_fixes", d)
		_maj_apercu(classe)
	var champ_fixe := _nombre(float(fixes.get(t, 0)), -99, 999, 1, regler_fixe)
	champ_fixe.tooltip_text = "Dégâts ajoutés à chaque coup, avant les bonus du lanceur."
	ligne.add_child(champ_fixe)
	ligne.add_child(_etiquette("+ PV max de la cible"))
	var parts: Dictionary = Dictionary(valeur_competence(classe, "pv_max_cible", {"pv_max_cible": {}}))
	var regler_pv := func(v):
		var d: Dictionary = Dictionary(valeur_competence(classe, "pv_max_cible", {"pv_max_cible": {}})).duplicate()
		if v == 0:
			d.erase(t)
		else:
			d[t] = snappedf(v / 100.0, 0.0001)
		_regler_competence(classe, "pv_max_cible", d)
		_maj_apercu(classe)
	var champ_pv := _nombre(float(parts.get(t, 0)) * 100.0, 0, 100, 0.5, regler_pv, " %")
	champ_pv.tooltip_text = "Part des PV max de la cible ajoutée aux dégâts (ou aux soins pour la lumière)."
	ligne.add_child(champ_pv)
	var aide := _etiquette("(" + texte_defaut + ")", Color(0.6, 0.6, 0.66), 12)
	ligne.add_child(aide)
	return ligne


func _texte_des(des: Array, t: String, ennemi: bool) -> String:
	if des.is_empty():
		var defaut: Array = Formules.DES_TYPES.get(t, [])
		if ennemi:
			defaut = Formules.des_reduits(defaut)
		des = defaut
	return " + ".join(des.map(func(d): return "%dd%d" % [int(d[0]), int(d[1])])) if not des.is_empty() else "aucun"


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
# Onglet Altérations (2026-11-06) : briques primaires, composées, personnalisées, créateur
# ---------------------------------------------------------------------------

const VUES_ALTERATIONS := ["Briques primaires", "Altérations composées", "Altérations personnalisées"]
const NOMS_PARAMS := {"valeur": "valeur", "type": "type", "chance": "chance", "pv_max": "PV max", "pv_actuels": "PV actuels",
	"fixe": "fixe", "des": "dés", "cumul": "cumul", "croissant": "croissant", "mana_max": "mana max",
	"degats_par_mana": "dégâts par mana", "nombre": "nombre", "points": "points", "selon_puissance": "selon la puissance",
	"stat": "statistique", "carac": "caractéristique", "part": "part"}


func _onglet_alterations() -> void:
	var corps := HBoxContainer.new()
	corps.name = "Altérations"
	onglets.add_child(corps)
	var gauche := VBoxContainer.new()
	corps.add_child(gauche)
	choix_vue_alterations = _liste_deroulante(VUES_ALTERATIONS, 1, func(k):
		vue_alterations = k
		alteration_choisie = ""
		_remplir_liste_alterations()
		_vider(fiche_alteration), 250)
	gauche.add_child(choix_vue_alterations)
	choix_classement = _liste_deroulante(["Classer par nom", "Classer par type"], 0, func(k):
		classer_par_type = k == 1
		_remplir_liste_alterations(), 250)
	gauche.add_child(choix_classement)
	filtre_alterations = LineEdit.new()
	filtre_alterations.placeholder_text = "Chercher…"
	filtre_alterations.clear_button_enabled = true
	filtre_alterations.text_changed.connect(func(_t): _remplir_liste_alterations())
	gauche.add_child(filtre_alterations)
	liste_alterations = ItemList.new()
	liste_alterations.custom_minimum_size = Vector2(250, 0)
	liste_alterations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	liste_alterations.item_selected.connect(func(k):
		var m = liste_alterations.get_item_metadata(k)
		if m != null:
			if vue_alterations == 0:
				choisir_brique(String(m))
			else:
				choisir_alteration(String(m)))
	gauche.add_child(liste_alterations)
	gauche.add_child(_bouton("Créer une altération", func(): creer_alteration()))
	var defile := ScrollContainer.new()
	defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	fiche_alteration = VBoxContainer.new()
	fiche_alteration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(fiche_alteration)


## Altérations brutes de la copie de travail (composées réglées + personnalisées, avant enregistrement).
func brutes_travail() -> Dictionary:
	if not _cache_brutes.is_empty():
		return _cache_brutes
	var b := {}
	var composees := BriquesAlterations.composees()
	for nom in composees:
		b[nom] = composees[nom].duplicate(true)
	DonneesEnnemis.appliquer_alterations(b, editions)
	_cache_brutes = b
	return b


func est_personnalisee(nom: String) -> bool:
	return not BriquesAlterations.composees().has(nom)


func libelle_alteration(nom: String) -> String:
	var b: Dictionary = brutes_travail().get(Alterations.nom_canonique(nom), {})
	return String(b.get("libelle", nom))


## Définition construite depuis la copie de travail (aperçu de l'éditeur).
func definition_travail(nom: String) -> Dictionary:
	if not _cache_definitions.has(nom):
		var b := brutes_travail()
		_cache_definitions[nom] = BriquesAlterations.construire(b[nom], b, nom) if b.has(nom) else {}
	return _cache_definitions[nom]


func categorie_travail(nom: String) -> String:
	var d := definition_travail(nom)
	if d.get("nature") == "bonus":
		return "amélioration"
	return "dégâts" if d.has("dots") or d.has("fins") else "malus"


func _remplir_liste_alterations() -> void:
	if liste_alterations == null:
		return
	liste_alterations.clear()
	choix_classement.disabled = vue_alterations == 0
	var cherche := filtre_alterations.text.strip_edges().to_lower() if filtre_alterations != null else ""
	if vue_alterations == 0:
		for f in BriquesAlterations.par_famille():
			var ids: Array = f[1].filter(func(id): return cherche == "" or cherche in String(BriquesAlterations.BRIQUES[id]["libelle"]).to_lower())
			if ids.is_empty():
				continue
			_titre_liste(liste_alterations, "%s (%d)" % [f[0], ids.size()])
			for id in ids:
				liste_alterations.add_item(String(BriquesAlterations.BRIQUES[id]["libelle"]))
				liste_alterations.set_item_metadata(liste_alterations.item_count - 1, id)
				if id == alteration_choisie:
					liste_alterations.select(liste_alterations.item_count - 1)
		return
	var garder := func(n): return est_personnalisee(n) == (vue_alterations == 2) and (cherche == "" or cherche in libelle_alteration(n).to_lower())
	var noms := noms_alterations().filter(garder)
	var groupes := [["", noms]]
	if classer_par_type:
		groupes = []
		for c in Alterations.CATEGORIES:
			groupes.append([Alterations.NOMS_CATEGORIES[c], noms.filter(func(n): return categorie_travail(n) == c)])
	for g in groupes:
		if g[0] != "":
			_titre_liste(liste_alterations, "%s (%d)" % [g[0], g[1].size()])
		for n in g[1]:
			var e = editions["alterations"].get(n, {})
			liste_alterations.add_item("%s%s%s" % ["+ " if categorie_travail(n) == "amélioration" else "", libelle_alteration(n),
				" ✎" if (e is Dictionary and not e.is_empty()) else ""])
			liste_alterations.set_item_metadata(liste_alterations.item_count - 1, n)
			if n == alteration_choisie:
				liste_alterations.select(liste_alterations.item_count - 1)
	if noms.is_empty() and vue_alterations == 2:
		liste_alterations.add_item("(aucune : « Créer une altération »)")
		liste_alterations.set_item_selectable(liste_alterations.item_count - 1, false)
		liste_alterations.set_item_metadata(liste_alterations.item_count - 1, null)


func _titre_liste(liste: ItemList, texte: String) -> void:
	var k := liste.add_item("— %s —" % texte)
	liste.set_item_selectable(k, false)
	liste.set_item_custom_fg_color(k, COULEUR_TITRE)
	liste.set_item_metadata(k, null)


## Fiche d'une brique primaire : ce qu'elle fait, ses réglages, les altérations qui l'utilisent.
func choisir_brique(id: String) -> void:
	alteration_choisie = id
	_vider(fiche_alteration)
	var spec: Dictionary = BriquesAlterations.BRIQUES[id]
	fiche_alteration.add_child(_etiquette("%s — brique primaire (%s)" % [spec["libelle"], String(spec["famille"]).to_lower()], COULEUR_TITRE, 15))
	if spec.has("aide"):
		fiche_alteration.add_child(_texte(String(spec["aide"])))
	var params: Array = spec["params"].keys().map(func(p): return NOMS_PARAMS.get(p, p))
	fiche_alteration.add_child(_texte("Réglages : " + (", ".join(params) if not params.is_empty() else "aucun")))
	fiche_alteration.add_child(_texte("Exemple : " + BriquesAlterations.phrase(_brique_neuve(id))))
	var qui := []
	var b := brutes_travail()
	for nom in b:
		var d := BriquesAlterations.construire(b[nom], b, nom)
		if d["briques"].any(func(x): return x["brique"] == id):
			qui.append(String(b[nom].get("libelle", nom)))
	qui.sort()
	fiche_alteration.add_child(_texte("Utilisée par (%d) : %s" % [qui.size(), ", ".join(qui) if not qui.is_empty() else "aucune altération"]))


func _texte(t: String, couleur := Color(0.8, 0.78, 0.85), taille := 13) -> Label:
	var l := _etiquette(t, couleur, taille)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _brique_neuve(id: String) -> Dictionary:
	var b := {"brique": id}
	for p in BriquesAlterations.BRIQUES[id]["params"]:
		var v = BriquesAlterations.VALEURS_NOUVELLE_BRIQUE.get(p, 0)
		b[p] = v.duplicate() if v is Array else v
	return b


## Brute de travail d'une altération (copie modifiable).
func _brute(nom: String) -> Dictionary:
	return brutes_travail().get(nom, {}).duplicate(true)


## Enregistre dans la copie de travail la brute modifiée d'une altération (réglage d'une composée, ou personnalisée).
func _poser_brute(nom: String, brute: Dictionary, texte: String) -> void:
	if est_personnalisee(nom):
		editions["alterations_personnalisees"][nom] = brute
	else:
		var e: Dictionary = editions["alterations"].get(nom, {})
		var origine: Dictionary = BriquesAlterations.composees()[nom]
		for cle in ["duree", "cumul_max"]:
			if int(brute.get(cle, 1)) != int(origine.get(cle, 1)):
				e[cle] = int(brute[cle])
			else:
				e.erase(cle)
		if brute["briques"] != origine["briques"]:
			e["briques"] = brute["briques"].duplicate(true)
		else:
			e.erase("briques")
		if e.is_empty():
			editions["alterations"].erase(nom)
		else:
			editions["alterations"][nom] = e
	_change(texte)
	_maj_description(nom)


## Fiche d'une altération composée ou personnalisée : le créateur (nom, nature, durée, cumul, morceaux).
func choisir_alteration(nom: String) -> void:
	alteration_choisie = nom
	_vider(fiche_alteration)
	_maj = true
	var brute := _brute(nom)
	var perso := est_personnalisee(nom)
	fiche_alteration.add_child(_etiquette("%s — %s (%s)" % [brute.get("libelle", nom), "personnalisée" if perso else "composée",
		String(Alterations.NOMS_CATEGORIES[categorie_travail(nom)]).to_lower()], COULEUR_TITRE, 15))
	var desc := _texte(BriquesAlterations.decrire(definition_travail(nom)), Color(0.9, 0.9, 0.7))
	desc.name = "Description"
	fiche_alteration.add_child(desc)
	_section(fiche_alteration, "Réglages")
	if perso:
		var champ := LineEdit.new()
		champ.text = String(brute.get("libelle", nom))
		champ.custom_minimum_size = Vector2(260, 0)
		champ.text_submitted.connect(func(t): renommer_alteration(nom, t))
		champ.focus_exited.connect(func(): renommer_alteration(nom, champ.text))
		_ligne(fiche_alteration, "Nom", champ)
		_ligne(fiche_alteration, "Nature", _liste_deroulante(["Malus", "Amélioration"], 1 if brute.get("nature") == "bonus" else 0,
			func(k):
				var b := _brute(nom)
				b["nature"] = "bonus" if k == 1 else "malus"
				_poser_brute(nom, b, "%s : nature" % nom)))
	_ligne(fiche_alteration, "Durée (tours)", _nombre(float(brute.get("duree", 3)), 1, 20, 1, func(v):
		var b := _brute(nom)
		b["duree"] = int(v)
		_poser_brute(nom, b, "%s : durée" % nom)))
	_ligne(fiche_alteration, "Cumul maximal", _nombre(float(brute.get("cumul_max", 1)), 1, 10, 1, func(v):
		var b := _brute(nom)
		b["cumul_max"] = int(v)
		_poser_brute(nom, b, "%s : cumul" % nom)))
	_section(fiche_alteration, "Morceaux", "Les briques (effets de base) et les altérations citées qui composent celle-ci. Survoler un nom pour son aide.")
	var morceaux: Array = brute.get("briques", [])
	for k in morceaux.size():
		fiche_alteration.add_child(_ligne_morceau(nom, k, morceaux[k]))
	# Ajouter une brique ou une altération
	_section(fiche_alteration, "Ajouter", "Une brique arrive avec des valeurs proposées, à régler ; une altération citée arrive à 100 % de puissance.")
	var ajout := HBoxContainer.new()
	var ids := []
	var textes := []
	for f in BriquesAlterations.par_famille():
		for id in f[1]:
			ids.append(id)
			textes.append("%s (%s)" % [BriquesAlterations.BRIQUES[id]["libelle"], String(f[0]).to_lower()])
	var choix_b := _liste_deroulante(textes, 0, func(_k): pass, 260)
	ajout.add_child(choix_b)
	ajout.add_child(_bouton("Ajouter la brique", func():
		var b := _brute(nom)
		b["briques"].append(_brique_neuve(ids[choix_b.selected]))
		_poser_brute(nom, b, "%s : brique ajoutée" % nom)
		choisir_alteration(nom)))
	fiche_alteration.add_child(ajout)
	var ajout2 := HBoxContainer.new()
	var autres: Array = noms_alterations().filter(func(n): return n != nom)
	var choix_a := _liste_deroulante(autres.map(func(n): return libelle_alteration(n)), 0, func(_k): pass, 260)
	ajout2.add_child(choix_a)
	ajout2.add_child(_bouton("Ajouter l'altération", func():
		if autres.is_empty():
			return
		var b := _brute(nom)
		b["briques"].append({"alteration": autres[choix_a.selected], "puissance": 100})
		_poser_brute(nom, b, "%s : altération ajoutée" % nom)
		choisir_alteration(nom)))
	fiche_alteration.add_child(ajout2)
	# Qui l'inflige
	_section(fiche_alteration, "Utilisation")
	var qui := []
	for c in toutes_les_competences():
		var e_c = editions["competences"].get(c, {})
		if e_c is Dictionary and e_c.get("type_alteration", {}).has(nom):
			qui.append(nom_competence(c))
		elif BasesCompetences.BASES.get(c, {}).get("alterations", {}).has(nom):
			qui.append(nom_competence(c))
	fiche_alteration.add_child(_texte("Compétences qui l'infligent : " + (", ".join(qui) if not qui.is_empty() else "aucune réglée ici")))
	var bas := HBoxContainer.new()
	if perso:
		bas.add_child(_bouton("Supprimer cette altération", func(): supprimer_alteration(nom)))
	else:
		bas.add_child(_bouton("Remettre d'origine", func():
			editions["alterations"].erase(nom)
			_change(nom + " remise d'origine")
			_remplir_liste_alterations()
			choisir_alteration(nom)))
	bas.add_child(_bouton("Copier en altération personnalisée", func(): creer_alteration(nom)))
	fiche_alteration.add_child(bas)
	fiche_alteration.add_child(_etiquette("Les réglages valent pour tout le jeu (héros compris), aux prochains combats, une fois enregistrés.",
		Color(0.65, 0.65, 0.7), 12))
	_maj = false


## Règle la durée ou le cumul maximal d'une altération (composée ou personnalisée).
func _regler_alteration(nom: String, champ: String, valeur: int) -> void:
	var b := _brute(nom)
	b[champ] = valeur
	_poser_brute(nom, b, "%s : %s" % [nom, champ])


func _maj_description(nom: String) -> void:
	var desc := fiche_alteration.get_node_or_null("Description")
	if desc != null:
		desc.text = BriquesAlterations.decrire(definition_travail(nom))


## Une ligne du créateur : une brique et ses réglages, ou une altération citée et sa puissance.
func _ligne_morceau(nom: String, k: int, m: Dictionary) -> Control:
	var cadre := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.15)
	style.border_color = Color(0.3, 0.28, 0.36)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	cadre.add_theme_stylebox_override("panel", style)
	var ligne := HFlowContainer.new()
	cadre.add_child(ligne)
	for sens in [-1, 1]:
		var fleche := _bouton("↑" if sens < 0 else "↓", func():
			var b := _brute(nom)
			var j: int = k + sens
			if j < 0 or j >= b["briques"].size():
				return
			var tmp = b["briques"][k]
			b["briques"][k] = b["briques"][j]
			b["briques"][j] = tmp
			_poser_brute(nom, b, "%s : morceau déplacé" % nom)
			choisir_alteration(nom))
		fleche.tooltip_text = "Monter" if sens < 0 else "Descendre"
		ligne.add_child(fleche)
	var regler := func(cle: String, valeur):
		var b := _brute(nom)
		b["briques"][k][cle] = valeur
		_poser_brute(nom, b, "%s : %s" % [nom, cle])
	if m.has("alteration"):
		ligne.add_child(_etiquette("Altération : %s" % libelle_alteration(String(m["alteration"])), Color(0.75, 0.85, 1)))
		ligne.add_child(_etiquette("puissance"))
		ligne.add_child(_nombre(float(m.get("puissance", 100)), 0, 1000, 5, func(v): regler.call("puissance", v), " %"))
	else:
		var id := String(m.get("brique", ""))
		var spec: Dictionary = BriquesAlterations.BRIQUES.get(id, {"libelle": id, "params": {}})
		var titre := _etiquette(String(spec["libelle"]), Color(0.75, 1, 0.8))
		titre.tooltip_text = String(spec.get("aide", spec["libelle"])) + "
" + BriquesAlterations.phrase(m)
		titre.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(titre)
		for p in spec["params"]:
			ligne.add_child(_etiquette(NOMS_PARAMS.get(p, p)))
			ligne.add_child(_controle_param(String(spec["params"][p]), m.get(p, _absent(String(spec["params"][p]))),
				func(v): regler.call(p, v)))
	var retirer := _bouton("✕", func():
		var b := _brute(nom)
		b["briques"].remove_at(k)
		_poser_brute(nom, b, "%s : morceau retiré" % nom)
		choisir_alteration(nom))
	retirer.tooltip_text = "Retirer ce morceau"
	ligne.add_child(retirer)
	return cadre


## Valeur d'un réglage absent d'une brique (il ne compte pas : 0, aucun dé, case décochée).
func _absent(genre: String):
	return {"pct": 0.0, "nombre": 0.0, "des": [0, 2], "cumul": "aucun", "oui": false, "type": "feu", "defense": "physique",
		"baisse": "armure", "carac": "force"}.get(genre, 0)


## Contrôle d'un réglage de brique selon son genre (BriquesAlterations.BRIQUES).
func _controle_param(genre: String, valeur, action: Callable) -> Control:
	match genre:
		"pct":
			return _nombre(float(valeur) * 100.0, -1000, 1000, 0.5, func(v): action.call(snappedf(v / 100.0, 0.0001)), " %")
		"nombre":
			return _nombre(float(valeur), -9999, 9999, 0.5, action)
		"type", "defense", "baisse", "carac", "cumul":
			var cles: Array
			var textes: Array
			match genre:
				"type":
					cles = BriquesAlterations.TYPES
					textes = cles
				"defense":
					cles = BriquesAlterations.TYPES_DEFENSE
					textes = cles.map(func(c): return {"elementaire": "élémentaire (feu, froid, foudre)",
						"magique": "magique (arcane, chaos, ombre)", "physique": "physique (tous)"}.get(c, c))
				"baisse":
					cles = BriquesAlterations.STATS_BAISSE.keys()
					textes = cles.map(func(c): return BriquesAlterations.STATS_BAISSE[c][0])
				"carac":
					cles = Caracteristiques.LISTE
					textes = cles.map(func(c): return Caracteristiques.NOMS[c])
				_:
					cles = BriquesAlterations.CUMULS.keys()
					textes = cles.map(func(c): return BriquesAlterations.CUMULS[c])
			return _liste_deroulante(textes, cles.find(valeur), func(i): action.call(cles[i]), 170)
		"des":
			var d: Array = valeur if valeur is Array and valeur.size() == 2 else [0, 2]
			var h := HBoxContainer.new()
			var n := _nombre(float(d[0]), 0, 50, 1, func(_v): pass)
			var f := _nombre(float(d[1]), 2, 20, 1, func(_v): pass, "")
			n.custom_minimum_size = Vector2(60, 0)
			f.custom_minimum_size = Vector2(60, 0)
			n.value_changed.connect(func(v):
				if not _maj:
					action.call([int(v), int(f.value)]))
			f.value_changed.connect(func(v):
				if not _maj:
					action.call([int(n.value), int(v)]))
			h.add_child(n)
			h.add_child(_etiquette("d"))
			h.add_child(f)
			return h
		"oui":
			var c := CheckBox.new()
			c.button_pressed = bool(valeur)
			c.focus_mode = Control.FOCUS_NONE
			c.toggled.connect(func(v):
				if not _maj:
					action.call(v))
			return c
	return _etiquette(str(valeur))


## Créateur : nouvelle altération personnalisée (vide, ou copie de ``modele``).
func creer_alteration(modele := "") -> String:
	var base := "nouvelle altération" if modele == "" else libelle_alteration(modele).to_lower() + " (copie)"
	var nom := base
	var i := 2
	var b := brutes_travail()
	while b.has(nom):
		nom = "%s %d" % [base, i]
		i += 1
	var brute: Dictionary
	if modele != "" and b.has(modele):
		brute = b[modele].duplicate(true)
	else:
		brute = {"nature": "malus", "duree": 3, "cumul_max": 1, "briques": [_brique_neuve("toucher")]}
		brute["briques"][0]["valeur"] = -0.10
	brute["libelle"] = nom.substr(0, 1).to_upper() + nom.substr(1)
	editions["alterations_personnalisees"][nom] = brute
	_change("altération créée : " + nom)
	vue_alterations = 2
	choix_vue_alterations.select(2)
	alteration_choisie = nom
	_remplir_liste_alterations()
	choisir_alteration(nom)
	return nom


## Renomme une altération personnalisée (son nom interne suit le nom affiché, en minuscules).
func renommer_alteration(nom: String, texte: String) -> void:
	texte = texte.strip_edges()
	if texte == "" or not editions["alterations_personnalisees"].has(nom):
		return
	var cle := texte.to_lower()
	var brute: Dictionary = editions["alterations_personnalisees"][nom]
	if cle == nom:
		if brute.get("libelle") != texte:
			brute["libelle"] = texte
			_change("%s renommée" % nom)
			_remplir_liste_alterations()
		return
	if brutes_travail().has(cle):
		etat.text = "« %s » existe déjà" % texte
		return
	editions["alterations_personnalisees"].erase(nom)
	brute["libelle"] = texte
	editions["alterations_personnalisees"][cle] = brute
	# Les compétences et les autres altérations qui la citaient suivent
	for c in editions["competences"]:
		var ta = editions["competences"][c].get("type_alteration") if editions["competences"][c] is Dictionary else null
		if ta is Dictionary and ta.has(nom):
			ta[cle] = ta[nom]
			ta.erase(nom)
	for n in editions["alterations_personnalisees"]:
		for m in editions["alterations_personnalisees"][n].get("briques", []):
			if m is Dictionary and m.get("alteration") == nom:
				m["alteration"] = cle
	_change("%s renommée en %s" % [nom, cle])
	alteration_choisie = cle
	_remplir_liste_alterations()
	choisir_alteration.call_deferred(cle)


func supprimer_alteration(nom: String) -> void:
	editions["alterations_personnalisees"].erase(nom)
	for c in editions["competences"]:
		var ta = editions["competences"][c].get("type_alteration") if editions["competences"][c] is Dictionary else null
		if ta is Dictionary:
			ta.erase(nom)
	_change("altération supprimée : " + nom)
	alteration_choisie = ""
	_vider(fiche_alteration)
	_remplir_liste_alterations()


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
	var libelles_alt := noms_alt.map(func(n): return libelle_alteration(n))
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
