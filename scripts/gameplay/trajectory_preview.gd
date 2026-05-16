class_name TrajectoryPreview
extends Node2D

const _Field := preload("res://scripts/gameplay/field.gd")

const THROTTLE_FLICK_DELTA: float = 0.01
const THROTTLE_ROTATION_DELTA: float = 0.5
const TRAJECTORY_EXTEND: float = 2000.0
const BOUNCE_DIRECTION_LENGTH: float = 100.0
const LINE_WIDTH: float = 2.0
const GHOST_ALPHA: float = 0.35

var _prev_flick: float = -INF
var _prev_rotation: float = -INF
var _trajectory_points: Array[Vector2] = []
var _hit_point: Vector2 = Vector2.ZERO
var _hit_direction: Vector2 = Vector2.ZERO
var _hit_color: Color = Color.WHITE

func _ready() -> void:
	SignalBus.aim_inputs_changed.connect(_on_aim_inputs_changed)
	SignalBus.phase_changed.connect(_on_phase_changed)
	hide()

func _on_phase_changed(phase: int) -> void:
	var match_phase := phase as Enums.MatchState
	visible = match_phase == Enums.MatchState.AIM
	if not visible:
		clear()

func _on_aim_inputs_changed(rotation_degrees: float, flick_power: float) -> void:
	if abs(flick_power - _prev_flick) < THROTTLE_FLICK_DELTA and abs(rotation_degrees - _prev_rotation) < THROTTLE_ROTATION_DELTA:
		return
	_prev_flick = flick_power
	_prev_rotation = rotation_degrees
	_update_prediction(rotation_degrees)

func _update_prediction(rotation_degrees: float) -> void:
	var field := get_parent() as Node2D
	var shooter_pos: Vector2 = field.get_shooter_position()
	if shooter_pos == Vector2.ZERO:
		clear()
		return

	var direction := Vector2.LEFT.rotated(deg_to_rad(rotation_degrees))
	var marbles: Array[Vector2] = field.get_field_marble_positions()
	var result := _simulate_trajectory(shooter_pos, direction, marbles)
	_trajectory_points = result[0] as Array[Vector2]
	_hit_point = result[1] as Vector2
	_hit_direction = result[2] as Vector2
	_hit_color = result[3] as Color
	queue_redraw()

func _simulate_trajectory(origin: Vector2, direction: Vector2, marbles: Array[Vector2]) -> Array:
	var points: Array[Vector2] = [origin]
	var pos := origin
	var dir := direction.normalized()
	var entry_radius := _Field.FIELD_RADIUS - _Field.WALL_THICKNESS - Marble.RADIUS

	if origin.distance_to(_Field.FIELD_CENTER) > entry_radius:
		# Shooter outside field — compute entry point (passes through wall)
		var entry := _circle_ray_intersection(pos, dir, _Field.FIELD_CENTER, entry_radius)
		if entry == Vector2.ZERO:
			points.append(pos + dir * TRAJECTORY_EXTEND)
			return [points, Vector2.ZERO, Vector2.ZERO, Color.WHITE]
		points.append(entry)
		pos = entry + dir * 0.5
	else:
		# Shooter already inside field — start directly from origin
		points.append(origin + dir * 0.1)
		pos = origin + dir * (Marble.RADIUS + 1.0)

	# Find nearest marble hit (wall excluded — passes through if no hit)
	var nearest := _find_nearest_marble_hit(pos, dir, marbles)
	if nearest.is_empty():
		points.append(pos + dir * TRAJECTORY_EXTEND)
		return [points, Vector2.ZERO, Vector2.ZERO, Color.WHITE]

	var hit: Vector2 = nearest["hit"]
	var normal: Vector2 = nearest["normal"]
	var color: Color = nearest["color"]

	points.append(hit)
	var bounce_dir := dir.bounce(normal)
	points.append(hit + bounce_dir * BOUNCE_DIRECTION_LENGTH)
	return [points, hit, bounce_dir, color]

static func _circle_ray_intersection(origin: Vector2, dir: Vector2, center: Vector2, radius: float) -> Vector2:
	var oc := origin - center
	var a := dir.dot(dir)
	var b := 2.0 * oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return Vector2.ZERO
	var t1 := (-b - sqrt(disc)) / (2.0 * a)
	var t2 := (-b + sqrt(disc)) / (2.0 * a)
	var t := INF
	if t1 > 0.001: t = t1
	if t2 > 0.001 and t2 < t: t = t2
	if t == INF:
		return Vector2.ZERO
	return origin + dir * t

static func _find_nearest_marble_hit(origin: Vector2, dir: Vector2, marbles: Array[Vector2]) -> Dictionary:
	var best_t := INF
	var best_hit := Vector2.ZERO
	var best_normal := Vector2.ZERO
	var best_color := Color.WHITE
	var combined_radius := Marble.RADIUS * 2.0

	for mp: Vector2 in marbles:
		var m_hit := _circle_ray_intersection(origin, dir, mp, combined_radius)
		if m_hit == Vector2.ZERO:
			continue
		var t := origin.distance_squared_to(m_hit)
		if t < best_t:
			best_t = t
			best_hit = m_hit
			best_normal = (m_hit - mp).normalized()
			best_color = Color(1.0, 0.85, 0.3, 0.8)

	if best_t == INF:
		return {}
	return {"hit": best_hit, "normal": best_normal, "color": best_color}

func _draw() -> void:
	if _trajectory_points.size() < 2:
		return

	var n := _trajectory_points.size()

	# Entry line: shooter → field entry (white)
	draw_line(_trajectory_points[0], _trajectory_points[1], Color(1.0, 1.0, 1.0, 0.9), LINE_WIDTH, true)

	if n >= 3:
		# Pre-bounce line: entry → hit point (or extension if no hit)
		draw_line(_trajectory_points[1], _trajectory_points[2], Color(1.0, 0.95, 0.6, 0.6), LINE_WIDTH, true)

		# Ghost marble marker at hit point (only when there is an actual hit)
		if _hit_point != Vector2.ZERO:
			var ghost_color := _hit_color
			ghost_color.a = GHOST_ALPHA
			draw_circle(_hit_point, Marble.RADIUS, ghost_color)
			draw_arc(_hit_point, Marble.RADIUS, 0, TAU, 16, ghost_color.darkened(0.4), 2.0)

	if n >= 4:
		# Post-bounce direction line (dashed)
		var from := _trajectory_points[2]
		var to := _trajectory_points[3]
		var dash_len := 8.0
		var gap_len := 6.0
		var seg_dir := (to - from).normalized()
		var seg_dist := from.distance_to(to)
		var drawn := 0.0
		while drawn < seg_dist:
			var seg_end: float = drawn + dash_len
			if seg_end > seg_dist:
				seg_end = seg_dist
			draw_line(from + seg_dir * drawn, from + seg_dir * seg_end, Color(1.0, 0.5, 0.2, 0.5), 1.5, true)
			drawn = seg_end + gap_len

func clear() -> void:
	_trajectory_points.clear()
	_hit_point = Vector2.ZERO
	_hit_direction = Vector2.ZERO
	queue_redraw()
