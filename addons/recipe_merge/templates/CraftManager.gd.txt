# CraftingManager.gd
extends Node
class_name CraftingManager

var all_recipes: Array[CraftRecipe] = []
var unlocked_recipes: Array[CraftRecipe] = []

func _ready() -> void:
	all_recipes = ItemDB.get_recipes()
	unlock_initial_recipes()

func unlock_initial_recipes() -> void:
	for recipe in all_recipes:
		if recipe.required_smith_level <= 1:
			unlocked_recipes.append(recipe)

func unlock_recipe(recipe_name: String) -> bool:
	for recipe in all_recipes:
		if recipe.recipe_name == recipe_name and not unlocked_recipes.has(recipe):
			unlocked_recipes.append(recipe)
			return true
	return false

func get_available_recipes() -> Array[CraftRecipe]:
	return unlocked_recipes.duplicate()

# Сохранение/загрузка разблокированных рецептов (по стабильному id)
func save_unlocked_recipes() -> Dictionary:
	var save_data = {"unlocked_recipes": []}
	for recipe in unlocked_recipes:
		save_data["unlocked_recipes"].append(recipe.id)
	return save_data

func load_unlocked_recipes(data: Dictionary) -> void:
	unlocked_recipes.clear()
	for rid in data.get("unlocked_recipes", []):
		for recipe in all_recipes:
			if recipe.id == rid:
				unlocked_recipes.append(recipe)
				break
