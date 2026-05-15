extends Node2D

const FIELD_WIDTH: float = 900.0
const FIELD_HEIGHT: float = 500.0
const WALL_THICKNESS: float = 12.0
const MARBLE_SCENE := preload("res://scenes/gameplay/marble.tscn")

@onready var _gravity_zone: Area2D = %GravityZone

var gravity_direction: Vector2 = Vector2.ZERO
var gravity_magnitude: float = 0.0

func _ready() -> void:
	add_to_group("game_field")
	_apply_gravity()

func _apply_gravity() -> void:
	if _gravity_zone:
		_gravity_zone.gravity_direction = gravity_direction
		_gravity_zone.gravity = gravity_magnitude
		_gravity_zone.gravity_point = false

func set_gravity(direction: Vector2, magnitude: float) -> void:
	gravity_direction = direction
	gravity_magnitude = magnitude
	_apply_gravity()

func spawn_marble(data: MarbleData, player_id: int, position: Vector2, color: Color) -> Marble:
	var marble := MARBLE_SCENE.instantiate() as Marble
	marble.setup(data, player_id, color)
	marble.position = position
	add_child(marble)
	return marble

func set_linear_damp(damp: float) -> void:
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is RigidBody2D:
			body.linear_damp = damp

func find_valid_position(preferred: Vector2, radius: float = Marble.RADIUS) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius + 4.0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4294967295
	query.transform = Transform2D(0, preferred)

	var results := space_state.intersect_shape(query, 1)
	if results.is_empty():
		return preferred

	var step := radius * 2.0 + 4.0
	for attempt: int in 25:
		var angle := float(attempt) * 0.618033988749895  # golden angle
		var dist := sqrt(float(attempt + 1)) * step
		var candidate := preferred + Vector2.RIGHT.rotated(angle) * dist
		candidate.x = clampf(candidate.x, radius + WALL_THICKNESS, FIELD_WIDTH - radius - WALL_THICKNESS)
		candidate.y = clampf(candidate.y, radius + WALL_THICKNESS, FIELD_HEIGHT - radius - WALL_THICKNESS)
		query.transform = Transform2D(0, candidate)
		results = space_state.intersect_shape(query, 1)
		if results.is_empty():
			return candidate

	return preferred
