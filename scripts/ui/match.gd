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
@onready var _hand: Hand = %Hand
@onready var _play_area: PlayArea = %PlayArea
@onready var _aim_controls_container: VBoxContainer = %AimControlsContainer
@onready var _table_frame: Control = %TableFrame
@onready var _phase_buttons_container: VBoxContainer = $"ControlsPanel/ControlsVBox/PhaseButtons"

var _fsm: StateChart
var _aim_controls: BoxContainer
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
var _aim_pulse_tween: Tween
var _slide_tween: Tween
var _right_panel_tween: Tween
var _phase_buttons_rest_x: float
var _aim_controls_rest_x: float
var _previous_button_phase: int = -1
var _card_library: CardLibrary
var _card_data_cache: Array[CardData] = []
var _card_lookup: Dictionary = {}
var _mana_bottle: ProgressBar
var _mana_bottle_label: Label
var _card_count_box: Panel
var _card_count_label: Label
var _mana_panel: Panel

func _ready() -> void:
	_aim_button.pressed.connect(_on_aim_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_execute_button.pressed.connect(_on_execute_pressed)
	_aim_back_button.pressed.connect(_on_aim_back_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.device_passed.connect(_on_device_passed)
	SignalBus.marble_played_changed.connect(_on_marble_played_changed)

	_play_area.card_played.connect(_on_card_played)

	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_phase_buttons_rest_x = _phase_buttons_container.position.x
	_aim_controls_rest_x = _aim_controls_container.position.x

	_card_library = CardLibrary.new()
	_card_library.load_cards()
	_card_data_cache.assign(_card_library.cards)
	for cd: CardData in _card_data_cache:
		_card_lookup[cd.card_name] = cd
	for player_id: int in [1, 2]:
		MatchManager.init_player_deck(player_id, _card_data_cache)

	_build_aim_controls()
	_build_draw_hud()

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
	_aim_controls = VBoxContainer.new()
	_aim_controls.name = "AimControls"
	_aim_controls.visible = true
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

	_aim_controls_container.add_child(_aim_controls)

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
	if has_node("Field/SubViewport/Field"):
		return get_node("Field/SubViewport/Field") as Node2D
	return null

func _on_phase_changed(phase: int) -> void:
	print("[Match] _on_phase_changed: ", _phase_name(phase as Enums.MatchState))
	_update_hud()
	_show_phase_buttons()
	_update_hand_visibility()

	if phase == Enums.MatchState.DRAW and multiplayer.is_server():
		_start_draw_sequence()

	if phase == Enums.MatchState.PLAY and _table_frame.offset_top > 10.0:
		_slide_table_frame_in()

func _on_aim_pressed() -> void:
	_fsm.send_event("aim")
	_slide_table_frame_out()

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

func _on_marble_played_changed(played: bool) -> void:
	if played:
		_start_aim_pulse()
	else:
		_stop_aim_pulse()

func _start_aim_pulse() -> void:
	if _aim_pulse_tween and _aim_pulse_tween.is_valid():
		return
	_aim_pulse_tween = create_tween()
	_aim_pulse_tween.set_loops(0)
	_aim_pulse_tween.tween_property(_aim_button, "scale", Vector2(1.08, 1.08), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aim_pulse_tween.tween_property(_aim_button, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_aim_pulse() -> void:
	if _aim_pulse_tween and _aim_pulse_tween.is_valid():
		_aim_pulse_tween.kill()
	_aim_button.scale = Vector2(1.0, 1.0)

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

	_update_mana_bottle_display()
	_update_card_count_display()

func _show_phase_buttons() -> void:
	var phase := MatchManager.current_phase
	var is_offline := NetworkManager.session_key == "OFFLINE"
	var is_active := is_offline or MatchManager.active_player_id == NetworkManager.local_player_id
	var is_server_ok := multiplayer.is_server() or not is_offline

	print("[Match] _show_phase_buttons: phase=%s is_active=%s is_server_ok=%s" % [_phase_name(phase), is_active, is_server_ok])

	_animate_right_panel(phase, is_server_ok)

	_play_area.mouse_filter = Control.MOUSE_FILTER_PASS if phase == Enums.MatchState.PLAY else Control.MOUSE_FILTER_IGNORE

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
			MatchManager.set_active_player(MatchManager.get_opponent_id())
			_fsm.send_event("next_turn")

func _animate_right_panel(phase: int, is_server_ok: bool) -> void:
	if _right_panel_tween and _right_panel_tween.is_valid():
		_right_panel_tween.kill()

	var is_initial := _previous_button_phase == -1
	var was_aim := _previous_button_phase == Enums.MatchState.AIM
	var is_aim := phase == Enums.MatchState.AIM
	_previous_button_phase = phase

	if is_initial:
		_sync_button_visibility(phase, is_server_ok)
		_sync_aim_controls_snap(is_aim)
		return

	var pb := _phase_buttons_container
	var ac := _aim_controls_container
	var off_x := _phase_buttons_rest_x + 200.0
	var ac_off_x := _aim_controls_rest_x + 200.0

	_right_panel_tween = create_tween()

	# Phase 1: Slide out — 0.15s (aim controls join if leaving AIM)
	_right_panel_tween.set_trans(Tween.TRANS_QUAD)
	_right_panel_tween.set_ease(Tween.EASE_IN)
	_right_panel_tween.tween_property(pb, "position:x", off_x, 0.15)
	if was_aim:
		_right_panel_tween.parallel().tween_property(ac, "position:x", ac_off_x, 0.15)

	# Phase 2: Swap visibility at midpoint
	_right_panel_tween.tween_callback(_sync_button_visibility.bind(phase, is_server_ok))
	_right_panel_tween.tween_callback(func(): _sync_aim_controls_prep(is_aim))

	# Phase 3: Slide in — 0.25s (aim controls join if entering AIM)
	_right_panel_tween.set_trans(Tween.TRANS_QUAD)
	_right_panel_tween.set_ease(Tween.EASE_OUT)
	_right_panel_tween.tween_property(pb, "position:x", _phase_buttons_rest_x, 0.25)
	if is_aim:
		_right_panel_tween.parallel().tween_property(ac, "position:x", _aim_controls_rest_x, 0.25)

func _sync_button_visibility(phase: int, is_server_ok: bool) -> void:
	_aim_button.visible = phase == Enums.MatchState.PLAY and is_server_ok
	_end_turn_button.visible = phase == Enums.MatchState.PLAY and is_server_ok
	_execute_button.visible = phase == Enums.MatchState.AIM and is_server_ok
	_aim_back_button.visible = phase == Enums.MatchState.AIM and is_server_ok

func _sync_aim_controls_snap(is_aim: bool) -> void:
	var ac := _aim_controls_container
	ac.visible = is_aim
	ac.position = Vector2(_aim_controls_rest_x, ac.position.y)

func _sync_aim_controls_prep(is_aim: bool) -> void:
	var ac := _aim_controls_container
	if is_aim:
		ac.position = Vector2(_aim_controls_rest_x + 200.0, ac.position.y)
		ac.visible = true
	else:
		ac.visible = false
		ac.position = Vector2(_aim_controls_rest_x, ac.position.y)

func _reset_aim_controls() -> void:
	_fine_tune_value = 0.0
	_last_emitted_total = -INF
	_rotation_label.text = "Field: %.0f" % _rotation_value
	_fine_tune_label.text = "Aim: 0"
	_flick_slider.set_value_no_signal(0.0)
	_flick_label.text = "Flick Power: 0.0"
	_flick_value = 0.0
	_apply_map_rotation()
	_emit_aim_if_changed.call_deferred()

func _disable_buttons() -> void:
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

func _update_hand_visibility() -> void:
	var phase := MatchManager.current_phase
	var is_play := phase == Enums.MatchState.PLAY
	_hand.visible = is_play

# -- Draw HUD (mana bottle + card count box) --

func _build_draw_hud() -> void:
	var vp_size := get_viewport_rect().size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.6, 0.8)
	panel_style.set_corner_radius_all(8)

	_mana_panel = Panel.new()
	_mana_panel.name = "ManaBottle"
	_mana_panel.position = Vector2(96, vp_size.y - 80)
	_mana_panel.size = Vector2(140, 56)
	_mana_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mana_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_mana_panel)

	_mana_bottle_label = Label.new()
	_mana_bottle_label.name = "ManaLabel"
	_mana_bottle_label.position = Vector2(8, 4)
	_mana_bottle_label.size = Vector2(124, 16)
	_mana_bottle_label.text = "Mana: 0/0"
	_mana_bottle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_bottle_label.add_theme_font_size_override("font_size", 11)
	_mana_bottle_label.add_theme_color_override("font_color", Color.WHITE)
	_mana_panel.add_child(_mana_bottle_label)

	_mana_bottle = ProgressBar.new()
	_mana_bottle.name = "ManaBar"
	_mana_bottle.position = Vector2(8, 24)
	_mana_bottle.size = Vector2(124, 22)
	_mana_bottle.min_value = 0
	_mana_bottle.max_value = 100
	_mana_bottle.value = 0
	_mana_bottle.show_percentage = false
	_mana_panel.add_child(_mana_bottle)

	_card_count_box = Panel.new()
	_card_count_box.name = "CardCountBox"
	_card_count_box.position = Vector2(16, vp_size.y - 80)
	_card_count_box.size = Vector2(64, 56)
	_card_count_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_count_box.add_theme_stylebox_override("panel", panel_style)
	add_child(_card_count_box)

	_card_count_label = Label.new()
	_card_count_label.name = "CardCountLabel"
	_card_count_label.anchors_preset = Control.PRESET_FULL_RECT
	_card_count_label.text = "0"
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_count_label.add_theme_font_size_override("font_size", 26)
	_card_count_label.add_theme_color_override("font_color", Color.WHITE)
	_card_count_box.add_child(_card_count_label)

func _start_draw_sequence() -> void:
	var active_id: int = MatchManager.active_player_id
	_update_card_count_display()

	# 1. Animate mana bottle fill
	_animate_mana_fill(active_id)
	await get_tree().create_timer(0.7).timeout

	# 2. Draw cards from deck
	_hand.clear_cards()
	var drawn: Array[CardData] = MatchManager.draw_cards(active_id, 5)
	if drawn.is_empty():
		_fsm.send_event("draw_complete")
		return

	var factory: CardDataFactory = $CardManager.card_factory as CardDataFactory
	if factory == null:
		_fsm.send_event("draw_complete")
		return

	# 3. Create cards in hand and record target positions
	var card_infos: Array[Dictionary] = []
	for cd: CardData in drawn:
		var card := factory.create_card_from_data(cd, _hand)
		card_infos.append({"card": card, "target": card.global_position})

	# 4. Move all cards to the shared discard/deal origin
	var origin := _get_discard_origin()
	for info: Dictionary in card_infos:
		var card: Card = info["card"]
		if card.card_container != null:
			card.card_container.remove_card(card)
		card.reparent(self)
		card.global_position = origin
		card.scale = Vector2(0.25, 0.25)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_update_card_count_display()

	# 5. Staggered deal animation
	var stagger: float = 0.1
	for i: int in card_infos.size():
		var info: Dictionary = card_infos[i]
		var card: Card = info["card"]
		var target: Vector2 = info["target"]
		var t := create_tween()
		t.tween_interval(i * stagger)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "global_position", target, 0.35)
		t.parallel().tween_property(card, "scale", Vector2.ONE, 0.35)

	# 6. Wait for all cards to arrive, then add back to hand
	var total_duration := float(card_infos.size() - 1) * stagger + 0.35
	await get_tree().create_timer(total_duration).timeout

	for info: Dictionary in card_infos:
		var card: Card = info["card"]
		card.reparent(_hand.get_node("Cards"))
		card.card_container = _hand
		_hand._held_cards.append(card)
	_hand.update_card_ui()

	_update_mana_bottle_display()
	print("[Match] Dealt %d cards to hand (draw pile: %d)" % [drawn.size(), MatchManager.get_draw_pile_count(active_id)])

	# 7. Auto-transition to PLAY
	_fsm.send_event("draw_complete")

func _animate_mana_fill(player_id: int) -> void:
	var max_mana: int = _get_max_mana(player_id)
	if max_mana <= 0:
		return

	_mana_bottle.max_value = max_mana
	_mana_bottle_label.text = "Mana: 0/%d" % max_mana

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_mana_bottle_value, 0.0, float(max_mana), 0.6)
	tween.tween_callback(func():
		_mana_bottle_label.text = "Mana: %d/%d" % [MatchManager.player_mana[player_id], max_mana]
	)

