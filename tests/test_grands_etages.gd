extends SceneTree
## Grands étages (GenerateurEtage, 2026-10-27) : sur ETAGES_TESTES étages générés, vérifie la taille (environ
## 50 salles), qu'on peut aller partout depuis le départ, le boss au bout de la voie principale, les
## carrefours (salles à 3 ou 4 passages), les boucles (grands cercles : deux salles voisines reliées alors que le
## chemin entre elles faisait au moins GenerateurEtage.BOUCLE_MIN salles) et les salles bonus.
## Affiche aussi un étage dessiné en texte. « BILAN grands étages : 0 échec(s) ».
## Lancer : Godot --headless --path . -s tests/test_grands_etages.gd

const ETAGES_TESTES := 200

var echecs := 0


func verifier(condition: bool, texte: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC : " + texte)


func _initialize() -> void:
	var tailles := []
	var carrefours := []
	var boucles := []
	var bonus := []
	for n in ETAGES_TESTES:
		var etage := 1 + n % 10
		var plan := GenerateurEtage.generer_plan(etage)
		tailles.append(plan.size())
		# Tout est relié au départ
		var vues := {1: true}
		var file := [1]
		while not file.is_empty():
			var c: int = file.pop_front()
			for v in plan[c]["connexions"]:
				if not vues.has(v):
					vues[v] = true
					file.append(v)
		verifier(vues.size() == plan.size(), "étage %d : %d salles inaccessibles" % [etage, plan.size() - vues.size()])
		var aretes := 0
		var c3 := 0
		var b := 0
		var positions := {}
		for i in plan:
			aretes += plan[i]["connexions"].size()
			if plan[i]["connexions"].size() >= 3:
				c3 += 1
			if plan[i]["role"] == "bonus":
				b += 1
			verifier(not positions.has(plan[i]["position"]), "deux salles sur la même case")
			positions[plan[i]["position"]] = true
			for v in plan[i]["connexions"]:
				var d: Vector2i = plan[v]["position"] - plan[i]["position"]
				verifier(absi(d.x) + absi(d.y) == 1, "passage entre deux salles non voisines")
		aretes /= 2
		carrefours.append(c3)
		boucles.append(aretes - plan.size() + 1)  # nombre de cercles indépendants
		bonus.append(b)
		var boss_n := 0
		for i in plan:
			if plan[i]["role"] == "boss":
				boss_n += 1
		verifier(boss_n == 1, "un seul boss par étage")
		if n == 0:
			dessiner(plan)
	var moy := func(l: Array) -> float:
		var s := 0.0
		for x in l:
			s += x
		return s / l.size()
	print("Salles par étage : moyenne %.1f (de %d à %d)" % [moy.call(tailles), tailles.min(), tailles.max()])
	print("Carrefours (3-4 passages) : moyenne %.1f (de %d à %d)" % [moy.call(carrefours), carrefours.min(), carrefours.max()])
	print("Boucles : moyenne %.1f (de %d à %d)" % [moy.call(boucles), boucles.min(), boucles.max()])
	print("Salles bonus : moyenne %.1f" % moy.call(bonus))
	# Depuis le 2026-11-03, les chemins d'accès aux prisons des coins s'ajoutent (≈ 9 salles en moyenne)
	# Depuis le 2026-11-04, les salles des blocs « en_plus » (la bibliothèque, 14) s'ajoutent aussi
	var en_plus := 0
	for nom in BlocsSalles.BLOCS:
		if BlocsSalles.BLOCS[nom].get("en_plus", false):
			en_plus += BlocsSalles.BLOCS[nom]["salles"].size()
	var visee := GenerateurEtage.TAILLE_ETAGE + en_plus
	# + 30 : chemins des prisons (≈ 9), salles d'entrée des blocs et couloirs qui les raccordent à l'étage (≈ 15 avec
	# la bibliothèque et le laboratoire, 2026-11-04)
	verifier(moy.call(tailles) >= visee - 5 and moy.call(tailles) <= visee + 30,
		"environ %d salles par étage, plus les chemins d'accès aux prisons" % visee)
	verifier(tailles.min() >= 40, "aucun étage trop petit (%d)" % tailles.min())
	verifier(moy.call(carrefours) >= 8, "des carrefours dans chaque étage")
	verifier(moy.call(boucles) >= 3.5, "des boucles dans chaque étage")
	print("BILAN grands étages : %d échec(s)" % echecs)
	quit()


## Dessine le plan en texte : D départ, G boss, + bonus, o salle ; - et | les passages.
func dessiner(plan: Dictionary) -> void:
	var par_case := {}
	var x0 := 1000
	var x1 := -1000
	var y1 := 0
	for i in plan:
		var p: Vector2i = plan[i]["position"]
		par_case[p] = i
		x0 = mini(x0, p.x)
		x1 = maxi(x1, p.x)
		y1 = maxi(y1, p.y)
	for y in range(y1, -1, -1):
		var ligne := ""
		var dessous := ""
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if par_case.has(c):
				var s: Dictionary = plan[par_case[c]]
				ligne += {"depart": "D", "boss": "G", "bonus": "+"}.get(s["role"], "o")
				var droite = par_case.get(c + Vector2i(1, 0))
				ligne += "-" if droite != null and s["connexions"].has(droite) else " "
				var bas = par_case.get(c + Vector2i(0, -1))
				dessous += "| " if bas != null and s["connexions"].has(bas) else "  "
			else:
				ligne += "  "
				dessous += "  "
		print(ligne)
		print(dessous)
