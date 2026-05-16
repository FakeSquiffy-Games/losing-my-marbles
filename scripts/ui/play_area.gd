class_name PlayArea
extends CardContainer

signal card_played(card: Card)

func _ready() -> void:
	super._ready()

func _card_can_be_added(_cards: Array) -> bool:
	return true

func move_cards(cards: Array, index: int = -1, with_history: bool = true) -> bool:
	var result := super.move_cards(cards, index, with_history)
	if result:
		for c in cards:
			if c is Card:
				card_played.emit(c)
	return result
