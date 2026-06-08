extends CanvasLayer

## Pannello chat verticale (scena `ui/dialogue/dialogue_chat_ui.tscn`).

const BUBBLE_SCENE := preload("res://ui/dialogue/chat_message_bubble.tscn")
const NPC_FALLBACK_REPLIES := {
	"barbarian": "Non ho toccato niente. Ero vicino al camino quando ho sentito urlare.",
	"knight": "La vittima aveva molti nemici, ma qualcuno qui dentro sta mentendo sull'orario.",
	"mage": "Ci sono tracce di magia residua vicino al tavolo. Non significa che sia stata opera mia.",
	"ranger": "Ho visto una figura incappucciata attraversare il salone poco prima del delitto.",
	"rogue": "Io apro serrature, non gole. Chiedi a chi aveva davvero un movente.",
	"rogue_hooded": "Sono arrivato tardi. Quando sono entrato, la vittima era gia a terra.",
}
const REPLY_MIN_DELAY := 0.8
const REPLY_MAX_DELAY := 1.2
const TYPING_SCENE := preload("res://ui/dialogue/typing_indicator_bubble.tscn")

## Bridge HTTP verso ChatBDI (MAS in game/chatBDI/interpreter). Solo per i role_key elencati;
## gli altri NPC restano sulle risposte statiche di NPC_FALLBACK_REPLIES.
const BRIDGE_URL := "http://127.0.0.1:8090/dialogue"
const BRIDGE_ROLE_KEYS := { "alberto": true, "evelina": true, "clarissa": true, "vittorio": true }
## Alto di proposito: su PC lenti le 3 passate LLM possono richiedere minuti.
## Tenuto maggiore del timeout lato Java (600s) cosi' e' il server a rispondere per primo.
const BRIDGE_TIMEOUT := 660.0

const SLIDE_DURATION := 0.45
const SLIDE_OFFSET := 460.0

signal close_requested

@onready var _panel: Panel = %ChatPanel
@onready var _header_label: Label = %HeaderLabel
@onready var _scroll: ScrollContainer = %MessageScroll
@onready var _messages_vbox: VBoxContainer = %MessagesVBox
@onready var _input_line: LineEdit = %MessageInput
@onready var _send_button: Button = %SendButton
@onready var _input_row: HBoxContainer = %MessageInput.get_parent()

var _typing_node: Control = null
var _npc_id: String = ""
var _role_key: String = ""
var _is_open: bool = false
var _readonly: bool = false
var _slide_tween: Tween = null
var _waiting: bool = false
var _typing_status_timer: float = 0.0
var _typing_status_shown: bool = false
var _header_base_name: String = ""


func _ready() -> void:
	layer = 8
	_panel.visible = false
	_panel.modulate.a = 1.0
	_reset_panel_offscreen()


func is_open() -> bool:
	return _is_open


func is_readonly() -> bool:
	return _readonly


func open(npc_id: String, npc_name: String, intro_text: String = "", role_key: String = "") -> void:
	if _is_open:
		_force_hide_panel()

	_npc_id = npc_id
	_role_key = role_key if role_key != "" else npc_id
	_readonly = false
	_is_open = true
	_waiting = false
	_header_label.text = npc_name

	GameState.ensure_npc_dialogue_session(_role_key, npc_name, npc_id)
	var history := GameState.get_dialogue_messages(_role_key)
	if history.is_empty() and intro_text.strip_edges() != "":
		GameState.append_dialogue_message(_role_key, intro_text, false)

	_set_input_visible(true)
	_rebuild_bubbles_from_history(_role_key)

	_reset_panel_offscreen()
	_panel.visible = true
	_input_line.editable = true
	_input_line.text = ""
	_input_line.grab_focus()
	_slide_to(0.0, true)


func open_readonly(role_key: String) -> void:
	if role_key.is_empty() or not GameState.has_met_npc(role_key):
		return
	if _is_open:
		_force_hide_panel()

	var session: Dictionary = GameState.npc_dialogue_histories.get(role_key, {})
	_role_key = role_key
	_npc_id = str(session.get("model_id", role_key))
	_readonly = true
	_is_open = true
	_waiting = false
	_header_label.text = str(session.get("display_name", role_key))

	_set_input_visible(false)
	_rebuild_bubbles_from_history(role_key)

	layer = 12
	_reset_panel_offscreen()
	_panel.visible = true
	_slide_to(0.0, true)


func close() -> void:
	if not _is_open:
		_force_hide_panel()
		return
	var was_readonly := _readonly
	_is_open = false
	_waiting = false
	_readonly = false
	_input_line.release_focus()
	_hide_typing()
	_slide_to(SLIDE_OFFSET, false)
	if was_readonly:
		layer = 8


