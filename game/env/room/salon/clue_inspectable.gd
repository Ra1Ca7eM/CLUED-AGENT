extends Area3D

## Segnale con un solo argomento: compatibile con `main_game_runtime._on_inspectable_interacted`.
signal interacted(clue: Area3D)
signal player_entered(clue: Area3D)
signal player_exited(clue: Area3D)

const DEFAULT_INSPECTION_CAM_DISTANCE := 0.85
const DEFAULT_INSPECTION_LIGHT_SPOT_ANGLE_DEG := 28.0
const DEFAULT_INSPECTION_LIGHT_ENERGY := 6.0
const UV_ENERGY_SCALE_IN_INSPECTION := 8.0 / 6.0

@export var display_name: String = ""
@export_multiline var description: String = ""

## UV flags — non influenzano nulla se lasciati a default (false / "").
@export var uv_reactive: bool = false
@export var uv_required_to_reveal: bool = false
@export_multiline var uv_description: String = ""
## Mesh nascoste fino a Inspection mode + torcia UV; poi visibili per sempre e uv_reactive anche in mondo FPS.
@export var uv_required_to_reveal_only_inspection_mode_meshes: Array[NodePath] = []
## Distanza camera ispezione dal focus (lungo la direzione di inquadratura).
@export var inspection_cam_distance: float = DEFAULT_INSPECTION_CAM_DISTANCE
## Pitch (X), yaw (Y), roll (Z) in gradi. (0,0,0) = inquadratura dall'alto come default storico.
@export var inspection_cam_rotation_degrees: Vector3 = Vector3.ZERO
@export var inspection_light_spot_angle_deg: float = DEFAULT_INSPECTION_LIGHT_SPOT_ANGLE_DEG
@export var inspection_light_energy: float = DEFAULT_INSPECTION_LIGHT_ENERGY
## Se true, applica il materiale sangue a tutte le MeshInstance3D figlie in _ready.
@export var apply_blood_material: bool = false
## Posizione sulla mappa del taccuino (coordinate canvas ~500x365).
@export var map_clue_id: String = ""
@export_enum("Primo Piano:0", "Piano Terra:1", "Cantina:2", "Giardino:3") var map_floor: int = 1
@export var map_position: Vector2 = Vector2.ZERO
## Se true, MapZoneManager ricalcola floor/position dalla posizione 3D nella MapZone.
@export var use_zone_map_position: bool = true

var _player_inside: bool = false
var _revealed: bool = true
var _under_uv: bool = false
var _inspection_only_under_uv: bool = false
var _inspection_only_meshes: Array[MeshInstance3D] = []
var _inspection_only_revealed: bool = false
# MeshInstance3D -> Material originale (null se nessun override)
var _saved_mat: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_ray_pickable = true
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1048575

	if uv_reactive:
		add_to_group("uv_reactive")

	_resolve_inspection_only_meshes()
	_hide_inspection_only_meshes()

	if apply_blood_material:
		_setup_blood_visual()

	if uv_required_to_reveal:
		_revealed = false
		_set_meshes_visible(false)
		monitoring = false

	if map_clue_id != "" and not use_zone_map_position:
		GameState.register_map_clue(map_clue_id, display_name, map_floor, map_position)

	call_deferred("_sync_initial_overlaps")

func setup(new_display_name: String, new_description: String) -> void:
	display_name = new_display_name
	description = new_description

func interact() -> void:
	if map_clue_id != "":
		GameState.mark_clue_inspected(map_clue_id)
	emit_signal("interacted", self)

func requires_inspection_uv_reveal() -> bool:
	return not uv_required_to_reveal_only_inspection_mode_meshes.is_empty()


func is_inspection_uv_detail_revealed() -> bool:
	return _inspection_only_revealed


## Torna la descrizione attiva in base allo stato UV corrente.
func get_active_description() -> String:
	if (_under_uv or _inspection_only_under_uv) and uv_description != "":
		return uv_description
	return description

func get_inspection_tuning() -> Dictionary:
	return {
		"cam_distance": inspection_cam_distance,
		"cam_rotation_degrees": inspection_cam_rotation_degrees,
		"light_spot_angle_deg": inspection_light_spot_angle_deg,
		"light_energy": inspection_light_energy,
		"uv_light_energy_scale": UV_ENERGY_SCALE_IN_INSPECTION,
	}

# ── UV API ──────────────────────────────────────────────────────────────────

