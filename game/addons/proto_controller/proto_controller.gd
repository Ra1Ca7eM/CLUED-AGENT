extends CharacterBody3D

@export var can_move : bool = true
@export var has_gravity : bool = true
@export var can_jump : bool = true
@export var can_sprint : bool = true

@export_group("Speeds")
@export var look_speed : float = 0.002
@export var base_speed : float = 4.8
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 8.0

@export_group("Input Actions")
@export var input_left : String = "move_left"
@export var input_right : String = "move_right"
@export var input_forward : String = "move_forward"
@export var input_back : String = "move_back"
@export var input_jump : String = "jump"
@export var input_sprint : String = "sprint"
@export var selected_character_id: String = ""

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
## Ispezione / UI: blocca WASD, salto, scatto e look; E / Esc restano gestiti dal runtime su Main.
var _inspection_mode: bool = false
var _uv_mode: bool = false
var _saved_spring_length: float = -1.0
var _spring_arm: SpringArm3D = null
var _spring_tween: Tween = null

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var visual_model: Node3D = $Rogue_Hooded
var anim_tree: AnimationTree = null
var state_machine = null

func _ready() -> void:
	CollisionLayers.configure_player_body(self)
	add_to_group("player")
	setup_selected_character()
	check_input_mappings()
	# Salita scale: snap al pavimento tra i gradini (senza dover saltare).
	floor_snap_length = 0.58
	floor_max_angle = deg_to_rad(66.0)
	floor_constant_speed = true
	wall_min_slide_angle = deg_to_rad(28.0)
	max_slides = 6
	# Impostiamo la rotazione iniziale leggendola dal nodo Head
	look_rotation.y = head.rotation.y
	look_rotation.x = head.rotation.x

func setup_selected_character() -> void:
	var character_id := selected_character_id
	if character_id.is_empty():
		character_id = GameState.selected_character_id
	
	var scene_path: String = GameState.get_character_scene_path(character_id)
	if scene_path.is_empty():
		scene_path = GameState.get_character_scene_path("rogue_hooded")
	
	var default_transform := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if visual_model:
		default_transform = visual_model.transform
		visual_model.queue_free()
	
	var character_scene: PackedScene = load(scene_path) as PackedScene
	if character_scene == null:
		push_error("Impossibile caricare il personaggio: " + scene_path)
		return
	
	visual_model = character_scene.instantiate() as Node3D
	visual_model.transform = default_transform
	add_child(visual_model)
	
	anim_tree = visual_model.get_node_or_null("AnimationTree")
	if anim_tree:
		state_machine = anim_tree.get("parameters/StateMachine/playback")

func _unhandled_input(event: InputEvent) -> void:
	if _inspection_mode:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

func _physics_process(delta: float) -> void:
	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	if can_jump and Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity

	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		
		# Calcola la direzione basandosi sull'orientamento Y della telecamera (Head)
		var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, head.rotation.y).normalized()
		
		if direction:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			
			# Ruota fluidamente il modello del personaggio verso la direzione di movimento
			var target_rotation = atan2(velocity.x, velocity.z)
			if visual_model:
				visual_model.rotation.y = lerp_angle(visual_model.rotation.y, target_rotation, delta * 12.0)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	
	# Gestione Animazioni
	if state_machine == null:
		return
	
	if is_on_floor():
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		if horizontal_velocity.length() > 0.1:
			# Se ci muoviamo, controlliamo se il tasto scatto è premuto
			if Input.is_action_pressed(input_sprint):
				state_machine.travel("Run") 
			else:
				state_machine.travel("Walk")
		else:
			state_machine.travel("Idle")
	else:
		state_machine.travel("Jump")

func rotate_look(rot_input : Vector2):
	look_rotation.y -= rot_input.x * look_speed
	look_rotation.x -= rot_input.y * look_speed
	# Limita la rotazione verticale per non capovolgere la telecamera
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-80), deg_to_rad(60))

	# Applica la rotazione SOLO al nodo Head, slegandola dal corpo del giocatore
	head.rotation.y = look_rotation.y
	head.rotation.x = look_rotation.x

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func set_inspection_mode(active: bool) -> void:
	_inspection_mode = active
	can_move = not active
	can_jump = not active
	can_sprint = not active
	if visual_model:
		visual_model.visible = not active
	if active:
		velocity.x = 0.0
		velocity.z = 0.0

## Modalità dialogo: blocca movimento/look come l'ispezione, ma mantiene
## visibile il modello del giocatore (inquadrato dalla camera del dialogo).
func set_dialogue_mode(active: bool) -> void:
	_inspection_mode = active
	can_move = not active
	can_jump = not active
	can_sprint = not active
	if active:
		velocity.x = 0.0
		velocity.z = 0.0
		release_mouse()

func set_uv_mode(active: bool) -> void:
	if _uv_mode == active:
		return
	_uv_mode = active
	can_move = not active
	can_jump = not active
	can_sprint = not active
	if active:
		velocity.x = 0.0
		velocity.z = 0.0
	if _spring_arm == null:
		_spring_arm = head.get_node_or_null("SpringArm3D") as SpringArm3D
		if _spring_arm and _saved_spring_length < 0.0:
			_saved_spring_length = _spring_arm.spring_length
	if _spring_arm:
		if _spring_tween and _spring_tween.is_valid():
			_spring_tween.kill()
		_spring_tween = create_tween()
		var target := 0.0 if active else _saved_spring_length
		_spring_tween.tween_property(_spring_arm, "spring_length", target, 0.15)
	if visual_model:
		visual_model.visible = not active

func check_input_mappings():
	var required_actions = [input_left, input_right, input_forward, input_back, input_jump, input_sprint]
	for action in required_actions:
		if not InputMap.has_action(action):
			push_error("Missing InputAction: " + action)
