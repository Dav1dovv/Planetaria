# weapon_stats.gd
## Характеристики оружия и ответ на вопрос «стоит ли это крафтить?».
## Чистая логика без интерфейса (можно тестировать отдельно).
##
## Сравнивает создаваемое оружие с ЛУЧШИМ из того, что у игрока уже есть (рюкзак + хотбар)
## того же типа (ближний бой с ближним, стрелковое со стрелковым).
##
## Допущения (поправь формулы, если у тебя иначе):
##   • Atk_speed – чем больше, тем чаще удары (множитель скорости атаки).
##   • Урон в секунду (DPS) = Damage × Atk_speed × число снарядов.
##   • Прочность тратится на 1 удар; у стрелкового – durability_per_shot (если задан).
##   • Урон за всю жизнь оружия = Damage × снаряды × (max_durability ÷ расход на удар).
class_name WeaponStats
extends RefCounted

const C_OK     := Color("6fd36a")
const C_BAD    := Color("ff5360")
const C_WARN   := Color("ffb55c")
const C_DIM    := Color("9aa5b8")
const C_ACCENT := Color("7fe9ee")

## Порог, после которого оружие считаем заметно лучше/хуже (иначе «примерно такое же»)
const BETTER_RATIO := 1.15
const WORSE_RATIO  := 0.90
const LONGER_LIFE_RATIO := 1.25

const ON_HIT_NAMES := {
	"slow": "Slow", "burn": "Burn", "poison": "Poison", "freeze": "Freeze",
	"bleed": "Bleed", "corruption": "Corruption", "heal_on_hit": "Heal on hit",
}


# ─────────────────────────────────────────────────────────────────────────────
#  Базовые величины
# ─────────────────────────────────────────────────────────────────────────────

## Показываем характеристики и сравнение только для настоящего оружия.
static func is_comparable(item: ItemData) -> bool:
	var e := item as equip_data
	return e != null and e.is_weapon and not e.consumable


static func projectiles(item: equip_data) -> int:
	return maxi(1, item.num_projectiles)


static func style_of(item: equip_data) -> String:
	return "ranged" if item.projectile != null else "melee"


static func dps(item: equip_data) -> float:
	return float(item.Damage) * item.Atk_speed * projectiles(item)


static func hits_before_break(item: equip_data) -> float:
	return float(item.max_durability) / float(maxi(1, item.durability_per_shot))


static func lifetime_damage(item: equip_data) -> float:
	return float(item.Damage) * projectiles(item) * hits_before_break(item)


# ─────────────────────────────────────────────────────────────────────────────
#  Что у игрока уже есть
# ─────────────────────────────────────────────────────────────────────────────

## Всё оружие игрока: рюкзак и хотбар. Не падает на пустых слотах и отсутствующем хотбаре.
static func owned_weapons(inventory: Object) -> Array[equip_data]:
	var out: Array[equip_data] = []
	if inventory == null:
		return out
	var slots: Array = []
	slots.append_array(inventory.get("items") if inventory.get("items") != null else [])
	var hotbar: Object = inventory.get("hotbar")
	if hotbar != null and hotbar.get("slots") != null:
		slots.append_array(hotbar.get("slots"))
	for slot in slots:
		var item = slot.item if slot != null else null
		if item is equip_data and is_comparable(item):
			out.append(item)
	return out


## Лучшее по урону в секунду оружие того же типа. null, если такого нет.
static func best_owned(inventory: Object, like: equip_data) -> equip_data:
	var best: equip_data = null
	for weapon in owned_weapons(inventory):
		if style_of(weapon) != style_of(like):
			continue
		if best == null or dps(weapon) > dps(best):
			best = weapon
	return best


# ─────────────────────────────────────────────────────────────────────────────
#  Строки таблицы
# ─────────────────────────────────────────────────────────────────────────────

