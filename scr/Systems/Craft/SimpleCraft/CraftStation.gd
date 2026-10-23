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
## ОПТИМИЗАЦИИ (сохранены):
##  • Рецепты строит ItemDB; _refresh() дебаунсится через call_deferred;
##    кнопки сетки рецептов переиспользуются между refresh-ами.
##
## UX (этот проход):
##  • Справа теперь видно название и описание рецепта, заголовок «Нужно:»,
##    у каждого ингредиента «есть/нужно», а под списком – причина, почему
##    кнопка недоступна («Не хватает материалов», «Инвентарь полон»…).
##  • Выбранный рецепт подсвечен рамкой; на рецептах, которые можно создать
##    прямо сейчас, горит зелёная точка.
##  • После действия – подтверждение («Создано: Меч ×1») и «подскок» результата.
##  • Геймпад/клавиатура: рамка фокуса, фокус выбирает рецепт, LB/RB (PageUp/PageDown)
##    переключают вкладки, при открытии фокус уже на первом рецепте.
##
## ИСПРАВЛЕНО:
##  • Ремонт чинил «первый найденный» экземпляр, даже целый, а ресурсы списывал –
##    теперь чинится самая изношенная копия, и только если она есть.
##  • Крафт при полном рюкзаке списывал ресурсы и терял результат – теперь
##    ресурсы возвращаются, а игрок видит «Инвентарь полон».
##  • Разборка при полном рюкзаке – то же самое (проверка места до списания).
##  • Был сигнал visibility_changed на несуществующий метод – метод добавлен.
## ─────────────────────────────────────────────────────────────────
extends Control

# ─────────────────────────────────────────────────────────────────
#  НОДЫ  — привяжи в сцене к своим путям
# ─────────────────────────────────────────────────────────────────

# Вкладки
@onready var tab_craft:       Button = $Craft/TabBar/TabCraft
@onready var tab_repair:      Button = $Craft/TabBar/TabRepair
@onready var tab_disassemble: Button = $Craft/TabBar/TabDisassemble

# Левая панель — список рецептов
@onready var category_filter: OptionButton  = $Craft/Body/Left/CategoryFilter
@onready var recipe_grid:     GridContainer = $Craft/Body/Left/Scroll/RecipeGrid

# Правая панель — предпросмотр
@onready var result_slot:      InventorySlot = $Craft/Body/Right/ResultSlot
@onready var ingredients_list: VBoxContainer = $Craft/Body/Right/IngredientsList
@onready var craft_button:     Button        = $Craft/Body/Right/CraftButton
@onready var craft_max_button: Button        = $Craft/Body/Right/ResultSlot/MaxCount
@onready var gold_label:       Label         = $Craft/Body/Right/GoldLabel  # заголовок списка: «Нужно:» / «Получишь:»

# ─────────────────────────────────────────────────────────────────
#  НАСТРОЙКИ
# ─────────────────────────────────────────────────────────────────

## Вид этой станции — задаётся отдельно для каждого объекта в мире
enum StationType { SMITH, WORKBENCH, CAULDRON }
@export var station_type: StationType = StationType.WORKBENCH

## Предмет "Золото" для проверки оплаты
@export var gold_item: ItemData

## Папка с рецептами (оставлено для совместимости со сценами; рецепты строит ItemDB)
@export var recipes_folder: String = "res://misc/Content/Recipes/Craft/"

# ─────────────────────────────────────────────────────────────────
#  ЦВЕТА
# ─────────────────────────────────────────────────────────────────

const C_OK     := Color("6fd36a")
const C_BAD    := Color("ff5360")
const C_DIM    := Color("9aa5b8")
const C_ACCENT := Color("7fe9ee")
const C_TEXT   := Color("eef2f8")

# Ячейка рецепта: иконки в проекте 16×16, поэтому рисуем ровно вдвое больше (32×32): пиксели
# остаются чёткими, без размытия. Колонка шириной 138 px вмещает три таких ячейки.
const CELL_SIZE := 36
const ICON_SIZE := 32
const GRID_COLUMNS := 3

