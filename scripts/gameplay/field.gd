extends Node2D

const FIELD_RADIUS: float = 220.0
const FIELD_CENTER: Vector2 = Vector2(450.0, 250.0)
const WALL_THICKNESS: float = 12.0
const MARBLE_SCENE := preload("res://scenes/gameplay/marble.tscn")

const SHOOTER_FOCUS_PRIORITY: int = 20
const BOARD_OVERVIEW_PRIORITY: int = 10
const SHOOTER_SPAWN_DIST: float = FIELD_RADIUS - WALL_THICKNESS - Marble.RADIUS - 2.0

@onready var _background: ColorRect = %Background
@onready var _gravity_zone: Area2D = %GravityZone
@onready var _board_cam: PhantomCamera2D = %BoardOverviewCamera

var _shooter_cam: PhantomCamera2D
var _shooter_sample_marble: Marble = null
var _trajectory_preview: TrajectoryPreview
var _bodies_inside_boundary: Array[int] = []
var gravity_direction: Vector2 = Vector2.ZERO
var gravity_magnitude: float = 0.0

func _ready() -> void:
	add_to_group("game_field")
	_apply_gravity()
	_update_gravity_shape()
	_setup_boundary_detector()
	_setup_shooter_camera()
	_setup_trajectory_preview()
	$Camera2D.ignore_rotation = false
	_background.visible = false
	queue_redraw()
	SignalBus.phase_changed.connect(_on_phase_changed_for_camera)
	SignalBus.phase_changed.connect(_on_phase_changed_for_shooter_marble)

func _draw() -> void:
	draw_circle(FIELD_CENTER, FIELD_RADIUS, Color(0.15, 0.2, 0.15, 1.0))
	draw_arc(FIELD_CENTER, FIELD_RADIUS, 0, TAU, 72, Color(0.25, 0.35, 0.25, 1.0), WALL_THICKNESS)

func _update_gravity_shape() -> void:
	var shape_node := _gravity_zone.get_node_or_null("CollisionShape2D")
	if shape_node:
		var circle := CircleShape2D.new()
		circle.radius = FIELD_RADIUS + 40.0
		shape_node.shape = circle
		shape_node.position = FIELD_CENTER

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

func set_map_rotation(degrees: float) -> void:
	_board_cam.rotation_degrees = degrees
	if _shooter_cam:
		_shooter_cam.rotation_degrees = degrees
	_update_shooter_marble_position(degrees)

func _update_shooter_marble_position(degrees: float) -> void:
	if not is_instance_valid(_shooter_sample_marble):
		return
	_shooter_sample_marble.position = FIELD_CENTER + Vector2.RIGHT.rotated(deg_to_rad(degrees)) * SHOOTER_SPAWN_DIST

func find_valid_position(preferred: Vector2, radius: float = Marble.RADIUS) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius + 4.0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4294967295
	query.transform = Transform2D(0, preferred)

	var results := space_state.intersect_shape(query, 1)
	if results.is_empty() and _is_inside_field(preferred, radius):
		return preferred

	var step := radius * 2.0 + 4.0
	for attempt: int in 25:
		var angle := float(attempt) * 0.618033988749895
		var dist := sqrt(float(attempt + 1)) * step
		var candidate := preferred + Vector2.RIGHT.rotated(angle) * dist
		if not _is_inside_field(candidate, radius):
			var to_center := FIELD_CENTER - candidate
			if to_center.length() > 0:
				candidate = FIELD_CENTER - to_center.normalized() * (FIELD_RADIUS - radius - WALL_THICKNESS - 4.0)
		query.transform = Transform2D(0, candidate)
		results = space_state.intersect_shape(query, 1)
		if results.is_empty() and _is_inside_field(candidate, radius):
			return candidate

	return preferred

func _is_inside_field(pos: Vector2, radius: float) -> bool:
	return pos.distance_to(FIELD_CENTER) + radius <= FIELD_RADIUS - WALL_THICKNESS - 2.0

