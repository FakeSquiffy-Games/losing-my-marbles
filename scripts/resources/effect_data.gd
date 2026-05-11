class_name EffectData
extends Resource

enum Target { KNOCKER, OPPONENT, BOTH, FIELD }

@export var effect_id: String = ""
@export var value: float = 0.0
@export var target: Target = Target.KNOCKER