# ─────────────────────────────────────────────────────────────────
#  СОСТОЯНИЕ
# ─────────────────────────────────────────────────────────────────

enum Tab { CRAFT, REPAIR, DISASSEMBLE }

var current_tab:     Tab = Tab.CRAFT
var all_recipes:     Array[CraftRecipe] = []
var shown_recipes:   Array[CraftRecipe] = []
var selected_recipe: CraftRecipe = null
var inventory:       Inventory = null

# Кнопки сетки рецептов, переиспользуемые между refresh-ами: recipe -> Control.
var _recipe_buttons: Dictionary = {}
# Флаг, чтобы схлопнуть несколько _refresh() за один кадр в один call_deferred.
var _refresh_queued: bool = false

# Элементы правой панели, которые строятся кодом
var _title_label:  Label
var _desc_label:   Label
var _status_label: Label
var _pad_hint:     Label
var _stats_panel:  CraftStatsPanel   # характеристики и сравнение для создаваемого оружия
var _flash_until_ms: int = 0
var _flash_token: int = 0   # чтобы старый таймер не погасил более новое сообщение
var _pulse_tween: Tween

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

	_hide_dead_search_box()
	_build_detail_ui()
	_load_recipes()

	category_filter.item_selected.connect(_on_category_changed)
	craft_button.pressed.connect(_on_action_pressed)
	craft_max_button.pressed.connect(_on_action_max_pressed)

	tab_craft.pressed.connect(func(): _switch_tab(Tab.CRAFT))
	tab_repair.pressed.connect(func(): _switch_tab(Tab.REPAIR))
	tab_disassemble.pressed.connect(func(): _switch_tab(Tab.DISASSEMBLE))

	_update_tab_labels()
	_refresh()


## Строка поиска когда-то была отключена в коде, но осталась в сцене невидимой «заглушкой».
func _hide_dead_search_box() -> void:
	var search_box := get_node_or_null("Craft/Body/Left/SearchBox") as Control
	if search_box:
		search_box.visible = false


## Название, описание и строка статуса под списком ингредиентов + подсказка геймпада.
func _build_detail_ui() -> void:
	var right := ingredients_list.get_parent() as VBoxContainer

	# Верхняя распорка в сцене была под пустую рамку; освобождаем место под название
	var spacer := right.get_node_or_null("Control") as Control
	if spacer:
		spacer.custom_minimum_size.y = 4

	_title_label = _make_label(8, C_TEXT)
	right.add_child(_title_label)
	right.move_child(_title_label, result_slot.get_index() + 1)

	_desc_label = _make_label(6, C_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 14)
	right.add_child(_desc_label)
	right.move_child(_desc_label, _title_label.get_index() + 1)

	gold_label.add_theme_font_size_override("font_size", 6)
	gold_label.add_theme_color_override("font_color", C_DIM)

	_status_label = _make_label(6, C_BAD)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 8)
	right.add_child(_status_label)
	right.move_child(_status_label, ingredients_list.get_index() + 1)

	# Левая колонка: сетка рецептов (чуть ниже, чем раньше) + панель характеристик оружия
	var scroll := recipe_grid.get_parent() as ScrollContainer
	var left := scroll.get_parent() as VBoxContainer
	scroll.custom_minimum_size.y = 112   # три ряда крупных ячеек
	recipe_grid.columns = GRID_COLUMNS
	recipe_grid.custom_minimum_size = Vector2.ZERO
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ячейки делят ширину, каждая стоит по центру
	recipe_grid.add_theme_constant_override("h_separation", 0)
	recipe_grid.add_theme_constant_override("v_separation", 2)
	_stats_panel = CraftStatsPanel.new()
	left.add_child(_stats_panel)

	# Подсказка про вкладки – только когда играют с геймпада
	_pad_hint = _make_label(5, Color(1, 1, 1, 0.45))
	left.add_child(_pad_hint)
	InputHints.bind_label(_pad_hint, InputHints.craft_hint)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# ─────────────────────────────────────────────────────────────────
