## WeaponForge.gd
## Чистая ЛОГИКА комбинатора оружия, без интерфейса (можно проверять отдельно).
##
## Правила (GDD v0.8, «крафт оружия по свойствам»):
##   • Слотов комбинации максимум 4: слот 0 — основа (оружие), слоты 1–3 — добавки.
##   • Любое оружие комбинируется только с ОДНИМ другим оружием (его «функция»), остальное —
##     ресурсы и реликвии со свойствами (ItemData.craft_properties).
##   • Спрайт не меняется; меняются эффект, характеристики, отклик.
##   • У каждого свойства есть свой минус (множители в CraftProperty).
##   • Чем сильнее оружие, тем ниже его прочность: стабильные 100, мощное ломается быстрее.
##   • Починить комбинированное оружие можно любым ресурсом (режим «Ремонт»).
##   • Платим монетами; ресурсы, реликвии и оружие-добавка сгорают.
class_name WeaponForge
extends RefCounted

const CONFIG_PATH := "res://game/Systems/Craft/Combiner/ForgeConfig.gd"

enum Mode { COMBINE, REPAIR }
enum Role { NONE, WEAPON, COMBINED, MATERIAL }

const C_OK := Color("6fe08a")
const C_BAD := Color("e8454f")
const C_WARN := Color("ffc857")
const C_DIM := Color("9aa5b8")

static var _cfg: ForgeConfig


static func config() -> ForgeConfig:
	if _cfg == null:
		if ResourceLoader.exists(CONFIG_PATH):
			_cfg = load(CONFIG_PATH) as ForgeConfig
		if _cfg == null:
			_cfg = ForgeConfig.new()  # значения по умолчанию, если файл не найден
	return _cfg


# ─────────────────────────────────────────────────────────────────────────────
#  Классификация и допуск в слоты
# ─────────────────────────────────────────────────────────────────────────────

static func role_of(item: ItemData) -> Role:
	if item == null:
		return Role.NONE
	if item is CombinedWeapon:
		return Role.COMBINED
	var eq := item as equip_data
	if eq != null and eq.is_weapon and not eq.consumable:
		return Role.WEAPON
	if not item.craft_properties.is_empty():
		return Role.MATERIAL
	return Role.NONE


## "" — предмет можно положить в слот; иначе ключ перевода с причиной отказа.
## others — предметы в ДРУГИХ слотах (без того, куда кладём).
static func why_not(mode: Mode, slot_index: int, item: ItemData, others: Array) -> String:
	var role := role_of(item)
	if mode == Mode.REPAIR:
		if slot_index == 0:
			return "" if (role == Role.WEAPON or role == Role.COMBINED) else "Put a weapon to repair"
		if slot_index == 1:
			if item == null or item is equip_data or item.is_counter_item:
				return "Any resource works for repair"
			return ""
		return "Not used when repairing"

	if role == Role.NONE:
		return "This item has no properties"
	if role == Role.COMBINED:
		return "Already combined"
	if slot_index == 0:
		return "" if role == Role.WEAPON else "Base must be a weapon"
	if role == Role.WEAPON:
		var donors := 0
		for other in others:
			if role_of(other) == Role.WEAPON:
				donors += 1
		# Слот 0 тоже оружие, но он «основа», а не добавка — считаем только слоты 1+
		if donors >= config().max_donor_weapons:
			return "Only one extra weapon"
	return ""


# ─────────────────────────────────────────────────────────────────────────────
#  Сборка
# ─────────────────────────────────────────────────────────────────────────────

