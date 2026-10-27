extends RefCounted
class_name SimpleNameGenerator

# Слоги смешаны из разных "культур" в один общий пул —
# этого достаточно, чтобы имена звучали разнообразно и подходили миру Aleria.
var onset := [
	"Ar", "Va", "Kar", "Tig", "Sar", "Ash", "Ge", "Nar", "Mik", "Hov",
	"Bor", "Vla", "Rad", "Mir", "Sve", "Yar", "Dob", "Rus", "Stan", "Zor",
	"Al", "Ed", "Wil", "Ric", "Rob", "Gil", "Hen", "Fred", "Os", "Leo",
]

var middle := ["a", "an", "ar", "en", "ig", "or", "os", "i", "e", ""]

var ending := [
	"an", "en", "ig", "ush", "ak", "ik", "on", "es",
	"slav", "mir", "gor", "dan", "min", "rad",
	"win", "bert", "mond", "ric", "ley", "ton", "ard", "wyn",
]

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## Генерирует одно случайное имя героя.
func generate_name() -> String:
	var name := _pick(onset)
	if rng.randf() < 0.6:
		name += _pick(middle)
	name += _pick(ending)
	return name.capitalize()


func _pick(pool: Array) -> String:
	return pool[rng.randi_range(0, pool.size() - 1)]
