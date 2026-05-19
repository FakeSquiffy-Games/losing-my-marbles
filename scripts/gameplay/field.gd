extends Node2D

const FIELD_RADIUS: float = 220.0
const FIELD_CENTER: Vector2 = Vector2(450.0, 250.0)
const WALL_THICKNESS: float = 12.0
const MARBLE_SCENE := preload("res://scenes/gameplay/marble.tscn")

const SHOOTER_FOCUS_PRIORITY: int = 20
const BOARD_OVERVIEW_PRIORITY: int = 10
const SHOOTER_SPAWN_DIST: float = FIELD_RADIUS + Marble.RADIUS + 6.0
const SNAPSHOT_TICKS: int = 2
const SNAPSHOT_INTERVAL: float = 2.0 / 60.0
const SIMULATION_TIMEOUT: float = 10.0
const VELOCITY_THRESHOLD: float = 0.5
const ANGULAR_VELOCITY_THRESHOLD: float = 0.1
const SLEEP_CHECK_DELAY: float = 0.3

@onready var _background: ColorRect = %Background
@onready var _gravity_zone: Area2D = %GravityZone
@onready var _board_cam: PhantomCamera2D = %BoardOverviewCamera

var _shooter_cam: PhantomCamera2D
var _shooter_sample_marble: Marble = null
var _current_rotation_degrees: float = 0.0
var _trajectory_preview: TrajectoryPreview
var _client_marbles: Dictionary = {}
var _bodies_inside_boundary: Array[int] = []
var _exited_marbles: Array[Marble] = []
var _active_shooter_id: int = 0
var _snapshot_buffer: Array[Dictionary] = []
var _tick_counter: int = 0
var _sim_elapsed: float = 0.0
var _sim_active: bool = false
var gravity_direction: Vector2 = Vector2.ZERO
var gravity_magnitude: float = 0.0

func _ready() -> void:
	add_to_group("game_field")
	set_physics_process(true)
	_apply_gravity()
	_update_gravity_shape()
	_setup_boundary_detector()
	_setup_viewport_boundary()
	_setup_shooter_camera()
	_setup_trajectory_preview()
	$Camera2D.ignore_rotation = false
	_background.visible = false
	queue_redraw()
	SignalBus.phase_changed.connect(_on_phase_changed_for_camera)
	SignalBus.phase_changed.connect(_on_phase_changed_for_shooter_marble)
	SignalBus.phase_changed.connect(_on_phase_changed_for_simulation)

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

func spawn_marble(data: MarbleData, player_id: int, position: Vector2) -> Marble:
	var marble := MARBLE_SCENE.instantiate() as Marble
	marble.setup(data, player_id)
	marble.position = position
	add_child(marble)
	return marble

func sync_marbles_to_clients() -> void:
	if not multiplayer.is_server():
		return
	var data: Array[Dictionary] = []
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is Marble:
			var m := body as Marble
			data.append({
				"id": m.get_instance_id(),
				"pos_x": m.global_position.x,
				"pos_y": m.global_position.y,
				"pid": m.owner_player_id,
			})
	_sync_marble_state.rpc(data)

func get_client_marble(marble_id: int) -> ClientMarbleVisual:
	return _client_marbles.get(marble_id, null)

func set_linear_damp(damp: float) -> void:
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is RigidBody2D:
			body.linear_damp = damp

func set_map_rotation(degrees: float) -> void:
	_current_rotation_degrees = degrees
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
		if is_instance_valid(_shooter_sample_marble):
			_update_shooter_marble_position(_current_rotation_degrees)
	elif match_phase == Enums.MatchState.END_TURN:
		_despawn_shooter_sample()

func _spawn_shooter_sample() -> void:
	if is_instance_valid(_shooter_sample_marble):
		return
	var shooter_id := MatchManager.active_player_id
	var data := MarblePoolManager.get_marble()
	var pos := _get_shooter_spawn_pos(shooter_id)
	_shooter_sample_marble = spawn_marble(data, shooter_id, pos)
	_shooter_sample_marble.freeze = true
	_update_shooter_marble_position(_current_rotation_degrees)

func _despawn_shooter_sample() -> void:
	if is_instance_valid(_shooter_sample_marble):
		_shooter_sample_marble.queue_free()
	_shooter_sample_marble = null

func spawn_shooter_marble(data: MarbleData, player_id: int) -> void:
	if is_instance_valid(_shooter_sample_marble):
		_shooter_sample_marble.queue_free()
		_shooter_sample_marble = null

	var pos := _get_shooter_spawn_pos(player_id)
	_shooter_sample_marble = spawn_marble(data, player_id, pos)
	_shooter_sample_marble.freeze = true
	_update_shooter_marble_position(_current_rotation_degrees)
	print("[Field] Shooter marble spawned for player %d from card '%s'" % [player_id, data.card_name])

func activate_shooter_marble() -> Marble:
	var marble := _shooter_sample_marble
	_shooter_sample_marble = null
	if is_instance_valid(marble):
		marble.freeze = false
		_active_shooter_id = marble.get_instance_id()
	return marble