func _setup_shooter_camera() -> void:
	_shooter_cam = PhantomCamera2D.new()
	_shooter_cam.name = "ShooterFocusCamera"
	_shooter_cam.position = FIELD_CENTER
	_shooter_cam.priority = 0
	add_child(_shooter_cam)

func _on_phase_changed_for_camera(phase: int) -> void:
	var match_phase: Enums.MatchState = phase as Enums.MatchState
	var is_aiming := match_phase == Enums.MatchState.AIM or match_phase == Enums.MatchState.SIMULATING
	_shooter_cam.set_priority(SHOOTER_FOCUS_PRIORITY if is_aiming else 0)

func _on_phase_changed_for_shooter_marble(phase: int) -> void:
	var match_phase: Enums.MatchState = phase as Enums.MatchState
	if match_phase == Enums.MatchState.AIM:
		_spawn_shooter_sample()
	elif match_phase != Enums.MatchState.SIMULATING:
		_despawn_shooter_sample()

func _spawn_shooter_sample() -> void:
	if is_instance_valid(_shooter_sample_marble):
		return
	var shooter_id := MatchManager.active_player_id
	var data := MarblePoolManager.get_marble()
	var color := Color.RED if shooter_id == 1 else Color.BLUE
	var pos := _get_shooter_spawn_pos(shooter_id)
	_shooter_sample_marble = spawn_marble(data, shooter_id, pos, color)
	_shooter_sample_marble.freeze = true

func _despawn_shooter_sample() -> void:
	if is_instance_valid(_shooter_sample_marble):
		_shooter_sample_marble.queue_free()
	_shooter_sample_marble = null

func activate_shooter_marble() -> Marble:
	var marble := _shooter_sample_marble
	_shooter_sample_marble = null
	if is_instance_valid(marble):
		marble.freeze = false
	return marble

func _get_shooter_spawn_pos(player_id: int) -> Vector2:
	return FIELD_CENTER + Vector2.RIGHT * SHOOTER_SPAWN_DIST

func get_shooter_position() -> Vector2:
	if is_instance_valid(_shooter_sample_marble):
		return _shooter_sample_marble.position
	return Vector2.ZERO

func get_field_marble_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("field_marbles"):
		if node is Marble and node != _shooter_sample_marble:
			positions.append((node as Node2D).position)
	return positions

func _setup_trajectory_preview() -> void:
	_trajectory_preview = TrajectoryPreview.new()
	_trajectory_preview.name = "TrajectoryPreview"
	add_child(_trajectory_preview)

func _setup_boundary_detector() -> void:
	var boundary := Area2D.new()
	boundary.name = "BoundaryDetector"
	boundary.collision_layer = 0
	boundary.collision_mask = 1
	boundary.monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FIELD_RADIUS + 30.0
	shape.shape = circle
	shape.position = FIELD_CENTER

	boundary.add_child(shape)
	boundary.body_entered.connect(_on_body_entered_boundary)
	boundary.body_exited.connect(_on_body_exited_boundary)
	add_child(boundary)

func _on_body_entered_boundary(body: Node2D) -> void:
	if body is Marble:
		var id := body.get_instance_id()
		if id not in _bodies_inside_boundary:
			_bodies_inside_boundary.append(id)

func _on_body_exited_boundary(body: Node2D) -> void:
	if body is Marble:
		var id := body.get_instance_id()
		if id in _bodies_inside_boundary:
			_bodies_inside_boundary.erase(id)
			print("[Field] Marble exited boundary — player=%d" % body.owner_player_id)
			SignalBus.marble_exited_boundary.emit(body as Marble)

func _exit_tree() -> void:
	if SignalBus.phase_changed.is_connected(_on_phase_changed_for_camera):
		SignalBus.phase_changed.disconnect(_on_phase_changed_for_camera)
	if SignalBus.phase_changed.is_connected(_on_phase_changed_for_shooter_marble):
		SignalBus.phase_changed.disconnect(_on_phase_changed_for_shooter_marble)