func _force_hide_panel() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
		_slide_tween = null
	_is_open = false
	_waiting = false
	_readonly = false
	_panel.visible = false
	_panel.modulate.a = 1.0
	_reset_panel_offscreen()
	layer = 8


func _reset_panel_offscreen() -> void:
	_panel.offset_left = SLIDE_OFFSET
	_panel.offset_right = SLIDE_OFFSET


func _set_input_visible(visible: bool) -> void:
	if _input_row:
		_input_row.visible = visible


func _rebuild_bubbles_from_history(role_key: String) -> void:
	_clear_messages()
	for msg in GameState.get_dialogue_messages(role_key):
		if msg is Dictionary:
			_add_bubble(str(msg.get("text", "")), bool(msg.get("from_player", false)))


func _slide_to(target_offset: float, opening: bool) -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_panel, "offset_left", target_offset, SLIDE_DURATION)
	_slide_tween.tween_property(_panel, "offset_right", target_offset, SLIDE_DURATION)
	if not opening:
		_slide_tween.finished.connect(func() -> void:
			_panel.visible = false
			_reset_panel_offscreen()
		, CONNECT_ONE_SHOT)


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_send_pressed() -> void:
	_submit(_input_line.text)


func _on_text_submitted(text: String) -> void:
	_submit(text)


func _submit(text: String) -> void:
	if _readonly or _waiting:
		return
	var msg := text.strip_edges()
	if msg == "":
		return
	_add_bubble(msg, true)
	GameState.append_dialogue_message(_role_key, msg, true)
	_input_line.text = ""
	_input_line.grab_focus()
	_show_typing()
	_waiting = true
	_request_npc_reply(msg)


func _request_npc_reply(player_text: String) -> void:
	# NPC collegati a ChatBDI: instrada al bridge (= "@role_key" automatico).
	if BRIDGE_ROLE_KEYS.has(_role_key):
		_request_bridge_reply(player_text)
		return
	# Altri NPC: comportamento statico legacy.
	await get_tree().create_timer(randf_range(REPLY_MIN_DELAY, REPLY_MAX_DELAY)).timeout
	if not _is_open or _readonly:
		return
	var reply := str(NPC_FALLBACK_REPLIES.get(_npc_id, "Non ho altro da aggiungere per ora."))
	_deliver_npc_reply(reply)


## Nome NPC da mostrare nei messaggi d'errore (fallback su un'etichetta neutra).
func _npc_label() -> String:
	var label := _header_label.text.strip_edges()
	return label if label != "" else "Il personaggio"


func _request_bridge_reply(player_text: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = BRIDGE_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			_on_bridge_reply(result, code, body)
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := JSON.stringify({ "role_key": _role_key, "player_text": player_text })
	var err := http.request(BRIDGE_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_deliver_error("(%s non risponde — MAS non raggiungibile.)" % _npc_label())


func _on_bridge_reply(result: int, code: int, body: PackedByteArray) -> void:
	if not _is_open or _readonly:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_deliver_error("(%s non risponde — verifica che il MAS sia avviato.)" % _npc_label())
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		_deliver_error("(%s non risponde — verifica che il MAS sia avviato.)" % _npc_label())
		return
	var reply := str(parsed.get("reply_nl", "")).strip_edges()
	if reply == "":
		_deliver_error("(%s non ha risposto nulla.)" % _npc_label())
		return
	_deliver_npc_reply(reply)


func _deliver_npc_reply(reply: String) -> void:
	_hide_typing()
	_add_bubble(reply, false)
	GameState.append_dialogue_message(_role_key, reply, false)
	_waiting = false


## Mostra un messaggio d'errore in chat (NON salvato nello storico/Taccuino) e sblocca l'input.
func _deliver_error(text: String) -> void:
	_hide_typing()
	_add_bubble(text, false)
	_waiting = false


func _add_bubble(text: String, is_player: bool) -> void:
	var bubble: PanelContainer = BUBBLE_SCENE.instantiate() as PanelContainer
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_vbox.add_child(bubble)
	bubble.call("setup", text, is_player)
	_scroll_to_bottom()


func _show_typing() -> void:
	if _typing_node != null:
		return
	_typing_node = TYPING_SCENE.instantiate() as Control
	_messages_vbox.add_child(_typing_node)
	_scroll_to_bottom()


func _hide_typing() -> void:
	if _typing_node != null:
		_typing_node.queue_free()
		_typing_node = null


func _clear_messages() -> void:
	_hide_typing()
	for child in _messages_vbox.get_children():
		child.queue_free()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var sb := _scroll.get_v_scroll_bar()
	if sb:
		_scroll.scroll_vertical = int(sb.max_value)
