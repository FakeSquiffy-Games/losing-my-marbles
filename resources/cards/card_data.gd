class_name CardData
extends Resource

enum Type { MARBLE, POWER_UP, TRICK, TERRAIN }

@export var card_name: String = "New Card"
@export var type: Type = Type.MARBLE
@export var mana_cost: int = 1
@export var description: String = ""
@export var effect_id: String = "" # Used by the EffectHandler
@export var value: float = 0.0     # Generic value (e.g., damage, boost amount)
