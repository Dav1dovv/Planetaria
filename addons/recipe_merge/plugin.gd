@tool
extends EditorPlugin
## Recipe Merge (Godot 4.2+). Меню: Project → Tools → «Recipe Merge…»

const MENU_NAME := "Recipe Merge: слить рецепты в ItemData"
const BACKUP_DIR := "res://_recipe_merge_backup/"
const TPL_DIR := "res://addons/recipe_merge/templates/"
const RECIPE_KEYS := [
	"mode", "result_item", "result_amount",
	"main_resource", "main_amount", "secondary_resource", "secondary_amount",
	"third_resource", "third_amount", "gold_cost",
	"disassemble_target", "salvage_resource_1", "salvage_amount_1",
	"salvage_resource_2", "salvage_amount_2", "salvage_resource_3", "salvage_amount_3",
	"repair_target", "repair_amount", "required_smith_level",
	"station_restriction", "category",
]

var dlg: AcceptDialog
var folder_edit: LineEdit
var move_check: CheckBox
var log_box: RichTextLabel
var _warnings := 0

func _enter_tree() -> void:
	add_tool_menu_item(MENU_NAME, _open_dialog)
	_build_ui()

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if is_instance_valid(dlg):
		dlg.queue_free()

func _open_dialog() -> void:
	dlg.popup_centered(Vector2i(780, 600))

# ───────────────────────── UI ─────────────────────────
func _build_ui() -> void:
	dlg = AcceptDialog.new()
	dlg.title = "Recipe Merge"
	dlg.ok_button_text = "Закрыть"
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(740, 520)
	dlg.add_child(vb)

	var info := Label.new()
	info.text = "Шаг 1: ставит поля в ItemData, ItemDB (автозагрузка), новый CraftRecipe, патчит CraftStation и CraftManager. Потом дождись конца сканирования файлов.\nШаг 2: переносит данные старых рецептов в предметы.\nВсе изменяемые файлы сначала копируются в res://_recipe_merge_backup/. Лучше ещё и сделать коммит в git."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(720, 0)
	vb.add_child(info)

	var row := HBoxContainer.new()
	vb.add_child(row)
	var lbl := Label.new()
	lbl.text = "Папка старых рецептов:"
	row.add_child(lbl)
	folder_edit = LineEdit.new()
	folder_edit.text = "res://misc/Content/Recipes/Craft/"
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(folder_edit)

	move_check = CheckBox.new()
	move_check.text = "После миграции убрать старые рецепты (.tres) в backup"
	move_check.button_pressed = true
	vb.add_child(move_check)

	var btns := HBoxContainer.new()
	vb.add_child(btns)
	var b1 := Button.new()
	b1.text = "Шаг 1: установить"
	b1.pressed.connect(_step1)
	btns.add_child(b1)
	var b2 := Button.new()
	b2.text = "Шаг 2: перенести рецепты"
	b2.pressed.connect(_step2)
	btns.add_child(b2)

	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(log_box)

	EditorInterface.get_base_control().add_child(dlg)

func _log(msg: String, color: String = "white") -> void:
	if color == "yellow" or color == "red":
		_warnings += 1
	log_box.append_text("[color=%s]%s[/color]\n" % [color, msg.replace("[", "[lb]")])
	print("[RecipeMerge] ", msg)

