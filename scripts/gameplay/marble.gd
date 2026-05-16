class_name Marble
extends RigidBody2D

const RADIUS: float = 15.0

var marble_data: MarbleData = null
var owner_player_id: int = 0
var _color: Color = Color.WHITE

func setup(data: MarbleData, player_id: int, color: Color) -> void:
	marble_data = data
	owner_player_id = player_id
	_color = color

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	if data and data.physics:
		linear_damp = data.physics.friction
		mass = data.physics.weight
		gravity_scale = data.physics.gravity_modifier

		var phys_mat := PhysicsMaterial.new()
		phys_mat.bounce = data.physics.elasticity
		physics_material_override = phys_mat

	add_to_group("field_marbles")
	queue_redraw()

func get_color() -> Color:
	return _color

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 16, _color.darkened(0.3), 2.0)