func _set_mana_bottle_value(val: float) -> void:
	_mana_bottle.value = val

func _get_max_mana(player_id: int) -> int:
	var character: CharacterData = MatchManager.player_characters.get(player_id, null)
	return character.mana if character else 5

func _update_mana_bottle_display() -> void:
	var player_id: int = MatchManager.active_player_id
	var max_mana: int = _get_max_mana(player_id)
	_mana_bottle.max_value = max_mana
	_mana_bottle.value = MatchManager.player_mana.get(player_id, 0)
	_mana_bottle_label.text = "Mana: %d/%d" % [int(_mana_bottle.value), max_mana]

func _update_card_count_display() -> void:
	var player_id: int = MatchManager.active_player_id
	var count: int = MatchManager.get_draw_pile_count(player_id)
	_card_count_label.text = str(count)

# -- Card play --

func _on_card_played(card: Card) -> void:
	if not multiplayer.is_server():
		return
	var card_data: CardData = card.card_info.get("card_data", null)
	if card_data == null:
		push_warning("[Match] Card played with no CardData")
		_return_card_to_hand(card)
		return

	var error := _validate_card_play(card_data)
	if not error.is_empty():
		push_warning("[Match] Card play rejected: %s" % error)
		_return_card_to_hand(card)
		return

	MatchManager.spend_mana(MatchManager.active_player_id, card_data.mana_cost)
	MatchManager.discard_card(MatchManager.active_player_id, card_data)
	if card_data.type == Enums.CardTypeEnum.MARBLE:
		MatchManager.set_marble_played()

	_animate_card_play(card)

	_update_hud()
	SignalBus.card_play_validated.emit(card_data.card_name, true)
	print("[Match] Card played: %s (mana: %d, marble_played: %s)" % [card_data.card_name, MatchManager.player_mana[MatchManager.active_player_id], MatchManager.marble_played])

