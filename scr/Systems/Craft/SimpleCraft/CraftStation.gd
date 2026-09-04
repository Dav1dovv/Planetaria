## CraftStation.gd
## Универсальный экран крафта с тремя вкладками:
##   • Крафт    — создание предметов из ресурсов
##   • Ремонт   — починка сломанного предмета за ресурсы/золото
##   • Разборка — получить ресурсы из ненужного предмета
##
## Станция бывает трёх видов (station_type), задаётся отдельно для
## каждого объекта в мире (наковальня / верстак / котёл):
##   • SMITH     — кузнец: рецепты с station_restriction = SMITH_ONLY или ANY
##   • WORKBENCH — верстак: рецепты с station_restriction = WORKBENCH_ONLY или ANY
##   • CAULDRON  — котёл: ВСЕ рецепты категории Food и только они
##     (еда никогда не показывается у кузнеца/верстака, даже если
##     на рецепте стоит ANY — см. CraftRecipe.CATEGORY_FOOD)
## ─────────────────────────────────────────────────────────────────
##
## ИЗМЕНЕНИЯ В ЭТОЙ ВЕРСИИ:
##  • Рецепты грузятся с диска один раз на папку и кэшируются на уровне класса
##    (_recipe_cache: static). Если на сцене несколько станций (кузнец + верстак),
##    они больше не пересканируют диск каждая сама по себе.
##  • _refresh() дебаунсится через call_deferred: если за один кадр прилетело
##    несколько inventory_changed/hotbar_changed подряд, пересборка UI выполнится
##    один раз, а не по числу сигналов.
##  • _rebuild_grid() больше не делает queue_free()+создать заново на КАЖДЫЙ refresh —
##    кнопки переиспользуются (обновляется только modulate/tooltip), пересоздаются
##    только когда реально меняется набор показанных рецептов.
## ─────────────────────────────────────────────────────────────────
extends Control

# ─────────────────────────────────────────────────────────────────
#  НОДЫ  — привяжи в сцене к своим путям
# ─────────────────────────────────────────────────────────────────

# Вкладки
@onready var tab_craft:      Button = $Craft/TabBar/TabCraft
@onready var tab_repair:     Button = $Craft/TabBar/TabRepair
@onready var tab_disassemble: Button = $Craft/TabBar/TabDisassemble

# Левая панель — список рецептов
#@onready var search_box:      LineEdit     = $Craft/Body/Left/SearchBox
@onready var category_filter: OptionButton = $Craft/Body/Left/CategoryFilter
@onready var recipe_grid:     GridContainer = $Craft/Body/Left/Scroll/RecipeGrid

# Правая панель — предпросмотр
@onready var result_slot:      InventorySlot   = $Craft/Body/Right/ResultSlot
@onready var ingredients_list: VBoxContainer   = $Craft/Body/Right/IngredientsList
@onready var craft_button:     Button          = $Craft/Body/Right/CraftButton
@onready var craft_max_button: Button          = $Craft/Body/Right/ResultSlot/MaxCount
@onready var gold_label:       Label           = $Craft/Body/Right/GoldLabel

# ─────────────────────────────────────────────────────────────────
#  НАСТРОЙКИ
# ─────────────────────────────────────────────────────────────────

## Вид этой станции — задаётся отдельно для каждого объекта в мире
enum StationType { SMITH, WORKBENCH, CAULDRON }
@export var station_type: StationType = StationType.WORKBENCH

## Предмет "Золото" для проверки оплаты
@export var gold_item: ItemData

## Папка с рецептами
@export var recipes_folder: String = "res://misc/Content/Recipes/Craft/"

# ─────────────────────────────────────────────────────────────────
#  СОСТОЯНИЕ
# ─────────────────────────────────────────────────────────────────

enum Tab { CRAFT, REPAIR, DISASSEMBLE }

var current_tab:   Tab = Tab.CRAFT
var all_recipes:   Array[CraftRecipe] = []
var shown_recipes: Array[CraftRecipe] = []
var selected_recipe: CraftRecipe = null
var inventory: Inventory = null

# Кэш рецептов на уровне класса: recipes_folder -> Array[CraftRecipe].
# Общий для всех станций на сцене (кузнец + верстак не грузят папку дважды).
static var _recipe_cache: Dictionary = {}

# Кнопки сетки рецептов, переиспользуемые между refresh-ами: recipe -> Control.
var _recipe_buttons: Dictionary = {}
# Флаг, чтобы схлопнуть несколько _refresh() за один кадр в один call_deferred.
var _refresh_queued: bool = false

