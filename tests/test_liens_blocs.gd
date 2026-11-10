extends SceneTree
## Liens des blocs de salles (BlocsSalles.BLOCS) face aux portes actuelles des images (2026-11-10) : chaque lien et
## chaque entrée vise une porte qui existe, aucune porte ne sert deux fois, toutes les salles d'un bloc sont reliées.
## Une porte retouchée dans l'éditeur (ajoutée ou supprimée) décale les numéros des suivantes : ce test le signale.
## Il affiche aussi les liens qui ne vont pas gauche ↔ droite ou fond ↔ bas (permis, mais à connaître).
## godot --headless --path . -s tests/test_liens_blocs.gd

const PAIRES := [["gauche", "droite"], ["droite", "gauche"], ["devant", "bas"], ["bas", "devant"]]
var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	for nom in BlocsSalles.BLOCS:
		var b: Dictionary = BlocsSalles.BLOCS[nom]
		var portes := {}
		for cle in b["salles"]:
			var s: Dictionary = b["salles"][cle]
			portes[cle] = PlanSalles.directions(s["image"], bool(s.get("miroir", false)))
		var prises := {}
		var groupe := {}
		for cle in portes:
			groupe[cle] = cle
		var racine := func(c: String) -> String:
			while groupe[c] != c:
				c = groupe[c]
			return c
		var utiliser := func(cle: String, i: int, cas: String) -> String:
			verifier(i < portes[cle].size(), "%s : %s n'a pas de porte %d (%s)" % [nom, cle, i, cas])
			var k := "%s:%d" % [cle, i]
			verifier(not prises.has(k), "%s : porte %s utilisée deux fois" % [nom, k])
			prises[k] = true
			return portes[cle][i] if i < portes[cle].size() else "absente"
		for l in b["liens"]:
			var d0: String = utiliser.call(l[0], l[1], str(l))
			var d1: String = utiliser.call(l[2], l[3], str(l))
			if not ([d0, d1] in PAIRES):
				print("  %s : %s (%s) ↔ %s (%s)" % [nom, l[0], d0, l[2], d1])
			groupe[racine.call(l[0])] = racine.call(l[2])
		for e in b["entrees"]:
			utiliser.call(e[0], e[1], "entrée")
		var groupes := {}
		for cle in portes:
			groupes[racine.call(cle)] = true
		verifier(groupes.size() == 1, "%s : salles en %d morceaux non reliés" % [nom, groupes.size()])
	print("BILAN liens des blocs : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
