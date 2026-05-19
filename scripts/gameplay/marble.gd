class_name Marble
extends RigidBody2D

const RADIUS: float = 15.0

var marble_data: MarbleData = null
var owner_player_id: int = 0
var _color: Color = Color.WHITE

var _sprite: Sprite2D = null


static func make_circle_texture(color: Color) -> ImageTexture:
	var size := int(RADIUS * 2 + 4)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in size:
		for y in size:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= RADIUS:
				image.set_pixel(x, y, color)
			elif dist <= RADIUS + 2.0:
				image.set_pixel(x, y, color.darkened(0.3))
	return ImageTexture.create_from_image(image)


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

	var tex: Texture2D = null
	if data and not data.card_name.is_empty():
		var path := "res://assets/sprites/marbles/%s.png" % data.card_name.to_snake_case()
		if ResourceLoader.exists(path):
			var loaded := ResourceLoader.load(path)
			if loaded is Texture2D:
				tex = loaded
	if not tex:
		tex = make_circle_texture(_color)
	if not _sprite:
		_sprite = get_node("%Sprite") as Sprite2D
	_sprite.texture = tex


func get_color() -> Color:
	return _color
