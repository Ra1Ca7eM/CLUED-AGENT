extends Node

signal map_context_changed
signal dialogue_history_changed

var selected_character_id: String = "rogue_hooded"
var selected_character_name: String = "Rogue Hooded"

var notebook_entries: Array[Dictionary] = []
var current_room: String = "Salone"
var current_map_key: String = "salon"
var current_map_floor: int = 1
## Coordinate pianta 500×365; (-1,-1) = fuori da una MapZone.
var player_map_position: Vector2 = Vector2(-1.0, -1.0)
## True mentre la camera di ispezione overhead è attiva (torcia mondo disattivata).
var inspection_active: bool = false
## id -> { id, name, floor, position, inspected, normal_desc, uv_desc, image_path, uv_image_path,
##         requires_inspection_uv_reveal, uv_detail_revealed }
var map_clues: Dictionary = {}

func add_notebook_entry(type: String, entry_name: String, text: String) -> void:
	for e in notebook_entries:
		if e.get("type") == type and e.get("name") == entry_name and e.get("text") == text:
			return
	notebook_entries.append({"type": type, "name": entry_name, "text": text})

func clear_notebook() -> void:
	notebook_entries.clear()


func set_map_context(map_key: String, floor_idx: int, display_name: String) -> void:
	var changed := map_key != current_map_key or floor_idx != current_map_floor or display_name != current_room
	current_map_key = map_key
	current_map_floor = floor_idx
	current_room = display_name
	if changed:
		map_context_changed.emit()


func clear_map_context() -> void:
	var had_context := current_map_key != ""
	current_map_key = ""
	current_room = ""
	if player_map_position.x >= 0.0:
		player_map_position = Vector2(-1.0, -1.0)
		map_context_changed.emit()
	elif had_context:
		map_context_changed.emit()


func set_player_map_position(design_pos: Vector2) -> void:
	if design_pos.is_equal_approx(player_map_position):
		return
	player_map_position = design_pos
	map_context_changed.emit()


func register_map_clue(clue_id: String, clue_name: String, floor_idx: int, design_pos: Vector2, metadata: Dictionary = {}) -> void:
	if clue_id == "":
		return
	var inspected := false
	var prev: Dictionary = {}
	if map_clues.has(clue_id):
		prev = map_clues[clue_id]
		inspected = prev.get("inspected", false)
	var normal_desc := str(metadata.get("normal_desc", prev.get("normal_desc", "")))
	var uv_desc := str(metadata.get("uv_desc", prev.get("uv_desc", "")))
	var image_path := str(metadata.get("image_path", prev.get("image_path", "")))
	var uv_image_path := str(metadata.get("uv_image_path", prev.get("uv_image_path", "")))
	var requires_reveal := bool(metadata.get("requires_inspection_uv_reveal", prev.get("requires_inspection_uv_reveal", false)))
	var uv_detail_revealed := bool(prev.get("uv_detail_revealed", false))
	if bool(metadata.get("uv_detail_revealed", false)):
		uv_detail_revealed = true
	if not requires_reveal:
		uv_detail_revealed = true
	map_clues[clue_id] = {
		"id": clue_id,
		"name": clue_name,
		"floor": floor_idx,
		"position": design_pos,
		"inspected": inspected,
		"normal_desc": normal_desc,
		"uv_desc": uv_desc,
		"image_path": image_path,
		"uv_image_path": uv_image_path,
		"requires_inspection_uv_reveal": requires_reveal,
		"uv_detail_revealed": uv_detail_revealed,
	}


func mark_clue_inspected(clue_id: String) -> void:
	if clue_id == "" or not map_clues.has(clue_id):
		return
	map_clues[clue_id]["inspected"] = true


func is_clue_inspected(clue_id: String) -> bool:
	if clue_id == "" or not map_clues.has(clue_id):
		return false
	return bool(map_clues[clue_id].get("inspected", false))


func update_clue_description(clue_id: String, new_description: String) -> void:
	if clue_id == "" or not map_clues.has(clue_id):
		return
	map_clues[clue_id]["normal_desc"] = new_description


