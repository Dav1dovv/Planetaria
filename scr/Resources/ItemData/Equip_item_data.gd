@icon("res://common/icons/helpcon3.png")
extends ItemData
class_name equip_data

@export_category("equip_data")
@export var lvl : int = 1
@export_range(10, 500, 1) var max_durability: int = 100
var durability: int = -1  # -1 = не инициализирована
@export_range(1, 93, 1)     var Damage:    int   = 7
@export_range(10.0,100.0,0.1) var hit_distance: float = 10.0
@export_range(0.85, 3, 0.01) var Atk_speed: float = 1.0
@export var equiped_weapon_sprite: Texture
@export var projectile: PackedScene
@export var is_weapon: bool = true
@export var num_projectiles: int = 1
@export var spread_degrees: float = 0.0
@export var projectile_speed: float = 400.0
@export var accuracy_radius: float = 20.0
@export var knockback : float = 5

@export_group("Attack Behavior")
@export var one_shot_attack: bool = true

# ═══════════════════════════════════════════════════════════════════
#  LUNGE ATTACK — рывок-атака (тамплиер / рыцарь)
# ═══════════════════════════════════════════════════════════════════
@export_group("Lunge Attack")

## Включить рывок-атаку для этого оружия
@export var lunge_enabled: bool = false

## Скорость рывка (пикселей/сек)
@export_range(10.0, 120.0, 10.0) var lunge_speed: float = 10

## Длительность рывка (сек). Короткий = резкий укол, длинный = пробег сквозь толпу
@export_range(0.05, 0.6, 0.01) var lunge_duration: float = 0.18

## Урон рывка как доля от Damage (1.0 = полный, 1.5 = усиленный)
@export_range(0.5, 3.0, 0.1) var lunge_damage_multiplier: float = 1.2

## Рывок даёт неуязвимость (i-frames) на всё время
@export var lunge_invincible: bool = true

## Шлейф / след от рывка (PackedScene). Если null — без эффекта
@export var lunge_trail_scene: PackedScene


# ═══════════════════════════════════════════════════════════════════
#  ON-HIT EFFECTS — эффекты, накладываемые на цель при ударе
# ═══════════════════════════════════════════════════════════════════
@export_group("On-Hit Effects")

# ── On-Hit Effects — только эта секция меняется ────────────────────────────
# Заменить блок @export_group("On-Hit Effects") в оригинальном файле на этот:

@export_group("On-Hit Effects")

## Тип эффекта, накладываемого на цель при ударе.
## none        — без эффекта
## burn        — Обжиг DOT + паника (Взрывная ягода, огневое)
## poison      — Отравление DOT (Меч-Жало, Паучий кинжал; не работает на голем/скелет)
## freeze      — Заморозка: замедление -30-40% + слабый DOT (Лёд, Посох, Снежный лук)
## bleed       — Кровотечение: % от max HP в тик (Костяной бич, Костяной клинок)
## corruption  — Заражение: DOT + враг усиливается (Бездна, ловушки)
## slow        — Замедление без DOT (вспомогательный)
## heal_on_hit — Лечит игрока при попадании (особый случай)
@export_enum("none","burn","poison","freeze","bleed","corruption","slow","heal_on_hit") \
	var on_hit_effect: String = "none"

@export_range(0.0, 1.0, 0.01) var on_hit_chance: float = 1.0
@export_range(0.5, 15.0, 0.5) var on_hit_duration: float = 3.0
@export_range(0.1, 50.0, 0.1) var on_hit_potency: float = 5.0

# Только для bleed: процент от max HP врага за тик (default 3%)
@export_range(0.01, 0.15, 0.005) var on_hit_bleed_percent: float = 0.03

# Только для corruption: насколько усиливается враг (default +15% урона)
@export_range(0.05, 0.5, 0.05) var on_hit_corruption_bonus: float = 0.15


# ═══════════════════════════════════════════════════════════════════
#  PASSIVE EFFECTS — эффекты пока оружие держат в руках
# ═══════════════════════════════════════════════════════════════════
@export_group("Passive (while equipped)")

## Оружие излучает свет (Меч Света и подобные)
@export var passive_emits_light: bool = false

## Цвет света
@export var passive_light_color: Color = Color(1.0, 0.95, 0.6, 1.0)

## Радиус свечения (пиксели)
@export_range(32.0, 512.0, 8.0) var passive_light_radius: float = 180.0

## Интенсивность свечения PointLight2D (0..4)
@export_range(0.0, 4.0, 0.05) var passive_light_energy: float = 1.0

## Пассивный эффект статуса на самого игрока (buff/debuff, пока держит оружие)
## Значения: "none","regen","speed_boost","defense_boost","poison","burn"
@export_enum("none","regen","speed_boost","defense_boost","poison","burn") \
	var passive_player_effect: String = "none"

## Сила пассивного эффекта на игрока
@export_range(0.0, 50.0, 0.1) var passive_player_potency: float = 0.0
@export_group("CurseObject Interaction")
 
## Может ли это оружие отбивать CurseObject («Волейбол тьмы»)?
## Нож и расходное оружие (ветка, кость) → false
## Все мечи, луки, посохи → true
@export var can_deflect_curse: bool = true

# ═══════════════════════════════════════════════════════════════════
#  Прочность
# ═══════════════════════════════════════════════════════════════════
signal durability_changed(current: int, maximum: int)
signal weapon_broken

func get_durability() -> int:
	if durability < 0:
		durability = max_durability
	return durability

func reduce_durability(amount: int = 1) -> void:
	if durability < 0:
		durability = max_durability
	durability = max(0, durability - amount)
	emit_signal("durability_changed", durability, max_durability)
	if durability <= 0:
		emit_signal("weapon_broken")

func is_broken() -> bool:
	return get_durability() <= 0

func repair(amount: int = -1) -> void:
	if amount < 0:
		durability = max_durability
	else:
		durability = min(max_durability, get_durability() + amount)
	emit_signal("durability_changed", durability, max_durability)

func get_durability_ratio() -> float:
	return float(get_durability()) / float(max_durability)

func apply_quality_multiplier(q: int) -> void:
	super.apply_quality_multiplier(q)
	Damage        = int(Damage * (1.0 + q * 0.5))
	Atk_speed     += q * 0.1
	max_durability += q * 25
	if durability > 0:
		durability = min(durability, max_durability)
