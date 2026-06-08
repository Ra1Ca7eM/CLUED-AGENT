extends Camera3D

@export var target_casa: Marker3D
@export var target_porta: Marker3D

@export_category("Parametri Infinito")
@export var velocita_movimento: float = 0.07
@export var ampiezza_x: float = 13.0 # Quanto si allarga a destra e sinistra
@export var ampiezza_y: float = 2.0  # Quanto va avanti e indietro
@export var schermo_bianco: ColorRect

var tempo: float = 0.0
var centro_orbita: Vector3
var nel_menu: bool = true

func _ready():
	# Salviamo la posizione di partenza della camera come centro del percorso a infinito
	centro_orbita = global_position

func _process(delta):
	# Esegue il movimento solo finché siamo nel menù
	if nel_menu and target_casa:
		tempo += delta * velocita_movimento
		
		# Matematica dell'infinito (Curva di Lissajous)
		# Il seno del tempo moltiplicato per 2 sull'asse Z crea l'incrocio a forma di 8
		var offset_x = sin(tempo) * ampiezza_x
		var offset_y = sin(tempo * 2.0) * ampiezza_y
		
		# Aggiorniamo la posizione mantenendo l'altezza del centro_orbita
		global_position = centro_orbita + Vector3(offset_x, offset_y, 0)
		
		# Costringiamo la camera a guardare sempre la casa
		look_at(target_casa.global_position)

# Questa funzione verrà chiamata quando premi "Start Game"
func esegui_zoom_start():
	if not schermo_bianco:
		print("ERRORE: SchermoBianco non assegnato nell'Inspector!")
		return
	nel_menu = false # Blocca il movimento a infinito
	schermo_bianco.show()
	schermo_bianco.modulate.a = 0.0
	var tween = create_tween()
	# Imposta le animazioni in parallelo (posizione e FOV cambieranno insieme)
	tween.set_parallel(true) 
	# Curva di accelerazione: parte lento, va veloce, frena alla fine
	tween.set_trans(Tween.TRANS_CUBIC) 
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 1. Sposta la camera sul Marker della porta in 1.5 secondi
	tween.tween_property(self, "global_position", target_porta.global_position, 1.5)
	
	# 2. Stringe il FOV (effetto zoom drammatico) in 1.5 secondi
	tween.tween_property(self, "fov", 30.0, 1.5)
	
	# 3. Costringe la rotazione a guardare la porta in modo preciso (evita scatti strani)
	# Utilizza un trucco: guarda dalla posizione finale al target stesso
	var transform_finale = transform.looking_at(target_porta.global_position + Vector3(0,0,-1))
	tween.tween_property(self, "global_transform:basis", transform_finale.basis, 1.5)
	tween.tween_property(schermo_bianco, "modulate:a", 1.0, 1.5)
	# 4. Quando finisce lo zoom, cambia scena
	tween.set_parallel(false)
	tween.tween_callback(cambia_scena)

func cambia_scena():
	# Inserisci qui il percorso della tua scena di selezione personaggio
	get_tree().change_scene_to_file("res://env/SelectCharacter/SelectCharacter.tscn")
