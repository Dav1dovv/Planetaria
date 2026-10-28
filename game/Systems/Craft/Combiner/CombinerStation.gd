## CombinerStation.gd
## Окно КОМБИНАТОРА оружия. Открывается слева от рюкзака (справа — сам инвентарь, GDD).
##
##  Режим «Комбинировать»: 4 слота (основа + 3 добавки), превью результата, характеристики
##                          «было → стало», плюсы и минусы свойств, цена в монетах.
##  Режим «Ремонт»:        оружие в слот 1, любой ресурс в слот 2 — ресурс чинит оружие.
##
## Как класть предметы:   перетащить из рюкзака/хотбара ИЛИ просто кликнуть по предмету (A на геймпаде).
## Как забрать обратно:   клик по слоту комбинатора. При закрытии окна всё возвращается в рюкзак.
##
## Весь вид (слоты, подписи, тема) лежит в CombinerStation.tscn — правится в редакторе.
## Числа баланса — в forge_config.tres. Логика без интерфейса — в WeaponForge.gd.
extends Control
class_name CombinerStation

const C_OK := UIStyle.GREEN
const C_BAD := UIStyle.RED
const C_WARN := UIStyle.AMBER
const C_DIM := UIStyle.METAL_LIGHT
const C_ACCENT := UIStyle.CYAN
const C_TEXT := UIStyle.CYAN_LIGHT

## Предмет «Монета» (Coin.tres) — им платим за сборку
@export var gold_item: ItemData
## Звук удачной сборки (необязательно)
@export var success_sfx: AudioStream

@onready var tab_combine: Button = $Window/TabBar/TabCombine
@onready var tab_repair: Button = $Window/TabBar/TabRepair
@onready var slots: Array[CombinerSlot] = [
	$Window/Body/Left/SlotsRow/Cell0/Slot,
	$Window/Body/Left/SlotsRow/Cell1/Slot,
	$Window/Body/Left/SlotsRow/Cell2/Slot,
	$Window/Body/Left/SlotsRow/Cell3/Slot,
]
@onready var cells: Array[Control] = [
	$Window/Body/Left/SlotsRow/Cell0, $Window/Body/Left/SlotsRow/Cell1,
	$Window/Body/Left/SlotsRow/Cell2, $Window/Body/Left/SlotsRow/Cell3,
]
@onready var captions: Array[Label] = [
	$Window/Body/Left/SlotsRow/Cell0/Caption, $Window/Body/Left/SlotsRow/Cell1/Caption,
	$Window/Body/Left/SlotsRow/Cell2/Caption, $Window/Body/Left/SlotsRow/Cell3/Caption,
]
@onready var result_slot: CombinerSlot = $Window/Body/Left/ResultRow/ResultSlot
@onready var result_name: Label = $Window/Body/Left/ResultRow/ResultName
@onready var cost_label: Label = $Window/Body/Left/CostLabel
@onready var action_button: Button = $Window/Body/Left/ActionButton
@onready var status_label: Label = $Window/Body/Left/StatusLabel
@onready var stats_panel: CraftStatsPanel = $Window/Body/Right/StatsPanel
@onready var lines_box: VBoxContainer = $Window/Body/Right/Lines
@onready var rules_label: Label = $Window/Body/Right/RulesLabel
@onready var pad_hint: Label = $Window/PadHint
@onready var led: TerminalLed = $Window/Led
@onready var sfx: AudioStreamPlayer = $Sfx

var mode: WeaponForge.Mode = WeaponForge.Mode.COMBINE
var inventory: Inventory = null

var _bag_hooked: bool = false
var _preview: Dictionary = {}      # результат WeaponForge.build() для текущих слотов
var _repair: Dictionary = {}       # план ремонта
var _flash_token: int = 0
var _flash_until_ms: int = 0
var _refresh_queued: bool = false
var _pulse_tween: Tween


