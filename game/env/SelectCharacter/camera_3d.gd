extends Camera3D

var pos_iniziale: Vector3
var rot_iniziale: Vector3

# Prende il riferimento al rettangolo bianco
@onready var schermo_bianco = $"../UI_Selezione/SchermoBianco"

func _ready():
	# 1. Salva la posizione e rotazione perfette che hai messo nell'editor
	pos_iniziale = global_position
	rot_iniziale = global_rotation
	
	# 2. Modifica la rotazione iniziale: guarda 40 gradi più in alto
	rotation_degrees.x += 40.0
	
	# 3. Crea l'animazione fluida (Tween)
	var tween = create_tween()
	tween.set_parallel(true) # Esegue le animazioni contemporaneamente
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Ruota la telecamera verso il basso fino alla posizione originale (in 2 secondi)
	tween.tween_property(self, "global_rotation", rot_iniziale, 2.2)
	
	# Fa svanire il rettangolo bianco da alfa 1.0 a 0.0 (in 1.5 secondi)
	if schermo_bianco:
		
		tween.tween_property(schermo_bianco, "modulate:a", 0.0, 2.0)
		# Alla fine, lo nasconde del tutto per non bloccare i click
		tween.chain().tween_callback(schermo_bianco.hide)

# Funzione per zommare sul personaggio (la useremo al click)
func vai_a_personaggio(target_pos: Vector3, target_rot: Vector3):
	var tween = create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, 0.8)
	tween.tween_property(self, "global_rotation", target_rot, 0.8)

# Funzione per tornare alla vista globale
func torna_indietro():
	var tween = create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", pos_iniziale, 0.8)
	tween.tween_property(self, "global_rotation", rot_iniziale, 0.8)