#  ЗАГРУЗКА РЕЦЕПТОВ
# ─────────────────────────────────────────────────────────────────

func _load_recipes() -> void:
	# Рецепты строит ItemDB из полей ItemData (аддон Recipe Merge)
	all_recipes = ItemDB.get_recipes()

# ─────────────────────────────────────────────────────────────────
#  ОТКРЫТИЕ / ВКЛАДКИ / ВВОД
# ─────────────────────────────────────────────────────────────────

## Подключено в сцене (раньше метода не было, и сигнал висел в пустоту).
func _on_visibility_changed() -> void:
	if not is_node_ready() or not visible:
		return
	_flash_until_ms = 0
	_refresh()
	if InputHints.device() == InputHints.Device.GAMEPAD:
		_focus_first_recipe.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP:
			step = -1
		elif event.keycode == KEY_PAGEDOWN:
			step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		_switch_tab(wrapi(int(current_tab) + step, 0, 3) as Tab)


func _switch_tab(tab: Tab) -> void:
	current_tab = tab
	selected_recipe = null
	_flash_until_ms = 0
	_update_tab_labels()
	_refresh()
	if InputHints.device() == InputHints.Device.GAMEPAD:
		_focus_first_recipe.call_deferred()


func _focus_first_recipe() -> void:
	if not is_visible_in_tree() or shown_recipes.is_empty():
		return
	var first: Control = _recipe_buttons.get(shown_recipes[0])
	if is_instance_valid(first):
		first.grab_focus()


func _update_tab_labels() -> void:
	# Активная вкладка яркая, остальные приглушены
	tab_craft.modulate       = Color.WHITE if current_tab == Tab.CRAFT else Color(0.6, 0.6, 0.6)
	tab_repair.modulate      = Color.WHITE if current_tab == Tab.REPAIR else Color(0.6, 0.6, 0.6)
	tab_disassemble.modulate = Color.WHITE if current_tab == Tab.DISASSEMBLE else Color(0.6, 0.6, 0.6)

	# Подпись кнопки действия (ключи переводов: Craft / REPAIR / Disassemble)
	match current_tab:
		Tab.CRAFT:       craft_button.text = "Craft"
		Tab.REPAIR:      craft_button.text = "REPAIR"
		Tab.DISASSEMBLE: craft_button.text = "Disassemble"

	# Кнопка "Макс" — только для крафта
	craft_max_button.visible = (current_tab == Tab.CRAFT)

# ─────────────────────────────────────────────────────────────────
#  ФИЛЬТРАЦИЯ И ОБНОВЛЕНИЕ СЕТКИ
# ─────────────────────────────────────────────────────────────────

## Схлопывает несколько срабатываний inventory_changed/hotbar_changed за один
## кадр в один вызов _refresh().
func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_deferred_refresh")

func _deferred_refresh() -> void:
	_refresh_queued = false
	_refresh()

func _refresh() -> void:
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

		# ── Категория ──
		if category_id > 0 and recipe.category != category_id - 1:
			continue

		shown_recipes.append(recipe)

	# Выбранный рецепт, который скрыли фильтром, не должен «висеть» в правой панели
	if selected_recipe and not shown_recipes.has(selected_recipe):
		selected_recipe = null

	_rebuild_grid()
	_update_preview()