# ─────────────────────────────────────────────────────────────────
#  ИНИЦИАЛИЗАЦИЯ
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	inventory = get_tree().get_first_node_in_group("Inventory")
	var hotbar = get_tree().get_first_node_in_group("Hotbar")

	if inventory:
		inventory.inventory_changed.connect(_request_refresh)
	if hotbar:
		hotbar.hotbar_changed.connect(_request_refresh)

	_load_recipes()
	_refresh()

	#search_box.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_changed)
	craft_button.pressed.connect(_on_action_pressed)
	craft_max_button.pressed.connect(_on_action_max_pressed)

	# Вкладки
	tab_craft.pressed.connect(func(): _switch_tab(Tab.CRAFT))
	tab_repair.pressed.connect(func(): _switch_tab(Tab.REPAIR))
	tab_disassemble.pressed.connect(func(): _switch_tab(Tab.DISASSEMBLE))

	_update_tab_labels()

# ─────────────────────────────────────────────────────────────────
#  ЗАГРУЗКА РЕЦЕПТОВ
# ─────────────────────────────────────────────────────────────────

func _load_recipes() -> void:
	if _recipe_cache.has(recipes_folder):
		all_recipes = _recipe_cache[recipes_folder]
		return

	all_recipes.clear()
	var dir := DirAccess.open(recipes_folder)
	if not dir:
		push_error("CraftStation: папка рецептов не найдена: " + recipes_folder)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var res = load(recipes_folder + file_name)
			if res is CraftRecipe:
				all_recipes.append(res)
		file_name = dir.get_next()

	all_recipes.sort_custom(func(a, b): return a.category < b.category)
	_recipe_cache[recipes_folder] = all_recipes

# ─────────────────────────────────────────────────────────────────
#  ВКЛАДКИ
# ─────────────────────────────────────────────────────────────────

func _switch_tab(tab: Tab) -> void:
	current_tab = tab
	selected_recipe = null
	_update_tab_labels()
	_refresh()

func _update_tab_labels() -> void:
	# Кнопки вкладок — выдели активную (можно менять стиль через theme)
	tab_craft.modulate      = Color.WHITE if current_tab == Tab.CRAFT else Color(0.6, 0.6, 0.6)
	tab_repair.modulate     = Color.WHITE if current_tab == Tab.REPAIR else Color(0.6, 0.6, 0.6)
	tab_disassemble.modulate = Color.WHITE if current_tab == Tab.DISASSEMBLE else Color(0.6, 0.6, 0.6)

	# Подпись кнопки действия
	match current_tab:
		Tab.CRAFT:       craft_button.text = "Создать"
		Tab.REPAIR:      craft_button.text = "Починить"
		Tab.DISASSEMBLE: craft_button.text = "Разобрать"

	# Кнопка "Макс" — только для крафта
	craft_max_button.visible = (current_tab == Tab.CRAFT)

# ─────────────────────────────────────────────────────────────────
#  ФИЛЬТРАЦИЯ И ОБНОВЛЕНИЕ СЕТКИ
# ─────────────────────────────────────────────────────────────────

## Схлопывает несколько срабатываний inventory_changed/hotbar_changed за один
## кадр в один вызов _refresh() — раньше при пачке изменений (например, крафт
## сразу нескольких предметов) UI пересобирался по числу сигналов.
func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_deferred_refresh")

func _deferred_refresh() -> void:
	_refresh_queued = false
	_refresh()

func _refresh() -> void:
	#var search_text := search_box.text.to_lower()
	var category_id := category_filter.selected  # 0 = Все

	shown_recipes.clear()

	for recipe in all_recipes:
		# ── Фильтр по вкладке ──
		match current_tab:
			Tab.CRAFT:
				if recipe.mode != CraftRecipe.Mode.CRAFT: continue
			Tab.REPAIR:
				if recipe.mode != CraftRecipe.Mode.REPAIR: continue
			Tab.DISASSEMBLE:
				if recipe.mode != CraftRecipe.Mode.DISASSEMBLE: continue

		# ── Фильтр по станции ──
		# Еда живёт только в котле, независимо от station_restriction.
		if recipe.category == CraftRecipe.CATEGORY_FOOD:
			if station_type != StationType.CAULDRON: continue
		else:
			if station_type == StationType.CAULDRON: continue
			match recipe.station_restriction:
				CraftRecipe.StationRestriction.SMITH_ONLY:
					if station_type != StationType.SMITH: continue
				CraftRecipe.StationRestriction.WORKBENCH_ONLY:
					if station_type != StationType.WORKBENCH: continue
				CraftRecipe.StationRestriction.ANY:
					pass

		# ── Поиск по названию ──
		#if not search_text.is_empty():
			#if not recipe.recipe_name.to_lower().contains(search_text):
				#continue

		# ── Категория ──
		if category_id > 0 and recipe.category != category_id - 1:
			continue

		shown_recipes.append(recipe)

	_rebuild_grid()
	_update_preview()

