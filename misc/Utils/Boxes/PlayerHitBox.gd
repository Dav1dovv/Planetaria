extends HitBox
class_name player_HitBox

signal critical_hit(target: Node)

@export var equip_sprite: Sprite2D
@export var hand : equip_data

var is_weapon := false
var play_anim: String = "Attack"

@onready var hotbar: Hotbar = get_tree().get_first_node_in_group("Hotbar")

func _ready() -> void:
	connect("area_entered", hit)
	if hotbar:
		hotbar.hotbar_changed.connect(_on_hotbar_changed)
		_update_from_hotbar()
	else:
		push_error("Hotbar not found! Add Hotbar node to group 'Hotbar'")

func _on_hotbar_changed() -> void:
	_update_from_hotbar()

func _update_from_hotbar() -> void:
	if not hotbar or hotbar.selected_index >= hotbar.slots.size():
		update_equip(null)
		return
	var slot_data = hotbar.slots[hotbar.selected_index]
	update_equip(slot_data.item)

func update_equip(new_equip : ItemData) -> void:
	if not equip_sprite:
		push_error("PlayerHitBox: equip_sprite is not assigned!")
		return

	if equip is equip_data and equip.weapon_broken.is_connected(_on_weapon_broken):
		equip.weapon_broken.disconnect(_on_weapon_broken)

	equip_sprite.modulate = Color.WHITE
	equip = new_equip

	if equip is equip_data:
		play_anim = "Attack"
		equip_sprite.offset   = Vector2(5.1, -3.66)
		equip_sprite.scale    = Vector2(1, 1)
		equip_sprite.rotation = 45
		equip_sprite.texture  = equip.equiped_weapon_sprite
		$CollisionShape2D.shape.radius  = equip.hit_distance
		$CollisionShape2D.position.x    = 6 + equip.hit_distance
		is_weapon = true
		equip.weapon_broken.connect(_on_weapon_broken)
		if equip.is_broken():
			equip_sprite.modulate = Color(0.4, 0.4, 0.4)

	elif equip is FoodData:
		play_anim = "Eating"
		equip_sprite.offset   = Vector2.ZERO
		equip_sprite.scale    = Vector2(0.5, 0.5)
		equip_sprite.rotation = 45
		equip_sprite.texture  = equip.icon
		is_weapon = false

	elif equip is ItemData:
		play_anim = "Attack"
		equip_sprite.offset   = Vector2.ZERO
		equip_sprite.scale    = Vector2(0.5, 0.5)
		equip_sprite.rotation = 45
		equip_sprite.texture  = equip.icon
		is_weapon = false

	else:
		equip = hand
		play_anim = "Attack"
		equip_sprite.texture = null
		is_weapon = false


func _on_weapon_broken() -> void:
	print("Оружие сломано!")
	var tween = create_tween()
	tween.tween_property(equip_sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(1, 1, 1), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(0.4, 0.4, 0.4), 0.2)


func hit(area: Area2D) -> void:
	if not is_weapon:
		return

	if equip is equip_data and equip.is_broken():
		#DebugLog.log("Оружие сломано — удар не наносится!")
		return

	apply_damage(area, equip.Damage)

	if equip is equip_data:
		_refresh_hotbar_slot_ui()


