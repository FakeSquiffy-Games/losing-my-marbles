extends Node

var _pool: Array[MarbleData] = []
var _ejected: Array[MarbleData] = []


func init_pool(p1_pool: Array[MarbleData], p2_pool: Array[MarbleData]) -> void:
	_pool.clear()
	_ejected.clear()

	_pool.append_array(p1_pool)
	_pool.append_array(p2_pool)

	if _pool.is_empty():
		push_error("[MarblePoolManager] Both players' public pools are empty — no marbles available")
		return

	_shuffle()
	print("[MarblePoolManager] Pool initialized — %d marbles (P1: %d, P2: %d)" % [_pool.size(), p1_pool.size(), p2_pool.size()])


func get_marble() -> MarbleData:
	if _pool.is_empty():
		refill_pool()
	if _pool.is_empty():
		push_error("[MarblePoolManager] Pool empty even after refill!")
		return null
	return _pool.pop_front()


func return_marble(marble: MarbleData) -> void:
	if marble:
		_ejected.append(marble)


func refill_pool() -> void:
	if _ejected.is_empty():
		push_warning("[MarblePoolManager] Cannot refill — no ejected marbles")
		return
	_pool.append_array(_ejected)
	_ejected.clear()
	_shuffle()
	print("[MarblePoolManager] Pool refilled — %d marbles returned and reshuffled" % _pool.size())


func draw_random(count: int) -> Array[MarbleData]:
	var result: Array[MarbleData] = []
	for _i: int in count:
		var marble := get_marble()
		if marble == null:
			break
		result.append(marble)
	return result


func is_empty() -> bool:
	return _pool.is_empty() and _ejected.is_empty()


func size() -> int:
	return _pool.size()


func _shuffle() -> void:
	for i: int in range(_pool.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp := _pool[i]
		_pool[i] = _pool[j]
		_pool[j] = temp
