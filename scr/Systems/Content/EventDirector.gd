extends Node
class_name EventDirector

## Ритм игры: раз в 80–120 секунд в мире случается событие — нашествие слизи,
## налёт свиней или падение припасов. Есть цель, таймер, награда. Между
## событиями игрок спокойно исследует, строит и крафтит.

const FIRST_EVENT_DELAY := 80
const EVENT_INTERVAL_MIN := 120
const EVENT_INTERVAL_MAX := 180

const SLIME_SCENES: Array[PackedScene] = [
	preload("res://misc/Entity/Enemies/slime.tscn"),
	preload("res://misc/Entity/Enemies/slime2.tscn"),
]
const PIG_SCENES: Array[PackedScene] = [
	preload("res://misc/Entity/Enemies/Pig1.tscn"),
	preload("res://misc/Entity/Enemies/Pig2.tscn"),
	preload("res://misc/Entity/Enemies/Pig3.tscn"),
]

## weight — относительная частота; time — секунды на выполнение
const EVENTS := {
	&"slime_rush": {
		"title": "SLIME RUSH!", "kind": "wave", "scenes": SLIME_SCENES,
		"count": 6, "time": 60.0, "weight": 3, "color": Color(0.5, 1.0, 0.6),
		"coins": 70, "potions": 1, "pieces": 0,
	},
	&"pig_raid": {
		"title": "PIG RAID!", "kind": "wave", "scenes": PIG_SCENES,
		"count": 4, "time": 75.0, "weight": 2, "color": Color(1.0, 0.6, 0.55),
		"coins": 60, "potions": 0, "pieces": 2,
	},
	&"supply_drop": {
		"title": "SUPPLY DROP!", "kind": "drop", "scenes": [],
		"count": 0, "time": 75.0, "weight": 2, "color": Color(0.55, 0.85, 1.0),
		"coins": 0, "potions": 0, "pieces": 0,
	},
	# Охота за реликвией: стрелка ведёт к реликвии, которую ещё не нашёл (см. ContentLoot)
	&"relic_hunt": {
		"title": "RELIC HUNT!", "kind": "drop", "scenes": [],
		"count": 0, "time": 150.0, "weight": 2, "color": Color(1.0, 0.85, 0.3),
		"coins": 60, "potions": 0, "pieces": 0, "relic": true,
	},
}

var _cooldown: float = FIRST_EVENT_DELAY
var _last_id: StringName = &""
var _event: Dictionary = {}

var _hud_layer: CanvasLayer
var _hud_label: Label


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null or Global.get_planet(Global.current_location) == null:
		if not _event.is_empty():
			_end_event(false, true)  # игрок ушёл с планеты
		return
	if get_tree().paused:
		return

	if _event.is_empty():
		if not get_tree().get_nodes_in_group("Boss").is_empty() or Global.is_opened_menu:
			return  # во время боя с боссом и в меню события не запускаем
		_cooldown -= delta
		if _cooldown <= 0.0:
			_start_event(_pick_event(), player)
	else:
		_tick_event(delta, player)


func reset() -> void:
	if not _event.is_empty():
		_end_event(false, true)
	_cooldown = FIRST_EVENT_DELAY
	_last_id = &""


func _pick_event() -> StringName:
	var pool: Array[StringName] = []
	for id: StringName in EVENTS:
		if id == _last_id:
			continue  # два одинаковых подряд не бывает
		if EVENTS[id].get("relic", false) and ContentLoot.missing_hunt_relics().is_empty():
			continue  # все реликвии охоты уже найдены
		for i in int(EVENTS[id]["weight"]):
			pool.append(id)
	return pool.pick_random()


# ─────────────────────────────────────────────────────────────────────────────
#  Запуск
# ─────────────────────────────────────────────────────────────────────────────
func _start_event(id: StringName, player: Node2D) -> void:
	var def: Dictionary = EVENTS[id]
	_last_id = id
	_event = {
		"id": id, "def": def, "time_left": def["time"],
		"killed": 0, "spawned": 0, "anchor": null, "marker": -1,
	}

	var subtitle := Loc.t("Defeat them all before time runs out") if def["kind"] == "wave" \
			else (Loc.t("Find the relic — follow the arrow") if def.get("relic", false) else Loc.t("Find the supplies — follow the arrow"))
	GameJuice.banner(Loc.t(def["title"]), subtitle, def["color"], 2.0)
	GameJuice.shake(2.0, 0.35)

	if def["kind"] == "wave":
		_spawn_wave(def, player)
	else:
		_spawn_supplies(def, player)
	_show_hud(true)


func _spawn_wave(def: Dictionary, player: Node2D) -> void:
	# Враги выходят по одному — волна нарастает, а не падает кучей
	for i in int(def["count"]):
		if _event.is_empty():
			return  # событие уже закончилось
		_spawn_enemy(def, player)
		await get_tree().create_timer(0.5).timeout


func _spawn_enemy(def: Dictionary, player: Node2D) -> void:
	var scenes: Array = def["scenes"]
	var scene: PackedScene = scenes.pick_random()
	var enemy := scene.instantiate() as Node2D
	enemy.global_position = _spawn_position(player)
	enemy.add_to_group("Creature")  # как у CreatureSpawner
	get_tree().current_scene.add_child(enemy)
	_event["spawned"] += 1
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died, CONNECT_ONE_SHOT)