## Кнопки переиспользуются между вызовами (recipe -> Control),
## пересоздаются только те, которых больше нет / появились новые.
func _rebuild_grid() -> void:
	var shown_set: Dictionary = {}
	for recipe in shown_recipes:
		shown_set[recipe] = true

	# Убираем кнопки рецептов, которых больше нет в выдаче.
	# remove_child, чтобы старые не висели в сетке до конца кадра и не сбивали порядок/фокус.
	for recipe in _recipe_buttons.keys().duplicate():
		if not shown_set.has(recipe):
			var btn: Control = _recipe_buttons[recipe]
			if is_instance_valid(btn):
				recipe_grid.remove_child(btn)
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
	button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.ignore_texture_size = true

	# Подложка слота: приглушённые (недоступные) рецепты остаются видимыми
	var bg := Panel.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("12151e")
	bg_style.border_color = Color("3a4252")
	bg_style.set_border_width_all(1)
	bg_style.anti_aliasing = false
	bg.add_theme_stylebox_override("panel", bg_style)
	button.add_child(bg)

	# Иконка
	var target_item := _get_display_item(recipe)
	if target_item:
		# Иконка занимает ячейку целиком и по центру (раньше висела в левом верхнем углу 16×16)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = target_item.icon
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		var pad := (CELL_SIZE - ICON_SIZE) / 2
		icon.offset_left = pad
		icon.offset_top = pad
		icon.offset_right = -pad
		icon.offset_bottom = -pad
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

	# Рамка выбора/фокуса
	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	button.add_child(frame)

	# Сколько предметов создаётся за раз («×5» у стрел, патронов, еды…)
	var amount := Label.new()
	amount.name = "Amount"
	amount.position = Vector2(0, CELL_SIZE - 10)
	amount.size = Vector2(CELL_SIZE - 2, 9)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_font_size_override("font_size", 6)
	amount.add_theme_color_override("font_color", Color.WHITE)
	amount.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	amount.add_theme_constant_override("outline_size", 3)
	amount.visible = false
	button.add_child(amount)

	# Зелёная точка: «это можно создать прямо сейчас»
	var dot := ColorRect.new()
	dot.name = "ReadyDot"
	dot.color = C_OK
	dot.size = Vector2(3, 3)
	dot.position = Vector2(CELL_SIZE - 6, 3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(dot)

	# И клик, и фокус (стрелки/геймпад) выбирают рецепт: справа сразу видны детали
	button.pressed.connect(_select_recipe.bind(recipe))
	button.focus_entered.connect(_select_recipe.bind(recipe))
	button.focus_exited.connect(_update_recipe_frames)

	_update_recipe_button(button, recipe)
	return button


## Обновляет доступность/тултип уже существующей кнопки — вызывается и при
## первом создании, и при последующих refresh-ах (без пересоздания ноды).
func _update_recipe_button(button: Control, recipe: CraftRecipe) -> void:
	var can := recipe.can_craft(inventory, gold_item)
	button.modulate = Color.WHITE if can else Color(0.55, 0.55, 0.55, 0.9)
	button.tooltip_text = _build_tooltip(recipe)
	var dot := button.get_node_or_null("ReadyDot") as Control
	if dot:
		dot.visible = can
	var badge := button.get_node_or_null("Amount") as Label
	if badge:
		var count := _result_amount(recipe)
		badge.visible = count > 1
		badge.text = "×%d" % count
	_style_frame(button, recipe)


func _select_recipe(recipe: CraftRecipe) -> void:
	if selected_recipe == recipe:
		return
	selected_recipe = recipe
	_flash_until_ms = 0
	_update_preview()
	_update_recipe_frames()


func _update_recipe_frames() -> void:
	for recipe in _recipe_buttons:
		var btn: Control = _recipe_buttons[recipe]
		if is_instance_valid(btn):
			_style_frame(btn, recipe)


## Выбранный – голубая рамка; только сфокусированный – белая.
func _style_frame(button: Control, recipe: CraftRecipe) -> void:
	var frame := button.get_node_or_null("Frame") as Panel
	if frame == null:
		return
	var selected := recipe == selected_recipe
	frame.visible = selected or button.has_focus()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_ACCENT, 0.10) if selected else Color.TRANSPARENT
	sb.border_color = C_ACCENT if selected else Color.WHITE
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	frame.add_theme_stylebox_override("panel", sb)


