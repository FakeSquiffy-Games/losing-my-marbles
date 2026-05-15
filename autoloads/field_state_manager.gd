extends Node

const DEFAULT_GRAVITY_MAGNITUDE: float = 0.0
const DEFAULT_GRAVITY_DIRECTION: Vector2 = Vector2.ZERO
const DEFAULT_LINEAR_DAMP: float = 2.0

var _map_base: Dictionary = {}
var _terrain_delta: Dictionary = {}
var _aoe_deltas: Array[Dictionary] = []

func _ready() -> void:
	_map_base = {
		"gravity_magnitude": DEFAULT_GRAVITY_MAGNITUDE,
		"gravity_direction": DEFAULT_GRAVITY_DIRECTION,
		"linear_damp": DEFAULT_LINEAR_DAMP,
	}
	call_deferred("recalculate")

func apply_map_base(properties: Dictionary) -> void:
	for key in properties:
		_map_base[key] = properties[key]
	recalculate()

func set_terrain_delta(key: String, value: Variant) -> void:
	_terrain_delta[key] = value
	recalculate()

func clear_terrain_delta(key: String) -> void:
	_terrain_delta.erase(key)
	recalculate()

func add_aoe_delta(delta: Dictionary, turns_remaining: int = 0) -> int:
	var idx := _aoe_deltas.size()
	delta["turns_remaining"] = turns_remaining
	_aoe_deltas.append(delta)
	recalculate()
	return idx

func remove_aoe_delta(idx: int) -> void:
	if idx >= 0 and idx < _aoe_deltas.size():
		_aoe_deltas.remove_at(idx)
		recalculate()

func tick_aoe_durations() -> void:
	var changed := false
	var i := _aoe_deltas.size() - 1
	while i >= 0:
		var aoe: Dictionary = _aoe_deltas[i]
		if aoe.has("turns_remaining"):
			aoe["turns_remaining"] = aoe["turns_remaining"] - 1
			if aoe["turns_remaining"] <= 0:
				_aoe_deltas.remove_at(i)
			changed = true
		i -= 1
	if changed:
		recalculate()

func recalculate() -> void:
	var effective := _compute_effective()
	push_to_engine(effective)

func push_to_engine(effective: Dictionary) -> void:
	var fields := get_tree().get_nodes_in_group("game_field")
	if fields.is_empty():
		return

	var field := fields[0]
	var gravity_dir: Vector2 = effective.get("gravity_direction", DEFAULT_GRAVITY_DIRECTION)
	var gravity_mag: float = effective.get("gravity_magnitude", DEFAULT_GRAVITY_MAGNITUDE)
	var damp: float = effective.get("linear_damp", DEFAULT_LINEAR_DAMP)

	field.set_gravity(gravity_dir, gravity_mag)
	field.set_linear_damp(damp)

func _compute_effective() -> Dictionary:
	var result := _map_base.duplicate()
	for key in _terrain_delta:
		if result.has(key):
			result[key] = result[key] + _terrain_delta[key]
		else:
			result[key] = _terrain_delta[key]
	for aoe in _aoe_deltas:
		for key in aoe:
			if result.has(key):
				result[key] = result[key] + aoe[key]
			else:
				result[key] = aoe[key]
	return result
