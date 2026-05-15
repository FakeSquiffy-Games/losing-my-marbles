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

	var field := fields[0]
	var default_marble := load("res://resources/cards/marble_standard.tres") as MarbleData

	field.spawn_marble(default_marble, 1, Vector2(150, 250), Color.RED)
	field.spawn_marble(default_marble, 1, Vector2(200, 180), Color.RED)
	field.spawn_marble(default_marble, 1, Vector2(200, 320), Color.RED)

	field.spawn_marble(default_marble, 2, Vector2(750, 250), Color.BLUE)
	field.spawn_marble(default_marble, 2, Vector2(700, 180), Color.BLUE)
	field.spawn_marble(default_marble, 2, Vector2(700, 320), Color.BLUE)

	print("[FSM] Initial marbles spawned")
	FieldStateManager._push_to_field()

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
	FieldStateManager.tick_aoe_durations()
	MatchManager.set_phase(Enums.MatchState.END_TURN)

func _on_match_over_entered() -> void:
	print("[FSM] >>> MatchOver state ENTERED")
	MatchManager.set_phase(Enums.MatchState.MATCH_OVER)
