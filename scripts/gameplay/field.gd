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
	_setup_boundary_detector()

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

func _setup_boundary_detector() -> void:
	var boundary := Area2D.new()
	boundary.name = "BoundaryDetector"
	boundary.collision_layer = 0
	boundary.collision_mask = 1
	boundary.monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(FIELD_WIDTH + 60.0, FIELD_HEIGHT + 60.0)
	shape.shape = rect
	shape.position = Vector2(FIELD_WIDTH / 2.0, FIELD_HEIGHT / 2.0)

	boundary.add_child(shape)
	boundary.body_exited.connect(_on_marble_exited_boundary)
	add_child(boundary)

func _on_marble_exited_boundary(body: Node2D) -> void:
	if body is Marble:
		print("[Field] Marble exited boundary — player=%d" % body.owner_player_id)
		SignalBus.marble_exited_boundary.emit(body as Marble)