# ─────────────────────────────────────────────────────────────────────────────
#  Инициализация
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("combiner_station")
	inventory = get_tree().get_first_node_in_group("Inventory") as Inventory

	for slot in slots:
		slot.station = self
		slot.clicked.connect(_on_slot_clicked)
	result_slot.station = self
	result_slot.clicked.connect(func(_s: CombinerSlot) -> void: _on_action_pressed())

	tab_combine.pressed.connect(_set_mode.bind(WeaponForge.Mode.COMBINE))
	tab_repair.pressed.connect(_set_mode.bind(WeaponForge.Mode.REPAIR))
	action_button.pressed.connect(_on_action_pressed)
	visibility_changed.connect(_on_visibility_changed)

	InputHints.bind_label(pad_hint, _hint_text)
	_refresh()


func _hint_text() -> String:
	match InputHints.device():
		InputHints.Device.GAMEPAD:
			return Loc.t("A — add / take back   |   LB / RB — mode")
		InputHints.Device.TOUCH:
			return Loc.t("Tap an item — add   |   tap a slot — take back")
		_:
			return Loc.t("Click or drag items in   |   click a slot — take back")


## Слоты рюкзака появляются в Inventory._ready (после нас), поэтому цепляемся при первом открытии.
func _hook_bag_slots() -> void:
	if _bag_hooked or inventory == null:
		return
	_bag_hooked = true
	for data in inventory.items:
		data.slot_node.pressed.connect(_on_bag_slot_pressed.bind(data.slot_node))
	if inventory.hotbar:
		for data in inventory.hotbar.slots:
			data.slot_node.pressed.connect(_on_bag_slot_pressed.bind(data.slot_node))


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_hook_bag_slots()
		_flash_until_ms = 0
		UIStyle.boot($Window)
		_refresh()
		if InputHints.device() == InputHints.Device.GAMEPAD:
			slots[0].grab_focus.call_deferred()
	else:
		return_all_to_bag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_request_refresh()


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
		var next := wrapi(int(mode) + step, 0, 2)
		_set_mode(next as WeaponForge.Mode)


# ─────────────────────────────────────────────────────────────────────────────
#  Допуск предметов и перенос между рюкзаком и слотами
# ─────────────────────────────────────────────────────────────────────────────

func _reason(slot: CombinerSlot, item: ItemData) -> String:
	var others: Array = []
	for s in slots:
		if s != slot and s.slot_index >= 1 and s.item != null:
			others.append(s.item)
	return WeaponForge.why_not(mode, slot.slot_index, item, others)


## Вызывается слотом при наведении перетаскиваемого предмета.
func can_place(slot: CombinerSlot, item: ItemData) -> bool:
	if slot == result_slot or not cells[slot.slot_index].visible:
		return false
	return _reason(slot, item) == ""


## Вызывается слотом при отпускании предмета над ним.
func place_from_drag(slot: CombinerSlot, data: Dictionary) -> void:
	var src: InventorySlotData = data.get("source_slot", null)
	var amount: int = data.get("amount", 1)
	var is_split: bool = data.get("split", false)
	if src == null or src.item == null:
		return
	# Shift-перетаскивание уже «отщепило» часть стака у источника: вернём лишнее
	var placed := _place(slot, src, amount, is_split)
	if is_split and placed >= 0:
		var leftover := amount - placed
		if leftover > 0:
			src.amount += leftover
			src.slot_node.ammount = src.amount
			src.slot_node.update_ui()
			_notify_source_changed(src)


## Кладёт предмет из источника в слот. Возвращает, сколько штук взято (-1 — отказ).
func _place(slot: CombinerSlot, src: InventorySlotData, want: int, from_split: bool = false) -> int:
	var item := src.item
	if item == null:
		return -1
	var reason := _reason(slot, item)
	if reason != "":
		_deny(slot, reason)
		return -1
	if not slot.is_empty() and not _return_slot(slot):
		return -1  # обмен невозможен: рюкзак полон

	var count := 1
	if mode == WeaponForge.Mode.REPAIR and slot.slot_index == 1:
		# Ремонт принимает стопку ресурса (при Shift-перетаскивании — отщеплённую часть)
		count = want if from_split else clampi(want, 1, maxi(src.amount, 1))
	var moved := _take_from_source(src, count, from_split)
	slot.set_content(moved, count)
	_request_refresh()
	return count


