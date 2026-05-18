extends Control

const PUBLIC_POOL_SIZE := 5
const MIN_PRIVATE_DECK_SIZE := 1
const PASS_DEVICE_SCENE := preload("res://scenes/ui/pass_device.tscn")

enum ListSource { AVAILABLE, PRIVATE_DECK, PUBLIC_POOL }

@onready var _available_list: ItemList = %AvailableCardsList
@onready var _private_list: ItemList = %PrivateDeckList
@onready var _public_list: ItemList = %PublicPoolList
@onready var _pool_status_label: Label = %PoolStatusLabel
@onready var _add_private_button: Button = %AddPrivateButton
@onready var _add_public_button: Button = %AddPublicButton
@onready var _remove_button: Button = %RemoveButton
@onready var _back_button: Button = %BackButton
@onready var _ready_button: Button = %ReadyButton
@onready var _card_type_filter: OptionButton = %CardTypeFilter
@onready var _title_label: Label = %TitleLabel

var _library: CardLibrary
var _private_deck: Array[CardData] = []
var _public_pool: Array[MarbleData] = []
var _player_id: int = 1
var _pass_device_active: bool = false


func _ready() -> void:
	_player_id = MatchManager.pre_match_player_id if MatchManager.pre_match_player_id > 0 else 1
	if _title_label:
		_title_label.text = "Player %d — Build Your Decks" % _player_id

	_add_private_button.pressed.connect(_on_add_private_pressed)
	_add_public_button.pressed.connect(_on_add_public_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_ready_button.pressed.connect(_on_ready_pressed)
	_card_type_filter.item_selected.connect(_on_filter_changed)

	_available_list.item_selected.connect(_on_available_selected)
	_private_list.item_selected.connect(_on_private_selected)
	_public_list.item_selected.connect(_on_public_selected)

	_populate_filter()
	_library = CardLibrary.new()
	_library.load_cards()
	_refresh_available_list()
	_update_pool_status()


func _load_cards() -> void:
	_library.load_cards()


func _populate_filter() -> void:
	_card_type_filter.add_item("All Types")
	_card_type_filter.add_item("Marble")
	_card_type_filter.add_item("Power-Up")
	_card_type_filter.add_item("Trick")
	_card_type_filter.add_item("Terrain")
	_card_type_filter.add_item("Area of Effect")


func _refresh_available_list(filter_type: int = 0) -> void:
	_available_list.clear()
	for card in _library.cards:
		if _private_deck.has(card) or (card is MarbleData and _public_pool.has(card as MarbleData)):
			continue
		if _matches_filter(card, filter_type):
			var display := _card_display_name(card)
			var idx := _available_list.add_item(display)
			_available_list.set_item_metadata(idx, card)


func _card_display_name(card: CardData) -> String:
	var name_str := card.card_name if card.card_name else card.resource_path.get_file().trim_suffix(".tres")
	var type_str := _type_to_string(card.type)
	return "%s  [%s]  Cost: %d" % [name_str, type_str, card.mana_cost]


func _type_to_string(type_val: int) -> String:
	match type_val:
		Enums.CardTypeEnum.MARBLE: return "Marble"
		Enums.CardTypeEnum.POWER_UP: return "Power-Up"
		Enums.CardTypeEnum.TRICK: return "Trick"
		Enums.CardTypeEnum.TERRAIN: return "Terrain"
		Enums.CardTypeEnum.AREA_OF_EFFECT: return "AOE"
		_: return "Unknown"


func _matches_filter(card: CardData, filter_idx: int) -> bool:
	if filter_idx == 0:
		return true
	return card.type == filter_idx - 1


func _on_filter_changed(idx: int) -> void:
	_refresh_available_list(idx)


func _on_available_selected(_idx: int) -> void:
	_private_list.deselect_all()
	_public_list.deselect_all()


func _on_private_selected(_idx: int) -> void:
	_available_list.deselect_all()
	_public_list.deselect_all()


func _on_public_selected(_idx: int) -> void:
	_available_list.deselect_all()
	_private_list.deselect_all()


func _get_selected_card() -> CardData:
	for idx in _available_list.get_selected_items():
		return _available_list.get_item_metadata(idx) as CardData
	return null


func _get_selected_from_private() -> int:
	var selected := _private_list.get_selected_items()
	if selected.is_empty():
		return -1
	return selected[0]


func _get_selected_from_public() -> int:
	var selected := _public_list.get_selected_items()
	if selected.is_empty():
		return -1
	return selected[0]


func _on_add_private_pressed() -> void:
	var card := _get_selected_card()
	if card == null:
		return
	_private_deck.append(card)
	_private_list.add_item(_card_display_name(card))
	_refresh_available_list(_card_type_filter.selected)


func _on_add_public_pressed() -> void:
	var card := _get_selected_card()
	if card == null:
		return
	if not card is MarbleData:
		return
	if _public_pool.size() >= PUBLIC_POOL_SIZE:
		return
	_public_pool.append(card as MarbleData)
	_public_list.add_item(_card_display_name(card))
	_refresh_available_list(_card_type_filter.selected)
	_update_pool_status()


func _on_remove_pressed() -> void:
	var private_idx := _get_selected_from_private()
	if private_idx >= 0:
		_private_deck.remove_at(private_idx)
		_private_list.remove_item(private_idx)
		_refresh_available_list(_card_type_filter.selected)
		return

	var public_idx := _get_selected_from_public()
	if public_idx >= 0:
		_public_pool.remove_at(public_idx)
		_public_list.remove_item(public_idx)
		_refresh_available_list(_card_type_filter.selected)
		_update_pool_status()


func _update_pool_status() -> void:
	_pool_status_label.text = "Public Marble Pool (%d/%d)" % [_public_pool.size(), PUBLIC_POOL_SIZE]
	if _public_pool.size() >= PUBLIC_POOL_SIZE:
		_add_public_button.disabled = true
	else:
		_add_public_button.disabled = false


func _validate_decks() -> String:
	var errors: Array[String] = []
	if _private_deck.size() < MIN_PRIVATE_DECK_SIZE:
		errors.append("Private deck needs at least %d card(s)." % MIN_PRIVATE_DECK_SIZE)
	if _public_pool.size() < PUBLIC_POOL_SIZE:
		errors.append("Public marble pool must be full (%d/%d)." % [_public_pool.size(), PUBLIC_POOL_SIZE])
	return ", ".join(errors) if errors else ""


func _on_ready_pressed() -> void:
	if _pass_device_active:
		return
	var error := _validate_decks()
	if error:
		_pool_status_label.text = error
		_pool_status_label.modulate = Color.RED
		return

	MatchManager.set_player_decks(_player_id, _private_deck.duplicate(), _public_pool.duplicate())
	print("[DeckBuilder] Player %d decks stored — private: %d, public: %d" % [_player_id, _private_deck.size(), _public_pool.size()])

	SignalBus.device_passed.connect(_on_device_passed, CONNECT_ONE_SHOT)
	_pass_device_active = true

	var pass_device := PASS_DEVICE_SCENE.instantiate()
	pass_device.setup(_player_id)
	add_child(pass_device)


func _on_device_passed(_next_player_id: int) -> void:
	if _player_id == 1:
		MatchManager.pre_match_player_id = 2
		get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")
	else:
		MatchManager.pre_match_player_id = 0
		get_tree().change_scene_to_file("res://scenes/ui/match.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