## Раньше: queue_free() всех детей + создать заново на КАЖДЫЙ _refresh().
## Теперь: кнопки переиспользуются между вызовами (recipe -> Control),
## пересоздаются только те, которых больше нет / появились новые.
func _rebuild_grid() -> void:
	var shown_set: Dictionary = {}
	for recipe in shown_recipes:
		shown_set[recipe] = true

	# Убираем кнопки рецептов, которых больше нет в выдаче
	for recipe in _recipe_buttons.keys().duplicate():
		if not shown_set.has(recipe):
			var btn: Control = _recipe_buttons[recipe]
			if is_instance_valid(btn):
				btn.queue_free()
			_recipe_buttons.erase(recipe)

	# Добавляем/обновляем и расставляем в правильном порядке
	for i in shown_recipes.size():
		var recipe := shown_recipes[i]
		var btn: Control = _recipe_buttons.get(recipe)
		if not is_instance_valid(btn):
			btn = _make_recipe_button(recipe)
			_recipe_buttons[recipe] = btn
			recipe_grid.add_child(btn)
		else:
			_update_recipe_button(btn, recipe)
		recipe_grid.move_child(btn, i)

func _make_recipe_button(recipe: CraftRecipe) -> Control:
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(24, 24)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.ignore_texture_size = true

	# Иконка
	var target_item := _get_display_item(recipe)
	if target_item:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = target_item.icon
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = recipe.recipe_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-20, 18)
		lbl.size = Vector2(64, 16)
		lbl.add_theme_font_size_override("font_size", 4)
		lbl.clip_text = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(lbl)

	button.pressed.connect(func():
		selected_recipe = recipe
		_update_preview()
	)

	_update_recipe_button(button, recipe)
	return button

## Обновляет доступность/тултип уже существующей кнопки — вызывается и при
## первом создании, и при последующих refresh-ах (без пересоздания ноды).
func _update_recipe_button(button: Control, recipe: CraftRecipe) -> void:
	var can := recipe.can_craft(inventory, gold_item)
	button.modulate = Color.WHITE if can else Color(0.55, 0.55, 0.55, 0.9)
	button.tooltip_text = _build_tooltip(recipe)

## Иконка для отображения в сетке рецептов
func _get_display_item(recipe: CraftRecipe) -> ItemData:
	match recipe.mode:
		CraftRecipe.Mode.CRAFT, CraftRecipe.Mode.REPAIR:
			return recipe.result_item
		CraftRecipe.Mode.DISASSEMBLE:
			return recipe.disassemble_target
	return null

# ─────────────────────────────────────────────────────────────────
#  ПРЕДПРОСМОТР (правая панель)
# ─────────────────────────────────────────────────────────────────

func _update_preview() -> void:
	for child in ingredients_list.get_children():
		child.queue_free()

	if not selected_recipe:
		_clear_preview()
		return

	match selected_recipe.mode:
		CraftRecipe.Mode.CRAFT:
			_preview_craft()
		CraftRecipe.Mode.REPAIR:
			_preview_repair()
		CraftRecipe.Mode.DISASSEMBLE:
			_preview_disassemble()

	var can := selected_recipe.can_craft(inventory, gold_item)
	craft_button.disabled = not can

func _clear_preview() -> void:
	result_slot.item = null
	result_slot.ammount = 0
	result_slot.update_ui()
	craft_button.disabled = true
	if gold_label:
		gold_label.text = ""

# ── Крафт ────────────────────────────────────────────────────────

func _preview_craft() -> void:
	result_slot.item = selected_recipe.result_item
	result_slot.ammount = selected_recipe.result_amount
	result_slot.update_ui()

	for ing in selected_recipe.get_ingredients():
		_add_row(ing["item"], ing["amount"])

	if selected_recipe.gold_cost > 0 and gold_item:
		_add_row(gold_item, selected_recipe.gold_cost, "Злт")

