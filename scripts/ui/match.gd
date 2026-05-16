extends Control

const MATCH_FSM_SCENE := preload("res://scenes/gameplay/match_fsm.tscn")
const PASS_DEVICE_SCENE := preload("res://scenes/ui/pass_device.tscn")

const AIM_FLICK_MIN: float = 0.0
const AIM_FLICK_MAX: float = 10.0
const ROTATION_SPEED: float = 120.0
const FINE_TUNE_SPEED: float = 60.0
const SHOT_IMPULSE_SCALE: float = 80.0

@onready var _phase_label: Label = %PhaseLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _player_label: Label = %PlayerLabel
@onready var _health_label: Label = %HealthLabel
@onready var _mana_label: Label = %ManaLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _aim_button: Button = %AimButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _execute_button: Button = %ExecuteButton
@onready var _aim_back_button: Button = %AimBackButton
@onready var _back_button: Button = %BackButton

var _fsm: StateChart
var _aim_controls: HBoxContainer
var _rotate_left_button: Button
var _rotate_right_button: Button
var _rotation_label: Label
var _fine_tune_left_button: Button
var _fine_tune_right_button: Button
var _fine_tune_label: Label
var _flick_slider: HSlider
var _flick_label: Label
var _flick_value: float = 0.0
var _rotation_value: float = 0.0
var _rotating_direction: int = 0
var _fine_tune_value: float = 0.0
var _fine_tune_direction: int = 0
var _last_emitted_total: float = -INF

