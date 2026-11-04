class_name EditeurDialogues
extends PanelContainer
## Menu « Dialogues » de l'éditeur de zones (2026-11-04, demande de l'utilisateur : « modifier tous les dialogues de
## tous les personnages »). Bouton « Dialogues » en haut à droite de l'éditeur, ou touche F3.
##
## À gauche, les personnages : ceux de ``donnees/dialogues.json`` (commis, diablotin, succube, gobelin blessé,
## prisonnier enchaîné, autel, gobelins pacifiques, rumeurs, prisonnier des cellules sans quête) et ceux de
## ``donnees/prisonniers.json`` (accueil et informations des prisonniers ordinaires, chaque quête, objets des quêtes).
## Au milieu, les textes du personnage choisi ; à droite, le texte choisi, modifiable. Dans une liste (bulles d'un
## commis, répliques d'une étape de quête, lore...), on peut ajouter ou supprimer des lignes. Les mots entre
## accolades ({direction}, {pv}...) sont remplacés dans le jeu. Enregistrer : Ctrl+S ou le bouton ; Fermer (Échap)
## enregistre aussi ce qui a été modifié.

const FICHIERS := ["dialogues.json", "prisonniers.json"]
## Clés de prisonniers.json qui sont des textes (le reste : identifiants, étapes, actions, à ne pas toucher ici).
const TEXTES_PRISONNIERS := ["nom", "presentation", "texte", "repete", "disparaitre", "message", "description",
	"accueil", "informations"]
## Noms lisibles des clés.
const NOMS_CLES := {"presentation": "Présentation", "explications": "Explications (une bulle par ligne)",
	"boutons": "Boutons", "fin": "Fin", "nom": "Nom affiché", "accueil": "Accueil", "informations": "Informations",
	"texte": "Texte (une bulle par ligne)", "repete": "Répliques suivantes", "etapes": "Étapes", "actions": "Actions",
	"actions_repete": "Actions (répétées)", "disparaitre": "Disparition", "message": "Message", "description": "Description",
	"rien_a_dire": "Plus rien à dire", "note_journal": "Note du journal", "reste": "Reste là", "disparait": "Disparaît",
	"chevalier": "Chevalier de la mort", "conseils": "Conseils", "lore": "Histoires (lore)", "affaires": "Affaires du héros",
	"etage": "Cet étage", "mensonges": "Mensonges", "sujets": "Sujets (boutons)", "faits": "Faits (vrai / faux)",
	"vrai": "Vrai", "faux": "Faux", "gardien": "Le boss", "rien": "Rien à dire", "effets_pactes": "Effets des pactes",
	"objets": "Objets"}

signal ferme

var donnees := {}  # fichier → contenu lu
var modifies := {}  # fichier → vrai
var personnages: Array = []  # [{nom, fichier, chemin, cles}]
var liste: ItemList
var arbre: Tree
var edition: TextEdit
var titre_texte: Label
var etat: Label
var bouton_ajouter: Button
var bouton_supprimer: Button
var choisi := {}  # métadonnées du texte choisi
var _maj := false


