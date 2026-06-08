extends Node3D

@export var cutscene_duration: float = 8.5
const MAIN_SCENE := preload("res://Main.tscn")

const _CAMERA_WALL_MARGIN := 0.32
const _DURATION_FADE_IN := 1.2
const _DURATION_ORBIT := 2.1
const _DURATION_KILLER_PASS := 0.28
const _KILLER_PASS_HALF_WIDTH := 2.75
const _DEATH_POSE_BLEND_SEC := 0.42
const _DURATION_TIGHTEN := 1.45
const _DURATION_FADE_OUT := 1.0

@onready var camera: Camera3D = $Camera3D
@onready var salon_set: Node3D = $SalonSet
@onready var actors_root: Node3D = $Actors
@onready var victim: Node3D = $Actors/Victim
@onready var killer_shadow: Node3D = $Actors/KillerShadow
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var subtitle: RichTextLabel = $UI/Subtitles
@onready var victim_transform_reference: Transform3D = $Actors/Victim.transform

var victim_animation_player: AnimationPlayer = null
var victim_animation_tree: AnimationTree = null

var cutscene_finished: bool = false
var look_target: Vector3 = Vector3.ZERO

var _killer_pos_a: Vector3 = Vector3.ZERO
var _killer_pos_b: Vector3 = Vector3.ZERO


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _run_setup_and_play()


func _run_setup_and_play() -> void:
	await _prepare_scene()
	_play_cutscene()


func _prepare_scene() -> void:
	_load_static_salon_set()
	await get_tree().process_frame
	_configure_victim()
	await get_tree().process_frame
	fade_rect.show()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 1.0
	subtitle.visible = false
	killer_shadow.visible = false
	look_target = victim.global_position + Vector3(0.0, 1.35, 0.0)
	_place_camera_initial_orbit()
	camera.look_at(look_target)
	if victim_animation_tree:
		victim_animation_tree.active = false
	if victim_animation_player:
		victim_animation_player.play("Player/Idle_A")


func _load_static_salon_set() -> void:
	if salon_set == null:
		return
	var main_instance := MAIN_SCENE.instantiate() as Node3D
	if main_instance == null:
		return
	main_instance.name = "MainCutsceneSet"
	var main_script: Variant = main_instance.get_script()
	if main_script != null:
		main_instance.set_script(null)
	var proto_controller := main_instance.get_node_or_null("ProtoController")
	if proto_controller:
		proto_controller.queue_free()
	var npc_root := main_instance.get_node_or_null("NPC")
	if npc_root:
		npc_root.queue_free()
	var tutorial_overlay := main_instance.get_node_or_null("TutorialOverlay")
	if tutorial_overlay:
		tutorial_overlay.queue_free()

	var house := main_instance.get_node_or_null("House") as Node3D
	var salon_in_main: Node3D = null
	if house:
		salon_in_main = house.get_node_or_null("Salon") as Node3D
	if salon_in_main == null:
		salon_in_main = main_instance.get_node_or_null("Salon") as Node3D
	if salon_in_main == null:
		push_error("Cutscene: Salon non trovato sotto House/Salon.")
		salon_set.add_child(main_instance)
		return

	var salon_script: Variant = salon_in_main.get_script()
	if salon_script != null:
		salon_in_main.set_script(null)
	for node_name in ["Player", "UI", "NPCs", "Inspectables", "InspectionView"]:
		var n := salon_in_main.get_node_or_null(node_name)
		if n:
			n.queue_free()

	salon_set.add_child(main_instance)

	if actors_root and salon_in_main:
		actors_root.reparent(salon_in_main)
		actors_root.transform = Transform3D.IDENTITY


func _configure_victim() -> void:
	if actors_root == null or victim == null:
		return
	var victim_id := _pick_victim_id()
	var scene_path := GameState.get_character_scene_path(victim_id)
	var victim_scene := load(scene_path) as PackedScene
	if victim_scene == null:
		return
	var new_victim := victim_scene.instantiate() as Node3D
	if new_victim == null:
		return
	new_victim.name = "Victim"
	new_victim.transform = victim_transform_reference
	actors_root.add_child(new_victim)
	victim.queue_free()
	victim = new_victim
	victim_animation_player = victim.get_node_or_null("AnimationPlayer") as AnimationPlayer
	victim_animation_tree = victim.get_node_or_null("AnimationTree") as AnimationTree


func _pick_victim_id() -> String:
	return GameState.get_victim_character_id()


func _unhandled_input(event: InputEvent) -> void:
	if cutscene_finished:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_end_cutscene()