func apply_damage(area: Area2D, damage: float) -> void:
	# ── Заражение: -50% урона от атак игрока при 50-79% (GDD 3.3) ────────────
	# Штраф уже накладывается компонентом PlayerInfection на Entity_stats.damage_modifier
	# (через EffectManager, тем же путём, что и оружейные баффы урона) — здесь
	# он просто применяется к фактическому исходящему урону.
	damage *= _get_outgoing_damage_multiplier()
	# ─────────────────────────────────────────────────────────────────────────

	# ── Harvestable ──────────────────────────────────────────────────────────
	if area.is_in_group("Harvestable"):
		#area.Harvest(damage, equip.lvl, equip.is_weapon)
		#DebugLog.log("area is harvestable: " + area.get_parent().name)
		if equip is equip_data:
			area.Harvest(damage, equip.lvl, equip.is_weapon)
			#DebugLog.log("area is harvestable: " + area.get_parent().name)
			if equip.lvl >= area.harvest_tool_lvl:
				equip.reduce_durability(1)
			elif  equip.lvl < area.harvest_tool_lvl:
				print("resource is harder: " + str(area.harvest_tool_lvl))
				# Кирка ниже нужного тира — ломается в 4× быстрее
				equip.reduce_durability(1 * area.harvest_tool_lvl)
		return
	# ────────────────────────────────────────────────────────────────────────

	# ── Enemy ────────────────────────────────────────────────────────────────
	if area.is_in_group("Ennemy"):
		var target := area.get_parent()
		var is_crit := false
		var final_damage := damage
		var poise_dmg := 0.0

		if equip is equip_data:
			var e := equip as equip_data
			is_crit = randf() < e.critical_chance
			if is_crit:
				final_damage *= e.critical_multiplier
			poise_dmg = e.poise_damage

		target.take_damage(final_damage, self, is_crit, poise_dmg)

		if is_crit:
			#DebugLog.log("КРИТ! " + str(final_damage) + " урона по " + target.name)
			emit_signal("critical_hit", target)

		if equip is equip_data:
			equip.reduce_durability(1)
		return
	# ────────────────────────────────────────────────────────────────────────


## Множитель к исходящему урону игрока — читает Entity_stats.damage_modifier
## (куда PlayerInfection пишет -0.5 при заражении 50-79%). Минимум 0.1x —
## чтобы урон не мог уйти в ноль/отрицательное значение при стакании дебаффов.
func _get_outgoing_damage_multiplier() -> float:
	if owner and "Entity_stats" in owner and owner.Entity_stats:
		return maxf(1.0 + owner.Entity_stats.damage_modifier, 0.1)
	return 1.0


func _refresh_hotbar_slot_ui() -> void:
	if not hotbar: return
	var slot_data = hotbar.slots[hotbar.selected_index]
	if slot_data.slot_node:
		slot_data.slot_node.update_ui()


func consume_food(food: FoodData) -> void:
	if not hotbar: return

	var slot_data := hotbar.slots[hotbar.selected_index]
	if not (slot_data.item is FoodData) or slot_data.amount <= 0:
		return

	slot_data.amount -= 1
	slot_data.slot_node.ammount = slot_data.amount
	slot_data.slot_node.update_ui()

	if slot_data.amount <= 0:
		slot_data.item = null
		slot_data.slot_node.item = null
		slot_data.slot_node.update_ui()
		update_equip(null)

	_apply_food_effects(food)
	hotbar.emit_signal("hotbar_changed")


func _apply_food_effects(food: FoodData) -> void:
	if food.eat_sound:
		var audio := AudioStreamPlayer.new()
		get_parent().add_child(audio)
		audio.stream = food.eat_sound
		audio.play()
		audio.finished.connect(audio.queue_free)

	var p := owner
	if not p:
		return

	for effect in food.effects:
		if p.has_method("apply_effect_instance"):
			p.apply_effect_instance(effect)
		if effect.effect_type == 0:
			if p.has_method("heal"):
				p.heal(effect.value)
				p.heal(food.health_restore)

	if p.has_method("heal"):
		p.heal(food.health_restore)
	if p.has_method("remove_curse"):
		p.remove_curse(food.remove_corription)
	if p.has_method("cure_infection"):
		p.cure_infection(food.cure_infection)


func eat_food() -> void:
	if not equip:
		return
	if equip is FoodData:
		consume_food(equip as FoodData)


func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if (anim_name == "Eating" or anim_name == "Drink") and equip is FoodData:
		consume_food(equip as FoodData)
