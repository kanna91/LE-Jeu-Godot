class_name U
extends RefCounted
## Petits équivalents des fonctions Python utilisées par le jeu d'origine
## (getattr, random.choices, round, format « g », str.capitalize...).


## ``getattr(o, nom, defaut)`` : ``defaut`` si ``o`` est nul ou n'a pas l'attribut.
static func ga(o, nom: String, defaut = 0):
	if o == null:
		return defaut
	if o is Dyn:
		return o.lire(nom, defaut)
	if o is Dictionary:
		return o.get(nom, defaut)
	if not (o is Object):
		return defaut  # getattr(0, "talents", []) : un nombre n'a pas d'attribut
	var v = o.get(nom)
	return defaut if v == null else v


## ``getattr(o, nom, 0) or 0`` : valeur numérique, 0 si absente ou nulle.
static func num(o, nom: String) -> float:
	var v = ga(o, nom, 0)
	if v == null or v is bool and not v:
		return 0.0
	if v is bool:
		return 1.0
	return float(v)


## ``hasattr(o, nom)``.
static func ha(o, nom: String) -> bool:
	if o == null:
		return false
	if o is Dyn:
		return o.possede(nom)
	if o is Dictionary:
		return o.has(nom)
	return nom in o


## ``bool(valeur)`` de Python (0, chaîne vide, liste vide, None : faux).
static func vrai(v) -> bool:
	if v == null:
		return false
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return v != ""
		TYPE_ARRAY, TYPE_DICTIONARY:
			return not v.is_empty()
	return true


## ``random.choices(elements, weights=poids)[0]``.
static func choix_pondere(elements: Array, poids: Array):
	var total := 0.0
	for p in poids:
		total += float(p)
	var r := randf() * total
	var cumul := 0.0
	for i in elements.size():
		cumul += float(poids[i])
		if r < cumul:
			return elements[i]
	return elements[elements.size() - 1]


## ``random.sample(population, k)``.
static func echantillon(population: Array, k: int) -> Array:
	var copie := population.duplicate()
	copie.shuffle()
	return copie.slice(0, k)


## ``round(x, n)`` (arrondi au plus proche, sans l'arrondi « bancaire » de Python).
static func arrondi(x: float, n: int = 0) -> float:
	var f := pow(10.0, n)
	return round(x * f) / f


## Format ``f"{x:g}"`` de Python (6 chiffres significatifs, sans zéros inutiles).
static func g(x) -> String:
	var v := float(x)
	if is_nan(v):
		return "nan"
	if v == 0.0:
		return "0"
	var exposant := int(floor(log(absf(v)) / log(10.0)))
	if exposant < -5 or exposant >= 6:
		var mantisse := v / pow(10.0, exposant)
		var m := U.g(snappedf(mantisse, 0.00001))
		return "%se%s%02d" % [m, "-" if exposant < 0 else "+", absi(exposant)]
	var decimales := maxi(0, 5 - exposant)
	var texte := ("%." + str(decimales) + "f") % v
	if "." in texte:
		texte = texte.rstrip("0").rstrip(".")
	if texte == "-0":
		texte = "0"
	return texte


## Format ``f"{x:.nf}"``.
static func f(x, n: int = 0) -> String:
	return ("%." + str(n) + "f") % float(x)


## ``str.capitalize()`` de Python : première lettre en majuscule, le reste en minuscules.
static func majuscule(texte: String) -> String:
	if texte.is_empty():
		return texte
	return texte.substr(0, 1).to_upper() + texte.substr(1).to_lower()


## Élément d'une liste dont la clé est la plus petite (``min(liste, key=...)``), le premier à égalité.
static func min_par(liste: Array, cle: Callable):
	var meilleur = null
	var valeur_min = null
	for e in liste:
		var v = cle.call(e)
		if valeur_min == null or v < valeur_min:
			meilleur = e
			valeur_min = v
	return meilleur


## Copie triée par clé (tri stable, comme ``sorted(liste, key=...)``).
static func trie_par(liste: Array, cle: Callable, inverse := false) -> Array:
	var avec_cles := []
	for i in liste.size():
		avec_cles.append([cle.call(liste[i]), i, liste[i]])
	avec_cles.sort_custom(func(a, b):
		if a[0] == b[0]:
			return a[1] < b[1]
		return (a[0] > b[0]) if inverse else (a[0] < b[0]))
	var resultat := []
	for t in avec_cles:
		resultat.append(t[2])
	return resultat


## Somme d'une liste de nombres.
static func somme(liste: Array) -> float:
	var total := 0.0
	for v in liste:
		total += float(v)
	return total


## Nombre entier avec séparateur de milliers (``f"{n:,}".replace(",", " ")``).
static func milliers(n) -> String:
	var entier := int(round(float(n)))
	var signe := "-" if entier < 0 else ""
	var chiffres := str(absi(entier))
	var resultat := ""
	while chiffres.length() > 3:
		resultat = " " + chiffres.substr(chiffres.length() - 3) + resultat
		chiffres = chiffres.substr(0, chiffres.length() - 3)
	return signe + chiffres + resultat


## Dictionnaire lu dans un fichier JSON de ``res://donnees``.
static func charger_json(nom: String):
	var fichier := FileAccess.open("res://donnees/" + nom, FileAccess.READ)
	if fichier == null:
		push_error("Fichier de données introuvable : " + nom)
		return null
	return JSON.parse_string(fichier.get_as_text())


## Convertit les nombres entiers d'une valeur JSON (lus en flottants) en entiers, récursivement.
static func entiers(valeur):
	if valeur is float and valeur == floor(valeur) and absf(valeur) < 1e15:
		return int(valeur)
	if valeur is Array:
		var liste := []
		for v in valeur:
			liste.append(entiers(v))
		return liste
	if valeur is Dictionary:
		var dico := {}
		for k in valeur:
			dico[k] = entiers(valeur[k])
		return dico
	return valeur
