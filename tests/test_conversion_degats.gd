extends SceneTree
## Conversion de dégâts des objets (2026-11-15) : part des dés arrondie au plus proche (au moins 1 dé), brut à 25 %
## au plus et jamais type de départ, estimation des dégâts convertie, effets générés.
## godot --headless --path godot -s tests/test_conversion_degats.gd

var echecs := 0


func verifier(condition: bool, message: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC : ", message)


func _lanceur(stats: Dictionary) -> Reference:
	return Reference.nouvelle(stats)


func _competence(nombre: int) -> Reference:
	return Reference.nouvelle({"des_degats": {"tranchant": [nombre, 2]}, "type_degats": ["tranchant"],
		"nom_classe": "Essai_conversion", "type_competence": "offensif", "facteur_degats": 1.0})


func _initialize() -> void:
	seed(7)
	var p := Formules.PREFIXE_CONVERSION
	# 6d2 + force 4 (2d2) = 8 dés
	for cas in [[0.25, 2.0 / 8], [0.5, 4.0 / 8], [0.75, 6.0 / 8], [1.0, 1.0]]:
		var l := _lanceur({"force": 4, p + "tranchant__feu": cas[0]})
		var c := Formules.conversions(l, _competence(6), "tranchant")
		verifier(c.size() == 1 and c[0][0] == "feu" and is_equal_approx(c[0][1], cas[1]),
			"8 dés à %s : %s" % [cas[0], c])
	# petits nombres : 3d2 à 25 % = 1 dé sur 3 (au moins 1 dé)
	var petit := Formules.conversions(_lanceur({p + "tranchant__froid": 0.25}), _competence(3), "tranchant")
	verifier(petit.size() == 1 and is_equal_approx(petit[0][1], 1.0 / 3), "3d2 à 25 %% : %s" % [petit])
	# brut : 25 % au plus, même demandé à 100 %, et sans arrondi aux dés
	var brut := Formules.conversions(_lanceur({p + "tranchant__brut": 1.0}), _competence(3), "tranchant")
	verifier(brut.size() == 1 and is_equal_approx(brut[0][1], 0.25), "brut plafonné : %s" % [brut])
	verifier(Formules.conversions(_lanceur({p + "brut__feu": 1.0}), _competence(3), "brut").is_empty(),
		"le brut ne se convertit pas")
	# estimation : 100 % tranchant -> feu ne laisse que du feu, du même montant avant défenses
	var cible := _lanceur({})
	var sans := Formules.estimer_degats(_lanceur({"force": 4}), _competence(6), cible, false)
	var avec := Formules.estimer_degats(_lanceur({"force": 4, p + "tranchant__feu": 1.0}), _competence(6), cible, false)
	verifier(sans.size() == 1 and sans[0][0] == "tranchant", "sans conversion : %s" % [sans])
	verifier(avec.size() == 1 and avec[0][0] == "feu" and is_equal_approx(avec[0][1], sans[0][1]),
		"100 %% en feu : %s / %s" % [avec, sans])
	var moitie := Formules.estimer_degats(_lanceur({"force": 4, p + "tranchant__feu": 0.5}), _competence(6), cible, false)
	verifier(moitie.size() == 2 and is_equal_approx(moitie[0][1] + moitie[1][1], sans[0][1]), "50 %% : %s" % [moitie])
	# description
	verifier(Formules.texte_conversion(p + "tranchant__feu", 0.5) == "50 % des dégâts tranchants deviennent des dégâts de feu",
		Formules.texte_conversion(p + "tranchant__feu", 0.5))
	# génération : 3000 objets, tous avec un effet unique
	var conversions := 0
	var arrivees := {}
	for i in 3000:
		var o = GenerationObjets.generer_objet(null, null, null, null, 1.0)
		for a in o.attributs():
			verifier(not String(a).begins_with("talent_ajout__"), "ancien ajout encore généré : %s" % a)
		var u := String(U.ga(o, "unique", ""))
		if not u.begins_with(p):
			continue
		conversions += 1
		var m := u.substr(p.length()).split("__")
		arrivees[m[1]] = arrivees.get(m[1], 0) + 1
		verifier(m[0] != "brut" and m[0] != m[1], "conversion %s" % u)
		verifier(Degats.groupe(m[0]) == String(o.orientation), "%s sur un objet %s" % [u, o.orientation])
		if o is Arme and o.orientation == "physique":
			verifier(m[0] == Formules.DES_ARMES[o.type_arme], "%s sur %s" % [u, o.nom])
		var part := float(U.ga(o, u, 0))
		verifier(part in ([0.25] if m[1] == "brut" else GenerationObjets.PARTS_CONVERSION), "part %s de %s" % [part, u])
		verifier(o.nom.ends_with(GenerationObjets.SUFFIXES_CONVERSION[m[1]]), "nom %s" % o.nom)
		verifier(DescriptionObjet.effet_unique(o).contains("deviennent des dégâts"), DescriptionObjet.effet_unique(o))
	print("Conversions : %d sur 3000 objets ; arrivées : %s" % [conversions, arrivees])
	verifier(conversions > 200, "trop peu de conversions : %d" % conversions)
	verifier(arrivees.size() == 10, "types d'arrivée : %s" % [arrivees.keys()])
	print("test_conversion_degats : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