# ── Ремонт ───────────────────────────────────────────────────────

func _preview_repair() -> void:
	# Показываем: что получится (починенный предмет)
	result_slot.item = selected_recipe.result_item
	result_slot.ammount = 1
	result_slot.update_ui()

	# Что нужно потратить
	for ing in selected_recipe.get_ingredients():
		_add_row(ing["item"], ing["amount"])

	if selected_recipe.gold_cost > 0 and gold_item:
		_add_row(gold_item, selected_recipe.gold_cost, "Злт")

	# Подсказка о восстановлении прочности
	if selected_recipe.repair_amount > 0 and gold_label:
		gold_label.text = "+%d прочности" % selected_recipe.repair_amount
	elif gold_label:
		gold_label.text = "Полный ремонт"

# ── Разборка ─────────────────────────────────────────────────────

func _preview_disassemble() -> void:
	# Показываем целевой предмет (что разбираем)
	result_slot.item = selected_recipe.disassemble_target
	result_slot.ammount = 1
	result_slot.update_ui()

	if gold_label:
		gold_label.text = "Получишь:"

	# Список того, что вернётся
	for res in selected_recipe.get_salvage_results():
		_add_row(res["item"], res["amount"], "", true)

	# Предупреждение: есть ли предмет в инвентаре?
	if selected_recipe.disassemble_target:
		var have := inventory.get_total_item_count(selected_recipe.disassemble_target) if inventory else 0
		if have == 0:
			_add_warning_row("Предмет отсутствует в инвентаре")

# ─────────────────────────────────────────────────────────────────
#  СТРОКИ ИНГРЕДИЕНТОВ
# ─────────────────────────────────────────────────────────────────

## prefix — лейбл перед именем ("Злт", "" и т.д.)
## is_output — зелёный цвет (это результат, не расход)
func _add_row(item: ItemData, amount: int, prefix: String = "", is_output: bool = false) -> void:
	var hbox := HBoxContainer.new()

	var icon := TextureRect.new()
	icon.texture = item.icon if item else null
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var have := inventory.get_total_item_count(item) if inventory else 0
	var enough := have >= amount

	var lbl := Label.new()
	var item_name := item.item_name if item else "?"
	var display := prefix if prefix != "" else item_name
	if is_output:
		lbl.text = "%s × %d" % [item_name, amount]
		lbl.modulate = Color(0.4, 1.0, 0.6)
	else:
		lbl.text = "%s: %d/%d" % [display, have, amount]
		lbl.modulate = Color(0.2, 1.0, 0.4) if enough else Color(1.0, 0.35, 0.35)

	lbl.add_theme_font_size_override("font_size", 7)

	hbox.add_child(icon)
	hbox.add_child(lbl)
	ingredients_list.add_child(hbox)

func _add_warning_row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "⚠ " + text
	lbl.modulate = Color(1.0, 0.8, 0.2)
	lbl.add_theme_font_size_override("font_size", 7)
	ingredients_list.add_child(lbl)

# ─────────────────────────────────────────────────────────────────
#  ВЫПОЛНЕНИЕ ДЕЙСТВИЯ
# ─────────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	if not selected_recipe or not selected_recipe.can_craft(inventory, gold_item):
		return
	_execute(1)

func _on_action_max_pressed() -> void:
	if not selected_recipe: return
	var max_count := selected_recipe.max_craftable(inventory, gold_item)
	if max_count > 0:
		_execute(max_count)

func _execute(times: int) -> void:
	if not selected_recipe or not inventory: return

	match selected_recipe.mode:
		CraftRecipe.Mode.CRAFT:
			_do_craft(times)
		CraftRecipe.Mode.REPAIR:
			_do_repair()
		CraftRecipe.Mode.DISASSEMBLE:
			_do_disassemble()

# ── Крафт ────────────────────────────────────────────────────────

func _do_craft(times: int) -> void:
	for ing in selected_recipe.get_ingredients():
		inventory.remove_from_total(ing["item"], ing["amount"] * times)

	if selected_recipe.gold_cost > 0 and gold_item:
		inventory.remove_from_total(gold_item, selected_recipe.gold_cost * times)

	inventory.add_item(
		selected_recipe.result_item.duplicate(),
		selected_recipe.result_amount * times
	)

	_refresh()

# ── Ремонт ───────────────────────────────────────────────────────

