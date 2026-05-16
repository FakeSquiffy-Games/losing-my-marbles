class_name ClientMarbleVisual
extends Node2D

var marble_id: int = 0
var player_id: int = 0
var marble_color: Color = Color.WHITE

func _draw() -> void:
	draw_circle(Vector2.ZERO, Marble.RADIUS, marble_color)
	draw_arc(Vector2.ZERO, Marble.RADIUS, 0, TAU, 16, marble_color.darkened(0.3), 2.0)
