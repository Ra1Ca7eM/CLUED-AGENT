extends PanelContainer

## Indicatore "sta scrivendo": tre puntini animati (nodi in scena).

const DOT_BASE_Y := 9.0
const ANIM_SPEED := 4.0
const ANIM_BOUNCE := 4.0

@onready var _dot1: Panel = %Dot1
@onready var _dot2: Panel = %Dot2
@onready var _dot3: Panel = %Dot3

var _dots: Array[Panel] = []
var _time: float = 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dots = [_dot1, _dot2, _dot3]


func _process(delta: float) -> void:
	_time += delta
	for i in range(_dots.size()):
		var phase: float = _time * ANIM_SPEED - float(i) * 0.6
		var s: float = sin(phase) * 0.5 + 0.5
		_dots[i].position.y = DOT_BASE_Y - s * ANIM_BOUNCE
		_dots[i].modulate.a = 0.45 + s * 0.55