func _ready() -> void:
	_ready_button.pressed.connect(_on_ready_pressed)
	_aim_button.pressed.connect(_on_aim_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_execute_button.pressed.connect(_on_execute_pressed)
	_aim_back_button.pressed.connect(_on_aim_back_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.device_passed.connect(_on_device_passed)

	_build_aim_controls()

	if not multiplayer.is_server():
		_disable_buttons()
		return

	MatchManager.set_active_player(1)
	print("[Match] set_active_player(1) done, phase=", MatchManager.current_phase)

	_fsm = MATCH_FSM_SCENE.instantiate()
	add_child(_fsm)
	_fsm.send_event.call_deferred("begin")
	print("[Match] send_event('begin') scheduled via call_deferred")

func _process(delta: float) -> void:
	var changed := false

	if _rotating_direction != 0:
		_rotation_value += ROTATION_SPEED * delta * _rotating_direction
		_rotation_label.text = "Field: %.0f" % _rotation_value
		_apply_map_rotation()
		changed = true

	if _fine_tune_direction != 0:
		_fine_tune_value += FINE_TUNE_SPEED * delta * _fine_tune_direction
		_fine_tune_label.text = "Aim: %.0f" % _fine_tune_value
		changed = true

	if changed:
		_emit_aim_if_changed()

func _emit_aim_if_changed() -> void:
	var total := _rotation_value + _fine_tune_value
	if abs(total - _last_emitted_total) > 0.5:
		_last_emitted_total = total
		SignalBus.aim_inputs_changed.emit(total, _flick_value)

func _build_aim_controls() -> void:
	_aim_controls = HBoxContainer.new()
	_aim_controls.name = "AimControls"
	_aim_controls.visible = false
	_aim_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_aim_controls.add_theme_constant_override("separation", 20)

	# Field rotation group
	var rotation_group := VBoxContainer.new()
	_rotation_label = Label.new()
	_rotation_label.text = "Field: 0"
	_rotation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var rotation_buttons := _make_button_pair(_on_rotate_left_down, _on_rotate_right_down, _on_rotate_up)
	_rotate_left_button = rotation_buttons.get_child(0) as Button
	_rotate_right_button = rotation_buttons.get_child(1) as Button

	rotation_group.add_child(_rotation_label)
	rotation_group.add_child(rotation_buttons)

	# Fine-tune aim group
	var fine_tune_group := VBoxContainer.new()
	_fine_tune_label = Label.new()
	_fine_tune_label.text = "Aim: 0"
	_fine_tune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var fine_tune_buttons := _make_button_pair(_on_fine_tune_left_down, _on_fine_tune_right_down, _on_fine_tune_up)
	_fine_tune_left_button = fine_tune_buttons.get_child(0) as Button
	_fine_tune_right_button = fine_tune_buttons.get_child(1) as Button

	fine_tune_group.add_child(_fine_tune_label)
	fine_tune_group.add_child(fine_tune_buttons)

	# Flick group
	var flick_group := _make_labeled_slider("Flick Power", AIM_FLICK_MIN, AIM_FLICK_MAX, 0.0)
	_flick_label = flick_group.get_child(0) as Label
	_flick_slider = flick_group.get_child(1) as HSlider
	_flick_slider.value_changed.connect(_on_flick_changed)

	_aim_controls.add_child(rotation_group)
	_aim_controls.add_child(fine_tune_group)
	_aim_controls.add_child(flick_group)

	var hud := $HUDContainer
	hud.add_child(_aim_controls)
	hud.move_child(_aim_controls, hud.get_child_count() - 2)

func _make_button_pair(on_left_down: Callable, on_right_down: Callable, on_up: Callable) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)

	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(40, 0)
	left.button_down.connect(on_left_down)
	left.button_up.connect(on_up)

	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(40, 0)
	right.button_down.connect(on_right_down)
	right.button_up.connect(on_up)

	container.add_child(left)
	container.add_child(right)
	return container

func _make_labeled_slider(label_text: String, min_val: float, max_val: float, default_val: float) -> VBoxContainer:
	var container := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s: %.1f" % [label_text, default_val]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 0.1
	slider.custom_minimum_size = Vector2(150, 0)

	container.add_child(label)
	container.add_child(slider)
	return container

func _on_rotate_left_down() -> void:
	_rotating_direction = -1

func _on_rotate_right_down() -> void:
	_rotating_direction = 1

func _on_rotate_up() -> void:
	_rotating_direction = 0

func _on_fine_tune_left_down() -> void:
	_fine_tune_direction = -1

func _on_fine_tune_right_down() -> void:
	_fine_tune_direction = 1

func _on_fine_tune_up() -> void:
	_fine_tune_direction = 0

func _on_flick_changed(value: float) -> void:
	_flick_label.text = "Flick Power: %.1f" % value
	_flick_value = value
	SignalBus.aim_inputs_changed.emit(_rotation_value + _fine_tune_value, _flick_value)

func _apply_map_rotation() -> void:
	var field_node := _get_field_node()
	if field_node:
		field_node.set_map_rotation(_rotation_value)

func _get_field_node() -> Node2D:
	if has_node("HUDContainer/Field/SubViewport/Field"):
		return get_node("HUDContainer/Field/SubViewport/Field") as Node2D
	return null

func _on_phase_changed(phase: int) -> void:
	print("[Match] _on_phase_changed: ", _phase_name(phase as Enums.MatchState))
	_update_hud()
	_show_phase_buttons()

func _on_ready_pressed() -> void:
	_fsm.send_event("ready")

func _on_aim_pressed() -> void:
	_fsm.send_event("aim")

func _on_end_turn_pressed() -> void:
	_fsm.send_event("end_turn")

func _on_execute_pressed() -> void:
	_execute_shot()
	_fsm.send_event("shoot")

func _execute_shot() -> void:
	if not multiplayer.is_server():
		return

	var field := _get_field_node()
	if not field:
		push_warning("[Match] Shot execution failed: no field node")
		return

	var marble: Marble = field.activate_shooter_marble()
	if not is_instance_valid(marble):
		push_warning("[Match] Shot execution failed: no shooter marble")
		return

	var direction := Vector2.LEFT.rotated(deg_to_rad(_rotation_value + _fine_tune_value))
	var character: CharacterData = MatchManager.player_characters.get(MatchManager.active_player_id, null)
	var power: float = character.power if character else 1.0
	var impulse := direction * _flick_value * power * SHOT_IMPULSE_SCALE

	marble.apply_central_impulse(impulse)
	print("[Match] Shot executed — direction=%s flick=%.1f power=%.1f scale=%.0f impulse=%s" % [direction, _flick_value, power, SHOT_IMPULSE_SCALE, impulse])

func _on_aim_back_pressed() -> void:
	_fsm.send_event("back")

func _on_device_passed(next_player_id: int) -> void:
	if MatchManager.current_phase != Enums.MatchState.END_TURN:
		return
	MatchManager.set_active_player(next_player_id)
	_fsm.send_event("next_turn")

func _update_hud() -> void:
	_phase_label.text = _phase_name(MatchManager.current_phase)
	_turn_label.text = "Turn: %d" % MatchManager.turn_number
	_player_label.text = "Active Player: %d" % MatchManager.active_player_id

	var p1_health: int = MatchManager.player_health.get(1, 0)
	var p2_health: int = MatchManager.player_health.get(2, 0)
	_health_label.text = "HP  P1: %d  |  P2: %d" % [p1_health, p2_health]

	var p1_mana: int = MatchManager.player_mana.get(1, 0)
	var p2_mana: int = MatchManager.player_mana.get(2, 0)
	_mana_label.text = "Mana  P1: %d  |  P2: %d" % [p1_mana, p2_mana]

func _show_phase_buttons() -> void:
	var phase := MatchManager.current_phase
	var is_offline := NetworkManager.session_key == "OFFLINE"
	var is_active := is_offline or MatchManager.active_player_id == NetworkManager.local_player_id
	var is_server_ok := multiplayer.is_server() or not is_offline

	print("[Match] _show_phase_buttons: phase=%s is_active=%s is_server_ok=%s" % [_phase_name(phase), is_active, is_server_ok])

	_ready_button.visible = phase == Enums.MatchState.DRAW and is_server_ok
	_aim_button.visible = phase == Enums.MatchState.PLAY and is_server_ok
	_end_turn_button.visible = phase == Enums.MatchState.PLAY and is_server_ok
	_execute_button.visible = phase == Enums.MatchState.AIM and is_server_ok
	_aim_back_button.visible = phase == Enums.MatchState.AIM and is_server_ok
	_aim_controls.visible = phase == Enums.MatchState.AIM and is_server_ok

	_ready_button.disabled = not is_active
	_aim_button.disabled = not is_active
	_end_turn_button.disabled = not is_active
	_execute_button.disabled = not is_active
	_aim_back_button.disabled = not is_active

	_rotate_left_button.disabled = not is_active
	_rotate_right_button.disabled = not is_active
	_fine_tune_left_button.disabled = not is_active
	_fine_tune_right_button.disabled = not is_active
	_flick_slider.editable = is_active

	if phase == Enums.MatchState.AIM and is_server_ok:
		_reset_aim_controls()

	if phase == Enums.MatchState.END_TURN and multiplayer.is_server():
		if NetworkManager.session_key == "OFFLINE":
			var pass_device := PASS_DEVICE_SCENE.instantiate()
			pass_device.setup(MatchManager.active_player_id)
			add_child(pass_device)
		else:
			# Online: next turn automatically
			MatchManager.set_active_player(MatchManager.get_opponent_id())
			_fsm.send_event("next_turn")

func _reset_aim_controls() -> void:
	_rotation_value = 0.0
	_fine_tune_value = 0.0
	_last_emitted_total = -INF
	_rotation_label.text = "Field: 0"
	_fine_tune_label.text = "Aim: 0"
	_flick_slider.value = 0.0

func _disable_buttons() -> void:
	_ready_button.disabled = true
	_aim_button.disabled = true
	_end_turn_button.disabled = true
	_execute_button.disabled = true
	_aim_back_button.disabled = true

func _phase_name(phase: Enums.MatchState) -> String:
	match phase:
		Enums.MatchState.INIT: return "Init"
		Enums.MatchState.DRAW: return "Draw"
		Enums.MatchState.PLAY: return "Play"
		Enums.MatchState.AIM: return "Aim"
		Enums.MatchState.SIMULATING: return "Simulating"
		Enums.MatchState.END_TURN: return "End Turn"
		Enums.MatchState.MATCH_OVER: return "Match Over"
		_: return "Unknown"

func _on_back_pressed() -> void:
	NetworkManager.reset_network()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _exit_tree() -> void:
	if SignalBus.phase_changed.is_connected(_on_phase_changed):
		SignalBus.phase_changed.disconnect(_on_phase_changed)
	if SignalBus.device_passed.is_connected(_on_device_passed):
		SignalBus.device_passed.disconnect(_on_device_passed)
