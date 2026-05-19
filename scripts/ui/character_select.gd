extends Control

@onready var _character_container: HBoxContainer = %CharacterContainer
@onready var _confirm_button: Button = %ConfirmButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton

var _library: CardLibrary
var _characters: Array[CharacterData] = []
var _character_cards: Array[Control] = []
var _selected_index: int = -1
var _current_selecting_player: int = 1

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_library = CardLibrary.new()
	_library.load_characters()
	_characters = _library.characters

	_current_selecting_player = MatchManager.pre_match_player_id
	_status_label.text = "Player %d: Select your character" % _current_selecting_player

	_populate_ui()

func _populate_ui() -> void:
	for char_data in _characters:
		var card := _create_character_card(char_data)
		_character_container.add_child(card)
		_character_cards.append(card)

func _create_character_card(data: CharacterData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 300)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var name_label := Label.new()
	var display_name := data.character_name if data.character_name else data.resource_path.get_file().trim_suffix(".tres")
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	vbox.add_child(HSeparator.new())

	var health_label := Label.new()
	health_label.text = "Health: %d" % data.health
	vbox.add_child(health_label)

	var mana_label := Label.new()
	mana_label.text = "Mana: %d" % data.mana
	vbox.add_child(mana_label)

	var power_label := Label.new()
	power_label.text = "Power: %.1f" % data.power
	vbox.add_child(power_label)

	var select_button := Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_character_selected.bind(_characters.find(data)))
	vbox.add_child(select_button)
	
	var character_pose := TextureRect.new()
	character_pose.texture = data.flick_pose
	character_pose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_pose.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character_pose.custom_minimum_size = Vector2(0, 360)
	vbox.add_child(character_pose)

	return card

func _on_character_selected(index: int) -> void:
	_selected_index = index
	_confirm_button.disabled = false

	for i in _character_cards.size():
		var card := _character_cards[i]
		card.modulate = Color.WHITE if i == index else Color(0.5, 0.5, 0.5, 1.0)

func _on_confirm_pressed() -> void:
	if _selected_index < 0:
		return
	var chosen := _characters[_selected_index]
	_confirm_button.disabled = true
	if _characters[_selected_index].character_name == "JC":
		AudioManager.play_ui_sound("jc_selected")
	if _characters[_selected_index].character_name == "Mae":
		AudioManager.play_ui_sound("mae_selected")
	if _characters[_selected_index].character_name == "Ryl":
		AudioManager.play_ui_sound("ryl_selected")
	if NetworkManager.is_host and NetworkManager.session_key != "OFFLINE":
		_request_character_select.rpc_id(1, _selected_index, _current_selecting_player)
	SignalBus.character_selected.emit(_current_selecting_player, chosen)

	get_tree().change_scene_to_file("res://scenes/ui/deck_builder.tscn")

@rpc("any_peer", "call_local")
func _request_character_select(char_index: int, selecting_player: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var chosen := _characters[char_index]
	SignalBus.character_selected.emit(sender_id, chosen)
	_sync_character_select.rpc(sender_id, char_index)

@rpc("authority", "call_local")
func _sync_character_select(player_id: int, char_index: int) -> void:
	var chosen := _characters[char_index]
	SignalBus.character_selected.emit(player_id, chosen)

func _on_back_pressed() -> void:
	NetworkManager.reset_network()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
