extends Control

@onready var _tab_container: TabContainer = %TabContainer

# Host elements
@onready var _host_key_label: Label = %HostKeyLabel
@onready var _host_status_label: Label = %HostStatusLabel
@onready var _host_start_button: Button = %HostStartButton
@onready var _host_back_button: Button = %HostBackButton
@onready var _host_player_list: ItemList = %HostPlayerList

# Join elements
@onready var _join_key_input: LineEdit = %JoinKeyInput
@onready var _join_button: Button = %JoinButton
@onready var _join_status_label: Label = %JoinStatusLabel
@onready var _join_back_button: Button = %JoinBackButton

func _ready() -> void:
	_tab_container.set_tab_title(0, "Host Game")
	_tab_container.set_tab_title(1, "Join Game")

	_host_start_button.pressed.connect(_on_host_start_pressed)
	_host_back_button.pressed.connect(_on_back_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_join_back_button.pressed.connect(_on_back_pressed)

	SignalBus.session_key_updated.connect(_on_session_key_updated)
	SignalBus.server_started.connect(_on_server_started)
	SignalBus.connected_to_server.connect(_on_connected_to_server)
	SignalBus.connection_failed.connect(_on_connection_failed)
	SignalBus.player_connected.connect(_on_player_connected)
	SignalBus.player_disconnected.connect(_on_player_disconnected)
	SignalBus.match_started.connect(_on_match_started)

	_join_key_input.text_changed.connect(_on_key_input_changed)

func _on_host_start_pressed() -> void:
	NetworkManager.host_game()
	_host_start_button.disabled = true
	_host_status_label.text = "Starting server..."

func _on_join_pressed() -> void:
	var key := _join_key_input.text.to_upper().strip_edges()
	if key.length() != NetworkManager.SESSION_KEY_LENGTH:
		_join_status_label.text = "Session Key must be 6 characters"
		return
	_join_button.disabled = true
	_join_status_label.text = "Searching for session..."
	NetworkManager.join_game_by_key(key)

func _on_back_pressed() -> void:
	NetworkManager.reset_network()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_session_key_updated(key: String) -> void:
	_host_key_label.text = key

func _on_server_started() -> void:
	_host_status_label.text = "Waiting for opponent..."
	_host_player_list.add_item("You (Host)")

func _on_connected_to_server() -> void:
	_join_status_label.text = "Connected! Waiting for host..."

func _on_connection_failed(reason: String) -> void:
	_join_status_label.text = reason
	_join_button.disabled = false

func _on_player_connected(peer_id: int) -> void:
	_host_player_list.add_item("Player %d" % peer_id)
	_host_status_label.text = "Opponent joined!"
	_host_start_button.text = "Start Match"
	_host_start_button.disabled = false
	if _host_start_button.pressed.is_connected(_on_host_start_pressed):
		_host_start_button.pressed.disconnect(_on_host_start_pressed)
	if not _host_start_button.pressed.is_connected(_on_start_match_pressed):
		_host_start_button.pressed.connect(_on_start_match_pressed)

func _on_player_disconnected(peer_id: int) -> void:
	for i in _host_player_list.item_count:
		if _host_player_list.get_item_text(i).begins_with("Player %d" % peer_id):
			_host_player_list.remove_item(i)
			break
	_host_status_label.text = "Opponent disconnected"

func _on_start_match_pressed() -> void:
	_start_match.rpc()

@rpc("authority", "call_local")
func _start_match() -> void:
	if not is_inside_tree():
		return
	SignalBus.match_started.emit()

func _on_match_started() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_key_input_changed(_new_text: String) -> void:
	_join_status_label.text = ""

func _cleanup_signals() -> void:
	if SignalBus.session_key_updated.is_connected(_on_session_key_updated):
		SignalBus.session_key_updated.disconnect(_on_session_key_updated)
	if SignalBus.server_started.is_connected(_on_server_started):
		SignalBus.server_started.disconnect(_on_server_started)
	if SignalBus.connected_to_server.is_connected(_on_connected_to_server):
		SignalBus.connected_to_server.disconnect(_on_connected_to_server)
	if SignalBus.connection_failed.is_connected(_on_connection_failed):
		SignalBus.connection_failed.disconnect(_on_connection_failed)
	if SignalBus.player_connected.is_connected(_on_player_connected):
		SignalBus.player_connected.disconnect(_on_player_connected)
	if SignalBus.player_disconnected.is_connected(_on_player_disconnected):
		SignalBus.player_disconnected.disconnect(_on_player_disconnected)
	if SignalBus.match_started.is_connected(_on_match_started):
		SignalBus.match_started.disconnect(_on_match_started)

func _exit_tree() -> void:
	_cleanup_signals()