func _ready() -> void:
	# Toute la fenêtre (le parent, l'éditeur, n'a pas de taille)
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.97)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	add_child(colonne)
	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var titre := Label.new()
	titre.text = "Dialogues des personnages"
	titre.add_theme_font_size_override("font_size", 18)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	haut.add_child(_bouton("Enregistrer (Ctrl+S)", enregistrer))
	haut.add_child(_bouton("Fermer (Échap)", fermer))
	var corps := HBoxContainer.new()
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(corps)
	liste = ItemList.new()
	liste.custom_minimum_size = Vector2(210, 0)
	liste.item_selected.connect(_personnage_choisi)
	corps.add_child(liste)
	arbre = Tree.new()
	arbre.custom_minimum_size = Vector2(320, 0)
	arbre.hide_root = true
	arbre.item_selected.connect(_texte_choisi)
	corps.add_child(arbre)
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(droite)
	titre_texte = Label.new()
	titre_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titre_texte.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	droite.add_child(titre_texte)
	edition = TextEdit.new()
	edition.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edition.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edition.editable = false
	edition.text_changed.connect(_texte_modifie)
	droite.add_child(edition)
	var boutons := HBoxContainer.new()
	droite.add_child(boutons)
	bouton_ajouter = _bouton("Ajouter une ligne", ajouter_ligne)
	bouton_supprimer = _bouton("Supprimer la ligne", supprimer_ligne)
	boutons.add_child(bouton_ajouter)
	boutons.add_child(bouton_supprimer)
	var aide := Label.new()
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.add_theme_font_size_override("font_size", 12)
	aide.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	aide.text = "Les mots entre accolades ({direction}, {pv}, {rumeur}...) sont remplacés dans le jeu : gardez-les tels quels. " + \
		"Une liste (une bulle par ligne) peut avoir autant de lignes qu'on veut."
	droite.add_child(aide)
	etat = Label.new()
	etat.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	colonne.add_child(etat)
	charger()


