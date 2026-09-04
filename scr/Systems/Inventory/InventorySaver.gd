# InventorySaver.gd
extends Node

@export var inventory_node: Inventory
@export var hotbar_node:    Hotbar

var inventory: Inventory:
	get: return inventory_node
var hotbar: Hotbar:
	get: return hotbar_node

func _ready() -> void:
	# Ждём один полный кадр — все slot._ready() гарантированно выполнены
	await get_tree().process_frame
	await get_tree().process_frame
	load_game()


# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение / загрузка  (файловый I/O только через SaveSystem)
# ─────────────────────────────────────────────────────────────────────────────

func save_game() -> void:
	var data := {
		"version"   : 9,
		"inventory" : _pack_container(inventory.items),
		"hotbar"    : _pack_container(hotbar.slots),
		"counters"  : inventory.pack_counters()
	}

	SaveLoad.save_inventory(data)


func load_game() -> void:
	var data: Dictionary = SaveLoad.load_inventory()

	if data.is_empty():
		print("[InventorySaver] Нет сохранения → стартовые предметы")
		Global.add_initial_items()
		return

	var version: int = data.get("version", 1)
	if version < 5:
		print("[InventorySaver] Старое сохранение (v%d) → сброс" % version)
		Global.add_initial_items()
		return

	_clear_all()
	_unpack_container(inventory.items, data.get("inventory", []))
	_unpack_container(hotbar.slots,    data.get("hotbar", []))
	inventory.unpack_counters(data.get("counters", []))

	hotbar._recalculate_accessories()
	hotbar.select_slot(hotbar.selected_index)
	inventory.emit_signal("inventory_changed")
	hotbar.emit_signal("hotbar_changed")
	print("[InventorySaver] Инвентарь загружен (v%d)" % version)


# ─────────────────────────────────────────────────────────────────────────────
#  Всё ниже не тронуто — сериализация предметов
# ─────────────────────────────────────────────────────────────────────────────

func _clear_all() -> void:
	for slot_data in inventory.items + hotbar.slots:
		slot_data.item = null
		slot_data.amount = 0
		slot_data.slot_node.item    = null
		slot_data.slot_node.ammount = 0
		slot_data.slot_node.update_ui()

func _pack_container(container: Array[InventorySlotData]) -> Array:
	var packed = []
	for slot_data in container:
		if !slot_data.item:
			packed.append(null)
			continue
		var item = slot_data.item
		var entry: Dictionary = {
			"type"        : _get_item_type(item),
			"item_name"   : item.item_name,
			"Animation"   : item.play_anim,
			"description" : item.description,
			"amount"      : slot_data.amount,
			"max_count"   : item.max_count,
			"stackable"   : item.stackable,
			"quality"     : item.quality,
			"icon_data"   : _serialize_texture(item.icon)
		}
		if item is equip_data:
			entry.merge({
				"lvl"             : item.lvl,
				"Damage"          : item.Damage,
				"hit_distance"    : item.hit_distance,
				"Atk_speed"       : item.Atk_speed,
				"sprite_data"     : _serialize_texture(item.equiped_weapon_sprite),
				"projectile_path" : item.projectile.resource_path if item.projectile else "",
				"is_weapon"       : item.is_weapon,
				"one_shot"        : item.one_shot_attack,
				"durability"      : item.get_durability(),
				"max_durability"  : item.max_durability
			})
		if item is FoodData:
			entry["hunger"] = item.health_restore
			entry["curse_rmv"] = item.remove_corription
			if item.eat_sound:
				entry["eat_sound"] = item.eat_sound.resource_path
			if item.effects.size() > 0:
				entry["effects"] = _pack_effects(item.effects)
		if item is AccessoryData && item.effects.size() > 0:
			entry["effects"] = _pack_effects(item.effects)
		packed.append(entry)
	return packed

func _unpack_container(container: Array[InventorySlotData], packed: Array) -> void:
	for i in range(min(container.size(), packed.size())):
		var entry = packed[i]
		if !entry: continue
		var item = _create_item_from_dict(entry)
		if !item: continue
		var slot_data = container[i]
		slot_data.item = item
		slot_data.amount = entry.get("amount", 1)
		slot_data.slot_node.item = item
		slot_data.slot_node.ammount = slot_data.amount
		slot_data.slot_node.update_ui()

