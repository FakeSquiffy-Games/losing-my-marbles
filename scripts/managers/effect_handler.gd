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
	_registry["deal_damage"] = _efx_deal_damage
	_registry["heal"] = _efx_heal
	_registry["drain_mana"] = _efx_drain_mana
	_registry["restore_mana"] = _efx_restore_mana
	_registry["set_linear_damp"] = _efx_set_linear_damp
	_registry["set_gravity"] = _efx_set_gravity
	_registry["apply_aoe"] = _efx_apply_aoe
	_registry["clear_terrain"] = _efx_clear_terrain


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
		var scaled := effect.duplicate() as EffectData
		scaled.value *= context.multiplier
		callable.call(scaled, targets, context)


func _resolve_target(effect: EffectData, context: Variant) -> Array:
	if context is PlayContext:
		return _resolve_play_target(effect, context as PlayContext)
	if context is SimulationContext:
		return _resolve_simulation_target(effect, context as SimulationContext)
	push_error("[EffectHandler] _resolve_target: unknown context type '%s'" % context.get_class())
	return []


func _resolve_play_target(effect: EffectData, ctx: PlayContext) -> Array:
	match effect.target:
		Enums.TargetEnum.SELF:
			return [ctx.active_player_id]
		Enums.TargetEnum.OPPONENT:
			return [ctx.opponent_player_id]
		Enums.TargetEnum.CURR_MARBLE:
			return [ctx.current_marble] if ctx.current_marble else []
		Enums.TargetEnum.BOTH:
			return [ctx.active_player_id, ctx.opponent_player_id]
		Enums.TargetEnum.FIELD_MAP:
			return [ctx.field_state_manager] if ctx.field_state_manager else []
		Enums.TargetEnum.FIELD_MARBLES:
			return get_tree().get_nodes_in_group("field_marbles")
		_:
			push_warning("[EffectHandler] Target '%s' is not valid in PLAY context" % Enums.TargetEnum.keys()[effect.target])
			return []


func _resolve_simulation_target(effect: EffectData, ctx: SimulationContext) -> Array:
	match effect.target:
		Enums.TargetEnum.KNOCKER:
			return [ctx.knocker_player_id]
		Enums.TargetEnum.KNOCKER_OPP:
			return [ctx.knocker_opp_player_id]
		Enums.TargetEnum.BOTH:
			return [ctx.knocker_player_id, ctx.knocker_opp_player_id]
		Enums.TargetEnum.FIELD_MAP:
			return [ctx.field_state_manager] if ctx.field_state_manager else []
		Enums.TargetEnum.FIELD_MARBLES:
			return get_tree().get_nodes_in_group("field_marbles")
		_:
			push_warning("[EffectHandler] Target '%s' is not valid in SIMULATION context" % Enums.TargetEnum.keys()[effect.target])
			return []


func _efx_deal_damage(effect: EffectData, targets: Array, _ctx: Variant) -> void:
	for target in targets:
		var pid: int = target as int
		var current: int = MatchManager.player_health.get(pid, 0)
		var new_health: int = max(0, current - int(effect.value))
		MatchManager.player_health[pid] = new_health
		print("[EffectHandler] deal_damage: player %d takes %d damage (%d → %d)" % [pid, int(effect.value), current, new_health])


func _efx_heal(effect: EffectData, targets: Array, _ctx: Variant) -> void:
	for target in targets:
		var pid: int = target as int
		var character: CharacterData = MatchManager.player_characters.get(pid, null)
		var max_hp: int = character.health if character else 100
		var current: int = MatchManager.player_health.get(pid, 0)
		var new_health: int = min(max_hp, current + int(effect.value))
		MatchManager.player_health[pid] = new_health
		print("[EffectHandler] heal: player %d restored %d health (%d → %d)" % [pid, int(effect.value), current, new_health])


func _efx_drain_mana(effect: EffectData, targets: Array, _ctx: Variant) -> void:
	for target in targets:
		var pid: int = target as int
		var current: int = MatchManager.player_mana.get(pid, 0)
		var new_mana: int = max(0, current - int(effect.value))
		MatchManager.player_mana[pid] = new_mana
		print("[EffectHandler] drain_mana: player %d loses %d mana (%d → %d)" % [pid, int(effect.value), current, new_mana])


func _efx_restore_mana(effect: EffectData, targets: Array, _ctx: Variant) -> void:
	for target in targets:
		var pid: int = target as int
		var character: CharacterData = MatchManager.player_characters.get(pid, null)
		var max_mana: int = character.mana * 2 if character else 6
		var current: int = MatchManager.player_mana.get(pid, 0)
		var new_mana: int = min(max_mana, current + int(effect.value))
		MatchManager.player_mana[pid] = new_mana
		print("[EffectHandler] restore_mana: player %d gains %d mana (%d → %d)" % [pid, int(effect.value), current, new_mana])


func _efx_set_linear_damp(effect: EffectData, _targets: Array, _ctx: Variant) -> void:
	FieldStateManager.set_terrain_delta("linear_damp", effect.value)
	print("[EffectHandler] set_linear_damp: field linear_damp terrain delta = %.2f" % effect.value)


func _efx_set_gravity(effect: EffectData, _targets: Array, _ctx: Variant) -> void:
	FieldStateManager.set_terrain_delta("gravity_magnitude", effect.value)
	print("[EffectHandler] set_gravity: field gravity terrain delta = %.2f" % effect.value)


func _efx_apply_aoe(effect: EffectData, _targets: Array, _ctx: Variant) -> void:
	var duration: int = 2
	var delta: Dictionary = {"linear_damp": effect.value}
	FieldStateManager.add_aoe_delta(delta, duration)
	print("[EffectHandler] apply_aoe: linear_damp AOE delta %.2f for %d turns" % [effect.value, duration])


func _efx_clear_terrain(_effect: EffectData, _targets: Array, _ctx: Variant) -> void:
	FieldStateManager.clear_terrain_delta("linear_damp")
	FieldStateManager.clear_terrain_delta("gravity_magnitude")
	print("[EffectHandler] clear_terrain: cleared all terrain deltas")


func _on_marble_knocked_out(marble_data: MarbleData, knocked_player_id: int) -> void:
	MatchManager.increment_knockout()
	var context := SimulationContext.new()
	context.knocker_player_id = MatchManager.active_player_id
	context.knocker_opp_player_id = 3 - MatchManager.active_player_id
	context.field_state_manager = FieldStateManager
	context.multiplier = MatchManager.get_active_multiplier()
	dispatch_simulation_effects(marble_data, context)


func _exit_tree() -> void:
	if SignalBus.marble_knocked_out.is_connected(_on_marble_knocked_out):
		SignalBus.marble_knocked_out.disconnect(_on_marble_knocked_out)