## Разбор слотов комбинации. items[0] — основа, остальное — добавки (могут быть null).
## Возвращает {problem, base, donor, mats}. problem == "" — собрать можно.
static func inspect(items: Array) -> Dictionary:
	var info := {"problem": "", "base": null, "donor": null, "mats": [] as Array[ItemData]}
	var base := items[0] as equip_data if not items.is_empty() else null
	if base == null:
		info["problem"] = "Put a base weapon"
		return info
	info["base"] = base
	for i in range(1, items.size()):
		var item := items[i] as ItemData
		match role_of(item):
			Role.WEAPON:
				if info["donor"] == null:
					info["donor"] = item
			Role.MATERIAL:
				(info["mats"] as Array[ItemData]).append(item)
	if info["donor"] == null and (info["mats"] as Array).is_empty():
		info["problem"] = "Add a weapon or a material"
	return info


## Строит результат. Возвращает
## {weapon: CombinedWeapon, notes: [{text,color}], fee: int, power: float}
static func build(base: equip_data, donor: equip_data, mats: Array[ItemData]) -> Dictionary:
	var cfg := config()
	var notes: Array[Dictionary] = []
	var r := CombinedWeapon.new()
	_copy_into(r, base)
	r.base_name = base.item_name
	r.donor_name = donor.item_name if donor else ""
	for m in mats:
		r.material_names.append(m.item_name)

	# ── Второе оружие: переносим только его «функцию» ──
	if donor != null:
		_apply_donor(r, base, donor, cfg, notes)

	# ── Свойства ресурсов и реликвий ──
	var dmg := 1.0
	var spd := 1.0
	var rng := 1.0
	var dur := 1.0
	var kb := 0.0
	var props: Array[CraftProperty] = []
	for m in mats:
		for p in m.craft_properties:
			if p != null:
				props.append(p)
	for p in props:
		dmg *= p.damage_mult
		spd *= p.speed_mult
		rng *= p.range_mult
		dur *= p.durability_mult
		kb += p.knockback_add
	dmg = clampf(dmg, cfg.min_total_mult, cfg.max_damage_mult)
	spd = clampf(spd, cfg.min_total_mult, cfg.max_speed_mult)
	rng = clampf(rng, cfg.min_total_mult, 2.0)
	dur = clampf(dur, cfg.min_total_mult, 3.0)

	r.Damage = maxi(1, roundi(r.Damage * dmg))
	r.Atk_speed = clampf(r.Atk_speed * spd, 0.85, 3.0)
	r.hit_distance = clampf(r.hit_distance * rng, 10.0, 100.0)
	r.knockback = maxf(0.0, r.knockback + kb)

	for p in props:
		_apply_effects(r, p, notes)

	# ── Сила и прочность: мощное оружие хрупче ──
	var power := WeaponStats.dps(r) / maxf(WeaponStats.dps(base), 0.001)
	var overpower := clampf((power - 1.0) * cfg.overpower_durability_k, 0.0, 0.8)
	var max_dur := roundi(cfg.base_durability * dur * (1.0 - overpower))
	r.max_durability = clampi(max_dur, cfg.min_durability, cfg.durability_cap)
	r.durability = r.max_durability
	if overpower > 0.05:
		notes.append({"text": Loc.t("Powerful weapons wear out faster"), "color": C_WARN})

	# ── Оформление ──
	r.stackable = false
	r.max_count = 1
	r.count = 1
	r.quality = base.quality
	r.item_name = _make_name(base, donor, mats)
	r.description = _make_description(base, donor, mats)
	var price := float(base.price)
	for m in mats:
		price += m.price * 0.5
	if donor:
		price += donor.price * 0.4
	r.price = roundi(price)

	# ── Плата ──
	var fee := cfg.fee_base
	for m in mats:
		fee += roundi(m.price * cfg.fee_price_k)
	if donor:
		fee += roundi(donor.price * cfg.fee_donor_k)
	fee += roundi(maxf(power - 1.0, 0.0) * cfg.fee_power)

	return {"weapon": r, "notes": notes, "fee": fee, "power": power}


