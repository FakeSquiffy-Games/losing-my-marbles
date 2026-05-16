class_name TrajectoryPreview
extends Node2D

const _Field := preload("res://scripts/gameplay/field.gd")

const THROTTLE_ROTATION_DELTA: float = 0.5
const TRAJECTORY_EXTEND: float = 2000.0
const LINE_WIDTH: float = 2.0
const GHOST_ALPHA: float = 0.35

var _prev_rotation: float = -INF
var _origin_point: Vector2 = Vector2.ZERO
var _end_point: Vector2 = Vector2.ZERO
var _hit_point: Vector2 = Vector2.ZERO
var _hit_color: Color = Color.WHITE
var _has_data: bool = false

func _ready() -> void:
	SignalBus.aim_inputs_changed.connect(_on_aim_inputs_changed)
	SignalBus.phase_changed.connect(_on_phase_changed)
	hide()

func _on_phase_changed(phase: int) -> void:
	var match_phase := phase as Enums.MatchState
	visible = match_phase == Enums.MatchState.AIM
	if visible:
		_prev_rotation = -INF
	else:
		clear()

func _on_aim_inputs_changed(rotation_degrees: float, _flick_power: float) -> void:
	if abs(rotation_degrees - _prev_rotation) < THROTTLE_ROTATION_DELTA:
		return
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
	_origin_point = shooter_pos
	_end_point = result.get("end", shooter_pos + direction * TRAJECTORY_EXTEND)
	_hit_point = result.get("hit", Vector2.ZERO)
	_hit_color = result.get("color", Color.WHITE)
	_has_data = true
	queue_redraw()

func _simulate_trajectory(origin: Vector2, direction: Vector2, marbles: Array[Vector2]) -> Dictionary:
	var dir := direction.normalized()
	var entry_radius := _Field.FIELD_RADIUS - _Field.WALL_THICKNESS - Marble.RADIUS
	var start_pos: Vector2

	if origin.distance_to(_Field.FIELD_CENTER) > entry_radius:
		var entry := _circle_ray_intersection(origin, dir, _Field.FIELD_CENTER, entry_radius)
		if entry == Vector2.ZERO:
			return {"end": origin + dir * TRAJECTORY_EXTEND, "hit": Vector2.ZERO}
		start_pos = entry + dir * 0.5
	else:
		start_pos = origin + dir * (Marble.RADIUS + 1.0)

	var nearest := _find_nearest_marble_hit(start_pos, dir, marbles)
	if nearest.is_empty():
		return {"end": start_pos + dir * TRAJECTORY_EXTEND, "hit": Vector2.ZERO}

	var hit: Vector2 = nearest["hit"]
	return {"end": hit, "hit": hit, "color": nearest["color"]}

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
	if not _has_data:
		return

	draw_line(_origin_point, _end_point, Color(1.0, 0.95, 0.6, 0.85), LINE_WIDTH, true)

	if _hit_point != Vector2.ZERO:
		var ghost_color := _hit_color
		ghost_color.a = GHOST_ALPHA
		draw_circle(_hit_point, Marble.RADIUS, ghost_color)
		draw_arc(_hit_point, Marble.RADIUS, 0, TAU, 16, ghost_color.darkened(0.4), 2.0)

func clear() -> void:
	_origin_point = Vector2.ZERO
	_end_point = Vector2.ZERO
	_hit_point = Vector2.ZERO
	_has_data = false
	queue_redraw()
