extends CanvasLayer

const NPC_PROFILE_CARD := preload("res://ui/notebook/npc_profile_card.tscn")

@onready var _panel: Panel = %NotebookPanel
@onready var _tab_container: TabContainer = %TabContainer
@onready var _dialogue_grid: GridContainer = %DialogueGrid
@onready var _dialogue_empty: Label = %DialogueEmptyLabel
@onready var _map_canvas: Control = %MapCanvas
@onready var _map_counter: Label = %MapCounter
@onready var _clue_popup: CluePopupPanel = %CluePopup

var _map_floor_buttons: Array[Button] = []
var _is_open: bool = false

func _ready() -> void:
	_map_floor_buttons = [%FloorBtn0, %FloorBtn1, %FloorBtn2, %FloorBtn3]
	for i in _map_floor_buttons.size():
		var floor_idx := i
		_map_floor_buttons[i].pressed.connect(func() -> void:
			_select_map_floor(floor_idx)
		)

	if _map_canvas.has_signal("clue_clicked"):
		_map_canvas.connect("clue_clicked", Callable(self, "_on_map_clue_clicked"))

	if _map_canvas.has_method("set_floor"):
		_map_canvas.call("set_floor", 1)

	_tab_container.current_tab = 0
	_panel.hide()

	if not GameState.map_context_changed.is_connected(_on_map_context_changed):
		GameState.map_context_changed.connect(_on_map_context_changed)
	if not GameState.dialogue_history_changed.is_connected(_on_dialogue_history_changed):
		GameState.dialogue_history_changed.connect(_on_dialogue_history_changed)

func _on_map_context_changed() -> void:
	if not _is_open:
		return
	if GameState.current_map_floor >= 0 and GameState.current_map_floor < _map_floor_buttons.size():
		_select_map_floor(GameState.current_map_floor)
	else:
		_refresh_map()

func _on_dialogue_history_changed() -> void:
	if _is_open:
		_refresh_entries()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_notebook"):
		get_viewport().set_input_as_handled()
		if _is_open:
			close()
		else:
			_open()
	elif event.is_action_pressed("ui_cancel") and _is_open:
		get_viewport().set_input_as_handled()
		var chat := _find_dialogue_chat_ui()
		if chat != null and chat.has_method("is_open") and chat.is_open():
			if chat.has_method("is_readonly") and chat.is_readonly():
				chat.close()
				return
		if _clue_popup != null and _clue_popup.visible:
			_hide_clue_popup()
		else:
			close()

func _open() -> void:
	for node in get_tree().get_nodes_in_group("overlay_ui"):
		if node != self and node.has_method("_is_currently_open") and node._is_currently_open():
			node.close()
	_refresh_entries()
	if GameState.current_map_floor >= 0 and GameState.current_map_floor < _map_floor_buttons.size():
		_select_map_floor(GameState.current_map_floor)
	else:
		_refresh_map()
	_panel.show()
	_is_open = true
	_freeze_player()

func close() -> void:
	if not _is_open:
		return
	var chat := _find_dialogue_chat_ui()
	if chat != null and chat.has_method("is_open") and chat.is_open() and chat.has_method("is_readonly") and chat.is_readonly():
		chat.close()
	_hide_clue_popup()
	_panel.hide()
	_is_open = false
	var other_open := false
	for node in get_tree().get_nodes_in_group("overlay_ui"):
		if node != self and node.has_method("_is_currently_open") and node._is_currently_open():
			other_open = true
			break
	if not other_open:
		_unfreeze_player()

func _is_currently_open() -> bool:
	return _is_open

func _refresh_entries() -> void:
	for child in _dialogue_grid.get_children():
		child.queue_free()

	var met: Array[Dictionary] = GameState.get_met_npcs_for_notebook()
	_dialogue_empty.visible = met.is_empty()

	for entry in met:
		var card := NPC_PROFILE_CARD.instantiate() as PanelContainer
		_dialogue_grid.add_child(card)
		card.setup(
			str(entry.get("role_key", "")),
			str(entry.get("display_name", "")),
			str(entry.get("model_id", ""))
		)
		card.pressed.connect(_on_profile_card_pressed)

func _on_profile_card_pressed(role_key: String) -> void:
	var chat := _find_dialogue_chat_ui()
	if chat == null:
		return
	chat.open_readonly(role_key)

func _find_dialogue_chat_ui() -> CanvasLayer:
	return get_tree().root.find_child("DialogueChatUI", true, false) as CanvasLayer

func _select_map_floor(floor_idx: int) -> void:
	for i in _map_floor_buttons.size():
		_map_floor_buttons[i].button_pressed = i == floor_idx
	if _map_canvas.has_method("set_floor"):
		_map_canvas.call("set_floor", floor_idx)
	_refresh_map()

func _refresh_map() -> void:
	var floor_idx := 1
	if _map_canvas and _map_canvas.has_method("get_current_floor"):
		floor_idx = int(_map_canvas.call("get_current_floor"))
	var counts := GameState.get_map_inspected_counts(floor_idx)
	_map_counter.text = "Trovati sulla mappa: %d / %d" % [counts.x, counts.y]
	if _map_canvas and _map_canvas.has_method("refresh"):
		_map_canvas.call("refresh")

func _freeze_player() -> void:
	var p := get_tree().root.find_child("ProtoController", true, false)
	if p == null:
		return
	p.set("can_move", false)
	p.set("can_jump", false)
	p.set("can_sprint", false)
	if p.has_method("release_mouse"):
		p.call("release_mouse")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unfreeze_player() -> void:
	var p := get_tree().root.find_child("ProtoController", true, false)
	if p == null:
		return
	p.set("can_move", true)
	p.set("can_jump", true)
	p.set("can_sprint", true)
	if p.has_method("capture_mouse"):
		p.call("capture_mouse")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_map_clue_clicked(clue_id: String) -> void:
	_clue_popup.show_clue(clue_id)

func _hide_clue_popup() -> void:
	if _clue_popup != null:
		_clue_popup.hide_popup()
