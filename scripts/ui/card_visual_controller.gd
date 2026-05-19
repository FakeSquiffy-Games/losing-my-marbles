class_name CardVisualController
extends Control

const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 210.0
const HOLE_LEFT: int = 10
const HOLE_TOP: int = 10
const HOLE_WIDTH: int = 130
const HOLE_HEIGHT: int = 110

static var _frame_cache: Dictionary = {}
static var _back_texture: ImageTexture = null

var mana_label: Label = null
var name_label: Label = null
var desc_label: Label = null
var sprite_rect: TextureRect = null
var frame_rect: TextureRect = null


func apply_card_data(card_data: CardData) -> void:
	_ensure_nodes()
	frame_rect.texture = _get_frame(card_data.type)
	sprite_rect.texture = _get_card_sprite(card_data)
	mana_label.text = str(card_data.mana_cost)
	name_label.text = card_data.card_name
	desc_label.text = card_data.description if not card_data.description.is_empty() else ""
	_style_labels()


func _ensure_nodes() -> void:
	if frame_rect == null:
		frame_rect = %FrameRect
		sprite_rect = %SpriteRect
		mana_label = %ManaCostLabel
		name_label = %CardNameLabel
		desc_label = %CardDescLabel


func apply_back(back_rect: TextureRect) -> void:
	back_rect.texture = _get_back()


func _style_labels() -> void:
	var outline_color := Color.BLACK
	for label: Label in [mana_label, name_label, desc_label]:
		label.add_theme_color_override("font_outline_color", outline_color)
		label.add_theme_constant_override("outline_size", 2)

	mana_label.add_theme_font_size_override("font_size", 16)
	mana_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))

	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)

	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


# -- Frame generation (type-specific, cached) --

static func _get_frame(type: int) -> ImageTexture:
	if type in _frame_cache:
		return _frame_cache[type]
	var tex := _make_frame(type)
	_frame_cache[type] = tex
	return tex


static func _make_frame(type: int) -> ImageTexture:
	var image := Image.create(int(CARD_WIDTH), int(CARD_HEIGHT), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var fill := _frame_fill(type)
	var accent := _frame_accent(type)
	var hole_right := HOLE_LEFT + HOLE_WIDTH
	var hole_bottom := HOLE_TOP + HOLE_HEIGHT

	for x in int(CARD_WIDTH):
		for y in int(CARD_HEIGHT):
			if x >= HOLE_LEFT and x < hole_right and y >= HOLE_TOP and y < hole_bottom:
				continue
			image.set_pixel(x, y, fill)

	# Outer border 2px
	for x in int(CARD_WIDTH):
		image.set_pixel(x, 0, accent); image.set_pixel(x, 1, accent)
		image.set_pixel(x, int(CARD_HEIGHT) - 1, accent); image.set_pixel(x, int(CARD_HEIGHT) - 2, accent)
	for y in int(CARD_HEIGHT):
		image.set_pixel(0, y, accent); image.set_pixel(1, y, accent)
		image.set_pixel(int(CARD_WIDTH) - 1, y, accent); image.set_pixel(int(CARD_WIDTH) - 2, y, accent)

	# Inner border around hole
	for x in range(HOLE_LEFT - 1, hole_right + 1):
		image.set_pixel(x, HOLE_TOP - 1, accent)
		image.set_pixel(x, hole_bottom, accent)
	for y in range(HOLE_TOP - 1, hole_bottom + 1):
		image.set_pixel(HOLE_LEFT - 1, y, accent)
		image.set_pixel(hole_right, y, accent)

	return ImageTexture.create_from_image(image)


static func _frame_fill(type: int) -> Color:
	match type:
		0: return Color(0.18, 0.10, 0.08, 1.0)   # MARBLE
		1: return Color(0.08, 0.12, 0.22, 1.0)    # POWER_UP
		2: return Color(0.08, 0.20, 0.10, 1.0)    # TRICK
		3: return Color(0.20, 0.16, 0.10, 1.0)    # TERRAIN
		4: return Color(0.18, 0.10, 0.22, 1.0)    # AoE
	return Color(0.1, 0.1, 0.1, 1.0)


static func _frame_accent(type: int) -> Color:
	match type:
		0: return Color(0.9, 0.45, 0.25, 1.0)     # MARBLE
		1: return Color(0.25, 0.50, 0.9, 1.0)     # POWER_UP
		2: return Color(0.25, 0.80, 0.35, 1.0)    # TRICK
		3: return Color(0.65, 0.50, 0.30, 1.0)    # TERRAIN
		4: return Color(0.65, 0.35, 0.80, 1.0)    # AoE
	return Color.WHITE


# -- Sprite generation (procedural placeholder) --

static func _make_sprite(type: int) -> ImageTexture:
	var image := Image.create(HOLE_WIDTH, HOLE_HEIGHT, false, Image.FORMAT_RGBA8)
	var base := _frame_accent(type)
	var dark := base.darkened(0.55)
	base.a = 0.6

	var cx := HOLE_WIDTH / 2.0
	var cy := HOLE_HEIGHT / 2.0
	var r := min(HOLE_WIDTH, HOLE_HEIGHT) / 3.5

	for x in HOLE_WIDTH:
		for y in HOLE_HEIGHT:
			var dist := Vector2(x - cx, y - cy).length()
			if dist < r:
				image.set_pixel(x, y, base)
			else:
				var t := clampf((dist - r) / (r * 0.7), 0.0, 1.0)
				image.set_pixel(x, y, dark.lerp(Color(0.05, 0.05, 0.08, 1.0), t))

	return ImageTexture.create_from_image(image)


static func _type_subdir(type: int) -> String:
	match type:
		0: return "marbles"
		1: return "power_ups"
		2: return "tricks"
		3: return "terrain"
		4: return "aoe"
	return "marbles"


static func _get_card_sprite(card_data: CardData) -> ImageTexture:
	var path := "res://assets/sprites/cards/%s/%s.png" % [_type_subdir(card_data.type), card_data.card_name.to_snake_case()]
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded
	return _make_sprite(card_data.type)


# -- Back face generation (cached) --

static func _get_back() -> ImageTexture:
	if _back_texture:
		return _back_texture
	_back_texture = _make_back()
	return _back_texture


static func _make_back() -> ImageTexture:
	var image := Image.create(int(CARD_WIDTH), int(CARD_HEIGHT), false, Image.FORMAT_RGBA8)
	image.fill(Color(0.08, 0.08, 0.22, 1.0))

	var accent := Color(0.15, 0.15, 0.40, 1.0)
	var cx := CARD_WIDTH / 2.0
	var cy := CARD_HEIGHT / 2.0
	var rx := 55.0
	var ry := 70.0

	for x in int(CARD_WIDTH):
		for y in int(CARD_HEIGHT):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy < 1.0:
				image.set_pixel(x, y, accent)

	return ImageTexture.create_from_image(image)
