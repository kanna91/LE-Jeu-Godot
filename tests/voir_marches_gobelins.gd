extends Control
## Aperçu des marches des gobelins faites par Grok (2026-10-28), AVANT de les brancher dans le jeu.
## Lit le dossier préparé par ``outils/apercu_marches_gobelins.py`` (C:\IA\pont-blender\apercu_gobelins), hors du jeu.
## Deux vues :
## - « Planche » : chaque gobelin dans ses 4 vues (face, trois quarts, profil, dos), qui marchent sur place ;
## - « Dans la salle » : les gobelins traversent la salle de la porte 2 de profil, à la vitesse de leur foulée
##   (comme le geôlier : l'image change selon la distance parcourue, les pieds ne doivent pas glisser).
## Touches : Tab = changer de vue ; Espace = pause ; + / - = ralentir ou accélérer ; Échap = quitter.
## Lancer : voir_marches_gobelins.bat

const DOSSIER := "C:/IA/pont-blender/apercu_gobelins"
const VUES := ["face", "trois_quarts", "profil", "dos"]
const NOMS_VUES := {"face": "face", "trois_quarts": "trois quarts", "profil": "profil", "dos": "dos"}
const HAUTEUR_SALLE := 150.0   # taille d'un gobelin dans la salle (pixels écran)

var sortes: Array = []
var infos := {}       # sorte -> animations.json
var images := {}      # sorte -> {vue -> [Texture2D]}
var fond: Texture2D
var mode := 0         # 0 planche, 1 salle
var pause := false
var ralenti := 1.0
var temps := 0.0
var marcheurs := []   # {sorte, x, sens, parcouru, y}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color8(20, 18, 26))
	var f := FileAccess.open(DOSSIER + "/sortes.json", FileAccess.READ)
	if f == null:
		push_error("Aperçu absent : lancer python outils/apercu_marches_gobelins.py")
		return
	sortes = JSON.parse_string(f.get_as_text())
	for s in sortes:
		infos[s] = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "/" + s + "/animations.json"))
		images[s] = {}
		for vue in infos[s]["vues"]:
			var liste := []
			for k in int(infos[s]["vues"][vue]["images"]):
				var im := Image.load_from_file("%s/%s/%s_%03d.png" % [DOSSIER, s, vue, k])
				liste.append(ImageTexture.create_from_image(im))
			images[s][vue] = liste
	var image_fond := Image.load_from_file(ProjectSettings.globalize_path("res://images/salles_peintes/porte2/fond.jpeg"))
	if image_fond:
		fond = ImageTexture.create_from_image(image_fond)
	var ys := [0.79, 0.85, 0.91, 0.96]   # fraction de la hauteur de l'écran
	for i in sortes.size():
		marcheurs.append({"sorte": sortes[i], "x": 260.0 + i * 230.0, "sens": 1 if i % 2 == 0 else -1,
			"parcouru": i * 3.0, "y": ys[i % ys.size()]})
	# Vérification sans regarder : « -- capture=<dossier> » enregistre les deux vues puis quitte
	for a in OS.get_cmdline_user_args():
		if a.begins_with("capture="):
			_capturer(a.substr(8))


func _capturer(dossier: String) -> void:
	for m in 2:
		mode = m
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/apercu_gobelins_%d.png" % [dossier, m])
	get_tree().quit()


func _process(delta: float) -> void:
	if not pause:
		var d := delta / ralenti
		temps += d
		for m in marcheurs:
			var info: Dictionary = infos[m["sorte"]]
			var v := float(info["foulee"]) * float(info["fps"]) * HAUTEUR_SALLE * _echelle_salle()
			m["x"] += v * d * m["sens"]
			m["parcouru"] += float(info["fps"]) * d
			if m["x"] > size.x - 160.0:
				m["sens"] = -1
			elif m["x"] < 160.0:
				m["sens"] = 1
	queue_redraw()


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_TAB: mode = 1 - mode
			KEY_SPACE: pause = not pause
			KEY_KP_ADD, KEY_PLUS, KEY_EQUAL: ralenti = max(0.25, ralenti / 2.0)
			KEY_KP_SUBTRACT, KEY_MINUS, KEY_6: ralenti = min(8.0, ralenti * 2.0)
			KEY_ESCAPE: get_tree().quit()


