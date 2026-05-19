extends Control

@onready var _online_button: Button = %OnlineButton
@onready var _offline_button: Button = %OfflineButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_online_button.pressed.connect(_on_online_pressed)
	_offline_button.pressed.connect(_on_offline_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	$BackgroundMusic.play()

func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/matchmaking_lobby.tscn")

func _on_offline_pressed() -> void:
	NetworkManager.create_offline_game()
	MatchManager.pre_match_player_id = 1
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/deck_builder.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
