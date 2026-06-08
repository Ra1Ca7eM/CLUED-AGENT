extends Node
class_name DoorController

signal toggled(controller: Node, is_open: bool)
signal opened(controller: Node)

const AUTO_CLOSE_DELAY := 10.0

var display_name: String = "porta"
var open_angle_deg: float = 180.0
var animation_duration: float = 0.55

## Nodo Node3D ruotabile (door_B o doorway(Clone)/door).
var panel: Node3D = null
## StaticBody3D da marcare per il raycast.
var collider_bodies: Array = []
## Corpi collisori che ruotano col pannello (sottoinsieme di collider_bodies discendente di panel):
## la loro collisione viene disattivata durante l'animazione per non spingere gli NPC nel muro.
var _moving_bodies: Array = []
var _saved_layers: Dictionary = {}

var is_open: bool = false
var _animating: bool = false
var _closed_rotation_y: float = 0.0
var _emit_opened_on_done: bool = false
var _interactor: Node3D = null
var _auto_close_timer: SceneTreeTimer = null
var _panel_tween: Tween = null


func is_animating() -> bool:
	return _animating


func get_interactor() -> Node3D:
	return _interactor


func set_interactor(body: Node3D) -> void:
	_interactor = body


func clear_interactor() -> void:
	_interactor = null


func setup(panel_node: Node3D, bodies: Array, name_label: String) -> void:
	panel = panel_node
	collider_bodies = bodies
	display_name = name_label
	if panel != null:
		_closed_rotation_y = panel.rotation.y
	_moving_bodies.clear()
	for body in collider_bodies:
		if body != null:
			body.set_meta("door_controller", self)
			# Un corpo "mobile" e' quello che ruota col pannello (gli sta sotto nell'albero).
			if panel != null and panel.is_ancestor_of(body):
				_moving_bodies.append(body)


func toggle(player_world_pos: Vector3, interactor: Node3D = null) -> void:
	if _animating or panel == null:
		return
	_interactor = interactor
	_cancel_auto_close()
	_animating = true
	var target_y: float
	if is_open:
		target_y = _closed_rotation_y
	else:
		target_y = _closed_rotation_y + _pick_open_sign(player_world_pos) * deg_to_rad(open_angle_deg)
	is_open = not is_open
	_start_panel_tween(target_y)
	emit_signal("toggled", self, is_open)


func open_for_agent(agent: Node3D) -> void:
	if panel == null or agent == null:
		return
	_interactor = agent
	_cancel_auto_close()
	# Gia' aperta e ferma: nessuna animazione, riprogramma solo l'auto-close.
	if is_open and not _animating:
		_schedule_auto_close()
		return
	# Chiusa o IN CHIUSURA (auto-close in corso): uccidi il tween e (ri)apri subito.
	# Senza questo, una riapertura durante la chiusura lasciava la porta in stallo.
	_kill_panel_tween()
	_animating = true
	_emit_opened_on_done = true
	is_open = true
	var target_y := _closed_rotation_y + _pick_open_sign(agent.global_position) * deg_to_rad(open_angle_deg)
	_start_panel_tween(target_y)


func _start_panel_tween(target_y: float) -> void:
	_kill_panel_tween()
	# Durante la rotazione il pannello non deve spingere gli NPC fermi davanti.
	_disable_moving_collision()
	_panel_tween = panel.create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_panel_tween.set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(panel, "rotation:y", target_y, animation_duration)
	_panel_tween.tween_callback(_on_tween_done)


func _kill_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = null


func _on_tween_done() -> void:
	_panel_tween = null
	_animating = false
	_restore_moving_collision()
	if _emit_opened_on_done:
		_emit_opened_on_done = false
		emit_signal("opened", self)
	if is_open:
		_schedule_auto_close()


func _schedule_auto_close() -> void:
	_cancel_auto_close()
	if not is_open:
		return
	_auto_close_timer = get_tree().create_timer(AUTO_CLOSE_DELAY)
	_auto_close_timer.timeout.connect(_on_auto_close_timeout)


func _cancel_auto_close() -> void:
	if _auto_close_timer != null and is_instance_valid(_auto_close_timer):
		if _auto_close_timer.timeout.is_connected(_on_auto_close_timeout):
			_auto_close_timer.timeout.disconnect(_on_auto_close_timeout)
	_auto_close_timer = null


func _on_auto_close_timeout() -> void:
	_auto_close_timer = null
	if is_open and not _animating:
		force_close(false)


## Chiude senza emettere toggled (es. dopo teleport portale).
func force_close(instant: bool = false) -> void:
	if panel == null or not is_open:
		return
	_cancel_auto_close()
	_kill_panel_tween()
	_emit_opened_on_done = false
	is_open = false
	_animating = false
	if instant:
		panel.rotation.y = _closed_rotation_y
		_restore_moving_collision()
		return
	_animating = true
	_start_panel_tween(_closed_rotation_y)


## Restituisce +1 o -1 per il verso di apertura.
## La porta si apre dal lato opposto al giocatore rispetto all'asse Z locale del pannello.
func _pick_open_sign(player_world_pos: Vector3) -> float:
	if panel == null:
		return 1.0
	var door_pos: Vector3 = panel.global_position
	var to_player: Vector3 = (player_world_pos - door_pos).normalized()
	var door_forward: Vector3 = -panel.global_transform.basis.z
	var dot: float = to_player.dot(door_forward)
	# Il giocatore e' "davanti" alla porta (dot > 0): apriamo dall'altro lato (segno -).
	# Se e' dietro (dot <= 0): apriamo verso il lato opposto a lui (segno +).
	return -1.0 if dot > 0.0 else 1.0


## Disattiva la collisione dei corpi mobili (pannello) durante l'animazione,
## salvando i layer originali per il ripristino.
func _disable_moving_collision() -> void:
	for body in _moving_bodies:
		if body == null or not is_instance_valid(body):
			continue
		if not _saved_layers.has(body):
			_saved_layers[body] = body.collision_layer
		body.collision_layer = 0


## Ripristina la collisione dei corpi mobili al termine dell'animazione.
func _restore_moving_collision() -> void:
	for body in _moving_bodies:
		if body == null or not is_instance_valid(body):
			continue
		if _saved_layers.has(body):
			body.collision_layer = _saved_layers[body]
	_saved_layers.clear()
