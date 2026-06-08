extends Area3D

# --- VARIABILI DEL PERSONAGGIO ---
@export var immagine_pannello: Texture2D
@export var character_id: String = ""

# --- VARIABILI PER L'OUTLINE & ANIMAZIONE ---
@export var radice_personaggio: Node3D 

# Prepara un riferimento all'AnimationPlayer (lo troveremo nell'editor)
@export var anim_tree: AnimationTree

var materiale_outline = preload("Materials/materiale_outline.tres") # Verifica percorso
var lista_mesh: Array[MeshInstance3D] = []
var selezionato: bool = false
var mouse_sopra: bool = false

func _ready():
	if character_id.is_empty() and get_parent():
		character_id = get_parent().name.to_lower()
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	
	if radice_personaggio:
		cerca_mesh_ricorsivamente(radice_personaggio)

func cerca_mesh_ricorsivamente(nodo: Node):
	if nodo is MeshInstance3D:
		lista_mesh.append(nodo)
	for figlio in nodo.get_children():
		cerca_mesh_ricorsivamente(figlio)

func _on_mouse_enter():
	mouse_sopra = true
	if not selezionato:
		for mesh in lista_mesh:
			mesh.material_overlay = materiale_outline

func _on_mouse_exit():
	mouse_sopra = false
	for mesh in lista_mesh:
		mesh.material_overlay = null

func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# --- NASCONDIAMO LA OUTLINE QUANDO SELEZIONATO ---
		selezionato = true
		for mesh in lista_mesh:
			mesh.material_overlay = null
		
		# --- RIPRODUZIONE ANIMAZIONE TRAMITE STATE MACHINE ---
		if anim_tree:
			var state_machine = anim_tree.get("parameters/StateMachine/playback")
			state_machine.travel("Jump_Idle")
		
		# --- LOGICA ZOOM E UI ---
		var target = get_node("CameraTarget")
		var telecamera_principale = get_viewport().get_camera_3d()
		
		if telecamera_principale.has_method("vai_a_personaggio"):
			telecamera_principale.vai_a_personaggio(target.global_position, target.global_rotation)
		
		get_tree().call_group("UI_Manager", "aggiorna_selezione_grafica", immagine_pannello, self)


func torna_a_riposo():
	selezionato = false
	if anim_tree:
		var state_machine = anim_tree.get("parameters/StateMachine/playback")
		state_machine.travel("Idle")
	
	if mouse_sopra:
		for mesh in lista_mesh:
			mesh.material_overlay = materiale_outline
