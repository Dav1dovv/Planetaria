# CraftingManager.gd
extends Node
class_name CraftingManager

@export var all_recipes: Array[CraftRecipe] = []
var unlocked_recipes: Array[CraftRecipe] = []

func _ready() -> void:
	# Разблокируем стартовые рецепты
	unlock_initial_recipes()

func unlock_initial_recipes() -> void:
	for recipe in all_recipes:
		if recipe.required_level <= 1:
			unlocked_recipes.append(recipe)

func unlock_recipe(recipe_name: String) -> bool:
	for recipe in all_recipes:
		if recipe.recipe_name == recipe_name and not unlocked_recipes.has(recipe):
			unlocked_recipes.append(recipe)
			return true
	return false

func get_available_recipes() -> Array[CraftRecipe]:
	return unlocked_recipes.duplicate()

# Сохранение/загрузка разблокированных рецептов
func save_unlocked_recipes() -> Dictionary:
	var save_data = {
		"unlocked_recipes": []
	}
	for recipe in unlocked_recipes:
		save_data["unlocked_recipes"].append(recipe.resource_path)
	return save_data

func load_unlocked_recipes(data: Dictionary) -> void:
	unlocked_recipes.clear()
	for recipe_path in data.get("unlocked_recipes", []):
		if ResourceLoader.exists(recipe_path):
			var recipe = load(recipe_path)
			unlocked_recipes.append(recipe)
