class_name Marble
extends RigidBody2D

const RADIUS: float = 15.0
const MARBLE_COLOR := Color(0.82, 0.82, 0.85, 1.0)

var marble_data: MarbleData = null
var owner_player_id: int = 0

const SPRITE_TARGET_DIAMETER: float = RADIUS * 2.0

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


func setup(data: MarbleData, player_id: int) -> void:
	marble_data = data
	owner_player_id = player_id

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
	var tex_is_asset: bool = false
	if data and not data.card_name.is_empty():
		var path := "res://assets/sprites/marbles/%s.png" % data.card_name.to_snake_case()
		if ResourceLoader.exists(path):
			var loaded := ResourceLoader.load(path)
			if loaded is Texture2D:
				tex = loaded
				tex_is_asset = true
	if not tex:
		tex = make_circle_texture(MARBLE_COLOR)
	if not _sprite:
		_sprite = get_node("%Sprite") as Sprite2D
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex_is_asset:
		_sprite.scale = Vector2(SPRITE_TARGET_DIAMETER / tex.get_width(), SPRITE_TARGET_DIAMETER / tex.get_height())
	else:
		_sprite.scale = Vector2.ONE
		
	# --- ADDED: Collision Sound Configuration ---
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


# --- ADDED: Collision Handler Function ---
func _on_body_entered(_body: Node) -> void:
	AudioManager.play_ui_sound("collide")