func _do_repair() -> void:
	# Снимаем ресурсы
	for ing in selected_recipe.get_ingredients():
		inventory.remove_from_total(ing["item"], ing["amount"])

	if selected_recipe.gold_cost > 0 and gold_item:
		inventory.remove_from_total(gold_item, selected_recipe.gold_cost)

	# Ищем сломанный предмет в инвентаре и чиним его
	var target := selected_recipe.repair_target
	if target:
		_repair_item_in_inventory(target, selected_recipe.repair_amount)
	else:
		# Универсальный ремонт — чиним первый найденный предмет с прочностью < max
		_repair_first_broken_item(selected_recipe.repair_amount)

	_refresh()

## Найти конкретный предмет в инвентаре и восстановить прочность
func _repair_item_in_inventory(target: ItemData, repair_amt: int) -> void:
	var all_slots: Array[InventorySlotData] = inventory.items.duplicate()
	if inventory.hotbar:
		all_slots.append_array(inventory.hotbar.slots)

	for slot in all_slots:
		if not slot.item: continue
		if slot.item.item_name != target.item_name: continue
		_apply_repair(slot.item, repair_amt)
		slot.slot_node.update_ui()
		return

## Починить первый сломанный предмет (для универсального рецепта)
func _repair_first_broken_item(repair_amt: int) -> void:
	var all_slots: Array[InventorySlotData] = inventory.items.duplicate()
	if inventory.hotbar:
		all_slots.append_array(inventory.hotbar.slots)

	for slot in all_slots:
		if not slot.item: continue
		if slot.item.has_method("get_durability") and slot.item.has_method("max_durability"):
			var dur = slot.item.get_durability()
			var max_d = slot.item.max_durability
			if dur < max_d:
				_apply_repair(slot.item, repair_amt)
				slot.slot_node.update_ui()
				return

func _apply_repair(item: ItemData, repair_amt: int) -> void:
	if item.has_method("get_durability") and "max_durability" in item:
		if repair_amt <= 0:
			# Полный ремонт
			item.durability = item.max_durability
		else:
			item.durability = mini(
				item.get_durability() + repair_amt,
				item.max_durability
			)

# ── Разборка ─────────────────────────────────────────────────────

func _do_disassemble() -> void:
	if not selected_recipe.disassemble_target: return

	# Убираем один предмет
	inventory.remove_from_total(selected_recipe.disassemble_target, 1)

	# Добавляем компоненты
	for res in selected_recipe.get_salvage_results():
		if res["item"]:
			inventory.add_item(res["item"].duplicate(), res["amount"])

	_refresh()

# ─────────────────────────────────────────────────────────────────
#  ТУЛТИП
# ─────────────────────────────────────────────────────────────────

func _build_tooltip(recipe: CraftRecipe) -> String:
	if not recipe: return ""
	var lines: PackedStringArray = [recipe.recipe_name]
	if recipe.description != "":
		lines.append(recipe.description)
	lines.append("──────────")

	match recipe.mode:
		CraftRecipe.Mode.CRAFT, CraftRecipe.Mode.REPAIR:
			for ing in recipe.get_ingredients():
				lines.append("• %s × %d" % [ing["item"].item_name if ing["item"] else "?", ing["amount"]])
			if recipe.gold_cost > 0:
				lines.append("• Золото × %d" % recipe.gold_cost)

		CraftRecipe.Mode.DISASSEMBLE:
			lines.append("Разобрать: %s" % (recipe.disassemble_target.item_name if recipe.disassemble_target else "?"))
			lines.append("Получишь:")
			for res in recipe.get_salvage_results():
				lines.append("  + %s × %d" % [res["item"].item_name if res["item"] else "?", res["amount"]])

	return "\n".join(lines)

# ─────────────────────────────────────────────────────────────────
#  СИГНАЛЫ ФИЛЬТРОВ И ЗАКРЫТИЕ
# ─────────────────────────────────────────────────────────────────

func _on_search_changed(_text: String)   -> void: _refresh()
func _on_category_changed(_index: int)  -> void: _refresh()

# Кнопки-теги категорий (если есть в сцене)
func _on_sword_tag_pressed()   -> void: category_filter.selected = 1; _refresh()
func _on_pickaxe_tag_pressed() -> void: category_filter.selected = 2; _refresh()
func _on_food_tag_pressed()    -> void: category_filter.selected = 3; _refresh()
func _on_items_tag_pressed()   -> void: category_filter.selected = 4; _refresh()

func _on_close_pressed() -> void:
	get_parent().get_parent().uncall_craft()
	Global.is_opened_menu = false
	Cursor.detection_mode(false)