func _play_cutscene() -> void:
	var sequence := create_tween()
	sequence.set_trans(Tween.TRANS_CUBIC)
	sequence.set_ease(Tween.EASE_IN_OUT)

	var pre_hold := _DURATION_FADE_IN + _DURATION_ORBIT + _DURATION_KILLER_PASS + _DURATION_TIGHTEN

	sequence.tween_property(fade_rect, "modulate:a", 0.0, _DURATION_FADE_IN)
	sequence.tween_callback(func() -> void:
		subtitle.visible = true
		subtitle.text = "[center]Pochi secondi prima dell'arrivo dell'investigatore...[/center]"
	)

	sequence.tween_method(_move_camera_looking_target, 0.0, 1.0, _DURATION_ORBIT)
	sequence.tween_callback(func() -> void:
		subtitle.text = "[center]Un'ombra attraversa il salone...[/center]"
	)

	sequence.tween_callback(func() -> void:
		_setup_killer_pass_in_front()
		killer_shadow.visible = true
		killer_shadow.global_position = _killer_pos_a
	)
	sequence.tween_method(_tween_killer_pass, 0.0, 1.0, _DURATION_KILLER_PASS)
	sequence.tween_callback(func() -> void:
		killer_shadow.visible = false
	)

	sequence.tween_callback(func() -> void:
		subtitle.text = "[center]Nessuno ha visto il volto.\nNessuno ha visto l'arma.[/center]"
		_play_victim_death()
	)
	sequence.tween_method(_tighten_camera_on_victim, 0.0, 1.0, _DURATION_TIGHTEN)

	sequence.tween_callback(func() -> void:
		subtitle.text = "[center]Ora restano solo indizi e menzogne.[/center]"
	)
	sequence.tween_interval(max(0.0, cutscene_duration - pre_hold))
	sequence.tween_property(fade_rect, "modulate:a", 1.0, _DURATION_FADE_OUT)
	sequence.tween_callback(_end_cutscene)


func _place_camera_initial_orbit() -> void:
	if victim == null:
		return
	var pivot := look_target
	var wanted := _orbit_camera_position(pivot, 0.0)
	camera.global_position = _resolve_camera_global(pivot, wanted)


func _orbit_camera_position(pivot: Vector3, weight: float) -> Vector3:
	var back := victim.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3(0, 0, 1)
	back = back.normalized()
	var radius := lerpf(5.0, 3.65, weight)
	var yaw := lerpf(-0.48, 0.78, weight)
	var height := lerpf(2.12, 1.82, weight)
	var offset := back.rotated(Vector3.UP, yaw) * radius
	return pivot + offset + Vector3(0.0, height, 0.0)


func _tighten_orbit_position(pivot: Vector3, weight: float) -> Vector3:
	var back := victim.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3(0, 0, 1)
	back = back.normalized()
	var radius := lerpf(3.35, 1.55, weight)
	var yaw := lerpf(0.18, 0.52, weight)
	var height := lerpf(1.72, 1.05, weight)
	var offset := back.rotated(Vector3.UP, yaw) * radius
	return pivot + offset + Vector3(0.0, height, 0.0)


func _move_camera_looking_target(weight: float) -> void:
	if victim == null:
		return
	var pivot := look_target
	var wanted := _orbit_camera_position(pivot, weight)
	camera.global_position = _resolve_camera_global(pivot, wanted)
	camera.look_at(pivot)


func _tighten_camera_on_victim(weight: float) -> void:
	if victim == null:
		return
	var pivot := look_target + Vector3(0.05, -0.12, 0.0)
	var wanted := _tighten_orbit_position(pivot, weight)
	camera.global_position = _resolve_camera_global(look_target, wanted)
	camera.look_at(pivot)


func _resolve_camera_global(pivot: Vector3, wanted: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return wanted
	var from := pivot + Vector3(0.0, 0.22, 0.0)
	var dir_full := wanted - from
	var dist := dir_full.length()
	if dist < 0.02:
		return wanted
	var dir := dir_full / dist
	var ray := PhysicsRayQueryParameters3D.create(from, wanted)
	ray.collide_with_areas = false
	if victim:
		ray.exclude = _collision_rids_under(victim)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return wanted
	var hit_pos: Vector3 = hit.position
	var along: float = (hit_pos - from).dot(dir)
	var capped: float = minf(dist, along - _CAMERA_WALL_MARGIN)
	return from + dir * maxf(capped, 0.42)


func _collision_rids_under(root: Node) -> Array[RID]:
	var out: Array[RID] = []
	_collect_collision_rids(root, out)
	return out


func _collect_collision_rids(n: Node, out: Array[RID]) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_collision_rids(c, out)


func _setup_killer_pass_in_front() -> void:
	if victim == null:
		return
	var cam_pos := camera.global_position
	var mid := look_target + (cam_pos - look_target).normalized() * 0.38
	mid.y = victim.global_position.y
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	_killer_pos_a = mid + right * _KILLER_PASS_HALF_WIDTH
	_killer_pos_b = mid - right * _KILLER_PASS_HALF_WIDTH
	_killer_pos_a.y = victim.global_position.y
	_killer_pos_b.y = victim.global_position.y


func _tween_killer_pass(t: float) -> void:
	killer_shadow.global_position = _killer_pos_a.lerp(_killer_pos_b, t)


func _play_victim_death() -> void:
	if victim_animation_player == null:
		return
	if victim_animation_tree:
		victim_animation_tree.active = false
	victim_animation_player.play("Player/Death_B")
	await get_tree().process_frame
	await get_tree().process_frame
	var anim_len: float = victim_animation_player.get_current_animation_length()
	if anim_len <= 0.05:
		anim_len = 2.85
		push_warning("Cutscene: lunghezza Death_B non disponibile, uso fallback %.2fs" % anim_len)
	var wait_sec: float = maxf(anim_len - _DEATH_POSE_BLEND_SEC - 0.05, 0.15)
	await get_tree().create_timer(wait_sec).timeout
	victim_animation_player.play("Player/Death_B_Pose", _DEATH_POSE_BLEND_SEC)


func _end_cutscene() -> void:
	if cutscene_finished:
		return
	cutscene_finished = true
	get_tree().change_scene_to_file("res://Main.tscn")
