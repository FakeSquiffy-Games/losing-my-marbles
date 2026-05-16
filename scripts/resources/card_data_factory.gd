class_name CardDataFactory
extends CardFactory

const CARD_SCENE := preload("res://addons/card-framework/card.tscn")
const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 210.0

var _card_data_cache: Dictionary = {}

func preload_card_data() -> void:
	var library := CardLibrary.new()
	library.load_cards()
	for card_data: CardData in library.cards:
		_card_data_cache[card_data.card_name] = card_data
	print("[CardDataFactory] Preloaded %d card data resources" % _card_data_cache.size())

func create_card(card_name: String, target: CardContainer) -> Card:
	var card_data: CardData = _card_data_cache.get(card_name, null)
	if card_data == null:
		push_error("[CardDataFactory] No CardData found for: %s" % card_name)
		return null
	return create_card_from_data(card_data, target)

func create_card_from_data(card_data: CardData, target: CardContainer) -> Card:
	var card: Card = CARD_SCENE.instantiate() as Card
	card.card_size = card_size

	var color := _color_for_type(card_data.type)
	var front_tex_rect := card.get_node("FrontFace/TextureRect") as TextureRect
	front_tex_rect.texture = _make_placeholder_texture(color)
	front_tex_rect.size = card_size

	var back_face := card.get_node("BackFace") as Control
	back_face.offset_right = card_size.x
	back_face.offset_bottom = card_size.y

	var back_tex_rect := card.get_node("BackFace/TextureRect") as TextureRect
	back_tex_rect.texture = _make_placeholder_texture(Color(0.1, 0.1, 0.3, 1.0))
	back_tex_rect.size = card_size

	var front_face := card.get_node("FrontFace") as Control
	front_face.offset_right = card_size.x
	front_face.offset_bottom = card_size.y
	_add_label(front_face, "NameLabel", card_data.card_name, 14, Vector2(8, 8))
	_add_label(front_face, "ManaLabel", "Mana: %d" % card_data.mana_cost, 12, Vector2(8, 32))
	_add_label(front_face, "TypeLabel", _type_string(card_data.type), 10, Vector2(8, 52))

	card.card_name = card_data.card_name
	card.card_info = {"card_data": card_data}

	target.get_node("Cards").add_child(card)
	target.add_card(card)
	return card

func _color_for_type(type: Enums.CardTypeEnum) -> Color:
	match type:
		Enums.CardTypeEnum.MARBLE:          return Color(0.8, 0.3, 0.2, 1.0)
		Enums.CardTypeEnum.POWER_UP:        return Color(0.2, 0.4, 0.8, 1.0)
		Enums.CardTypeEnum.TRICK:           return Color(0.2, 0.7, 0.3, 1.0)
		Enums.CardTypeEnum.TERRAIN:         return Color(0.5, 0.4, 0.2, 1.0)
		Enums.CardTypeEnum.AREA_OF_EFFECT:  return Color(0.5, 0.2, 0.6, 1.0)
	return Color.GRAY

func _type_string(type: Enums.CardTypeEnum) -> String:
	match type:
		Enums.CardTypeEnum.MARBLE:          return "Marble"
		Enums.CardTypeEnum.POWER_UP:        return "Power-Up"
		Enums.CardTypeEnum.TRICK:           return "Trick"
		Enums.CardTypeEnum.TERRAIN:         return "Terrain"
		Enums.CardTypeEnum.AREA_OF_EFFECT:  return "AoE"
	return "Unknown"

func _make_placeholder_texture(color: Color) -> ImageTexture:
	var image := Image.create(int(CARD_WIDTH), int(CARD_HEIGHT), false, Image.FORMAT_RGBA8)
	image.fill(color)

	var border := Color(1.0, 1.0, 1.0, 0.3)
	for x: int in int(CARD_WIDTH):
		image.set_pixel(x, 0, border)
		image.set_pixel(x, int(CARD_HEIGHT - 1), border)
	for y: int in int(CARD_HEIGHT):
		image.set_pixel(0, y, border)
		image.set_pixel(int(CARD_WIDTH - 1), y, border)

	return ImageTexture.create_from_image(image)

func _add_label(parent: Node, node_name: String, text: String, font_size: int, pos: Vector2) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
