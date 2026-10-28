## CombinedWeapon.gd
## Оружие, собранное в комбинаторе. Для боя это обычный equip_data (ничего в боевом коде менять не нужно),
## а здесь хранится «рецепт» — из чего оружие собрано, чтобы его можно было сохранить и собрать заново.
## Спрайт остаётся спрайтом основы: меняются эффект, звук и отклик (GDD).
@icon("res://addons/at-icons/mesh/sword.svg")
extends equip_data
class_name CombinedWeapon

## item_name основы, второго оружия и ресурсов/реликвий (по порядку слотов)
var base_name: String = ""
var donor_name: String = ""
var material_names: Array[String] = []


## Что кладём в сохранение: только «рецепт» и текущую прочность (характеристики пересчитаются).
func pack() -> Dictionary:
	return {
		"base": base_name,
		"donor": donor_name,
		"mats": material_names.duplicate(),
		"durability": get_durability(),
	}


## Короткие «чипы» свойств для подсказок: [{title, color}]
func recipe_parts() -> Array[String]:
	var out: Array[String] = []
	if donor_name != "":
		out.append(donor_name)
	out.append_array(material_names)
	return out