## Сколько штук создаётся за один раз (только для крафта; ремонт и разборка – не «создают»).
func _result_amount(recipe: CraftRecipe) -> int:
	return recipe.result_amount if recipe.mode == CraftRecipe.Mode.CRAFT else 1


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
	_clear_rows()

	if not selected_recipe:
		_clear_preview()
		return

	_title_label.text = Loc.t(selected_recipe.recipe_name)
	_title_label.add_theme_color_override("font_color", C_TEXT)
	_desc_label.text = selected_recipe.description

	match selected_recipe.mode:
		CraftRecipe.Mode.CRAFT:
			_preview_craft()
		CraftRecipe.Mode.REPAIR:
			_preview_repair()
		CraftRecipe.Mode.DISASSEMBLE:
			_preview_disassemble()

	var can := selected_recipe.can_craft(inventory, gold_item)
	craft_button.disabled = not can
	craft_max_button.disabled = not can
	_update_stats()
	_refresh_status()


## Характеристики и вердикт «стоит ли крафтить» – только для создаваемого оружия.
func _update_stats() -> void:
	var item: ItemData = null
	if selected_recipe and selected_recipe.mode == CraftRecipe.Mode.CRAFT:
		item = selected_recipe.result_item
	if WeaponStats.is_comparable(item):
		var weapon := item as equip_data
		_stats_panel.show_stats(weapon, WeaponStats.best_owned(inventory, weapon))
	else:
		_stats_panel.hide_stats()


func _clear_preview() -> void:
	_stats_panel.hide_stats()
	result_slot.item = null
	result_slot.ammount = 0
	result_slot.update_ui()
	craft_button.disabled = true
	craft_max_button.disabled = true
	gold_label.text = ""
	_desc_label.text = ""
	_title_label.text = Loc.t("Select a recipe") if not shown_recipes.is_empty() else Loc.t("Nothing to make here")
	_title_label.add_theme_color_override("font_color", C_DIM)
	_status_label.text = ""


## remove_child + queue_free: строки пропадают сразу, иначе при быстром
## переключении рецептов в списке на миг лежат строки двух рецептов.
func _clear_rows() -> void:
	for child in ingredients_list.get_children():
		ingredients_list.remove_child(child)
		child.queue_free()

# ── Крафт ────────────────────────────────────────────────────────

func _preview_craft() -> void:
	result_slot.item = selected_recipe.result_item
	result_slot.ammount = selected_recipe.result_amount
	result_slot.update_ui()
	gold_label.text = Loc.t("Needs:")
	_add_cost_rows()

# ── Ремонт ───────────────────────────────────────────────────────

func _preview_repair() -> void:
	# Показываем: что получится (починенный предмет)
	result_slot.item = selected_recipe.result_item
	result_slot.ammount = 1
	result_slot.update_ui()
	gold_label.text = Loc.t("Needs:")
	_add_cost_rows()

# ── Разборка ─────────────────────────────────────────────────────

func _preview_disassemble() -> void:
	# Показываем целевой предмет (что разбираем)
	result_slot.item = selected_recipe.disassemble_target
	result_slot.ammount = 1
	result_slot.update_ui()
	gold_label.text = Loc.t("Получишь:")

	# Список того, что вернётся
	for res in selected_recipe.get_salvage_results():
		_add_row(res["item"], res["amount"], "", true)

## Ингредиенты и золото – одинаково для крафта и ремонта.
func _add_cost_rows() -> void:
	for ing in selected_recipe.get_ingredients():
		_add_row(ing["item"], ing["amount"])
	if selected_recipe.gold_cost > 0 and gold_item:
		_add_row(gold_item, selected_recipe.gold_cost, Loc.t("Злт"))

# ─────────────────────────────────────────────────────────────────
#  СТРОКИ ИНГРЕДИЕНТОВ
# ─────────────────────────────────────────────────────────────────

