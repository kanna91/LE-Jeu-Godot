extends Node
## Musique de fond jouée en boucle pendant tout le jeu (autoload « Musique »).
## Pour changer de morceau : remplacer FICHIER, ou appeler Musique.jouer("res://...").
## Volume réglable dans le menu Options (0 à 100 %), enregistré dans user://options.cfg.

const FICHIER := "res://audio/musique/elf_song_tavern.mp3"
## Volume à 100 % (dB) ; le réglage du joueur s'applique par-dessus.
const VOLUME_DB := -8.0
const OPTIONS := "user://options.cfg"
const VOLUME_DEFAUT := 1.0  # = le volume d'avant le menu

var lecteur: AudioStreamPlayer
## Volume choisi par le joueur, de 0 (muet) à 1.
var volume := VOLUME_DEFAUT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continue même si le jeu est en pause
	lecteur = AudioStreamPlayer.new()
	add_child(lecteur)
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS) == OK:
		volume = clampf(float(cfg.get_value("audio", "musique", VOLUME_DEFAUT)), 0.0, 1.0)
	_appliquer()
	jouer(FICHIER)


func _appliquer() -> void:
	lecteur.volume_db = VOLUME_DB + linear_to_db(volume) if volume > 0.001 else -80.0


## Règle le volume (0 à 1) et l'enregistre.
func regler_volume(valeur: float) -> void:
	volume = clampf(valeur, 0.0, 1.0)
	_appliquer()
	var cfg := ConfigFile.new()
	cfg.load(OPTIONS)
	cfg.set_value("audio", "musique", volume)
	cfg.save(OPTIONS)


func jouer(chemin: String) -> void:
	var flux = load(chemin)
	if flux == null:
		push_warning("Musique introuvable : " + chemin)
		return
	if "loop" in flux:
		flux.loop = true  # MP3 / OGG : reboucle sans coupure
	lecteur.stream = flux
	lecteur.play()


func arreter() -> void:
	lecteur.stop()