func _bouton(t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


## Relit les deux fichiers et la liste des personnages.
func charger() -> void:
	donnees = {}
	modifies = {}
	for f in FICHIERS:
		var lu = U.charger_json(f)
		donnees[f] = lu if lu is Dictionary else {}
	personnages = []
	var d: Dictionary = donnees["dialogues.json"]
	for cle in d:
		if not String(cle).begins_with("_") and d[cle] is Dictionary:
			personnages.append({"nom": String(d[cle].get("_nom", cle)), "fichier": "dialogues.json", "chemin": [cle]})
	var p: Dictionary = donnees["prisonniers.json"]
	personnages.append({"nom": "Prisonniers ordinaires (accueil, informations)", "fichier": "prisonniers.json", "chemin": [],
		"cles": ["accueil", "informations"]})
	var quetes: Array = p.get("quetes", [])
	for k in quetes.size():
		personnages.append({"nom": "Quête : " + String(quetes[k].get("nom", "?")), "fichier": "prisonniers.json",
			"chemin": ["quetes", k]})
	if p.get("objets", {}) is Dictionary and not p.get("objets", {}).is_empty():
		personnages.append({"nom": "Objets des quêtes", "fichier": "prisonniers.json", "chemin": ["objets"]})
	liste.clear()
	for q in personnages:
		liste.add_item(q["nom"])
	if not personnages.is_empty():
		liste.select(0)
		_personnage_choisi(0)
	etat.text = ""


func _valeur(fichier: String, chemin: Array):
	var v = donnees[fichier]
	for k in chemin:
		v = v[k]
	return v


func _poser(fichier: String, chemin: Array, valeur) -> void:
	var parent = _valeur(fichier, chemin.slice(0, chemin.size() - 1))
	parent[chemin[-1]] = valeur


## Vrai si la chaîne sous la clé ``cle`` est un texte modifiable ici.
func _est_texte(fichier: String, cle: String) -> bool:
	if cle.begins_with("_"):
		return false
	return fichier == "dialogues.json" or cle in TEXTES_PRISONNIERS


func _nom_cle(cle) -> String:
	var c := str(cle)
	return NOMS_CLES.get(c, c.replace("_", " ").capitalize())


func _personnage_choisi(k: int) -> void:
	var q: Dictionary = personnages[k]
	arbre.clear()
	var racine := arbre.create_item()
	var v = _valeur(q["fichier"], q["chemin"])
	if q.has("cles"):
		for cle in q["cles"]:
			if not v.has(cle):
				v[cle] = []
			_remplir(racine, q["fichier"], q["chemin"] + [cle], v[cle], cle)
	else:
		_remplir_enfants(racine, q["fichier"], q["chemin"], v, "")
	_choisir({})
	var premier = _premier_texte(racine)
	if premier != null:
		premier.select(0)


func _premier_texte(item: TreeItem):
	for enfant in item.get_children():
		if enfant.get_metadata(0) is Dictionary and enfant.get_metadata(0).get("texte", false):
			return enfant
		var r = _premier_texte(enfant)
		if r != null:
			return r
	return null


## Ajoute à ``parent`` les entrées de ``v`` (dictionnaire ou liste) ; ``cle_liste`` : clé de la liste (pour savoir si
## ses chaînes sont des textes).
func _remplir_enfants(parent: TreeItem, fichier: String, chemin: Array, v, cle_liste: String) -> void:
	if v is Dictionary:
		for cle in v:
			if not String(cle).begins_with("_"):
				_remplir(parent, fichier, chemin + [cle], v[cle], String(cle))
	elif v is Array:
		for k in v.size():
			_remplir(parent, fichier, chemin + [k], v[k], cle_liste, true)


## Une entrée : texte (feuille), liste ou dictionnaire (branche, seulement si elle contient des textes).
func _remplir(parent: TreeItem, fichier: String, chemin: Array, v, cle: String, dans_liste := false) -> void:
	if v is String:
		if not _est_texte(fichier, cle):
			return
		var item := arbre.create_item(parent)
		var nom := ("Ligne %d" % (int(chemin[-1]) + 1)) if dans_liste else _nom_cle(cle)
		item.set_text(0, "%s : %s" % [nom, _apercu(v)])
		item.set_metadata(0, {"texte": true, "fichier": fichier, "chemin": chemin, "nom": nom, "dans_liste": dans_liste})
		return
	if not (v is Dictionary or v is Array) or not _contient_texte(fichier, v, cle):
		return
	var item := arbre.create_item(parent)
	var liste_textes: bool = v is Array and _est_texte(fichier, cle) and v.all(func(x): return x is String)
	var nom := ("Élément %d" % (int(chemin[-1]) + 1)) if dans_liste else _nom_cle(cle)
	item.set_text(0, nom + (" (%d)" % v.size() if liste_textes else ""))
	item.set_metadata(0, {"texte": false, "fichier": fichier, "chemin": chemin, "liste": liste_textes, "nom": nom})
	_remplir_enfants(item, fichier, chemin, v, cle)


func _contient_texte(fichier: String, v, cle: String) -> bool:
	if v is Array:
		if _est_texte(fichier, cle) and v.all(func(x): return x is String):
			return true  # liste de textes, même vide
		return v.any(func(x): return (x is Dictionary or x is Array) and _contient_texte(fichier, x, cle))
	if v is Dictionary:
		for k in v:
			if String(k).begins_with("_"):
				continue
			if v[k] is String and _est_texte(fichier, String(k)):
				return true
			if (v[k] is Dictionary or v[k] is Array) and _contient_texte(fichier, v[k], String(k)):
				return true
	return false


func _apercu(t: String) -> String:
	t = t.replace("\n", " ")
	return t if t.length() <= 48 else t.substr(0, 46) + "…"


func _texte_choisi() -> void:
	var item := arbre.get_selected()
	_choisir(item.get_metadata(0) if item != null else {})


func _choisir(m: Dictionary) -> void:
	choisi = m
	_maj = true
	if m.get("texte", false):
		edition.text = String(_valeur(m["fichier"], m["chemin"]))
		edition.editable = true
		titre_texte.text = "%s — %s" % [liste.get_item_text(liste.get_selected_items()[0]) if not liste.get_selected_items().is_empty() else "", m["nom"]]
	else:
		edition.text = ""
		edition.editable = false
		titre_texte.text = "Choisissez un texte." if not m.get("liste", false) else "%s : choisissez une ligne, ou ajoutez-en une." % m["nom"]
	_maj = false
	bouton_ajouter.disabled = not (m.get("liste", false) or m.get("dans_liste", false) and _parent_liste(m))
	bouton_supprimer.disabled = not (m.get("dans_liste", false) and _parent_liste(m))


## Vrai si le texte ``m`` est une ligne d'une liste de textes (on peut en ajouter / supprimer).
func _parent_liste(m: Dictionary) -> bool:
	var parent = _valeur(m["fichier"], m["chemin"].slice(0, m["chemin"].size() - 1))
	return parent is Array and parent.all(func(x): return x is String)


func _texte_modifie() -> void:
	if _maj or not choisi.get("texte", false):
		return
	_poser(choisi["fichier"], choisi["chemin"], edition.text)
	modifies[choisi["fichier"]] = true
	var item := arbre.get_selected()
	if item != null:
		item.set_text(0, "%s : %s" % [choisi["nom"], _apercu(edition.text)])
	etat.text = "Modifié (pas encore enregistré)"


## Ajoute une ligne vide à la liste choisie (ou après la ligne choisie) et la choisit.
func ajouter_ligne() -> void:
	var chemin_liste: Array
	var position: int
	if choisi.get("liste", false):
		chemin_liste = choisi["chemin"]
		position = _valeur(choisi["fichier"], chemin_liste).size()
	elif choisi.get("dans_liste", false):
		chemin_liste = choisi["chemin"].slice(0, choisi["chemin"].size() - 1)
		position = int(choisi["chemin"][-1]) + 1
	else:
		return
	var fichier: String = choisi["fichier"]
	_valeur(fichier, chemin_liste).insert(position, "")
	modifies[fichier] = true
	_reconstruire(fichier, chemin_liste + [position])
	etat.text = "Ligne ajoutée (pas encore enregistrée)"


func supprimer_ligne() -> void:
	if not choisi.get("dans_liste", false):
		return
	var fichier: String = choisi["fichier"]
	var chemin_liste: Array = choisi["chemin"].slice(0, choisi["chemin"].size() - 1)
	var l: Array = _valeur(fichier, chemin_liste)
	var k := int(choisi["chemin"][-1])
	l.remove_at(k)
	modifies[fichier] = true
	_reconstruire(fichier, chemin_liste + [k - 1] if k > 0 and not l.is_empty() else chemin_liste)
	etat.text = "Ligne supprimée (pas encore enregistrée)"


## Refait l'arbre du personnage choisi et choisit l'entrée ``chemin``.
func _reconstruire(fichier: String, chemin: Array) -> void:
	var sel := liste.get_selected_items()
	if sel.is_empty():
		return
	_personnage_choisi(sel[0])
	var item = _trouver(arbre.get_root(), fichier, chemin)
	if item != null:
		item.select(0)
		arbre.scroll_to_item(item)
	if choisi.get("texte", false):
		edition.grab_focus()


func _trouver(item: TreeItem, fichier: String, chemin: Array):
	for enfant in item.get_children():
		var m = enfant.get_metadata(0)
		if m is Dictionary and m["fichier"] == fichier and m["chemin"] == chemin:
			return enfant
		var r = _trouver(enfant, fichier, chemin)
		if r != null:
			return r
	return null


## Enregistre les fichiers modifiés. Renvoie le message.
func enregistrer() -> String:
	var faits := []
	for f in modifies:
		var fichier := FileAccess.open("res://donnees/" + f, FileAccess.WRITE)
		if fichier == null:
			etat.text = "ÉCHEC : impossible d'écrire donnees/" + f
			return etat.text
		fichier.store_string(JSON.stringify(U.entiers(donnees[f]), " ", false))
		fichier.close()
		faits.append(f)
	modifies = {}
	Dialogues.recharger()
	Rencontres._textes_prisonniers = {}
	etat.text = "Enregistré : " + ", ".join(faits) if not faits.is_empty() else "Rien à enregistrer."
	return etat.text


func fermer() -> void:
	if not modifies.is_empty():
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
