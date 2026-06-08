extends Control
class_name HouseMapCanvas

const CATALOG := preload("res://scripts/map/map_room_catalog.gd")
signal clue_clicked(clue_id: String)

## Indici piano (allineati ai tab in notebook_ui.gd)
enum MapFloor {
	FIRST = 0,
	GROUND = 1,
	BASEMENT = 2,
	GARDEN = 3,
}

const DESIGN_SIZE := CATALOG.DESIGN_SIZE
const DOT_RADIUS := 6.0
const PLAYER_DOT_RADIUS := 5.0
const HOVER_RADIUS := 14.0
const GARDEN_CORNER_CUT_RATIO_X := 0.10
const GARDEN_CORNER_CUT_RATIO_Y := 0.10

const COLOR_ROOM := Color(0.10, 0.13, 0.17, 1.0)
const COLOR_ROOM_CUR := Color(0.20, 0.30, 0.20, 1.0)
const COLOR_ROOM_BORDER := Color(0.57, 0.53, 0.44, 0.9)
const COLOR_TEXT := Color(0.92, 0.90, 0.84, 1.0)
const COLOR_ACCENT := Color(0.85, 0.75, 0.42, 1.0)
const COLOR_DOT := Color(0.85, 0.75, 0.42, 1.0)
const COLOR_PLAYER := Color(0.45, 0.85, 0.95, 1.0)
const COLOR_DOOR := Color(0.80, 0.78, 0.72, 0.95)
const TOOLTIP_TITLE_SIZE := 17
const TOOLTIP_HINT_SIZE := 12

## Porte: coordinate pianta 500×365 (centri lato stanza / scale da Main.tscn Door/).
const DOOR_GLYPHS: Dictionary = {
	MapFloor.FIRST: [
		{"pivot": Vector2(85, 180), "r": 12.0, "start": PI, "end": PI * 1.5},
		{"pivot": Vector2(415, 180), "r": 12.0, "start": PI * 1.5, "end": TAU},
		{"pivot": Vector2(140, 115), "r": 12.0, "start": PI * 0.5, "end": PI},
		{"pivot": Vector2(250, 115), "r": 12.0, "start": PI * 0.5, "end": PI},
		{"pivot": Vector2(360, 115), "r": 12.0, "start": PI * 0.5, "end": PI},
		{"pivot": Vector2(140, 245), "r": 12.0, "start": PI, "end": PI * 1.5},
		{"pivot": Vector2(250, 245), "r": 12.0, "start": PI, "end": PI * 1.5},
		{"pivot": Vector2(360, 245), "r": 12.0, "start": PI, "end": PI * 1.5},
	],
	MapFloor.GROUND: [
		{"pivot": Vector2(120, 180), "r": 12.0, "start": PI, "end": PI * 1.5},
		{"pivot": Vector2(380, 180), "r": 12.0, "start": PI * 1.5, "end": TAU},
		{"pivot": Vector2(355, 130), "r": 12.0, "start": PI, "end": PI * 1.5},
		{"pivot": Vector2(120, 230), "r": 12.0, "start": PI * 1.5, "end": TAU},
		{"pivot": Vector2(380, 75), "r": 12.0, "start": PI * 0.5, "end": PI},
	],
	MapFloor.BASEMENT: [
		{"pivot": Vector2(180, 182.5), "r": 12.0, "start": PI * 1.5, "end": TAU},
	],
	MapFloor.GARDEN: [
		{"pivot": Vector2(250, 264), "r": 12.0, "start": PI, "end": PI * 1.5},
	],
}

var current_floor: int = MapFloor.GROUND
var _hover_clue_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	if not GameState.map_context_changed.is_connected(_on_map_context_changed):
		GameState.map_context_changed.connect(_on_map_context_changed)


func _on_map_context_changed() -> void:
	queue_redraw()


func set_floor(floor_idx: int) -> void:
	current_floor = floor_idx
	_hover_clue_id = ""
	queue_redraw()


func get_current_floor() -> int:
	return current_floor


func refresh() -> void:
	queue_redraw()


func _get_rooms() -> Array[Dictionary]:
	return CATALOG.get_rooms_for_floor(current_floor)


func _flip_ground_y() -> bool:
	return current_floor == MapFloor.GROUND


func _flip_rect_y(rect: Rect2) -> Rect2:
	return Rect2(
		rect.position.x,
		DESIGN_SIZE.y - rect.position.y - rect.size.y,
		rect.size.x,
		rect.size.y
	)


func _flip_point_y(pos: Vector2) -> Vector2:
	return Vector2(pos.x, DESIGN_SIZE.y - pos.y)


func _map_design_rect(rect: Rect2) -> Rect2:
	if _flip_ground_y():
		return _flip_rect_y(rect)
	return rect


func _map_design_point(pos: Vector2) -> Vector2:
	if _flip_ground_y():
		return _flip_point_y(pos)
	return pos


func _design_to_canvas(design_pos: Vector2) -> Vector2:
	if size.x < 1.0 or size.y < 1.0:
		return design_pos
	return Vector2(
		design_pos.x / DESIGN_SIZE.x * size.x,
		design_pos.y / DESIGN_SIZE.y * size.y
	)


func _scale_rect(rect: Rect2) -> Rect2:
	var p := _design_to_canvas(rect.position)
	var s := Vector2(
		rect.size.x / DESIGN_SIZE.x * size.x,
		rect.size.y / DESIGN_SIZE.y * size.y
	)
	return Rect2(p, s)


