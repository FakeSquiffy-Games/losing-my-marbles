class_name CardLibrary
extends RefCounted

const CARDS_DIR := "res://resources/cards/"
const CHARACTERS_DIR := "res://resources/characters/"

var cards: Array[CardData] = []
var characters: Array[CharacterData] = []


func load_cards() -> void:
	cards.clear()
	for res: Resource in _load_tres_files(CARDS_DIR):
		if res is CardData:
			cards.append(res)


func load_characters() -> void:
	characters.clear()
	for res: Resource in _load_tres_files(CHARACTERS_DIR):
		if res is CharacterData:
			characters.append(res)


func _load_tres_files(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("CardLibrary: Cannot open directory: ", dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource := load(dir_path + file_name)
			if resource:
				result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
