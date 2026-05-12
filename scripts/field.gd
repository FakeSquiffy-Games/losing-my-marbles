extends Node2D

const FIELD_WIDTH: float = 900.0
const FIELD_HEIGHT: float = 500.0
const WALL_THICKNESS: float = 12.0

@onready var _gravity_zone: Area2D = %GravityZone

var gravity_direction: Vector2 = Vector2.DOWN
var gravity_magnitude: float = 980.0

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

func set_linear_damp(damp: float) -> void:
	for body in get_tree().get_nodes_in_group("field_marbles"):
		if body is RigidBody2D:
			body.linear_damp = damp
