## ItemAudit.gd — проверка контента на соответствие правилам экономики.
## Запуск (из корня проекта):  godot --headless -s tools/ItemAudit.gd
## Код выхода 1, если есть ошибки (удобно для CI / pre-commit).
##
## Правила:
##  • оружие/кирки получаем за монеты (craft_gold_cost > 0) или обмениваем на прошлую кирку;
##  • чиним ТОЛЬКО ресурсами, ВСЕГДА полностью (repair_amount == 0, repair_gold_cost == 0, монеты не ингредиент);
##  • снаряжение не стакается; иконка не пустая; item_name уникален.
extends SceneTree

const ITEMS_DIR := "res://misc/Content/Items/"
const SHEET := "res://Assets/Textures/SpriteSheets/Items-Sheet.png"

var _errors: PackedStringArray = []
var _warnings: PackedStringArray = []

func _init() -> void:
	var items: Array[ItemData] = []
	var names := {}
	var cells := {}
	var dir := DirAccess.open(ITEMS_DIR)
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res := load(ITEMS_DIR + fname)
		if not (res is ItemData):
			_err(fname, "не ItemData")
			continue
		var it := res as ItemData
		items.append(it)
		if names.has(it.item_name):
			_err(fname, "дубликат item_name '%s' (%s)" % [it.item_name, names[it.item_name]])
		names[it.item_name] = fname
		_check_icon(fname, it, cells)
		if it is equip_data:
			_check_gear(fname, it as equip_data)

	for k in cells:
		if cells[k].size() > 1:
			_warnings.append("ячейка %s используется несколькими предметами: %s" % [k, ", ".join(cells[k])])

	print("── ItemAudit: %d предметов ──" % items.size())
	for w in _warnings: print("WARN  ", w)
	for e in _errors: print("ERROR ", e)
	print("Итог: %d ошибок, %d предупреждений" % [_errors.size(), _warnings.size()])
	quit(1 if not _errors.is_empty() else 0)

func _err(f: String, msg: String) -> void: _errors.append("%s: %s" % [f, msg])

func _check_icon(f: String, it: ItemData, cells: Dictionary) -> void:
	if it.icon == null:
		_err(f, "нет иконки"); return
	if it.icon is AtlasTexture:
		var at := it.icon as AtlasTexture
		var img := at.atlas.get_image()
		if img == null: return
		var r := Rect2i(at.region)
		if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(r):
			_err(f, "регион иконки вне листа: %s" % r); return
		if img.get_region(r).is_invisible():
			_err(f, "иконка указывает на ПУСТУЮ ячейку %s" % r.position)
		var key := "(%d,%d)" % [r.position.x / 16, r.position.y / 16]
		cells[key] = cells.get(key, []) + [f]

func _check_gear(f: String, e: equip_data) -> void:
	if e.stackable or e.max_count != 1:
		_err(f, "снаряжение должно быть нестакаемым")
	if not e.has_repair_recipe():
		_err(f, "нет рецепта ремонта")
	if e.repair_amount != 0:
		_err(f, "repair_amount=%d — ремонт должен быть полным (0)" % e.repair_amount)
	if e.repair_gold_cost != 0:
		_err(f, "ремонт за монеты (%d) — чиним только ресурсами" % e.repair_gold_cost)
	for ing in e.repair_ingredients:
		if ing.item == null: _err(f, "пустой ингредиент ремонта")
		elif ing.item.is_counter_item: _err(f, "ремонт тратит счётчик '%s' — только ресурсы" % ing.item.item_name)
	var buyable := e.craft_gold_cost > 0
	if not buyable and e.craft_ingredients.is_empty():
		_warnings.append("%s: не продаётся и не крафтится (стартовый/дроп?)" % f)
	for ing in e.craft_ingredients:
		if ing.item == null: _err(f, "пустой ингредиент покупки")
		elif not (ing.item is equip_data) and not ing.item.is_counter_item:
			_err(f, "покупка требует ресурс '%s' — оружие/кирки получаем за монеты" % ing.item.item_name)
	if e.on_hit_effect != "none" and e.on_hit_chance <= 0.0:
		_err(f, "on_hit_effect задан, но шанс 0")