func _get_shooter_spawn_pos(player_id: int) -> Vector2:
	var preferred := FIELD_CENTER + Vector2.RIGHT * SHOOTER_SPAWN_DIST
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = Marble.RADIUS + 6.0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4294967295
	query.transform = Transform2D(0, preferred)

	if space_state.intersect_shape(query, 1).is_empty():
		return preferred

	var step := Marble.RADIUS * 2.0 + 4.0
	for attempt: int in 12:
		var angle := float(attempt) * 0.618033988749895
		var dist := sqrt(float(attempt + 1)) * step
		var candidate := preferred + Vector2.RIGHT.rotated(angle) * dist
		query.transform = Transform2D(0, candidate)
		if space_state.intersect_shape(query, 1).is_empty():
			return candidate

	return preferred

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
	circle.radius = FIELD_RADIUS
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
			_exited_marbles.append(body)
			SignalBus.marble_exited_boundary.emit(body as Marble)

func _physics_process(delta: float) -> void:
	if not _sim_active:
		return
	if not multiplayer.is_server():
		return

	_sim_elapsed += delta
	_tick_counter += 1

	if _tick_counter % SNAPSHOT_TICKS == 0:
		_capture_snapshot()
		if _sim_elapsed >= SLEEP_CHECK_DELAY:
			_check_simulation_complete()

	if _sim_elapsed >= SIMULATION_TIMEOUT:
		print("[Field] Simulation timeout — forcing completion")
		_finish_simulation()

func _on_phase_changed_for_simulation(phase: int) -> void:
	var match_phase := phase as Enums.MatchState
	if match_phase == Enums.MatchState.SIMULATING:
		_snapshot_buffer.clear()
		_exited_marbles.clear()
		_tick_counter = 0
		_sim_elapsed = 0.0
		_sim_active = true
		print("[Field] Simulation capture started")
	elif _sim_active:
		_sim_active = false
		print("[Field] Simulation capture stopped — %d snapshots captured" % _snapshot_buffer.size())

func _capture_snapshot() -> void:
	var frame: Dictionary = {}
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is RigidBody2D:
			frame[body.get_instance_id()] = {
				"pos": body.global_position,
				"vel": body.linear_velocity,
				"avel": body.angular_velocity,
				"pid": (body as Marble).owner_player_id,
			}
	_snapshot_buffer.append(frame)

func _check_simulation_complete() -> void:
	var marbles := get_tree().get_nodes_in_group("field_marbles")
	if marbles.is_empty():
		_finish_simulation()
		return

	for body in marbles:
		if body is RigidBody2D:
			if body.linear_velocity.length() >= VELOCITY_THRESHOLD:
				return
			if abs(body.angular_velocity) >= ANGULAR_VELOCITY_THRESHOLD:
				return
			if not body.sleeping and body.linear_velocity.length() > 0.01:
				return

	_finish_simulation()

func _finish_simulation() -> void:
	if not _sim_active:
		return
	_sim_active = false

	var final_state: Dictionary = {}
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is RigidBody2D:
			final_state[body.get_instance_id()] = {
				"pos": body.global_position,
				"vel": body.linear_velocity,
				"pid": (body as Marble).owner_player_id,
			}

	for marble in _exited_marbles:
		if is_instance_valid(marble):
			var marble_id: int = marble.get_instance_id()
			final_state.erase(marble_id)
			var is_shooter: bool = marble_id == _active_shooter_id
			if marble.marble_data and not is_shooter:
				MarblePoolManager.return_marble(marble.marble_data)
				SignalBus.marble_knocked_out.emit(marble.marble_data, marble.owner_player_id)
			marble.remove_from_group("field_marbles")
			marble.queue_free()
	_exited_marbles.clear()

	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is Marble and body != _shooter_sample_marble and not body.is_queued_for_deletion():
			if not _is_inside_field(body.global_position, Marble.RADIUS):
				var body_id: int = body.get_instance_id()
				final_state.erase(body_id)
				var is_shooter: bool = body_id == _active_shooter_id
				if body.marble_data and not is_shooter:
					MarblePoolManager.return_marble(body.marble_data)
					SignalBus.marble_knocked_out.emit(body.marble_data, body.owner_player_id)
				body.remove_from_group("field_marbles")
				body.queue_free()

	_resolve_marble_lifecycle(final_state)

	_check_field_empty_and_refill()

	print("[Field] Simulation finished — %d snapshots, %d marbles remaining" % [_snapshot_buffer.size(), final_state.size()])
	_sync_snapshot_replay.rpc(_snapshot_buffer, final_state)
	SignalBus.simulation_complete.emit(final_state)

func _resolve_marble_lifecycle(final_state: Dictionary) -> void:
	if _active_shooter_id == 0:
		return

	if _active_shooter_id in final_state:
		print("[Field] Shooter marble (id=%d) stayed on field — now a standard field marble" % _active_shooter_id)
	else:
		print("[Field] Shooter marble (id=%d) exited boundary — despawned, SIMULATION effects skipped" % _active_shooter_id)

	_active_shooter_id = 0