## Строки для таблицы: {label, value, delta, delta_color}. reference может быть null.
## Ключи label – ключи переводов (DMG, Speed, …).
static func rows(item: equip_data, reference: equip_data) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_row("DMG", _dmg_text(item), item.Damage, reference.Damage if reference else null, true, 0))
	out.append(_row("Speed", "%.2f" % item.Atk_speed, item.Atk_speed, reference.Atk_speed if reference else null, true, 2))
	out.append(_row("DPS", "%.1f" % dps(item), dps(item), dps(reference) if reference else null, true, 1))
	out.append(_row("Прочность", str(item.max_durability), item.max_durability, reference.max_durability if reference else null, true, 0))
	out.append(_row("Total dmg", str(int(round(lifetime_damage(item)))), lifetime_damage(item), lifetime_damage(reference) if reference else null, true, 0))
	out.append(_row("Range", "%d" % int(round(item.hit_distance)), item.hit_distance, reference.hit_distance if reference else null, true, 0))
	# Отбрасывание: больше не значит «лучше», поэтому разницу показываем нейтральным цветом
	out.append(_row("Knockback", "%.1f" % item.knockback, item.knockback, reference.knockback if reference else null, false, 1))
	return out


static func _dmg_text(item: equip_data) -> String:
	var n := projectiles(item)
	return "%d×%d" % [item.Damage, n] if n > 1 else str(item.Damage)


## higher_is_better == false: разницу показываем серым (ни хорошо, ни плохо).
static func _row(label: String, value: String, mine: float, theirs: Variant, higher_is_better: bool, decimals: int) -> Dictionary:
	var delta := ""
	var color := C_DIM
	if theirs != null:
		var d := mine - float(theirs)
		var eps := 0.5 * pow(10.0, -decimals)
		if absf(d) < eps:
			delta = "="
		else:
			delta = ("%+." + str(decimals) + "f") % d
			if higher_is_better:
				color = C_OK if d > 0.0 else C_BAD
	return {"label": label, "value": value, "delta": delta, "delta_color": color}


## Эффекты оружия одной строкой: «Поджог 30% · Рывок · Свет».
static func effects_text(item: equip_data) -> String:
	var parts: PackedStringArray = []
	if item.on_hit_effect != "none":
		parts.append("%s %d%%" % [Loc.t(ON_HIT_NAMES.get(item.on_hit_effect, item.on_hit_effect)), int(item.on_hit_chance * 100.0)])
	if item.lunge_enabled:
		parts.append(Loc.t("Lunge"))
	if item.passive_emits_light:
		parts.append(Loc.t("Emits light"))
	match item.passive_player_effect:
		"poison":
			parts.append(Loc.t("Holder takes poison"))
		"defense_boost":
			parts.append("%s +%d%%" % [Loc.t("Defense"), int(item.passive_player_potency * 100.0)])
	return " · ".join(parts)


# ─────────────────────────────────────────────────────────────────────────────
#  Вердикт
# ─────────────────────────────────────────────────────────────────────────────

## {text, color, versus}: ответ «стоит ли крафтить» и с чем сравнивали.
static func verdict(item: equip_data, reference: equip_data) -> Dictionary:
	if reference == null:
		return {"text": Loc.t("No weapon of this type yet"), "color": C_ACCENT, "versus": ""}

	var versus := Loc.t("vs %s") % Loc.t(reference.item_name)
	if reference.item_name == item.item_name:
		return {"text": Loc.t("You already own this weapon"), "color": C_DIM, "versus": ""}

	var ratio := dps(item) / maxf(dps(reference), 0.001)
	var life_ratio := lifetime_damage(item) / maxf(lifetime_damage(reference), 0.001)
	var has_effect := effects_text(item) != "" and effects_text(reference) == ""
	var percent := int(round(absf(ratio - 1.0) * 100.0))

	if ratio >= BETTER_RATIO:
		return {"text": Loc.t("Upgrade: +%d%% damage/sec") % percent, "color": C_OK, "versus": versus}
	if ratio >= WORSE_RATIO:
		if life_ratio >= LONGER_LIFE_RATIO:
			return {"text": Loc.t("Same damage, lasts +%d%% longer") % int(round((life_ratio - 1.0) * 100.0)), "color": C_OK, "versus": versus}
		if has_effect:
			return {"text": Loc.t("Same damage, plus an effect"), "color": C_ACCENT, "versus": versus}
		return {"text": Loc.t("Not an upgrade"), "color": C_DIM, "versus": versus}
	if has_effect:
		return {"text": Loc.t("Weaker, but has an effect (%d%%)") % percent, "color": C_WARN, "versus": versus}
	return {"text": Loc.t("Weaker: %d%% damage/sec") % percent, "color": C_BAD, "versus": versus}
