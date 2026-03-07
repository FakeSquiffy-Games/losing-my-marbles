extends Node

var is_rotating: bool = false
var aim_angle: float = -PI / 2

func _ready():
	GameState.marble_stopped.connect(_on_marble_stopped)
	if GameState.active_marble:
		GameState.active_marble.update_aim_line(0.5, aim_angle)

func _on_marble_stopped():
	is_rotating = false
	aim_angle = -PI / 2
	if GameState.active_marble:
		GameState.active_marble.update_aim_line(0.5, aim_angle)

func _input(event):
	if not GameState.active_marble:
		return
	if GameState.active_marble.linear_velocity.length() > 5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var dist = get_viewport().get_camera_2d().get_global_mouse_position().distance_to(GameState.active_marble.global_position)
		if event.pressed and dist < 30.0:
			is_rotating = true
		else:
			is_rotating = false
	if event is InputEventMouseMotion and is_rotating:
		var dir = GameState.active_marble.get_global_mouse_position() - GameState.active_marble.global_position
		aim_angle = dir.angle()
		GameState.active_marble.update_aim_line(0.5, aim_angle)

func launch(power: float):
	if not GameState.active_marble:
		return
	GameState.active_marble.launch(power, aim_angle)
