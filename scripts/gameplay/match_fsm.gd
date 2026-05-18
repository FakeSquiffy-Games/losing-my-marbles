extends StateChart

func _ready() -> void:
	print("[FSM] _ready() start — calling super()")
	super()
	print("[FSM] super() returned")

	var root := $RootState
	print("[FSM] RootState found: ", root != null)
	print("[FSM] RootState children: ", root.get_child_count())

	var init := root.get_node("Init")
	var draw := root.get_node("Draw")
	print("[FSM] Init node: ", init != null, "  Draw node: ", draw != null)

	init.state_entered.connect(_on_init_entered)
	draw.state_entered.connect(_on_draw_entered)
	root.get_node("Play").state_entered.connect(_on_play_entered)
	root.get_node("Aim").state_entered.connect(_on_aim_entered)
	root.get_node("Simulating").state_entered.connect(_on_simulating_entered)
	root.get_node("Simulating").state_exited.connect(_on_simulating_exited)
	root.get_node("EndTurn").state_entered.connect(_on_end_turn_entered)
	root.get_node("MatchOver").state_entered.connect(_on_match_over_entered)
	SignalBus.simulation_complete.connect(_on_simulation_complete)
	print("[FSM] All state_entered signals connected")

func _on_init_entered() -> void:
	print("[FSM] >>> Init state ENTERED — calling MatchManager.set_phase(INIT)")
	MatchManager.set_turn_order([1, 2])
	MatchManager.set_phase(Enums.MatchState.INIT)
	_spawn_initial_marbles()

func _spawn_initial_marbles() -> void:
	var fields := get_tree().get_nodes_in_group("game_field")
	if fields.is_empty():
		print("[FSM] No game_field found for spawning")
		return

	var field := fields[0] as Node2D
	const MARBLES_PER_PLAYER := 3
	const MARGIN := 80.0

	var p1_preferred: Array[Vector2] = [
		Vector2(310, 250),
		Vector2(320, 200),
		Vector2(320, 300),
	]
	var p2_preferred: Array[Vector2] = [
		Vector2(590, 250),
		Vector2(580, 200),
		Vector2(580, 300),
	]

	for i: int in MARBLES_PER_PLAYER:
		var marble_data := MarblePoolManager.get_marble()
		var pos_p1: Vector2 = field.find_valid_position(p1_preferred[i])
		field.spawn_marble(marble_data, 1, pos_p1, Color.RED)

		var marble_data2 := MarblePoolManager.get_marble()
		var pos_p2: Vector2 = field.find_valid_position(p2_preferred[i])
		field.spawn_marble(marble_data2, 2, pos_p2, Color.BLUE)

	print("[FSM] Initial marbles spawned")
	field.sync_marbles_to_clients()
	FieldStateManager.recalculate()

func _on_draw_entered() -> void:
	print("[FSM] >>> Draw state ENTERED — calling MatchManager.set_phase(DRAW)")
	MatchManager.generate_mana(MatchManager.active_player_id)
	MatchManager.reset_knockouts()
	MatchManager.set_phase(Enums.MatchState.DRAW)

func _on_play_entered() -> void:
	print("[FSM] >>> Play state ENTERED")
	MatchManager.set_phase(Enums.MatchState.PLAY)

func _on_aim_entered() -> void:
	print("[FSM] >>> Aim state ENTERED")
	MatchManager.set_phase(Enums.MatchState.AIM)

func _on_simulating_entered() -> void:
	print("[FSM] >>> Simulating state ENTERED")
	MatchManager.set_phase(Enums.MatchState.SIMULATING)

func _on_simulating_exited() -> void:
	print("[FSM] >>> Simulating state EXITED — resetting marble_played")
	MatchManager.reset_marble_played()

func _on_end_turn_entered() -> void:
	print("[FSM] >>> EndTurn state ENTERED")
	MatchManager.player_mana[MatchManager.active_player_id] = 0
	MatchManager.end_turn_return_hand_to_draw(MatchManager.active_player_id)
	FieldStateManager.tick_aoe_durations()
	MatchManager.set_phase(Enums.MatchState.END_TURN)

func _on_simulation_complete(_final_state: Dictionary) -> void:
	print("[FSM] Simulation complete, sending sim_done")
	send_event("sim_done")

func _on_match_over_entered() -> void:
	print("[FSM] >>> MatchOver state ENTERED")
	MatchManager.set_phase(Enums.MatchState.MATCH_OVER)
