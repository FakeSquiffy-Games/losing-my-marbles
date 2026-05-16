class_name PlayArea
extends CardContainer

signal card_played(card: Card)

func _ready() -> void:
	super._ready()

func _card_can_be_added(_cards: Array) -> bool:
	return true

func on_card_move_done(card: Card) -> void:
	card_played.emit(card)
