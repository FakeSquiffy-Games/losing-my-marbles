class_name CardDataFactory
extends CardFactory

const CARD_SCENE := preload("res://scenes/ui/card_visual.tscn")

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
	card.front_face_texture = card.get_node("FrontFace/FrameRect") as TextureRect
	card.back_face_texture = card.get_node("BackFace/BackRect") as TextureRect
	card.card_size = card_size

	var controller: CardVisualController = card.get_node("FrontFace") as CardVisualController
	controller.apply_card_data(card_data)

	var back_rect: TextureRect = card.get_node("BackFace/BackRect") as TextureRect
	controller.apply_back(back_rect)

	card.card_name = card_data.card_name
	card.card_info = {"card_data": card_data}

	target.get_node("Cards").add_child(card)
	target.add_card(card)
	return card
