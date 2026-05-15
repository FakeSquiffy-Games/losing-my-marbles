extends Control

const MATCH_FSM_SCENE := preload("res://scenes/gameplay/match_fsm.tscn")
const PASS_DEVICE_SCENE := preload("res://scenes/ui/pass_device.tscn")

@onready var _phase_label: Label = %PhaseLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _player_label: Label = %PlayerLabel
@onready var _health_label: Label = %HealthLabel
@onready var _mana_label: Label = %ManaLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _aim_button: Button = %AimButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _back_button: Button = %BackButton

var _fsm: StateChart

func _ready() -> void:
	_ready_button.pressed.connect(_on_ready_pressed)
	_aim_button.pressed.connect(_on_aim_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.device_passed.connect(_on_device_passed)

	if not multiplayer.is_server():
		_disable_buttons()
		return

	MatchManager.set_active_player(1)
	print("[Match] set_active_player(1) done, phase=", MatchManager.current_phase)

	_fsm = MATCH_FSM_SCENE.instantiate()
	add_child(_fsm)
	# _fsm.ready already fired synchronously during add_child (we're in a _ready() phase)
	# Use call_deferred so StateChart has fully settled before we send the event
	_fsm.send_event.call_deferred("begin")
	print("[Match] send_event('begin') scheduled via call_deferred")

func _on_phase_changed(phase: int) -> void:
	print("[Match] _on_phase_changed: ", _phase_name(phase as Enums.MatchState))
	_update_hud()
	_show_phase_buttons()

	if phase == Enums.MatchState.DRAW:
		MatchManager.generate_mana(MatchManager.active_player_id)

func _on_ready_pressed() -> void:
	_fsm.send_event("ready")

func _on_aim_pressed() -> void:
	_fsm.send_event("aim")

func _on_end_turn_pressed() -> void:
	_fsm.send_event("end_turn")

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
	print("[Match]   ready_btn: visible=%s (phase==DRAW=%s)" % [phase == Enums.MatchState.DRAW and is_server_ok, phase == Enums.MatchState.DRAW])

	_ready_button.visible = phase == Enums.MatchState.DRAW and is_server_ok
	_aim_button.visible = phase == Enums.MatchState.PLAY and is_server_ok
	_end_turn_button.visible = phase == Enums.MatchState.PLAY and is_server_ok

	_ready_button.disabled = not is_active
	_aim_button.disabled = not is_active
	_end_turn_button.disabled = not is_active

	if phase == Enums.MatchState.END_TURN and multiplayer.is_server():
		if NetworkManager.session_key == "OFFLINE":
			var pass_device := PASS_DEVICE_SCENE.instantiate()
			pass_device.setup(MatchManager.active_player_id)
			add_child(pass_device)
		else:
			# Online: next turn automatically
			MatchManager.set_active_player(MatchManager.get_opponent_id())
			_fsm.send_event("next_turn")

func _disable_buttons() -> void:
	_ready_button.disabled = true
	_aim_button.disabled = true
	_end_turn_button.disabled = true

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
