extends Node3D

@onready var telecamera = $Camera3D
@onready var btn_indietro = $UI_Selezione/BtnIndietro
@onready var immagine_dati = $UI_Selezione/ImmagineDati
@onready var btn_gioca = $UI_Selezione/BtnGioca
# NUOVO: Riferimento all'immagine del titolo
@onready var immagine_titolo = $UI_Selezione/ImmagineTitolo
@onready var schermo_bianco = $UI_Selezione/SchermoBianco

@export var tempo_comparsa: float = 0.3 
var nodo_personaggio_attuale: Area3D = null
var sta_cambiando_scena: bool = false

func _ready():
	btn_indietro.pressed.connect(_on_btn_indietro_pressed)
	btn_gioca.pressed.connect(_on_btn_gioca_pressed)
	# Assicuriamoci che il titolo sia visibile e le altre cose no
	immagine_titolo.show()
	immagine_dati.hide()
	btn_indietro.hide()
	btn_gioca.hide()

func aggiorna_selezione_grafica(nuova_texture: Texture2D, nodo_eroe: Area3D):
	nodo_personaggio_attuale = nodo_eroe
	
	# 1. Prepariamo l'immagine dei dati (quella che deve apparire)
	immagine_dati.texture = nuova_texture
	immagine_dati.modulate.a = 0.0
	immagine_dati.show()
	
	btn_indietro.show()
	btn_gioca.show()
	btn_indietro.modulate.a = 0.0
	btn_gioca.modulate.a = 0.0
	
	# 2. Creiamo l'animazione di scambio (Cross-fade)
	var tween = create_tween()
	tween.set_parallel(true) # Facciamo tutto insieme
	# Aggiungili al tween esistente
	tween.tween_property(btn_indietro, "modulate:a", 1.0, tempo_comparsa)
	tween.tween_property(btn_gioca, "modulate:a", 1.0, tempo_comparsa)
	# Il titolo scompare
	tween.tween_property(immagine_titolo, "modulate:a", 0.0, tempo_comparsa)
	# L'immagine dati compare
	tween.tween_property(immagine_dati, "modulate:a", 1.0, tempo_comparsa)
	
	# Alla fine nascondiamo il titolo per pulizia
	tween.chain().tween_callback(immagine_titolo.hide)

func _on_btn_indietro_pressed():
	telecamera.torna_indietro()
	
	if nodo_personaggio_attuale:
		nodo_personaggio_attuale.torna_a_riposo()
		nodo_personaggio_attuale = null
	
	# 3. Animazione per tornare indietro
	immagine_titolo.show() # Lo mostriamo prima di dargli opacità
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Il titolo ricompare
	tween.tween_property(immagine_titolo, "modulate:a", 1.0, tempo_comparsa)
	# L'immagine dati sparisce
	tween.tween_property(immagine_dati, "modulate:a", 0.0, tempo_comparsa)
	
	# Aggiungili al tween esistente
	tween.tween_property(btn_indietro, "modulate:a", 0.0, tempo_comparsa)
	tween.tween_property(btn_gioca, "modulate:a", 0.0, tempo_comparsa)
	# Nascondiamo i bottoni e l'immagine dati alla fine
	tween.chain().tween_callback(immagine_dati.hide)
	tween.chain().tween_callback(btn_gioca.hide)
	tween.chain().tween_callback(btn_indietro.hide)

func _on_btn_gioca_pressed() -> void:
	if nodo_personaggio_attuale == null or sta_cambiando_scena:
		return
	sta_cambiando_scena = true
	btn_gioca.disabled = true
	btn_indietro.disabled = true
	GameState.select_character(str(nodo_personaggio_attuale.get("character_id")))
	
	# Transizione cinematica coerente con il resto del flusso.
	schermo_bianco.color = Color(0, 0, 0, 1)
	schermo_bianco.show()
	schermo_bianco.modulate.a = 0.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(schermo_bianco, "modulate:a", 1.0, 1.0)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://env/cutscenes/cutscene_murder_salon.tscn")
	)
