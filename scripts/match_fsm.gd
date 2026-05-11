extends StateChart

@onready var _init_state: AtomicState = %Init
@onready var _draw_state: AtomicState = %Draw
@onready var _play_state: AtomicState = %Play
@onready var _aim_state: AtomicState = %Aim
@onready var _simulating_state: AtomicState = %Simulating
@onready var _end_turn_state: AtomicState = %EndTurn
@onready var _match_over_state: AtomicState = %MatchOver

func _ready() -> void:
	_init_state.state_entered.connect(_on_init_entered)
	_draw_state.state_entered.connect(_on_draw_entered)
	_play_state.state_entered.connect(_on_play_entered)
	_aim_state.state_entered.connect(_on_aim_entered)
	_simulating_state.state_entered.connect(_on_simulating_entered)
	_end_turn_state.state_entered.connect(_on_end_turn_entered)
	_match_over_state.state_entered.connect(_on_match_over_entered)

func _on_init_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.INIT)

func _on_draw_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.DRAW)

func _on_play_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.PLAY)

func _on_aim_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.AIM)

func _on_simulating_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.SIMULATING)

func _on_end_turn_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.END_TURN)

func _on_match_over_entered() -> void:
	MatchManager.set_phase(MatchManager.MatchPhase.MATCH_OVER)