# ───────────────────────── ШАГ 1 ─────────────────────────
func _step1() -> void:
	log_box.clear()
	_warnings = 0
	EditorInterface.save_all_scenes()

	var item_path := _class_path("ItemData")
	var recipe_path := _class_path("CraftRecipe")
	if item_path == "" or recipe_path == "":
		_log("Не найдены классы ItemData / CraftRecipe в проекте.", "red")
		return

	_backup("res://project.godot")
	_backup(item_path)
	_backup(recipe_path)

	if not _patch_itemdata(item_path):
		return

	# CraftIngredient (должен быть @tool, чтобы плагин мог создавать его в редакторе)
	var ing_path := _class_path("CraftIngredient")
	if ing_path == "":
		ing_path = item_path.get_base_dir().path_join("CraftIngredient.gd")
		_write(ing_path, _tpl("CraftIngredient.gd.txt"))
		_log("Создан " + ing_path, "green")
	else:
		var t := FileAccess.get_file_as_string(ing_path)
		if not t.contains("@tool"):
			_backup(ing_path)
			_write(ing_path, "@tool\n" + t)
			_log("В %s добавлен @tool" % ing_path, "green")

	# Новый CraftRecipe (адаптер)
	_write(recipe_path, _tpl("CraftRecipe.gd.txt"))
	_log("Обновлён " + recipe_path, "green")

	# ItemDB + автозагрузка
	var folders := _detect_item_folders()
	if folders.is_empty():
		_log("Не найдено ни одного .tres с предметами! Впиши папки в ItemDB.gd (ITEM_FOLDERS) вручную.", "yellow")
	var quoted: Array = []
	for f in folders:
		quoted.append('"%s"' % f)
	var db_text := _tpl("ItemDB.gd.txt").replace("__ITEM_FOLDERS__", ", ".join(quoted))
	var db_path := item_path.get_base_dir().path_join("ItemDB.gd")
	_write(db_path, db_text)
	if ProjectSettings.has_setting("autoload/ItemDB"):
		remove_autoload_singleton("ItemDB")
	add_autoload_singleton("ItemDB", db_path)
	_log("ItemDB создан (%s), папки предметов: %s" % [db_path, ", ".join(folders)], "green")

	# CraftManager / CraftStation
	var mgr := _find_script_containing("class_name CraftingManager")
	if mgr != "":
		_backup(mgr)
		_write(mgr, _tpl("CraftManager.gd.txt"))
		_log("Заменён " + mgr, "green")
	else:
		_log("CraftManager не найден — пропускаю.", "yellow")

	var station := _find_script_containing("func _load_recipes")
	if station != "":
		_patch_station(station)
	else:
		_log("CraftStation (func _load_recipes) не найден — поправь вручную: all_recipes = ItemDB.get_recipes()", "yellow")

	EditorInterface.get_resource_filesystem().scan()
	_log("\nШАГ 1 ГОТОВ. Подожди, пока Godot закончит сканирование (индикатор справа вверху), затем жми «Шаг 2».", "cyan")