func _spawn_supplies(_def: Dictionary, player: Node2D) -> void:
	var pos := _spawn_position(player)
	var anchor := Node2D.new()
	anchor.global_position = pos
	get_tree().current_scene.add_child(anchor)
	_event["anchor"] = anchor

	var is_relic: bool = _def.get("relic", false)
	if is_relic:
		ContentLoot.drop_relic(ContentLoot.next_hunt_relic(), pos)
	else:
		LootUtil.drop(LootUtil.COIN, randi_range(30, 60), pos, 14.0)
		LootUtil.drop(LootUtil.POTION, 2, pos, 14.0)
		LootUtil.drop(LootUtil.WOOD, 6, pos, 14.0)
		LootUtil.drop(LootUtil.STONE, 6, pos, 14.0)
		ContentLoot.supply_bonus(pos)

	var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
	if marker:
		_event["marker"] = marker.track(anchor, Loc.t("Relic") if is_relic else Loc.t("Supplies"), _def["color"])


## Берём точку у спавнера существ (он умеет отбирать проходимые тайлы).
func _spawn_position(player: Node2D) -> Vector2:
	var spawner := get_tree().get_first_node_in_group("Spawner")
	if spawner != null and spawner.has_method("_random_spawn_pos"):
		return spawner.call("_random_spawn_pos")
	return player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(180.0, 300.0)


# ─────────────────────────────────────────────────────────────────────────────
#  Ход события
# ─────────────────────────────────────────────────────────────────────────────
func _on_enemy_died() -> void:
	if not _event.is_empty():
		_event["killed"] += 1


func _tick_event(delta: float, player: Node2D) -> void:
	_event["time_left"] -= delta
	var def: Dictionary = _event["def"]

	var done := false
	if def["kind"] == "wave":
		done = _event["killed"] >= int(def["count"])
	else:
		var anchor := _event["anchor"] as Node2D
		done = is_instance_valid(anchor) and player.global_position.distance_to(anchor.global_position) < 40.0

	_update_hud()
	if done:
		_end_event(true)
	elif _event["time_left"] <= 0.0:
		_end_event(false)


func _end_event(success: bool, silent: bool = false) -> void:
	var def: Dictionary = _event["def"]
	var id: StringName = _event["id"]

	var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
	if marker and _event["marker"] != -1:
		marker.untrack(_event["marker"])
	var anchor := _event["anchor"] as Node2D
	var anchor_pos := anchor.global_position if is_instance_valid(anchor) else Vector2.ZERO
	if is_instance_valid(anchor):
		anchor.queue_free()
	_event = {}
	_cooldown = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)
	_show_hud(false)
	if def.get("relic", false) and not success:
		ContentLoot.cleanup_relic_drops()  # не оставляем дубликат на карте
	if silent:
		return

	if success:
		_reward(def, anchor_pos)
		Global.world_event_completed.emit(id)
		Global.report_planet_event(Global.current_location, QuestData.Kind.HELP_LOCALS, "world_event")
		if def["kind"] == "wave":
			# Задания «Отбить налёт»: target_id = ID события (pig_raid, slime_rush), пусто = любой
			Global.report_planet_event(Global.current_location, QuestData.Kind.REPEL_RAID, String(id))
			GameJuice.banner(Loc.t("EVENT COMPLETE!"), Loc.t("Event reward!"), Color(0.55, 1.0, 0.6), 1.6)
		else:
			GameJuice.toast(Loc.t("Relic found!") if def.get("relic", false) else Loc.t("Supplies secured!"), Color(0.55, 1.0, 0.6))
	else:
		GameJuice.toast(Loc.t("The event is over"), Color(0.85, 0.85, 0.85))


func _reward(def: Dictionary, _anchor_pos: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	var pos := player.global_position
	LootUtil.drop(LootUtil.COIN, int(def["coins"]), pos)
	LootUtil.drop(LootUtil.POTION, int(def["potions"]), pos)
	LootUtil.drop(LootUtil.ARTEFACT_PIECE, int(def["pieces"]), pos)
	ContentLoot.event_bonus(_last_id, pos)
	GameJuice.shake(2.0, 0.3)


# ─────────────────────────────────────────────────────────────────────────────
#  Плашка с прогрессом события
# ─────────────────────────────────────────────────────────────────────────────
func _show_hud(visible_state: bool) -> void:
	if _hud_layer == null:
		_hud_layer = CanvasLayer.new()
		_hud_layer.layer = 85
		add_child(_hud_layer)
		_hud_label = Label.new()
		_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_hud_label.add_theme_constant_override("outline_size", 6)
		_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(_hud_label)
		_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_label.visible = visible_state
	if visible_state:
		var h := get_viewport().get_visible_rect().size.y
		_hud_label.add_theme_font_size_override("font_size", int(h * 0.04))
		_hud_label.offset_top = h * 0.12
		_update_hud()


func _update_hud() -> void:
	if _event.is_empty() or _hud_label == null:
		return
	var def: Dictionary = _event["def"]
	var title: String = Loc.t(def["title"]).trim_suffix("!")
	var seconds := maxi(0, ceili(_event["time_left"]))
	if def["kind"] == "wave":
		_hud_label.text = Loc.t("%s  %d/%d  -  %d s") % [title, _event["killed"], int(def["count"]), seconds]
	else:
		_hud_label.text = Loc.t("%s  -  %d s") % [title, seconds]
	_hud_label.add_theme_color_override("font_color", def["color"])