func apply_uv_highlight(active: bool) -> void:
	if GameState.inspection_active and not _inspection_only_meshes.is_empty():
		if _inspection_only_under_uv == active:
			return
		_inspection_only_under_uv = active
		_set_emission_on_meshes(_inspection_only_meshes, active)
		return

	if _inspection_only_revealed and not _inspection_only_meshes.is_empty():
		if _inspection_only_under_uv == active:
			return
		_inspection_only_under_uv = active
		_set_emission_on_meshes(_inspection_only_meshes, active)
		return

	if not uv_reactive or _under_uv == active:
		return
	_under_uv = active
	var meshes := _find_mesh_instances(true)
	_set_emission_on_meshes(meshes, active)

func reveal_under_uv() -> void:
	if GameState.inspection_active:
		_reveal_inspection_only_meshes()
		return

	if _revealed:
		return
	_revealed = true
	_set_meshes_visible(true)
	monitoring = true
	call_deferred("_sync_initial_overlaps")

# ── Helpers ─────────────────────────────────────────────────────────────────

func _resolve_inspection_only_meshes() -> void:
	_inspection_only_meshes.clear()
	var seen: Dictionary = {}
	for path in uv_required_to_reveal_only_inspection_mode_meshes:
		if path.is_empty():
			continue
		var node: Node = get_node_or_null(path)
		if node == null:
			push_warning("%s: NodePath inspection-only non trovato: %s" % [name, path])
			continue
		var targets: Array[MeshInstance3D] = []
		if node is MeshInstance3D:
			targets.append(node as MeshInstance3D)
		else:
			targets.assign(_collect_mesh_instances_under(node))
		for mi in targets:
			if not seen.has(mi):
				seen[mi] = true
				_inspection_only_meshes.append(mi)

func _collect_mesh_instances_under(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			result.append(cur as MeshInstance3D)
		for ch in cur.get_children():
			stack.append(ch)
	return result

func _hide_inspection_only_meshes() -> void:
	for mi in _inspection_only_meshes:
		mi.visible = false

func _reveal_inspection_only_meshes() -> void:
	if _inspection_only_revealed:
		return
	_inspection_only_revealed = true
	for mi in _inspection_only_meshes:
		mi.visible = true
	if not is_in_group("uv_reactive"):
		add_to_group("uv_reactive")
	if map_clue_id != "":
		GameState.mark_clue_uv_detail_revealed(map_clue_id)

func _is_inspection_only_mesh(mi: MeshInstance3D) -> bool:
	return _inspection_only_meshes.has(mi)

func _find_mesh_instances(exclude_inspection_only: bool = false) -> Array:
	var result: Array = []
	var stack: Array = get_children()
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mesh_inst := cur as MeshInstance3D
			if exclude_inspection_only and _is_inspection_only_mesh(mesh_inst):
				continue
			result.append(mesh_inst)
		for ch in cur.get_children():
			stack.append(ch)
	return result

func _set_meshes_visible(v: bool) -> void:
	for mi in _find_mesh_instances(true):
		(mi as MeshInstance3D).visible = v

func _setup_blood_visual() -> void:
	var mat := _make_blood_material()
	for mi in _find_mesh_instances(true):
		var mesh_inst := mi as MeshInstance3D
		mesh_inst.material_override = mat

func _resolve_surface_material(mesh_inst: MeshInstance3D) -> StandardMaterial3D:
	if mesh_inst.material_override is StandardMaterial3D:
		return mesh_inst.material_override as StandardMaterial3D
	var active_mat := mesh_inst.get_active_material(0)
	if active_mat is StandardMaterial3D:
		return active_mat as StandardMaterial3D
	return null

func _make_blood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.04, 0.05, 0.92)
	mat.roughness = 0.18
	mat.metallic = 0.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _set_emission_on_meshes(meshes: Array, active: bool) -> void:
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if active:
			if not _saved_mat.has(mesh_inst):
				_saved_mat[mesh_inst] = mesh_inst.material_override
			var base := _resolve_surface_material(mesh_inst)
			var mat: StandardMaterial3D
			if base:
				mat = base.duplicate() as StandardMaterial3D
			else:
				mat = _make_blood_material()
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.95, 0.05)
			mat.emission_energy_multiplier = 3.5
			mesh_inst.material_override = mat
		else:
			if _saved_mat.has(mesh_inst):
				mesh_inst.material_override = _saved_mat[mesh_inst]
				_saved_mat.erase(mesh_inst)

func _sync_initial_overlaps() -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node) -> void:
	if not _is_player_body(body):
		return
	if _player_inside:
		return
	if not _revealed:
		return
	_player_inside = true
	emit_signal("player_entered", self)

func _on_body_exited(body: Node) -> void:
	if not _is_player_body(body):
		return
	_player_inside = false
	emit_signal("player_exited", self)

func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	var n: Node = body
	while n != null:
		if n.name == "Player" or n.name == "ProtoController":
			return true
		if n.is_in_group("player"):
			return true
		n = n.get_parent()
	return false