## Строит готовое оружие из сохранённого «рецепта» (см. CombinedWeapon.pack()).
## null — если основа больше не существует.
static func rebuild(packed: Dictionary) -> CombinedWeapon:
	var base_key := str(packed.get("base", ""))
	var base := ItemDB.get_item(base_key) as equip_data
	if base == null:
		push_warning("[WeaponForge] rebuild: основа '%s' не найдена в ItemDB" % base_key)
		return null
	var donor: equip_data = null
	var donor_key := str(packed.get("donor", ""))
	if donor_key != "":
		donor = ItemDB.get_item(donor_key) as equip_data
		if donor == null:
			push_warning("[WeaponForge] rebuild: второе оружие '%s' не найдено в ItemDB — пропущено" % donor_key)
	var mats: Array[ItemData] = []
	for n in packed.get("mats", []):
		var item: ItemData = ItemDB.get_item(str(n))
		if item != null:
			mats.append(item)
		else:
			push_warning("[WeaponForge] rebuild: материал '%s' не найден в ItemDB — пропущен" % str(n))
	var weapon := build(base, donor, mats)["weapon"] as CombinedWeapon
	var saved := int(packed.get("durability", weapon.max_durability))
	weapon.durability = clampi(saved, 0, weapon.max_durability)
	return weapon


# ─────────────────────────────────────────────────────────────────────────────
#  Ремонт
# ─────────────────────────────────────────────────────────────────────────────

## {missing, per_unit, units, restore}: сколько штук ресурса уйдёт и сколько прочности вернётся.
static func repair_plan(weapon: equip_data, resource: ItemData, available: int) -> Dictionary:
	var cfg := config()
	var plan := {"missing": 0, "per_unit": 0, "units": 0, "restore": 0}
	if weapon == null or resource == null:
		return plan
	var missing := weapon.max_durability - weapon.get_durability()
	var per_unit := maxi(cfg.repair_min_per_unit, roundi(resource.price * cfg.repair_per_price))
	var units := mini(available, ceili(float(missing) / float(per_unit))) if missing > 0 else 0
	plan["missing"] = missing
	plan["per_unit"] = per_unit
	plan["units"] = units
	plan["restore"] = mini(missing, units * per_unit)
	return plan


# ─────────────────────────────────────────────────────────────────────────────
#  Внутреннее
# ─────────────────────────────────────────────────────────────────────────────

## Копирует все переменные скрипта (и ItemData, и equip_data), включая прочность.
static func _copy_into(dst: Resource, src: Resource) -> void:
	for prop in src.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var prop_name := str(prop["name"])
		if prop_name in ["base_name", "donor_name", "material_names"]:
			continue
		dst.set(prop_name, src.get(prop_name))