## [иконка] Название ........ есть/нужно
## prefix    — подпись вместо имени (например, «Злт»)
## is_output — зелёный «× N»: это результат, а не расход
func _add_row(item: ItemData, amount: int, prefix: String = "", is_output: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var icon := TextureRect.new()
	icon.texture = item.icon if item else null
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = prefix if prefix != "" else (Loc.t(item.item_name) if item else "?")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 7)
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 7)
	if is_output:
		count_label.text = "×%d" % amount
		count_label.add_theme_color_override("font_color", C_OK)
	else:
		var have := inventory.get_total_item_count(item) if inventory else 0
		count_label.text = "%d/%d" % [have, amount]
		count_label.add_theme_color_override("font_color", C_OK if have >= amount else C_BAD)
	row.add_child(count_label)

	ingredients_list.add_child(row)

# ─────────────────────────────────────────────────────────────────
#  СТАТУС: почему нельзя / что получилось
# ─────────────────────────────────────────────────────────────────

## Постоянная строка под ингредиентами: причина, по которой кнопка недоступна.
## Не затирает временное сообщение об успехе (_flash_status).
func _refresh_status() -> void:
	if Time.get_ticks_msec() < _flash_until_ms:
		return
	var text := ""
	var color := C_BAD
	if selected_recipe:
		match selected_recipe.mode:
			CraftRecipe.Mode.REPAIR:
				match selected_recipe.get_repair_blocker(inventory):
					"missing":
						text = Loc.t("Bring the item to repair it")
					"intact":
						text = Loc.t("Item is not damaged")
						color = C_DIM
					_:
						if selected_recipe.can_craft(inventory, gold_item):
							text = Loc.t("Full repair")
							color = C_DIM
						else:
							text = Loc.t("Not enough materials")
			CraftRecipe.Mode.CRAFT:
				if not selected_recipe.can_craft(inventory, gold_item):
					text = Loc.t("Not enough materials")
			CraftRecipe.Mode.DISASSEMBLE:
				if not selected_recipe.can_craft(inventory, gold_item):
					text = Loc.t("Предмет отсутствует в инвентаре")
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


## Временное сообщение (успех / «Инвентарь полон»). Потом возвращается обычный статус.
func _flash_status(text: String, color: Color, seconds: float = 1.5) -> void:
	_flash_token += 1
	var token := _flash_token
	_flash_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	# Таймер сцены может сработать на миллисекунды раньше метки времени,
	# поэтому сообщение гасим по токену, а не по сравнению часов.
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if token == _flash_token:
			_flash_until_ms = 0
			_refresh_status())