func _get_discard_origin() -> Vector2:
	return _card_count_box.global_position + _card_count_box.size / 2.0

func _kill_card_tweens(card: Card) -> void:
	if card.hover_tween and card.hover_tween.is_valid():
		card.hover_tween.kill()
		card.hover_tween = null
	if card.move_tween and card.move_tween.is_valid():
		card.move_tween.kill()
		card.move_tween = null

func _animate_card_play(card: Card) -> void:
	if card.card_container != null:
		card.card_container.remove_card(card)

	card.reparent(self)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_card_tweens(card)

	var discard_target := _get_discard_origin()

	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.3, 1.3), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_begin_card_discard.bind(card, discard_target))

func _begin_card_discard(card: Card, discard_target: Vector2) -> void:
	if not is_instance_valid(card):
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "global_position", discard_target, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(card.queue_free)

@rpc("any_peer", "call_local", "reliable")
func _request_play_card(card_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != MatchManager.active_player_id:
		push_warning("[Match] Card play rejected: sender %d is not active player %d" % [sender_id, MatchManager.active_player_id])
		return

	var card_data: CardData = _card_lookup.get(card_name, null)
	if card_data == null:
		push_warning("[Match] Card play rejected: unknown card '%s'" % card_name)
		return

	var error := _validate_card_play(card_data)
	if not error.is_empty():
		push_warning("[Match] Card play rejected: %s" % error)
		return

	MatchManager.spend_mana(MatchManager.active_player_id, card_data.mana_cost)
	MatchManager.discard_card(MatchManager.active_player_id, card_data)
	if card_data.type == Enums.CardTypeEnum.MARBLE:
		MatchManager.set_marble_played()
	SignalBus.card_play_validated.emit(card_name, true)
	print("[Match] Card played (RPC): %s (mana: %d)" % [card_name, MatchManager.player_mana[MatchManager.active_player_id]])
	print(MatchManager.player_decks[1].discard_pile.size())

func _validate_card_play(card_data: CardData) -> String:
	if MatchManager.current_phase != Enums.MatchState.PLAY:
		return "Not in PLAY phase (current: %s)" % _phase_name(MatchManager.current_phase)
	if not MatchManager.has_card_in_hand(MatchManager.active_player_id, card_data):
		return "Card not in player's hand"
	if card_data.type == Enums.CardTypeEnum.MARBLE and MatchManager.marble_played:
		return "Already played a marble this turn"
	if card_data.mana_cost > MatchManager.player_mana.get(MatchManager.active_player_id, 0):
		return "Not enough mana (need %d, have %d)" % [card_data.mana_cost, MatchManager.player_mana[MatchManager.active_player_id]]
	return ""

func _return_card_to_hand(card: Card) -> void:
	if not is_instance_valid(card):
		return
	if _hand.has_card(card):
		return
	_hand.move_cards([card])

func _exit_tree() -> void:
	if SignalBus.phase_changed.is_connected(_on_phase_changed):
		SignalBus.phase_changed.disconnect(_on_phase_changed)
	if SignalBus.device_passed.is_connected(_on_device_passed):
		SignalBus.device_passed.disconnect(_on_device_passed)
	if SignalBus.marble_played_changed.is_connected(_on_marble_played_changed):
		SignalBus.marble_played_changed.disconnect(_on_marble_played_changed)
	if get_tree().root.size_changed.is_connected(_on_viewport_size_changed):
		get_tree().root.size_changed.disconnect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	# Reposition TableFrame if it's slid out
	if _table_frame.offset_top > 10.0:
		var vp_height := get_viewport_rect().size.y
		_table_frame.offset_top = vp_height
		_table_frame.offset_bottom = vp_height

	# Reposition draw HUD elements
	var vp_size := get_viewport_rect().size
	if _mana_panel:
		_mana_panel.position.y = vp_size.y - 80
	if _card_count_box:
		_card_count_box.position.y = vp_size.y - 80

func _slide_table_frame_out() -> void:
	var vp_height := get_viewport_rect().size.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_table_frame, "offset_top", vp_height, 0.4)
	tween.tween_property(_table_frame, "offset_bottom", vp_height, 0.4)

func _slide_table_frame_in() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_table_frame, "offset_top", 0.0, 0.4)
	tween.tween_property(_table_frame, "offset_bottom", 0.0, 0.4)