## Достаёт count штук из слота-источника. Предмет едет сам (с прочностью), копия — только для остатка.
func _take_from_source(src: InventorySlotData, count: int, already_detached: bool) -> ItemData:
	var item := src.item
	var out: ItemData
	if already_detached:
		# Shift-перетаскивание: у источника уже отнято, предмет остаётся в источнике как шаблон
		out = item.duplicate()
	elif src.amount <= count:
		out = item
		src.item = null
		src.amount = 0
	else:
		out = item.duplicate()
		src.amount -= count
	src.slot_node.item = src.item
	src.slot_node.ammount = src.amount
	src.slot_node.update_ui()
	_notify_source_changed(src)
	return out


func _notify_source_changed(src: InventorySlotData) -> void:
	if inventory == null:
		return
	inventory.emit_signal("inventory_changed")
	var hotbar := inventory.hotbar
	if hotbar != null and src.slot_node != null and src.slot_node.hotbar != null:
		hotbar.emit_signal("hotbar_changed")
		hotbar._recalculate_accessories()
		hotbar._update_equip()


## Клик по предмету в рюкзаке/хотбаре, пока окно открыто: отправляем его в подходящий слот.
func _on_bag_slot_pressed(bag_slot: InventorySlot) -> void:
	if not is_visible_in_tree() or inventory == null or Input.is_key_pressed(KEY_SHIFT):
		return
	var src: InventorySlotData = null
	if bag_slot.hotbar != null:
		src = inventory.hotbar.get_slot_data_by_node(bag_slot)
	else:
		src = inventory.get_slot_data_by_node(bag_slot)
	if src == null or src.item == null:
		return

	var target := _auto_target(src.item)
	if target == null:
		# Покажем, почему нельзя (причина для первого слота, куда предмет мог бы по смыслу идти)
		var is_weapon := WeaponForge.role_of(src.item) == WeaponForge.Role.WEAPON
		var probe := slots[0] if (is_weapon and slots[0].is_empty()) else slots[1]
		var why := _reason(probe, src.item)
		_deny(probe, why if why != "" else "No free slot")
		return
	_place(target, src, src.amount)


## Первый подходящий пустой слот. В режиме ремонта занятый слот заменяется (оружие ↔ оружие, ресурс ↔ ресурс).
## В режиме комбинации ничего не заменяем молча: чтобы сменить основу, сначала кликни по ней.
func _auto_target(item: ItemData) -> CombinerSlot:
	var limit := 2 if mode == WeaponForge.Mode.REPAIR else slots.size()
	for i in limit:
		if slots[i].is_empty() and _reason(slots[i], item) == "":
			return slots[i]
	if mode == WeaponForge.Mode.REPAIR:
		for i in 2:
			if _reason(slots[i], item) == "":
				return slots[i]
	return null


func _on_slot_clicked(slot: CombinerSlot) -> void:
	if slot.is_empty():
		_flash(Loc.t("Click an item in your bag to add it"), C_DIM, 1.4)
		return
	if _return_slot(slot):
		_request_refresh()


## Возвращает содержимое слота в рюкзак. false — места нет (предмет остаётся в слоте).
func _return_slot(slot: CombinerSlot) -> bool:
	if slot.item == null:
		return true
	if inventory == null or not inventory.can_add_item(slot.item, slot.ammount):
		_flash(Loc.t("Bag is full"), C_BAD, 1.6)
		slot.flash_denied()
		return false
	Global.pickup_item(slot.item, slot.ammount, true)
	slot.set_content(null)
	return true


## Всё из слотов — обратно в рюкзак (закрытие окна, смена режима, сохранение игры).
func return_all_to_bag() -> void:
	if not is_node_ready():
		return
	for slot in slots:
		_return_slot(slot)
	_request_refresh()


func _deny(slot: CombinerSlot, reason_key: String) -> void:
	slot.flash_denied()
	_flash(Loc.t(reason_key), C_BAD, 1.8)


