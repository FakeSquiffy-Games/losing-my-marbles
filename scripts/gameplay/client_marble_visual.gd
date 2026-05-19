class_name ClientMarbleVisual
extends Node2D

var marble_id: int = 0
var player_id: int = 0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_sprite.texture = Marble.make_circle_texture(Marble.MARBLE_COLOR)
