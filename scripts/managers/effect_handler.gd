extends Node

## PlayContext — data carrier for PLAY-phase effect dispatch.
class PlayContext:
	extends RefCounted

	var active_player_id: int = 0
	var opponent_player_id: int = 0
	var current_marble: MarbleData = null
	var field_state_manager: FieldStateManager = null


## SimulationContext — data carrier for SIMULATION-phase effect dispatch.
class SimulationContext:
	extends RefCounted

	var knocker_player_id: int = 0
	var knocker_opp_player_id: int = 0
	var field_state_manager: FieldStateManager = null
	var multiplier: float = 1.0


var _registry: Dictionary = {}


func _ready() -> void:
	SignalBus.marble_knocked_out.connect(_on_marble_knocked_out)


func dispatch_play_effects(card: CardData, context: PlayContext) -> void:
	print("[EffectHandler] dispatch_play_effects — card='%s' effects=%d player=%d" % [card.card_name, card.effects.size(), context.active_player_id])

	for effect: EffectData in card.effects:
		if effect.trigger != Enums.TriggerEnum.PLAY:
			continue
		var callable: Callable = _registry.get(effect.effect_id, Callable())
		if not callable.is_valid():
			push_warning("[EffectHandler] No handler registered for effect_id: '%s'" % effect.effect_id)
			continue
		var targets: Array = _resolve_target(effect, context)
		if targets.is_empty():
			continue
		callable.call(effect, targets, context)


func dispatch_simulation_effects(marble: MarbleData, context: SimulationContext) -> void:
	print("[EffectHandler] dispatch_simulation_effects — marble='%s' effects=%d knocker=%d multiplier=%.1f" % [marble.card_name, marble.effects.size(), context.knocker_player_id, context.multiplier])

	for effect: EffectData in marble.effects:
		if effect.trigger != Enums.TriggerEnum.SIMULATION:
			continue
		var callable: Callable = _registry.get(effect.effect_id, Callable())
		if not callable.is_valid():
			push_warning("[EffectHandler] No handler registered for effect_id: '%s'" % effect.effect_id)
			continue
		var targets: Array = _resolve_target(effect, context)
		if targets.is_empty():
			continue
		callable.call(effect, targets, context)


func _resolve_target(effect: EffectData, context: Variant) -> Array:
	return []


func _on_marble_knocked_out(marble_data: MarbleData, knocked_player_id: int) -> void:
	var context := SimulationContext.new()
	context.knocker_player_id = MatchManager.active_player_id
	context.knocker_opp_player_id = 3 - MatchManager.active_player_id
	context.field_state_manager = FieldStateManager
	context.multiplier = MatchManager.get_active_multiplier() if MatchManager.has_method("get_active_multiplier") else 1.0
	dispatch_simulation_effects(marble_data, context)


func _exit_tree() -> void:
	if SignalBus.marble_knocked_out.is_connected(_on_marble_knocked_out):
		SignalBus.marble_knocked_out.disconnect(_on_marble_knocked_out)