# ─────────────────────────────────────────────────────────────────────────────
#  Режимы
# ─────────────────────────────────────────────────────────────────────────────

func _set_mode(new_mode: WeaponForge.Mode) -> void:
	if new_mode == mode:
		return
	return_all_to_bag()
	mode = new_mode
	_flash_until_ms = 0
	_refresh()


# ─────────────────────────────────────────────────────────────────────────────
#  Обновление экрана
# ─────────────────────────────────────────────────────────────────────────────

func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_deferred_refresh.call_deferred()


func _deferred_refresh() -> void:
	_refresh_queued = false
	_refresh()


func _refresh() -> void:
	tab_combine.modulate = Color.WHITE if mode == WeaponForge.Mode.COMBINE else Color(0.6, 0.6, 0.6)
	tab_repair.modulate = Color.WHITE if mode == WeaponForge.Mode.REPAIR else Color(0.6, 0.6, 0.6)
	var repairing := mode == WeaponForge.Mode.REPAIR
	cells[2].visible = not repairing
	cells[3].visible = not repairing
	_update_captions()
	_clear_lines()
	_preview = {}
	_repair = {}
	if repairing:
		_refresh_repair()
	else:
		_refresh_combine()


func _update_captions() -> void:
	if mode == WeaponForge.Mode.REPAIR:
		captions[0].text = Loc.t("Weapon")
		captions[1].text = Loc.t("Resource")
		action_button.text = Loc.t("REPAIR")
		rules_label.text = Loc.t("A resource restores durability. Any resource works.")
	else:
		captions[0].text = Loc.t("Base")
		for i in range(1, 4):
			captions[i].text = Loc.t("Add-on")
		action_button.text = Loc.t("Combine")
		rules_label.text = Loc.t("4 slots. Only 1 extra weapon. The rest — materials.")


func _refresh_combine() -> void:
	var items: Array = []
	for slot in slots:
		items.append(slot.item)
	var info := WeaponForge.inspect(items)

	if info["problem"] != "":
		result_slot.set_content(null)
		result_name.text = ""
		stats_panel.hide_stats()
		cost_label.text = ""
		_set_action(false, Loc.t(info["problem"]), C_DIM)
		return

	var base := info["base"] as equip_data
	_preview = WeaponForge.build(base, info["donor"] as equip_data, info["mats"] as Array[ItemData])
	var weapon := _preview["weapon"] as CombinedWeapon
	result_slot.set_content(weapon)
	result_name.text = weapon.item_name
	stats_panel.show_stats(weapon, base)

	# Плюсы и минусы: по каждому ресурсу/реликвии отдельный блок
	for mat in info["mats"] as Array[ItemData]:
		_add_line(Loc.t(mat.item_name), C_TEXT, false)
		for prop in mat.craft_properties:
			if prop == null:
				continue
			for line in prop.describe_lines():
				var good: bool = line["good"]
				_add_line(("+ " if good else "− ") + line["text"], C_OK if good else C_BAD, true)
	for note in _preview["notes"] as Array[Dictionary]:
		_add_line(note["text"], note["color"], false)
	_add_line("%s: %d / %d" % [Loc.t("Durability"), weapon.max_durability, WeaponForge.config().base_durability], C_DIM, false)

	var fee: int = _preview["fee"]
	var coins := inventory.get_total_item_count(gold_item) if (inventory and gold_item) else 0
	cost_label.text = "%s: %d  (%d)" % [Loc.t("Cost"), fee, coins]
	cost_label.add_theme_color_override("font_color", C_OK if coins >= fee else C_BAD)

	if coins < fee:
		_set_action(false, Loc.t("Not enough coins"), C_BAD)
	else:
		_set_action(true, "", C_DIM)