func _draw() -> void:
	var rooms := _get_rooms()
	var font: Font = ThemeDB.fallback_font
	var room_key := GameState.current_map_key

	for room in rooms:
		var rect: Rect2 = _scale_rect(_map_design_rect(room["rect"]))
		var is_current: bool = room.get("key", "") == room_key
		var fill := COLOR_ROOM_CUR if is_current else COLOR_ROOM
		if room.get("shape", "rect") == "garden":
			_draw_garden_chamfered_rect(rect, fill)
		else:
			draw_rect(rect, fill)
			draw_rect(rect, COLOR_ROOM_BORDER, false, 1.5)
		_draw_room_label(font, rect, room["name"])
	_draw_door_glyphs()

	for clue in GameState.get_map_clues_for_floor(current_floor, true):
		var pos: Vector2 = _design_to_canvas(_map_design_point(clue.get("position", Vector2.ZERO)))
		var clue_id: String = str(clue.get("id", ""))
		var radius := DOT_RADIUS + 2.0 if clue_id == _hover_clue_id else DOT_RADIUS
		draw_circle(pos, radius, COLOR_DOT)
		draw_arc(pos, radius, 0.0, TAU, 16, Color(0.1, 0.1, 0.1, 0.8), 1.5)

	_draw_player_dot()

	if _hover_clue_id != "":
		var hovered := GameState.get_map_clue(_hover_clue_id)
		if not hovered.is_empty() and hovered.get("inspected", false):
			var tip_pos: Vector2 = _design_to_canvas(_map_design_point(hovered["position"])) + Vector2(0.0, -28.0)
			var tip := str(hovered.get("name", ""))
			draw_string(font, tip_pos, tip, HORIZONTAL_ALIGNMENT_CENTER, 240, TOOLTIP_TITLE_SIZE, COLOR_ACCENT)
			var hint := "Clicca per rivedere le informazioni"
			if not GameState.can_show_clue_map_details(_hover_clue_id):
				hint = "Sblocca il dettaglio UV in ispezione"
			draw_string(
				font,
				tip_pos + Vector2(0.0, 16.0),
				hint,
				HORIZONTAL_ALIGNMENT_CENTER,
				300,
				TOOLTIP_HINT_SIZE,
				COLOR_TEXT
			)


func _draw_player_dot() -> void:
	if current_floor != GameState.current_map_floor:
		return
	var pos := GameState.player_map_position
	if pos.x < 0.0:
		return
	var canvas_pos: Vector2 = _design_to_canvas(_map_design_point(pos))
	draw_circle(canvas_pos, PLAYER_DOT_RADIUS, COLOR_PLAYER)
	draw_arc(canvas_pos, PLAYER_DOT_RADIUS, 0.0, TAU, 16, Color(0.05, 0.08, 0.12, 0.9), 1.5)


func _draw_room_label(font: Font, rect: Rect2, label: String) -> void:
	var text_pos := Vector2(rect.position.x, rect.position.y + rect.size.y * 0.52)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, COLOR_TEXT)


func _draw_garden_chamfered_rect(rect: Rect2, fill: Color) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var cut_x: float = w * GARDEN_CORNER_CUT_RATIO_X
	var cut_y: float = h * GARDEN_CORNER_CUT_RATIO_Y
	cut_x = minf(cut_x, w * 0.45)
	cut_y = minf(cut_y, h * 0.45)
	var x := rect.position.x
	var y := rect.position.y

	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(x + cut_x, y),
		Vector2(x + w - cut_x, y),
		Vector2(x + w, y + cut_y),
		Vector2(x + w, y + h - cut_y),
		Vector2(x + w - cut_x, y + h),
		Vector2(x + cut_x, y + h),
		Vector2(x, y + h - cut_y),
		Vector2(x, y + cut_y),
	])

	draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, COLOR_ROOM_BORDER, 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover(event.position)
		if _hover_clue_id != "":
			emit_signal("clue_clicked", _hover_clue_id)
			accept_event()


func _update_hover(local_pos: Vector2) -> void:
	var best_id := ""
	var best_dist := HOVER_RADIUS * HOVER_RADIUS
	for clue in GameState.get_map_clues_for_floor(current_floor, true):
		var canvas_pos: Vector2 = _design_to_canvas(_map_design_point(clue.get("position", Vector2.ZERO)))
		var d := local_pos.distance_squared_to(canvas_pos)
		if d < best_dist:
			best_dist = d
			best_id = str(clue.get("id", ""))
	if best_id != _hover_clue_id:
		_hover_clue_id = best_id
		queue_redraw()

func _draw_door_glyphs() -> void:
	if not DOOR_GLYPHS.has(current_floor):
		return
	for glyph in DOOR_GLYPHS[current_floor]:
		_draw_door_glyph(glyph)

func _draw_door_glyph(glyph: Dictionary) -> void:
	var pivot_design: Vector2 = _map_design_point(glyph.get("pivot", Vector2.ZERO))
	var pivot := _design_to_canvas(pivot_design)
	var radius: float = float(glyph.get("r", 10.0)) * minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var start_angle: float = float(glyph.get("start", 0.0))
	var end_angle: float = float(glyph.get("end", PI * 0.5))
	draw_arc(pivot, radius, start_angle, end_angle, 16, COLOR_DOOR, 1.5)
	var wall_dir := Vector2(cos(start_angle), sin(start_angle))
	var wall_len := radius * 0.65
	draw_line(pivot, pivot + wall_dir * wall_len, COLOR_DOOR, 1.5)
