extends RefCounted
class_name MapRoomCatalog

## Pianta 500×365 — allineata a HouseMapCanvas.MapFloor
enum MapFloor {
	FIRST = 0,
	GROUND = 1,
	BASEMENT = 2,
	GARDEN = 3,
}

const DESIGN_SIZE := Vector2(500.0, 365.0)

const FLOOR_FOLDER_GROUND := "PianoTerra"
const FLOOR_FOLDER_FIRST := "PrimoPiano"
const FLOOR_FOLDER_BASEMENT := "Cantina"
const FLOOR_FOLDER_GARDEN := "Giardino"

const FIRST_FLOOR_ROOMS: Array[Dictionary] = [
	{"name": "Stanza 1", "rect": Rect2(85, 15, 110, 100), "key": "room1"},
	{"name": "Stanza 3", "rect": Rect2(195, 15, 110, 100), "key": "room3"},
	{"name": "Stanza 5", "rect": Rect2(305, 15, 110, 100), "key": "room5"},
	{"name": "Corridoio", "rect": Rect2(85, 115, 330, 130), "key": "corridor"},
	{"name": "Stanza 2", "rect": Rect2(85, 245, 110, 100), "key": "room2"},
	{"name": "Stanza 4", "rect": Rect2(195, 245, 110, 100), "key": "room4"},
	{"name": "Stanza 6", "rect": Rect2(305, 245, 110, 100), "key": "room6"},
	{"name": "Scala Ovest", "rect": Rect2(10, 115, 75, 130), "key": "stairs_w"},
	{"name": "Scala Est", "rect": Rect2(415, 115, 75, 130), "key": "stairs_e"},
]

const GROUND_ROOMS: Array[Dictionary] = [
	{"name": "Cucina", "rect": Rect2(180, 20, 200, 110), "key": "kitchen"},
	{"name": "Salone", "rect": Rect2(120, 130, 260, 200), "key": "salon"},
	{"name": "Scala Ovest", "rect": Rect2(20, 130, 100, 100), "key": "stairs_ground_w"},
	{"name": "Scala Est", "rect": Rect2(380, 130, 100, 100), "key": "stairs_ground_r"},
	{"name": "Bagno", "rect": Rect2(20, 230, 100, 100), "key": "bagno"},
]

const BASEMENT_ROOMS: Array[Dictionary] = [
	{"name": "Scala Ovest", "rect": Rect2(80, 145, 100, 75), "key": "stairs_e"},
	{"name": "Cantina", "rect": Rect2(180, 40, 260, 285), "key": "basement_hall"},
]

const GARDEN_ROOMS: Array[Dictionary] = [
	## Footprint orizzontale sul tab (Z mondo → larghezza, X mondo → altezza; 27:14.65 ≈ 310:168).
	{"name": "Giardino", "rect": Rect2(95, 96, 310, 168), "key": "garden", "shape": "garden"},
]

const DISPLAY_NAMES: Dictionary = {
	"salon": "Salone",
	"kitchen": "Cucina",
	"bagno": "Bagno",
	"stairs_ground_w": "Scala Ovest",
	"stairs_ground_r": "Scala Est",
	"stairs_w": "Scala Ovest",
	"stairs_e": "Scala Est",
	"basement_hall": "Cantina",
	"corridor": "Corridoio",
	"room1": "Stanza 1",
	"room2": "Stanza 2",
	"room3": "Stanza 3",
	"room4": "Stanza 4",
	"room5": "Stanza 5",
	"room6": "Stanza 6",
	"garden": "Giardino",
}


static func get_rooms_for_floor(floor_idx: int) -> Array[Dictionary]:
	match floor_idx:
		MapFloor.FIRST:
			return FIRST_FLOOR_ROOMS
		MapFloor.GROUND:
			return GROUND_ROOMS
		MapFloor.BASEMENT:
			return BASEMENT_ROOMS
		MapFloor.GARDEN:
			return GARDEN_ROOMS
		_:
			return GROUND_ROOMS


static func get_room_rect(floor_idx: int, key: String) -> Rect2:
	for room in get_rooms_for_floor(floor_idx):
		if room.get("key", "") == key:
			return room["rect"] as Rect2
	return Rect2()


static func get_display_name(key: String) -> String:
	return str(DISPLAY_NAMES.get(key, key.capitalize()))


static func floor_idx_from_folder(folder_name: String) -> int:
	match folder_name:
		FLOOR_FOLDER_FIRST:
			return MapFloor.FIRST
		FLOOR_FOLDER_GROUND:
			return MapFloor.GROUND
		FLOOR_FOLDER_BASEMENT:
			return MapFloor.BASEMENT
		FLOOR_FOLDER_GARDEN:
			return MapFloor.GARDEN
		_:
			return MapFloor.GROUND


static func resolve_zone_suffix(suffix: String, floor_idx: int) -> String:
	match suffix:
		"corridoio":
			return "corridor"
		"bathroom":
			return "bagno"
		"scalaOvest":
			if floor_idx == MapFloor.GROUND:
				return "stairs_ground_w"
			if floor_idx == MapFloor.FIRST:
				return "stairs_w"
			return "stairs_e"
		"scalaEst":
			if floor_idx == MapFloor.GROUND:
				return "stairs_ground_r"
			return "stairs_e"
		"cantina":
			return "basement_hall"
		"giardino":
			return "garden"
		_:
			return suffix


static func parse_zone_node_name(node_name: String) -> String:
	const PREFIX := "MapZone_"
	if node_name.begins_with(PREFIX):
		return node_name.substr(PREFIX.length())
	return ""


## Inversione assi mondo (X/Z) → coordinate pianta; calibrata su MapZone in Main.tscn.
static func projection_invert_x(floor_idx: int) -> bool:
	match floor_idx:
		MapFloor.GROUND, MapFloor.FIRST:
			return true
		_:
			return false


static func projection_invert_z(floor_idx: int) -> bool:
	match floor_idx:
		MapFloor.FIRST:
			return true
		_:
			return false
