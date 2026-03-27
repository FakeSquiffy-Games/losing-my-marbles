extends Node2D

@onready var label: Label = $Label

func _ready() -> void:
	EffectHandler.effect_triggered.connect(_on_effect_received)

func _on_effect_received(effect_name: String, _target_id: int) -> void:
	# Visual feedback for testing
	label.text = "Effect: " + effect_name
	
	# Shake effect using a Tween
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	
	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.5).timeout
	modulate = Color.WHITE
