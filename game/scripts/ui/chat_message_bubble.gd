extends PanelContainer

## Bolla messaggio chat. Grafica in scena; `setup()` imposta testo e variante giocatore/NPC.

const STYLE_PLAYER := preload("res://ui/dialogue/styles/bubble_player.tres")
const STYLE_NPC := preload("res://ui/dialogue/styles/bubble_npc.tres")
const COLOR_TEXT := Color(0.94, 0.92, 0.86, 1.0)

@onready var _message_label: Label = %MessageLabel


func setup(text: String, is_player: bool) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", STYLE_PLAYER if is_player else STYLE_NPC)
	_message_label.text = text
