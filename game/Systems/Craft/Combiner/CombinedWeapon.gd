## CombinedWeapon.gd
## Оружие, собранное в комбинаторе. Для боя это обычный equip_data (ничего в боевом коде менять не нужно),
## а здесь хранится «рецепт» — из чего оружие собрано, чтобы его можно было сохранить и собрать заново.
## Спрайт остаётся спрайтом основы: меняются эффект, звук и отклик (GDD).
@icon("res://addons/at-icons/mesh/sword.svg")
extends equip_data
class_name CombinedWeapon

## «Рецепт»: item_name основы, второго оружия и ресурсов/реликвий (по порядку слотов).
## @export_storage — значит Resource.duplicate() ТОЖЕ копирует эти поля (обычные var при duplicate() обнуляются,
## и тогда оружие теряло рецепт и пропадало из сохранения). В Inspector поля не показываются.
@export_storage var base_name: String = ""
@export_storage var donor_name: String = ""
@export_storage var material_names: Array[String] = []


## Рецепт цел (есть основа). Без него оружие нельзя собрать заново при загрузке.
func has_recipe() -> bool:
	return base_name != ""


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
