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
	call_deferred("_push_to_field")

func apply_map_base(properties: Dictionary) -> void:
	for key in properties:
		_map_base[key] = properties[key]
	_push_to_field()

func set_terrain_delta(key: String, value: Variant) -> void:
	_terrain_delta[key] = value
	_push_to_field()

func clear_terrain_delta(key: String) -> void:
	_terrain_delta.erase(key)
	_push_to_field()

func add_aoe_delta(delta: Dictionary) -> int:
	var idx := _aoe_deltas.size()
	_aoe_deltas.append(delta)
	_push_to_field()
	return idx

func remove_aoe_delta(idx: int) -> void:
	if idx >= 0 and idx < _aoe_deltas.size():
		_aoe_deltas.remove_at(idx)
		_push_to_field()

func _get_effective() -> Dictionary:
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

func _push_to_field() -> void:
	var fields := get_tree().get_nodes_in_group("game_field")
	if fields.is_empty():
		return

	var field := fields[0]
	var effective := _get_effective()

	var gravity_dir: Vector2 = effective.get("gravity_direction", DEFAULT_GRAVITY_DIRECTION)
	var gravity_mag: float = effective.get("gravity_magnitude", DEFAULT_GRAVITY_MAGNITUDE)
	var damp: float = effective.get("linear_damp", DEFAULT_LINEAR_DAMP)

	field.set_gravity(gravity_dir, gravity_mag)
	field.set_linear_damp(damp)
