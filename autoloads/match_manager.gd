extends Node

enum MatchPhase {
	PRE_MATCH = 0,
	INIT      = 1,
	DRAW      = 2,
	PLAY      = 3,
	AIM       = 4,
	SIMULATING = 5,
	END_TURN  = 6,
	MATCH_OVER = 7,
}

var current_phase: MatchPhase = MatchPhase.PRE_MATCH
var active_player_id: int = 1
var turn_number: int = 0

var player_health: Dictionary = {}
var player_mana: Dictionary = {}
var player_characters: Dictionary = {}
var _pending_characters: Dictionary = {}

func _ready() -> void:
	SignalBus.character_selected.connect(_on_character_selected)
	SignalBus.player_disconnected.connect(_on_player_disconnected)

func set_phase(phase: MatchPhase) -> void:
	if not multiplayer.is_server():
		return
	current_phase = phase
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
	current_phase = phase as MatchPhase
	active_player_id = active_player
	turn_number = turn
	player_health = health
	player_mana = mana

func _exit_tree() -> void:
	if SignalBus.character_selected.is_connected(_on_character_selected):
		SignalBus.character_selected.disconnect(_on_character_selected)
	if SignalBus.player_disconnected.is_connected(_on_player_disconnected):
		SignalBus.player_disconnected.disconnect(_on_player_disconnected)
