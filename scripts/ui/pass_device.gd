extends Control

@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton

var _next_player_id: int = 2

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)

func setup(current_player_id: int) -> void:
	_next_player_id = 3 - current_player_id
	_message_label.text = "Pass the device to Player %d\n\nPlayer %d: Do not peek!" % [_next_player_id, current_player_id]
	_confirm_button.text = "I am Player %d" % _next_player_id

func _on_confirm_pressed() -> void:
	SignalBus.turn_changed.emit(_next_player_id)
	queue_free()