static func _apply_donor(r: CombinedWeapon, base: equip_data, donor: equip_data, cfg: ForgeConfig, notes: Array[Dictionary]) -> void:
	var donor_shoots := donor.projectile != null
	if donor_shoots and base.projectile == null:
		# Ближний бой + стрелковое = гибрид. Анимация, темп и урон удара остаются от основы (Attack),
		# а от донора берём ТОЛЬКО логику стрельбы: какой снаряд и сколько снарядов летит на каждом замахе.
		r.projectile = donor.projectile
		r.num_projectiles = maxi(1, donor.num_projectiles)
		r.spread_degrees = donor.spread_degrees
		r.projectile_speed = donor.projectile_speed
		r.accuracy_radius = donor.accuracy_radius
		r.durability_per_shot = maxi(1, donor.durability_per_shot)
		r.projectile_damage_mult = cfg.shoot_damage_mult
		notes.append({"text": Loc.t("Strikes fire projectiles"), "color": C_OK})
		notes.append({"text": "%s: %d  (%s)" % [Loc.t("Projectiles"), r.num_projectiles, Loc.t(donor.item_name)], "color": C_OK})
		notes.append({"text": "%s %d%%" % [Loc.t("Shot damage"), roundi(cfg.shoot_damage_mult * 100.0)], "color": C_WARN})
	elif donor_shoots and base.projectile != null:
		r.num_projectiles = mini(base.num_projectiles + 1, 5)
		r.spread_degrees = base.spread_degrees + 4.0
		notes.append({"text": Loc.t("+1 projectile"), "color": C_OK})
	else:
		# Ближнее добавочное оружие даёт только свою особенность, если у основы такой нет
		var gave := false
		if base.on_hit_effect == "none" and donor.on_hit_effect != "none":
			r.on_hit_effect = donor.on_hit_effect
			r.on_hit_chance = donor.on_hit_chance
			r.on_hit_duration = donor.on_hit_duration
			r.on_hit_potency = donor.on_hit_potency
			r.on_hit_bleed_percent = donor.on_hit_bleed_percent
			r.on_hit_corruption_bonus = donor.on_hit_corruption_bonus
			gave = true
		if donor.lunge_enabled and not base.lunge_enabled:
			r.lunge_enabled = true
			r.lunge_speed = donor.lunge_speed
			r.lunge_duration = donor.lunge_duration
			r.lunge_damage_multiplier = donor.lunge_damage_multiplier
			r.lunge_invincible = donor.lunge_invincible
			r.lunge_trail_scene = donor.lunge_trail_scene
			gave = true
		if donor.passive_emits_light and not base.passive_emits_light:
			r.passive_emits_light = true
			r.passive_light_color = donor.passive_light_color
			r.passive_light_radius = donor.passive_light_radius
			r.passive_light_energy = donor.passive_light_energy
			gave = true
		if gave:
			notes.append({"text": Loc.t("Takes the special of the extra weapon"), "color": C_OK})
		else:
			notes.append({"text": Loc.t("Extra weapon adds nothing here"), "color": C_WARN})


static func _apply_effects(r: CombinedWeapon, p: CraftProperty, notes: Array[Dictionary]) -> void:
	if p.on_hit_effect != "none":
		if r.on_hit_effect == "none":
			r.on_hit_effect = p.on_hit_effect
			r.on_hit_chance = p.on_hit_chance
			r.on_hit_duration = p.on_hit_duration
			r.on_hit_potency = p.on_hit_potency
		elif r.on_hit_effect == p.on_hit_effect:
			r.on_hit_chance = minf(1.0, r.on_hit_chance + p.on_hit_chance * 0.5)
			r.on_hit_potency += p.on_hit_potency * 0.5
			notes.append({"text": Loc.t("Same effect stacks"), "color": C_OK})
		else:
			notes.append({"text": Loc.t("Effects conflict: only the first works"), "color": C_WARN})
	if p.grants_light and not r.passive_emits_light:
		r.passive_emits_light = true
		r.passive_light_color = p.light_color
	if p.grants_lunge and not r.lunge_enabled:
		r.lunge_enabled = true
		r.lunge_speed = 60.0
	if p.passive_player_effect != "none" and r.passive_player_effect == "none":
		r.passive_player_effect = p.passive_player_effect
		r.passive_player_potency = p.passive_player_potency


static func _make_name(base: equip_data, donor: equip_data, mats: Array[ItemData]) -> String:
	var parts: Array[String] = []
	for m in mats:
		if not m.craft_properties.is_empty() and m.craft_properties[0] != null:
			parts.append(Loc.t(m.craft_properties[0].title))
	if donor:
		parts.append(Loc.t(donor.item_name))
	var name := Loc.t(base.item_name)
	if parts.is_empty():
		return name + " +"
	name += " +" + parts[0]
	if parts.size() > 1:
		name += "+%d" % (parts.size() - 1)
	return name


static func _make_description(base: equip_data, donor: equip_data, mats: Array[ItemData]) -> String:
	var lines: PackedStringArray = [Loc.t("Combined weapon"), "• " + Loc.t(base.item_name)]
	if donor:
		lines.append("+ " + Loc.t(donor.item_name))
	for m in mats:
		lines.append("+ " + Loc.t(m.item_name))
	return "\n".join(lines)
