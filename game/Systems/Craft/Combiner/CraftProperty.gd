## CraftProperty.gd
## Свойство ресурса/артефакта для КОМБИНАТОРА оружия (идея «как готовка в Zelda»).
## У каждого ресурса или реликвии 1–2 свойства (ItemData.craft_properties).
## Сочетание свойств определяет эффект получившегося оружия.
##
## У каждого свойства есть ПЛЮС и свой МИНУС: оба задаются числами ниже (множители),
## а строки «+20% урона / −15% прочности» интерфейс строит сам.
## Новое свойство = новый .tres в misc/Content/Properties/ (правится в Inspector, без кода).
@icon("res://common/icons/helpcon4.png")
extends Resource
class_name CraftProperty

## Короткое имя (ключ перевода): «Fire», «Ice», «Swift»…
@export var title: String = ""
@export_multiline var description: String = ""
## Цвет «чипа» свойства в интерфейсе
@export var color: Color = Color("45e6e6")

@export_group("Stat modifiers (1.0 = без изменений)")
@export_range(0.2, 3.0, 0.01) var damage_mult: float = 1.0
@export_range(0.2, 3.0, 0.01) var speed_mult: float = 1.0
@export_range(0.2, 3.0, 0.01) var range_mult: float = 1.0
## Минус свойства обычно живёт здесь: хрупкость
@export_range(0.2, 3.0, 0.01) var durability_mult: float = 1.0
@export_range(-20.0, 20.0, 0.5) var knockback_add: float = 0.0

@export_group("On-hit effect (как у equip_data)")
@export_enum("none", "burn", "poison", "freeze", "bleed", "corruption", "slow", "heal_on_hit") \
	var on_hit_effect: String = "none"
@export_range(0.0, 1.0, 0.01) var on_hit_chance: float = 0.3
@export_range(0.5, 15.0, 0.5) var on_hit_duration: float = 3.0
@export_range(0.1, 50.0, 0.1) var on_hit_potency: float = 5.0

@export_group("Passive (пока оружие в руке)")
@export var grants_light: bool = false
@export var light_color: Color = Color(1.0, 0.95, 0.6, 1.0)
@export var grants_lunge: bool = false
@export_enum("none", "regen", "speed_boost", "defense_boost", "poison", "burn") \
	var passive_player_effect: String = "none"
@export_range(0.0, 50.0, 0.1) var passive_player_potency: float = 0.0


## Строки «что делает свойство» для интерфейса: [{text, good}]. good=false — это минус.
func describe_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add_percent(out, "Damage", damage_mult)
	_add_percent(out, "Speed", speed_mult)
	_add_percent(out, "Range", range_mult)
	_add_percent(out, "Durability", durability_mult)
	if not is_zero_approx(knockback_add):
		out.append({"text": "%s %+.1f" % [Loc.t("Knockback"), knockback_add], "good": knockback_add > 0.0})
	if on_hit_effect != "none":
		out.append({"text": "%s %d%%" % [Loc.t(WeaponStats.ON_HIT_NAMES.get(on_hit_effect, on_hit_effect)), int(on_hit_chance * 100.0)], "good": true})
	if grants_light:
		out.append({"text": Loc.t("Emits light"), "good": true})
	if grants_lunge:
		out.append({"text": Loc.t("Lunge"), "good": true})
	match passive_player_effect:
		"none":
			pass
		"poison", "burn":
			out.append({"text": Loc.t("Holder takes " + passive_player_effect), "good": false})
		_:
			out.append({"text": Loc.t("pfx_" + passive_player_effect), "good": true})
	return out


static func _add_percent(out: Array[Dictionary], label: String, mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		return
	var percent := int(round((mult - 1.0) * 100.0))
	out.append({"text": "%s %+d%%" % [Loc.t(label), percent], "good": percent > 0})