func get_map_clue(clue_id: String) -> Dictionary:
	if map_clues.has(clue_id):
		return map_clues[clue_id]
	return {}


func mark_clue_uv_detail_revealed(clue_id: String) -> void:
	if clue_id == "" or not map_clues.has(clue_id):
		return
	map_clues[clue_id]["uv_detail_revealed"] = true


func can_show_clue_map_details(clue_id: String) -> bool:
	if clue_id == "" or not map_clues.has(clue_id):
		return false
	var clue: Dictionary = map_clues[clue_id]
	if not clue.get("requires_inspection_uv_reveal", false):
		return true
	return clue.get("uv_detail_revealed", false)


func get_map_clues_for_floor(floor_idx: int, only_discovered: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for clue in map_clues.values():
		if int(clue.get("floor", -1)) != floor_idx:
			continue
		if only_discovered and not clue.get("inspected", false):
			continue
		out.append(clue)
	return out


func get_map_inspected_counts(floor_idx: int = -1) -> Vector2i:
	var total := 0
	var done := 0
	for clue in map_clues.values():
		if floor_idx >= 0 and int(clue.get("floor", -1)) != floor_idx:
			continue
		total += 1
		if clue.get("inspected", false):
			done += 1
	return Vector2i(done, total)

const CHARACTER_SCENES := {
	"barbarian": "res://Assets/Scenes/barbarian.tscn",
	"knight": "res://Assets/Scenes/knight.tscn",
	"mage": "res://Assets/Scenes/mage.tscn",
	"ranger": "res://Assets/Scenes/ranger.tscn",
	"rogue": "res://Assets/Scenes/rogue.tscn",
	"rogue_hooded": "res://Assets/Scenes/rogue_hooded.tscn",
}

const CHARACTER_NAMES := {
	"barbarian": "Barbarian",
	"knight": "Knight",
	"mage": "Mage",
	"ranger": "Ranger",
	"rogue": "Rogue",
	"rogue_hooded": "Rogue Hooded",
}

enum NarrativeRole { AURELIO, EVELINA, CLARISSA, ALBERTO, VITTORIO }

const ROLE_KEYS := {
	NarrativeRole.AURELIO: "aurelio",
	NarrativeRole.EVELINA: "evelina",
	NarrativeRole.CLARISSA: "clarissa",
	NarrativeRole.ALBERTO: "alberto",
	NarrativeRole.VITTORIO: "vittorio",
}

const ROLE_DISPLAY_NAME := {
	NarrativeRole.AURELIO: "Aurelio Valtieri",
	NarrativeRole.EVELINA: "Evelina Valtieri",
	NarrativeRole.CLARISSA: "Clarissa Vance",
	NarrativeRole.ALBERTO: "Alberto Mori",
	NarrativeRole.VITTORIO: "Vittorio Serra",
}

const NPC_ROLES: Array[NarrativeRole] = [
	NarrativeRole.EVELINA,
	NarrativeRole.CLARISSA,
	NarrativeRole.ALBERTO,
	NarrativeRole.VITTORIO,
]

## Modello 3D per ruolo narrativo in base alla scelta del giocatore (storia.md).
const CAST_BY_PLAYER: Dictionary = {
	"rogue_hooded": {
		"aurelio": "barbarian", "evelina": "mage", "clarissa": "rogue",
		"alberto": "ranger", "vittorio": "knight",
	},
	"barbarian": {
		"aurelio": "ranger", "evelina": "mage", "clarissa": "rogue",
		"alberto": "rogue_hooded", "vittorio": "knight",
	},
	"mage": {
		"aurelio": "barbarian", "evelina": "rogue_hooded", "clarissa": "rogue",
		"alberto": "ranger", "vittorio": "knight",
	},
	"rogue": {
		"aurelio": "barbarian", "evelina": "mage", "clarissa": "rogue_hooded",
		"alberto": "ranger", "vittorio": "knight",
	},
	"ranger": {
		"aurelio": "barbarian", "evelina": "mage", "clarissa": "rogue",
		"alberto": "rogue_hooded", "vittorio": "knight",
	},
	"knight": {
		"aurelio": "barbarian", "evelina": "mage", "clarissa": "rogue",
		"alberto": "ranger", "vittorio": "rogue_hooded",
	},
}

func select_character(character_id: String) -> void:
	if not CHARACTER_SCENES.has(character_id):
		push_warning("Personaggio non riconosciuto: " + character_id)
		return
	selected_character_id = character_id
	selected_character_name = CHARACTER_NAMES.get(character_id, character_id.capitalize())

func get_character_scene_path(character_id: String) -> String:
	return CHARACTER_SCENES.get(character_id, "")

func get_character_name(character_id: String) -> String:
	return CHARACTER_NAMES.get(character_id, character_id.capitalize())

func get_player_visual_id() -> String:
	return selected_character_id

func get_role_display_name(role: NarrativeRole) -> String:
	return ROLE_DISPLAY_NAME.get(role, "")

func _get_cast_for_player(player_id: String) -> Dictionary:
	if CAST_BY_PLAYER.has(player_id):
		return CAST_BY_PLAYER[player_id]
	push_warning("Cast non definito per player: " + player_id + ", uso rogue_hooded.")
	return CAST_BY_PLAYER["rogue_hooded"]

func resolve_model_for_role(role: NarrativeRole, player_id: String = "") -> String:
	if player_id.is_empty():
		player_id = selected_character_id
	var cast: Dictionary = _get_cast_for_player(player_id)
	var key: String = ROLE_KEYS.get(role, "")
	return str(cast.get(key, "rogue_hooded"))

func get_victim_character_id() -> String:
	return resolve_model_for_role(NarrativeRole.AURELIO)

func get_npc_cast() -> Array[Dictionary]:
	var cast: Dictionary = _get_cast_for_player(selected_character_id)
	var out: Array[Dictionary] = []
	for role in NPC_ROLES:
		var role_key: String = ROLE_KEYS[role]
		out.append({
			"role": role,
			"role_key": role_key,
			"model_id": str(cast[role_key]),
			"display_name": ROLE_DISPLAY_NAME[role],
		})
	return out

const NPC_PROFILE_IMAGE_ROOT := "res://MODELLI3D/NPC_PROFILE/"

## role_key -> { display_name, model_id, messages: [{ from_player, text }] }
var npc_dialogue_histories: Dictionary = {}

func get_npc_profile_image_path(model_id: String) -> String:
	return NPC_PROFILE_IMAGE_ROOT + model_id + ".png"

func ensure_npc_dialogue_session(role_key: String, display_name: String, model_id: String) -> void:
	if role_key.is_empty():
		return
	if not npc_dialogue_histories.has(role_key):
		npc_dialogue_histories[role_key] = {
			"display_name": display_name,
			"model_id": model_id,
			"messages": [],
		}
		return
	var session: Dictionary = npc_dialogue_histories[role_key]
	if display_name != "":
		session["display_name"] = display_name
	if model_id != "" and str(session.get("model_id", "")).is_empty():
		session["model_id"] = model_id

func append_dialogue_message(role_key: String, text: String, from_player: bool) -> void:
	var trimmed := text.strip_edges()
	if role_key.is_empty() or trimmed.is_empty():
		return
	if not npc_dialogue_histories.has(role_key):
		return
	var messages: Array = npc_dialogue_histories[role_key]["messages"]
	messages.append({"from_player": from_player, "text": trimmed})
	dialogue_history_changed.emit()

func has_met_npc(role_key: String) -> bool:
	if role_key.is_empty() or not npc_dialogue_histories.has(role_key):
		return false
	var messages: Array = npc_dialogue_histories[role_key].get("messages", [])
	return messages.size() >= 1

func get_dialogue_messages(role_key: String) -> Array:
	if not npc_dialogue_histories.has(role_key):
		return []
	return npc_dialogue_histories[role_key].get("messages", []).duplicate(true)

func get_met_npcs_for_notebook() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for role_key in npc_dialogue_histories.keys():
		if not has_met_npc(role_key):
			continue
		var session: Dictionary = npc_dialogue_histories[role_key]
		out.append({
			"role_key": role_key,
			"display_name": str(session.get("display_name", role_key)),
			"model_id": str(session.get("model_id", "rogue_hooded")),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	return out
