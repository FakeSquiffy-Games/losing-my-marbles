class_name DeckManager
extends RefCounted

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []

func init(cards: Array[CardData]) -> void:
	draw_pile.assign(cards)
	_fisher_yates_shuffle(draw_pile)

func draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for _i: int in count:
		if draw_pile.is_empty():
			_reshuffle_discard_to_draw()
		if draw_pile.is_empty():
			break
		drawn.append(draw_pile.pop_back())
	return drawn

func add_to_hand(card_data: CardData) -> void:
	hand.append(card_data)

func play_card(card_data: CardData) -> void:
	var idx: int = hand.find(card_data)
	if idx == -1:
		for i: int in hand.size():
			if hand[i].card_name == card_data.card_name:
				idx = i
				break
	if idx != -1:
		var removed: CardData = hand.pop_at(idx)
		discard_pile.append(removed)

func has_card_in_hand(card_data: CardData) -> bool:
	if hand.has(card_data):
		return true
	for cd: CardData in hand:
		if cd.card_name == card_data.card_name:
			return true
	return false

func end_turn_return_hand_to_draw() -> void:
	for cd: CardData in hand:
		draw_pile.append(cd)
	hand.clear()
	_fisher_yates_shuffle(draw_pile)

func get_draw_pile_count() -> int:
	return draw_pile.size()

func _reshuffle_discard_to_draw() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.assign(discard_pile)
	discard_pile.clear()
	_fisher_yates_shuffle(draw_pile)

func _fisher_yates_shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
