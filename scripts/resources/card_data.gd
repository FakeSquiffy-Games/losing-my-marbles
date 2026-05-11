class_name CardData
extends Resource

enum CardType { MARBLE, POWER_UP, TRICK, TERRAIN, AREA_OF_EFFECT }

@export var type: CardType = CardType.MARBLE
@export var mana_cost: int = 1
@export var effects: Array[EffectData] = []