# ───────────────────────── ШАГ 2 ─────────────────────────
func _step2() -> void:
	log_box.clear()
	_warnings = 0
	EditorInterface.save_all_scenes()

	var item_script_path := _class_path("ItemData")
	var ing_script_path := _class_path("CraftIngredient")
	if item_script_path == "" or ing_script_path == "":
		_log("Не найдены ItemData/CraftIngredient. Сначала Шаг 1.", "red")
		return
	var item_script: Script = ResourceLoader.load(item_script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	var names: Array = []
	for p in item_script.get_script_property_list():
		names.append(p["name"])
	if not "craft_ingredients" in names:
		_log("В ItemData ещё нет новых полей. Выполни Шаг 1 и дождись сканирования.", "red")
		return
	var ing_script: Script = ResourceLoader.load(ing_script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)

	var folder := folder_edit.text.strip_edges()
	var files: Array = []
	_walk(folder, ["tres", "res"], [], files)
	var recipe_files: Array = []
	for f in files:
		if _script_class(f) == "CraftRecipe":
			recipe_files.append(f)
	if recipe_files.is_empty():
		_log("В %s нет старых рецептов CraftRecipe (.tres)." % folder, "yellow")
		return

	var touched: Dictionary = {}
	var claimed: Dictionary = {}
	var stats := {"craft": 0, "salvage": 0, "repair": 0}
	for f in recipe_files:
		_migrate_one(f, _parse_recipe(f), ing_script, touched, claimed, stats)

	for path in touched:
		_backup(path)
		var err := ResourceSaver.save(touched[path], path)
		if err != OK:
			_log("Не удалось сохранить %s (ошибка %d)" % [path, err], "red")

	if move_check.button_pressed:
		for f in recipe_files:
			_backup(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		_log("Старые рецепты перемещены в " + BACKUP_DIR, "green")

	EditorInterface.get_resource_filesystem().scan()
	_log("\nГОТОВО. Крафт: %d, ремонт: %d, разборка: %d. Изменено предметов: %d. Предупреждений: %d." % [
		stats["craft"], stats["repair"], stats["salvage"], touched.size(), _warnings], "cyan")

func _migrate_one(file: String, d: Dictionary, ing_script: Script, touched: Dictionary, claimed: Dictionary, stats: Dictionary) -> void:
	var mode := int(d["mode"])
	match mode:
		0: # CRAFT
			var item = _load_item(d["result_item"])
			if item == null:
				_log("%s: нет result_item — пропущен" % file.get_file(), "yellow"); return
			if claimed.has("0:" + item.resource_path):
				_log("%s: у «%s» уже есть крафт-рецепт, этот потерян" % [file.get_file(), item.item_name], "yellow"); return
			claimed["0:" + item.resource_path] = true
			_set_list(item, "craft_ingredients", [
				[d["main_resource"], d["main_amount"]],
				[d["secondary_resource"], d["secondary_amount"]],
				[d["third_resource"], d["third_amount"]]], ing_script)
			item.set("craft_amount", int(d["result_amount"]))
			item.set("craft_gold_cost", int(d["gold_cost"]))
			item.set("craft_category", int(d["category"]))
			item.set("craft_smith_level", int(d["required_smith_level"]))
			item.set("craft_station", int(d["station_restriction"]))
			touched[item.resource_path] = item
			stats["craft"] += 1
		1: # REPAIR
			var item = _load_item(d["repair_target"])
			if item == null:
				_log("%s: универсальный ремонт (repair_target пуст) не переносится" % file.get_file(), "yellow"); return
			if claimed.has("1:" + item.resource_path):
				_log("%s: у «%s» уже есть рецепт ремонта, этот потерян" % [file.get_file(), item.item_name], "yellow"); return
			claimed["1:" + item.resource_path] = true
			_set_list(item, "repair_ingredients", [
				[d["main_resource"], d["main_amount"]],
				[d["secondary_resource"], d["secondary_amount"]],
				[d["third_resource"], d["third_amount"]]], ing_script)
			item.set("repair_gold_cost", int(d["gold_cost"]))
			item.set("repair_amount", int(d["repair_amount"]))
			touched[item.resource_path] = item
			stats["repair"] += 1
		2: # DISASSEMBLE
			var item = _load_item(d["disassemble_target"])
			if item == null:
				_log("%s: нет disassemble_target — пропущен" % file.get_file(), "yellow"); return
			if claimed.has("2:" + item.resource_path):
				_log("%s: у «%s» уже есть разборка, эта потеряна" % [file.get_file(), item.item_name], "yellow"); return
			claimed["2:" + item.resource_path] = true
			_set_list(item, "salvage", [
				[d["salvage_resource_1"], d["salvage_amount_1"]],
				[d["salvage_resource_2"], d["salvage_amount_2"]],
				[d["salvage_resource_3"], d["salvage_amount_3"]]], ing_script)
			touched[item.resource_path] = item
			stats["salvage"] += 1

func _set_list(item: Resource, prop: String, pairs: Array, ing_script: Script) -> void:
	var arr := Array([], TYPE_OBJECT, &"Resource", ing_script)
	for p in pairs:
		var res = _load_item(p[0])
		if res == null or int(p[1]) <= 0:
			continue
		var c = ing_script.new()
		c.set("item", res)
		c.set("amount", int(p[1]))
		arr.append(c)
	item.set(prop, arr)

func _load_item(path: String) -> Resource:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r = load(path)
	if r is Resource and r.resource_path != "":
		return r
	return null

# ─────────── Разбор старого .tres как текста (не зависит от старого скрипта) ───────────
func _parse_recipe(path: String) -> Dictionary:
	var d := {
		"mode": 0, "result_item": "", "result_amount": 1,
		"main_resource": "", "main_amount": 1, "secondary_resource": "", "secondary_amount": 1,
		"third_resource": "", "third_amount": 1, "gold_cost": 0,
		"disassemble_target": "", "salvage_resource_1": "", "salvage_amount_1": 1,
		"salvage_resource_2": "", "salvage_amount_2": 0, "salvage_resource_3": "", "salvage_amount_3": 0,
		"repair_target": "", "repair_amount": 0, "required_smith_level": 1,
		"station_restriction": 0, "category": 0,
	}
	var ext: Dictionary = {}
	var in_res := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("[ext_resource"):
			var p := _attr(line, "path")
			if p == "":
				var uid := _attr(line, "uid")
				if uid != "":
					var id := ResourceUID.text_to_id(uid)
					if ResourceUID.has_id(id):
						p = ResourceUID.get_id_path(id)
			ext[_attr(line, "id")] = p
		elif line.begins_with("[resource]"):
			in_res = true
		elif in_res and " = " in line:
			var k := line.get_slice(" = ", 0)
			if k in RECIPE_KEYS:
				var v := line.substr(k.length() + 3)
				if v.begins_with("ExtResource("):
					d[k] = ext.get(v.get_slice("\"", 1), "")
				elif v.begins_with("SubResource("):
					d[k] = ""
					_log("%s: %s — встроенный SubResource, не перенесён" % [path.get_file(), k], "yellow")
				else:
					d[k] = str_to_var(v)
	return d

func _attr(line: String, key: String) -> String:
	var rx := RegEx.create_from_string("\\s%s=\"([^\"]*)\"" % key)
	var m := rx.search(line)
	return m.get_string(1) if m else ""

# ───────────────────────── Патчи ─────────────────────────
func _patch_itemdata(path: String) -> bool:
	var t := FileAccess.get_file_as_string(path)
	if t.contains("craft_ingredients"):
		_log("ItemData уже содержит поля рецепта — пропускаю.", "yellow")
		return true
	var m := RegEx.create_from_string("(?m)^class_name\\s+ItemData[ \\t]*\\r?$").search(t)
	if not m:
		_log("В %s не найдена строка «class_name ItemData»." % path, "red")
		return false
	t = t.insert(m.get_end(), "\n\n" + _tpl("ItemData_enum.txt").rstrip("\n"))
	t = t.rstrip("\n") + "\n\n" + _tpl("ItemData_fields.txt")
	_write(path, t)
	_log("ItemData дополнен полями рецепта (%s)." % path, "green")
	return true

func _patch_station(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.contains("ItemDB.get_recipes()"):
		_log("CraftStation уже пропатчен.", "yellow"); return
	var lines := text.split("\n")
	var start := -1
	for i in lines.size():
		if lines[i].begins_with("func _load_recipes"):
			start = i; break
	if start < 0:
		_log("В %s нет func _load_recipes" % path, "yellow"); return
	var finish := lines.size()
	for j in range(start + 1, lines.size()):
		var ln: String = lines[j]
		if ln.strip_edges() != "" and not ln.begins_with("\t") and not ln.begins_with(" "):
			finish = j; break
	_backup(path)
	var body := PackedStringArray([
		"func _load_recipes() -> void:",
		"\t# Рецепты строит ItemDB из полей ItemData (аддон Recipe Merge)",
		"\tall_recipes = ItemDB.get_recipes()",
		"",
	])
	var out := lines.slice(0, start) + body + lines.slice(finish)
	_write(path, "\n".join(out))
	_log("CraftStation пропатчен: " + path, "green")

# ───────────────────────── Утилиты ─────────────────────────
func _tpl(file: String) -> String:
	return FileAccess.get_file_as_string(TPL_DIR + file)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_log("Не могу записать " + path, "red"); return
	f.store_string(text)
	f.close()

func _backup(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dst := BACKUP_DIR + path.trim_prefix("res://")
	if FileAccess.file_exists(dst):
		return   # оригинал уже сохранён раньше — не затираем
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(dst))

func _class_path(cname: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cname:
			return c["path"]
	return ""

func _item_classes() -> Array:
	var names: Array = ["ItemData"]
	var changed := true
	while changed:
		changed = false
		for c in ProjectSettings.get_global_class_list():
			if c["base"] in names and not (c["class"] in names):
				names.append(c["class"]); changed = true
	return names

func _script_class(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var m := RegEx.create_from_string("script_class=\"([^\"]+)\"").search(f.get_line())
	return m.get_string(1) if m else ""

func _detect_item_folders() -> Array:
	var files: Array = []
	_walk("res://", ["tres", "res"], [], files)
	var classes := _item_classes()
	var dirs: Dictionary = {}
	for f in files:
		if _script_class(f) in classes:
			dirs[f.get_base_dir() + "/"] = true
	# убираем вложенные папки — ItemDB сканирует рекурсивно
	var keys := dirs.keys()
	keys.sort()
	var result: Array = []
	for k in keys:
		var nested := false
		for r in result:
			if k.begins_with(r):
				nested = true; break
		if not nested:
			result.append(k)
	return result

func _find_script_containing(needle: String) -> String:
	var files: Array = []
	_walk("res://", ["gd"], [], files)
	for f in files:
		if FileAccess.get_file_as_string(f).contains(needle):
			return f
	return ""

func _walk(dir_path: String, exts: Array, skip: Array, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				if f != "addons" and not (full + "/").begins_with(BACKUP_DIR) and not skip.has(full):
					_walk(full, exts, skip, out)
			elif f.get_extension() in exts:
				out.append(full)
		f = d.get_next()
