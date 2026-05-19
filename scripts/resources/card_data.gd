class_name CardData
extends Resource

@export var card_name: String = ""
@export var type: Enums.CardTypeEnum = Enums.CardTypeEnum.TRICK
@export var mana_cost: int = 0
@export var description: String = ""
@export var effects: Array[EffectData] = []