func _check_field_empty_and_refill() -> void:
	var field_marbles := get_tree().get_nodes_in_group("field_marbles")
	var has_marbles := false
	for body in field_marbles:
		if body is Marble and body != _shooter_sample_marble and not body.is_queued_for_deletion():
			has_marbles = true
			break
	if not has_marbles:
		print("[Field] Field empty — spawning 6 marbles from pool")
		_spawn_field_marbles_from_pool(6)

func _spawn_field_marbles_from_pool(count: int) -> void:
	var marbles := MarblePoolManager.draw_random(count)
	if marbles.is_empty():
		push_warning("[Field] Cannot refill field — pool returned no marbles")
		return

	const MARGIN: float = Marble.RADIUS + WALL_THICKNESS + 10.0
	const SPAWN_RADIUS: float = FIELD_RADIUS - MARGIN

	for i: int in marbles.size():
		var data := marbles[i]
		var angle := randf() * TAU
		var dist := randf() * SPAWN_RADIUS * 0.5
		var preferred := FIELD_CENTER + Vector2.RIGHT.rotated(angle) * dist
		var pos := find_valid_position(preferred, Marble.RADIUS)
		var pid := (i % 2) + 1
		spawn_marble(data, pid, pos)

	print("[Field] Spawned %d marbles from pool at random center positions" % marbles.size())

func _setup_viewport_boundary() -> void:
	const VIEWPORT_EXTENTS := Vector2(380.0, 330.0)
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = 0.0
	wall_material.friction = 1.0

	_create_wall_segment(Vector2(FIELD_CENTER.x - VIEWPORT_EXTENTS.x, FIELD_CENTER.y), Vector2(6.0, VIEWPORT_EXTENTS.y * 2.0), wall_material)
	_create_wall_segment(Vector2(FIELD_CENTER.x + VIEWPORT_EXTENTS.x, FIELD_CENTER.y), Vector2(6.0, VIEWPORT_EXTENTS.y * 2.0), wall_material)
	_create_wall_segment(Vector2(FIELD_CENTER.x, FIELD_CENTER.y - VIEWPORT_EXTENTS.y), Vector2(VIEWPORT_EXTENTS.x * 2.0, 6.0), wall_material)
	_create_wall_segment(Vector2(FIELD_CENTER.x, FIELD_CENTER.y + VIEWPORT_EXTENTS.y), Vector2(VIEWPORT_EXTENTS.x * 2.0, 6.0), wall_material)

func _create_wall_segment(pos: Vector2, size: Vector2, material: PhysicsMaterial) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.physics_material_override = material
	wall.collision_layer = 1
	wall.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)

	var detector := Area2D.new()
	detector.collision_layer = 0
	detector.collision_mask = 1
	detector.monitoring = true
	var detector_shape := CollisionShape2D.new()
	var detector_rect := RectangleShape2D.new()
	detector_rect.size = size
	detector_shape.shape = detector_rect
	detector.add_child(detector_shape)
	detector.body_entered.connect(_on_viewport_wall_hit)
	wall.add_child(detector)

	add_child(wall)

func _on_viewport_wall_hit(body: Node2D) -> void:
	if body is RigidBody2D:
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0

@rpc("authority", "call_remote", "reliable")
func _sync_marble_state(data: Array) -> void:
	_clear_client_marbles()
	for entry: Dictionary in data:
		var marble_id: int = entry["id"]
		var pos := Vector2(entry["pos_x"], entry["pos_y"])
		var player_id: int = entry["pid"]
		_create_client_marble(marble_id, pos, player_id)

func _create_client_marble(marble_id: int, pos: Vector2, player_id: int) -> void:
	var visual := ClientMarbleVisual.new()
	visual.marble_id = marble_id
	visual.player_id = player_id
	visual.position = pos
	add_child(visual)
	_client_marbles[marble_id] = visual

func _clear_client_marbles() -> void:
	for visual in _client_marbles.values():
		if is_instance_valid(visual):
			visual.queue_free()
	_client_marbles.clear()

@rpc("authority", "call_remote", "reliable")
func _sync_snapshot_replay(_buffer: Array, _final_state: Dictionary) -> void:
	pass  # Client-side replay implemented in Sub-Phase 3.8

func _exit_tree() -> void:
	_clear_client_marbles()
	if SignalBus.phase_changed.is_connected(_on_phase_changed_for_camera):
		SignalBus.phase_changed.disconnect(_on_phase_changed_for_camera)
	if SignalBus.phase_changed.is_connected(_on_phase_changed_for_shooter_marble):
		SignalBus.phase_changed.disconnect(_on_phase_changed_for_shooter_marble)
	if SignalBus.phase_changed.is_connected(_on_phase_changed_for_simulation):
		SignalBus.phase_changed.disconnect(_on_phase_changed_for_simulation)
