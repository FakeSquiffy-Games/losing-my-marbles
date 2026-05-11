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
	root.get_node("EndTurn").state_entered.connect(_on_end_turn_entered)
	root.get_node("MatchOver").state_entered.connect(_on_match_over_entered)
	print("[FSM] All state_entered signals connected")

func _on_init_entered() -> void:
	print("[FSM] >>> Init state ENTERED — calling MatchManager.set_phase(INIT)")
	MatchManager.set_phase(MatchManager.MatchPhase.INIT)

func _on_draw_entered() -> void:
	print("[FSM] >>> Draw state ENTERED — calling MatchManager.set_phase(DRAW)")
	MatchManager.set_phase(MatchManager.MatchPhase.DRAW)

func _on_play_entered() -> void:
	print("[FSM] >>> Play state ENTERED")
	MatchManager.set_phase(MatchManager.MatchPhase.PLAY)

func _on_aim_entered() -> void:
	print("[FSM] >>> Aim state ENTERED")
	MatchManager.set_phase(MatchManager.MatchPhase.AIM)

func _on_simulating_entered() -> void:
	print("[FSM] >>> Simulating state ENTERED")
	MatchManager.set_phase(MatchManager.MatchPhase.SIMULATING)

func _on_end_turn_entered() -> void:
	print("[FSM] >>> EndTurn state ENTERED")
	MatchManager.set_phase(MatchManager.MatchPhase.END_TURN)

func _on_match_over_entered() -> void:
	print("[FSM] >>> MatchOver state ENTERED")
	MatchManager.set_phase(MatchManager.MatchPhase.MATCH_OVER)
