extends Node

var current_phase: Enums.MatchState = Enums.MatchState.INIT
var active_player_id: int = 1
var turn_number: int = 0
var marble_played: bool = false
var active_shooter_id: int = 0
var knockouts_this_turn: int = 0
var turn_order: Array[int] = []

var player_health: Dictionary = {}
var player_mana: Dictionary = {}
var player_characters: Dictionary = {}
var _pending_characters: Dictionary = {}

func _ready() -> void:
	SignalBus.character_selected.connect(_on_character_selected)
	SignalBus.player_disconnected.connect(_on_player_disconnected)

func set_phase(phase: Enums.MatchState) -> void:
	print("[MatchManager] set_phase(%d) called, is_server=%s" % [phase, multiplayer.is_server()])
	if not multiplayer.is_server():
		print("[MatchManager] set_phase REJECTED — not server")
		return
	current_phase = phase
	print("[MatchManager] phase set to %d, emitting phase_changed" % phase)
	_sync_match_state.rpc(phase, active_player_id, turn_number, player_health, player_mana)
	SignalBus.phase_changed.emit(phase)

func set_active_player(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	active_player_id = player_id
	turn_number += 1
	SignalBus.turn_changed.emit(player_id)
	_sync_match_state.rpc(current_phase, active_player_id, turn_number, player_health, player_mana)

func get_opponent_id() -> int:
	return 3 - active_player_id

func is_server() -> bool:
	return multiplayer.is_server()

func set_marble_played() -> void:
	marble_played = true

func reset_marble_played() -> void:
	marble_played = false

func set_active_shooter(player_id: int) -> void:
	active_shooter_id = player_id

func increment_knockout() -> void:
	knockouts_this_turn += 1

func reset_knockouts() -> void:
	knockouts_this_turn = 0

func set_turn_order(order: Array[int]) -> void:
	turn_order = order

@rpc("any_peer", "call_local", "reliable")
func _request_phase_advance(requested_event: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != active_player_id:
		push_warning("Phase advance request from non-active player: ", sender_id)
		return
	SignalBus.phase_advance_requested.emit(requested_event)

func _on_character_selected(player_id: int, character: CharacterData) -> void:
	player_characters[player_id] = character
	player_health[player_id] = character.health
	player_mana[player_id] = 0

	if not multiplayer.is_server():
		return

	_pending_characters[player_id] = character
	if _pending_characters.size() >= 2:
		SignalBus.match_started.emit()
		_pending_characters.clear()

func _on_player_disconnected(_player_id: int) -> void:
	player_characters.erase(_player_id)
	player_health.erase(_player_id)
	player_mana.erase(_player_id)

func generate_mana(player_id: int) -> void:
	var character: CharacterData = player_characters.get(player_id, null)
	if character:
		player_mana[player_id] = character.mana

func spend_mana(player_id: int, amount: int) -> bool:
	var current: int = player_mana.get(player_id, 0)
	if current < amount:
		return false
	player_mana[player_id] = current - amount
	return true

@rpc("authority", "call_local", "reliable")
func _sync_match_state(phase: int, active_player: int, turn: int, health: Dictionary, mana: Dictionary) -> void:
	current_phase = phase as Enums.MatchState
	active_player_id = active_player
	turn_number = turn
	player_health = health
	player_mana = mana

func _exit_tree() -> void:
	if SignalBus.character_selected.is_connected(_on_character_selected):
		SignalBus.character_selected.disconnect(_on_character_selected)
	if SignalBus.player_disconnected.is_connected(_on_player_disconnected):
		SignalBus.player_disconnected.disconnect(_on_player_disconnected)
