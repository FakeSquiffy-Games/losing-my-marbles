extends Node

var _pool: Array[MarbleData] = []
var _default_marble: MarbleData = null

func _ready() -> void:
	_default_marble = load("res://resources/cards/marble_standard.tres") as MarbleData

func get_marble() -> MarbleData:
	if _pool.is_empty():
		return _default_marble
	return _pool.pop_front()

func return_marble(marble: MarbleData) -> void:
	_pool.append(marble)

func is_empty() -> bool:
	return false

func size() -> int:
	return _pool.size()