func _refresh_repair() -> void:
	var weapon := slots[0].item as equip_data
	var resource := slots[1].item
	result_slot.set_content(null)
	result_name.text = ""
	stats_panel.hide_stats()
	cost_label.text = ""
	if weapon == null:
		_set_action(false, Loc.t("Put a weapon to repair"), C_DIM)
		return
	var cur := weapon.get_durability()
	_add_line("%s: %d / %d" % [Loc.t("Durability"), cur, weapon.max_durability], C_TEXT, false)
	if cur >= weapon.max_durability:
		_set_action(false, Loc.t("Item is not damaged"), C_DIM)
		return
	if resource == null:
		_set_action(false, Loc.t("Add a resource to repair with"), C_DIM)
		return
	_repair = WeaponForge.repair_plan(weapon, resource, slots[1].ammount)
	_add_line("%s +%d  (%d → %d)" % [Loc.t("Durability"), _repair["restore"], cur, cur + int(_repair["restore"])], C_OK, true)
	_add_line("%s: %d × %s" % [Loc.t("Uses"), _repair["units"], Loc.t(resource.item_name)], C_DIM, true)
	cost_label.text = "%s: %d × %s" % [Loc.t("Uses"), _repair["units"], Loc.t(resource.item_name)]
	cost_label.add_theme_color_override("font_color", C_DIM)
	_set_action(true, "", C_DIM)


func _set_action(ready_to_go: bool, reason: String, reason_color: Color) -> void:
	action_button.disabled = not ready_to_go
	led.color_on = C_ACCENT if ready_to_go else UIStyle.METAL_DARK
	led.color_off = led.color_on
	if Time.get_ticks_msec() < _flash_until_ms:
		return
	status_label.text = reason
	status_label.add_theme_color_override("font_color", reason_color)


func _clear_lines() -> void:
	for child in lines_box.get_children():
		lines_box.remove_child(child)
		child.queue_free()


func _add_line(text: String, color: Color, indent: bool) -> void:
	var label := Label.new()
	label.text = ("  " if indent else "") + text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", color)
	lines_box.add_child(label)


## Временное сообщение (успех / отказ); потом возвращается обычный статус.
func _flash(text: String, color: Color, seconds: float = 1.5) -> void:
	_flash_token += 1
	var token := _flash_token
	_flash_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if token == _flash_token:
			_flash_until_ms = 0
			_refresh())


# ─────────────────────────────────────────────────────────────────────────────
#  Действие: собрать / починить
# ─────────────────────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	if action_button.disabled or inventory == null:
		return
	if mode == WeaponForge.Mode.COMBINE:
		_do_combine()
	else:
		_do_repair()


func _do_combine() -> void:
	if _preview.is_empty():
		return
	var weapon := _preview["weapon"] as CombinedWeapon
	var fee: int = _preview["fee"]
	if gold_item != null and fee > 0 and not inventory.has_total_item(gold_item, fee):
		_flash(Loc.t("Not enough coins"), C_BAD, 1.8)
		return
	if not inventory.can_add_item(weapon, 1):
		_flash(Loc.t("Bag is full"), C_BAD, 1.8)
		return

	# Сначала платим, потом сжигаем ингредиенты и выдаём результат
	if gold_item != null and fee > 0:
		inventory.remove_from_total(gold_item, fee)
	for slot in slots:
		slot.set_content(null)
	Global.pickup_item(weapon, 1, true)

	_celebrate(Loc.t("Created: %s") % weapon.item_name)


func _do_repair() -> void:
	var weapon := slots[0].item as equip_data
	var resource_slot := slots[1]
	if weapon == null or resource_slot.item == null or _repair.is_empty():
		return
	var units: int = _repair["units"]
	var restore: int = _repair["restore"]
	if units <= 0 or restore <= 0:
		return
	weapon.repair(restore)  # equip_data.repair(amount) прибавляет amount к текущей прочности
	var left := resource_slot.ammount - units
	resource_slot.set_content(resource_slot.item if left > 0 else null, left)
	_celebrate(Loc.t("Repaired: %s") % Loc.t(weapon.item_name))


func _celebrate(message: String) -> void:
	_refresh()
	_flash(message, C_OK, 1.8)
	if success_sfx != null:
		sfx.stream = success_sfx
		sfx.play()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	result_slot.pivot_offset = result_slot.size / 2.0
	result_slot.scale = Vector2(1.4, 1.4)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(result_slot, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
