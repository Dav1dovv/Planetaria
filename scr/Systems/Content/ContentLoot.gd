class_name ContentLoot
extends RefCounted
## Таблицы лута нового контента: оружие, напитки, материалы, реликвии.
## Всё данные-ориентированно: предметы берутся из ItemDB по item_name,
## чтобы добавить новый дроп — достаточно дописать строку в таблицу ниже.
##
## Точки входа (вызываются из Global/EventDirector/EliteDirector):
##   enemy_bonus(id, pos)        — обычные враги: слизь, свиньи, крысы
##   elite_bonus(pos, golden)    — элитные враги
##   event_bonus(event_id, pos)  — награда за мировое событие
##   supply_bonus(pos)           — содержимое «сброса припасов»
##   boss_bonus(boss_id, pos)    — боссы (Медный Рыцарь → шлем + палаш)
##   next_hunt_relic()/drop_relic() — «Охота за реликвией»

## Реликвии, которые можно найти ТОЛЬКО в охоте за реликвиями (остальные — награды/босс)
const HUNT_RELICS: Array[String] = ["Bone Ring", "Fortune Ring", "Dark Grimoire", "Guardian Crystal"]

const ELITE_WEAPONS: Array[String] = ["Ruby Blade", "Solar Blade", "Frost Blade", "Bone Sickle", "Spider Caster", "Glacier Axe", "Axenrang"]
const RAID_WEAPONS: Array[String] = ["Templar Spear", "Spiked Mace", "War Hammer", "Golden Boomerang"]
const CURSED_WEAPONS: Array[String] = ["Abyss Blade", "Abyss Bow"]
const DRINKS: Array[String] = ["Root Tonic", "Rage Elixir", "Fire Grog", "Honey Mead", "Dark Wine", "Antidote"]


static func _drop(item_name: String, amount: int, pos: Vector2, spread: float = 12.0) -> void:
	var item: ItemData = ItemDB.get_item(item_name)
	if item == null:
		push_warning("ContentLoot: нет предмета '%s' в ItemDB" % item_name)
		return
	LootUtil.drop(item, amount, pos, spread)


static func _chance(p: float) -> bool:
	return randf() < p


# ─────────────────────────────────────────────────────────────────────────────
#  Источники
# ─────────────────────────────────────────────────────────────────────────────
static func enemy_bonus(enemy_id: String, pos: Vector2) -> void:
	match enemy_id:
		"slime":
			if _chance(0.55):
				_drop("Slime Gel", 2 if _chance(0.25) else 1, pos)
		"pig":
			if _chance(0.12):
				_drop("Empty Jar", 1, pos)
		"rat", "snail":
			if _chance(0.12):
				_drop("Empty Jar", 1, pos)
			if _chance(0.15):
				_drop("Slime Gel", 1, pos)


static func elite_bonus(pos: Vector2, golden: bool) -> void:
	if _chance(0.4):
		_drop("Slime Gel", 2, pos)
	if _chance(0.35 if golden else 0.12):
		_drop("Empty Jar", 1, pos)
	if _chance(0.20 if golden else 0.06):
		_drop(ELITE_WEAPONS.pick_random(), 1, pos)
	if golden and _chance(0.05):
		_drop(CURSED_WEAPONS.pick_random(), 1, pos)
	if golden and _chance(0.08):
		_drop("Star Shard", 1, pos)
	if _chance(0.12 if golden else 0.02):
		var relic := next_hunt_relic()
		if relic:
			drop_relic(relic, pos)


static func event_bonus(event_id: StringName, pos: Vector2) -> void:
	match event_id:
		&"slime_rush":
			_drop("Slime Gel", 3, pos)
			if _chance(0.5):
				_drop("Root Tonic", 1, pos)
		&"pig_raid":
			if _chance(0.6):
				_drop("Molotov", 2, pos)
			if _chance(0.4):
				_drop("Bomb", 3, pos)
			if _chance(0.25):
				_drop(RAID_WEAPONS.pick_random(), 1, pos)


static func supply_bonus(pos: Vector2) -> void:
	for i in randi_range(1, 2):
		_drop(DRINKS.pick_random(), 1, pos, 14.0)
	if _chance(0.5):
		_drop("Bomb", 2, pos, 14.0)
	if _chance(0.3):
		_drop("Frost Flask", 2, pos, 14.0)
	if _chance(0.05):
		_drop("Star Shard", 1, pos, 14.0)


static func boss_bonus(boss_id: String, pos: Vector2) -> void:
	if boss_id != "cooperknight":
		return
	# Гарантированные награды, но только если игрок их ещё не держит (повторные бои не дублируют)
	for n in ["Copper Knight's Helm", "Knight's Blade"]:
		var it: ItemData = ItemDB.get_item(n)
		if it and not owned(it):
			_drop(n, 1, pos, 18.0)
	_drop("Star Shard", 1, pos, 18.0)
	_drop("Antidote", 2, pos, 18.0)


# ─────────────────────────────────────────────────────────────────────────────
#  Реликвии
# ─────────────────────────────────────────────────────────────────────────────
static func owned(item: ItemData) -> bool:
	return Global.inventory != null and Global.inventory.has_total_item(item, 1)


## Реликвии охоты, которых у игрока ещё нет
static func missing_hunt_relics() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for n in HUNT_RELICS:
		var it: ItemData = ItemDB.get_item(n)
		if it and not owned(it):
			out.append(it)
	return out


static func next_hunt_relic() -> ItemData:
	var m := missing_hunt_relics()
	return m.pick_random() if not m.is_empty() else null


## Кладёт реликвию на землю и помечает группой — чтобы убрать её, если охота провалена
## (иначе следующая охота выдала бы дубликат).
static func drop_relic(item: ItemData, pos: Vector2) -> void:
	if item == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root: Node = tree.get_first_node_in_group("World")
	if root == null:
		root = tree.current_scene
	var d = LootUtil.DROP_SCENE.instantiate()
	d.update_drop(item.duplicate(), 1)
	d.global_position = pos
	d.add_to_group("RelicDrop")
	root.call_deferred("add_child", d)


static func cleanup_relic_drops() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("RelicDrop"):
		n.queue_free()