func _echelle_salle() -> float:
	return 1.0


func _image(s: String, vue: String, t: float) -> Texture2D:
	var liste: Array = images[s].get(vue, [])
	if liste.is_empty():
		return null
	var fps := float(infos[s]["vues"][vue]["fps"])
	return liste[int(t * fps) % liste.size()]


func _draw() -> void:
	var police := ThemeDB.fallback_font
	if sortes.is_empty():
		draw_string(police, Vector2(30, 60), "Aperçu absent : lancer python outils/apercu_marches_gobelins.py", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		return
	if mode == 0:
		_dessiner_planche(police)
	else:
		_dessiner_salle(police)
	var aide := "Tab : %s   Espace : pause   + / - : vitesse (×%s)   Échap : quitter" % [
		"voir dans la salle" if mode == 0 else "voir la planche", str(snapped(1.0 / ralenti, 0.01))]
	draw_rect(Rect2(0, size.y - 24, size.x, 24), Color(0, 0, 0, 0.6))
	draw_string(police, Vector2(10, size.y - 7), aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))


func _dessiner_planche(police: Font) -> void:
	var lignes := sortes.size()
	var haut_ligne := (size.y - 24.0 - 24.0) / lignes
	var gauche := 110.0
	var larg_col := (size.x - gauche) / VUES.size()
	for j in VUES.size():
		draw_string(police, Vector2(gauche + j * larg_col, 18), NOMS_VUES[VUES[j]], HORIZONTAL_ALIGNMENT_CENTER, larg_col, 15)
	for i in lignes:
		var s: String = sortes[i]
		var y0 := 24.0 + i * haut_ligne
		var info: Dictionary = infos[s]
		draw_string(police, Vector2(8, y0 + haut_ligne * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.5))
		draw_string(police, Vector2(8, y0 + haut_ligne * 0.5 + 18), "%s img/s" % info["fps"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
		for j in VUES.size():
			var tex := _image(s, VUES[j], temps)
			if tex == null:
				draw_string(police, Vector2(gauche + j * larg_col, y0 + haut_ligne * 0.5), "(absente)", HORIZONTAL_ALIGNMENT_CENTER, larg_col, 13, Color(0.6, 0.4, 0.4))
				continue
			var h := haut_ligne - 6.0
			var w := h * tex.get_width() / tex.get_height()
			var x := gauche + j * larg_col + (larg_col - w) * 0.5
			draw_line(Vector2(gauche + j * larg_col + 10, y0 + h + 2), Vector2(gauche + (j + 1) * larg_col - 10, y0 + h + 2), Color(1, 1, 1, 0.15), 1.0)
			draw_texture_rect(tex, Rect2(x, y0 + 2, w, h), false)


func _dessiner_salle(police: Font) -> void:
	if fond:
		var e := size.y / fond.get_height()
		var w := fond.get_width() * e
		draw_texture_rect(fond, Rect2((size.x - w) * 0.5, 0, w, size.y), false)
	var tries := marcheurs.duplicate()  # les plus proches dessinés en dernier
	tries.sort_custom(func(a, b): return a["y"] < b["y"])
	for m in tries:
		var s: String = m["sorte"]
		var liste: Array = images[s].get("profil", [])
		if liste.is_empty():
			continue
		var tex: Texture2D = liste[int(m["parcouru"]) % liste.size()]
		var h := HAUTEUR_SALLE
		var w := h * tex.get_width() / tex.get_height()
		var pied: float = m["y"] * size.y
		draw_set_transform(Vector2(m["x"], 0), 0.0, Vector2(m["sens"], 1))
		draw_texture_rect(tex, Rect2(-w * 0.5, pied - h, w, h), false)
		draw_set_transform(Vector2.ZERO)
		draw_string(police, Vector2(m["x"] - 40, pied + 14), s, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 0.85, 0.5))