func _create_item_from_dict(data: Dictionary) -> ItemData:
	var item: ItemData
	match data.get("type"):
		"equip_data":
			item = equip_data.new()
			item.lvl = data.get("lvl", 1)
			item.Damage = data.get("Damage", 5)
			if data.has("hit_distance"):
				item.hit_distance = data.hit_distance
			item.Atk_speed = data.get("Atk_speed", 1.0)
			item.equiped_weapon_sprite = _deserialize_texture(data.get("sprite_data"))
			if data.has("projectile_path") and data.projectile_path != "" and ResourceLoader.exists(data.projectile_path):
				item.projectile = load(data.projectile_path)
			item.is_weapon = data.get("is_weapon", true)
			item.one_shot_attack = data.get("one_shot", true)
			item.max_durability = data.get("max_durability", 100)
			item.durability = data.get("durability", item.max_durability)
		"FoodData":
			item = FoodData.new()
			item.health_restore = data.get("hunger", 20.0)
			item.remove_corription = data.get("curse_rmv",10) 
			if data.has("eat_sound") and ResourceLoader.exists(data.eat_sound):
				item.eat_sound = load(data.eat_sound)
			if data.has("effects"):
				item.effects = _unpack_effects(data.effects)
		"AccessoryData":
			item = AccessoryData.new()
			if data.has("effects"):
				item.effects = _unpack_effects(data.effects)
		_:
			item = ItemData.new()

	item.item_name   = data.get("item_name", "??")
	item.play_anim   = data.get("Animation", "Attack")
	item.description = data.get("description", "")
	item.max_count   = data.get("max_count", 64)
	item.stackable   = data.get("stackable", true)
	item.icon        = _deserialize_texture(data.get("icon_data"))
	item.quality     = data.get("quality", 0)

	if item is equip_data and not data.has("durability"):
		if item.has_method("apply_quality_multiplier"):
			item.apply_quality_multiplier(item.quality)
	elif not (item is equip_data):
		if item.has_method("apply_quality_multiplier"):
			item.apply_quality_multiplier(item.quality)

	return item

func _get_item_type(item: ItemData) -> String:
	if item is equip_data:    return "equip_data"
	if item is FoodData:      return "FoodData"
	if item is AccessoryData: return "AccessoryData"
	return "ItemData"

func _pack_effects(effects: Array[Effect]) -> Array:
	var arr: Array = []
	for e in effects:
		var d: Dictionary = {
			"type"     : e.effect_type,
			"value"    : e.value,
			"duration" : e.duration,
			"color"    : {"r": e.particle_color.r, "g": e.particle_color.g, "b": e.particle_color.b, "a": e.particle_color.a}
		}
		if e.particle: d["particle"] = e.particle.resource_path
		if e.icon:     d["icon"]     = _serialize_texture(e.icon)
		arr.append(d)
	return arr

func _unpack_effects(arr: Array) -> Array[Effect]:
	var effects: Array[Effect] = []
	for d in arr:
		var e := Effect.new()
		e.effect_type = d.get("type", 0)
		e.value       = d.get("value", 0.0)
		e.duration    = d.get("duration", 0.0)
		if d.has("color"):
			var c = d.color
			e.particle_color = Color(c.r, c.g, c.b, c.a)
		if d.has("particle") and ResourceLoader.exists(d.particle):
			e.particle = load(d.particle)
		if d.has("icon"):
			e.icon = _deserialize_texture(d.icon)
		effects.append(e)
	return effects

func _serialize_texture(t: Texture2D) -> Dictionary:
	if not t: return {}
	if t.resource_path != "":
		return {"path": t.resource_path}
	if t is AtlasTexture and t.atlas and t.atlas.resource_path != "":
		return {
			"type"       : "atlas",
			"atlas_path" : t.atlas.resource_path,
			"region"     : [t.region.position.x, t.region.position.y, t.region.size.x, t.region.size.y],
			"margin"     : [t.margin.position.x, t.margin.position.y, t.margin.size.x, t.margin.size.y]
		}
	return {}

func _deserialize_texture(data: Dictionary) -> Texture2D:
	if not data or data.is_empty(): return null
	if data.has("path") and data.path != "" and ResourceLoader.exists(data.path):
		return load(data.path)
	if data.get("type") == "atlas" and data.has("atlas_path") and ResourceLoader.exists(data.atlas_path):
		var at := AtlasTexture.new()
		at.atlas = load(data.atlas_path)
		if data.has("region"):
			at.region = Rect2(data.region[0], data.region[1], data.region[2], data.region[3])
		if data.has("margin"):
			at.margin = Rect2(data.margin[0], data.margin[1], data.margin[2], data.margin[3])
		return at
	return null