## «Подскок» результата: игрок чувствует, что предмет создан.
func _pulse_result() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	result_slot.pivot_offset = result_slot.size / 2.0
	result_slot.scale = Vector2(1.25, 1.25)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(result_slot, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _after_success(message: String) -> void:
	_refresh()
	_pulse_result()
	_flash_status(message, C_OK)

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
	var recipe := selected_recipe
	var total := recipe.result_amount * times

	_spend_cost(recipe, times)

	# Место проверяем ПОСЛЕ списания: израсходованные ресурсы освобождают слоты,
	# и полный рюкзак с рудой не должен блокировать крафт меча из этой руды.
	if not inventory.can_add_item(recipe.result_item, total):
		_refund_cost(recipe, times)
		_refresh()
		_flash_status(Loc.t("Инвентарь полон"), C_BAD, 1.8)
		return

	inventory.add_item(recipe.result_item.duplicate(), total)
	_after_success(Loc.t("Crafted: %s ×%d") % [Loc.t(recipe.recipe_name), total])


func _spend_cost(recipe: CraftRecipe, times: int) -> void:
	for ing in recipe.get_ingredients():
		inventory.remove_from_total(ing["item"], ing["amount"] * times)
	if recipe.gold_cost > 0 and gold_item:
		inventory.remove_from_total(gold_item, recipe.gold_cost * times)


## Возврат ресурсов, если результат некуда положить (золото – счётчик, слоты не занимает).
func _refund_cost(recipe: CraftRecipe, times: int) -> void:
	for ing in recipe.get_ingredients():
		if ing["item"]:
			inventory.add_item(ing["item"].duplicate(), ing["amount"] * times)
	if recipe.gold_cost > 0 and gold_item:
		inventory.add_item(gold_item, recipe.gold_cost * times)

# ── Ремонт ───────────────────────────────────────────────────────

func _do_repair() -> void:
	# Сначала находим, ЧТО чиним: ресурсы списываются только если цель есть и повреждена.
	var broken := CraftRecipe.find_damaged_copy(inventory, selected_recipe.repair_target)
	if broken == null:
		return

	# Чиним ДО списания ресурсов: списание шлёт hotbar_changed, и PlayerHitBox
	# должен уже увидеть целый предмет (иначе спрайт в руке останется серым).
	broken.durability = broken.max_durability
	broken.emit_signal("durability_changed", broken.durability, broken.max_durability)

	for ing in selected_recipe.get_ingredients():
		inventory.remove_from_total(ing["item"], ing["amount"])
	if selected_recipe.gold_cost > 0 and gold_item:
		inventory.remove_from_total(gold_item, selected_recipe.gold_cost)

	if inventory.hotbar:
		inventory.hotbar.emit_signal("hotbar_changed")
	inventory.emit_signal("inventory_changed")
	_after_success(Loc.t("Repaired: %s") % Loc.t(selected_recipe.recipe_name))

# ── Разборка ─────────────────────────────────────────────────────

func _do_disassemble() -> void:
	var recipe := selected_recipe
	if not recipe.disassemble_target: return

	# Место проверяем ДО списания: возвращать разобранный предмет пришлось бы
	# «как новый» (копия шаблона), а это лазейка для бесплатного ремонта.
	for res in recipe.get_salvage_results():
		if res["item"] and not inventory.can_add_item(res["item"], res["amount"]):
			_flash_status(Loc.t("Инвентарь полон"), C_BAD, 1.8)
			return

	inventory.remove_from_total(recipe.disassemble_target, 1)
	for res in recipe.get_salvage_results():
		if res["item"]:
			inventory.add_item(res["item"].duplicate(), res["amount"])
	_after_success(Loc.t("Disassembled: %s") % Loc.t(recipe.recipe_name))

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
				lines.append("• %s × %d" % [Loc.t(ing["item"].item_name) if ing["item"] else "?", ing["amount"]])
			if recipe.gold_cost > 0:
				lines.append(Loc.t("• Золото × %d") % recipe.gold_cost)
		CraftRecipe.Mode.DISASSEMBLE:
			lines.append(Loc.t("Разобрать: %s") % (Loc.t(recipe.disassemble_target.item_name) if recipe.disassemble_target else "?"))
			lines.append(Loc.t("Получишь:"))
			for res in recipe.get_salvage_results():
				lines.append("  + %s × %d" % [Loc.t(res["item"].item_name) if res["item"] else "?", res["amount"]])

	return "\n".join(lines)

# ─────────────────────────────────────────────────────────────────
#  СИГНАЛЫ ФИЛЬТРОВ И ЗАКРЫТИЕ
# ─────────────────────────────────────────────────────────────────

func _on_category_changed(_index: int)  -> void: _refresh()

# Кнопки-теги категорий (если есть в сцене)
func _on_sword_tag_pressed()   -> void: category_filter.selected = 1; _refresh()
func _on_pickaxe_tag_pressed() -> void: category_filter.selected = 2; _refresh()
func _on_food_tag_pressed()    -> void: category_filter.selected = 3; _refresh()
func _on_items_tag_pressed()   -> void: category_filter.selected = 4; _refresh()

func _on_close_pressed() -> void:
	Global.inventory.close_any()
