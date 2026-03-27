extends Panel

signal card_dropped_on_board(card_id: int, original_node: Node)

# Built-in Godot function: Can we drop this data here?
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card":
		return true
	return false

# Built-in Godot function: What happens when we drop it?
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var card_id: int = data["card_id"]
	var node: Node = data["original_node"]
	
	# Emit a signal to the MatchManager to ask the server to play it
	card_dropped_on_board.emit(card_id, node)
