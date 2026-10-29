extends RapierCharacterBody2D
class_name Entity

@export var Entity_stats: stats
@export var Vfx : VFX
@export var knockback_strength: float = 30.0
@export var knockback_duration: float = 0.1
## ID для заданий KILL_ENEMY. Пусто = берётся из имени сцены (Slime2.tscn -> "slime")
@export var enemy_id: String = ""

# ── Hit-feel настройки ──────────────────────────────────────────
@export_group("Hit Feel")
## Длительность hit-stop в секундах (0 = выкл)
@export var hitstop_duration: float = 0.06
## Сила дрожания камеры
@export var screen_shake_strength: float = 3.0
## Длительность дрожания камеры
@export var screen_shake_duration: float = 0.12
## Время неуязвимости после удара (iframes)
@export var invincibility_duration: float = 0.25
## «Тяжёлый» удар: доля от max_health, после которой цифра урона крупнее,
## а хит-стоп и тряска камеры сильнее
@export_range(0.01, 1.0, 0.01) var heavy_hit_ratio: float = 0.15
# ────────────────────────────────────────────────────────────────

# ── Terraria-стиль урона ────────────────────────────────────────
@export_group("Terraria Damage")
## Разброс урона: ±доля от удара (Terraria: ±15%). 0 = без разброса
@export_range(0.0, 0.5, 0.01) var damage_variance: float = 0.15
## Множитель критического удара (Terraria: x2)
@export var crit_multiplier: float = 2.0
## Сопротивление отбрасыванию: 0 = обычное, 0.5 = вдвое меньше, 1 = иммунитет (боссы)
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0
# ────────────────────────────────────────────────────────────────

# ── Стойкость (poise) / стаггер ─────────────────────────────────
@export_group("Poise / Stagger")
## Сколько «стойкости» выдерживает существо до оглушения. 0 = не оглушается
@export var max_poise: float = 100.0
## Скорость восстановления стойкости в секунду (когда не бьют)
@export var poise_decay_rate: float = 15.0
## Пауза перед началом восстановления после последнего удара
@export var poise_decay_delay: float = 1.0
## Длительность стаггера, когда стойкость кончилась
@export var stagger_duration: float = 1.0
## Множитель входящего урона во время стаггера (окно «добивания»)
@export var vulnerable_damage_multiplier: float = 1.5
# ────────────────────────────────────────────────────────────────

## Минимальный урон от любого удара (в Terraria удар никогда не бьёт на 0)
const MIN_DAMAGE: float = 1.0

## Печатать подробный лог урона в консоль (выключено — print() не бесплатен)
@export var debug_log_damage: bool = false

# Сигналы
signal health_changed(new_health: float)
signal died

# Переменные состояния
var is_alive: bool = true
var is_knocked_back: bool = false
var is_invincible: bool = false   # iframes
var is_invisible: bool = false    # см. set_invisibility()

# Стойкость считается лениво (по времени последнего удара) — без покадрового тика
var current_poise: float = 0.0
var _poise_hit_msec: int = 0
var _staggered_until_msec: int = 0

# Менеджер эффектов (баффы/дебаффы/DoT) — общий для игрока и существ
var effect_manager: EffectManager

# Кешируем спрайт сущности для flash-эффекта
var _entity_sprite: Node = null

func _ready():
	# КРИТИЧНО: дублируем Resource чтобы каждый инстанс имел свои Stats
	Entity_stats = Entity_stats.duplicate()
	Entity_stats.move_speed = Entity_stats.base_move_speed
	Entity_stats.current_health = Entity_stats.max_health
	effect_manager = _get_or_create_effect_manager()
	effect_manager.effect_added.connect(_on_effect_added)
	effect_manager.effect_removed.connect(_on_effect_removed)
	_entity_sprite = _find_sprite(self)

# ── ЭФФЕКТЫ (баффы / дебаффы / DoT) ──────────────────────────────
## EffectManager можно добавить руками в сцену (как дочерний Node) — тогда
## он подхватится автоматически. Если его нет, создаётся на лету.
func _get_or_create_effect_manager() -> EffectManager:
	for child in get_children():
		if child is EffectManager:
			return child
	var em := EffectManager.new()
	em.name = "EffectManager"
	add_child(em)
	return em

## Точка входа для Effect.apply_effect(target) — см. EffectResource.gd.
func apply_effect_instance(effect: Effect) -> void:
	effect_manager.apply_effect(effect)

## Точка входа для Effect.remove_effect(target).
func remove_effect_instance(effect: Effect) -> void:
	effect_manager.remove_effect(effect.effect_type)

func has_effect(effect_type) -> bool:
	return effect_manager.has_effect(effect_type)

## "Пока экипировано" — для аксессуаров (AccessoryData) и пассивов оружия
## (WeaponPassiveHandler). В отличие от apply_effect_instance() не снимается
## по таймеру: живёт, пока явно не вызовут remove_passive_effect() при снятии
## предмета. Несколько источников одного и того же эффекта не гасят друг друга.
func apply_passive_effect(effect: Effect) -> void:
	effect_manager.apply_passive_effect(effect)

func remove_passive_effect(effect: Effect) -> void:
	effect_manager.remove_passive_effect(effect)

## Переопредели в Player/Creature, если нужна реакция на появление эффекта
## (иконка в UI и т.п.). EffectDisplayUI игрока может слушать сигнал напрямую
## через player.effect_manager.effect_added.
func _on_effect_added(effect: Effect) -> void:
	pass

func _on_effect_removed(effect: Effect) -> void:
	pass

## Видимость для систем обнаружения (Creature.gd может проверять target.is_invisible
## в своей логике зрения/слуха, если такая проверка понадобится).
func set_invisibility(active: bool) -> void:
	is_invisible = active
	if _entity_sprite:
		_entity_sprite.modulate.a = 0.35 if active else 1.0

# ── КРИТЫ / STAGGER (переопределяется в подклассах, напр. Creature) ─
## Множитель входящего урона. Creature переопределяет — во время STUNNED
## существо получает больше урона (окно "добивания" после стаггера).
func get_incoming_damage_multiplier() -> float:
	return vulnerable_damage_multiplier if is_staggered() else 1.0

# ── POISE / STAGGER ─────────────────────────────────────────────
func is_staggered() -> bool:
	return Time.get_ticks_msec() < _staggered_until_msec

## Снимает стойкость. Игрока и «непробиваемых» (knockback_resistance = 1, боссы) не оглушаем.
func add_poise_damage(amount: float) -> void:
	if not is_alive or amount <= 0.0 or max_poise <= 0.0:
		return
	if knockback_resistance >= 1.0 or is_in_group("Player"):
		return
	var now := Time.get_ticks_msec()
	# Ленивое восстановление: сколько секунд стойкость успела отдыхать
	var rested := float(now - _poise_hit_msec) / 1000.0 - poise_decay_delay
	if rested > 0.0:
		current_poise = maxf(0.0, current_poise - poise_decay_rate * rested)
	_poise_hit_msec = now
	current_poise += amount * (1.0 - knockback_resistance)
	if current_poise >= max_poise:
		current_poise = 0.0
		_staggered_until_msec = now + int(stagger_duration * 1000.0)
		_on_staggered(stagger_duration)

## Переопредели: прервать атаку, оглушить и т.п.
func _on_staggered(_duration: float) -> void:
	pass

## Вызывается из take_damage() после расчёта урона, ДО проверки на смерть.
func _on_damage_received(damage_source: Node, _actual_damage: float, is_critical: bool) -> void:
	if damage_source != null and damage_source.has_method("get_poise_damage"):
		add_poise_damage(damage_source.get_poise_damage() * (1.5 if is_critical else 1.0))

## Кто на самом деле атаковал: владелец снаряда или игрок, внутри которого лежит оружие.
func _resolve_attacker(source: Node) -> Node2D:
	if source == null:
		return null
	var shooter = source.get("owner_player")
	if shooter is Node2D and is_instance_valid(shooter):
		return shooter
	var current: Node = source
	for i in 3:
		if current == null:
			return null
		if current.is_in_group("Player"):
			return current as Node2D
		current = current.get_parent()
	return null

# ── ПОЛУЧЕНИЕ УРОНА (по формуле Terraria) ───────────────────────
## Порядок расчёта, как в Terraria:
##   1) разброс ±damage_variance  2) крит x crit_multiplier
##   3) минус плоская защита (броня / 2)  4) минус % снижения  5) минимум 1
## Крит определяет АТАКУЮЩИЙ: если у damage_source есть метод roll_crit() -> bool,
## он вызывается один раз за удар (см. PlayerHitBox). Нет метода — крита нет
## (как и у мобов в Terraria).
func take_damage(damage: float, damage_source: Node2D = null, knockback_mod : float = 0.0) -> void:
	if not is_alive or is_invincible:
		return

	var is_critical := _roll_critical(damage_source)
	var actual_damage := _calculate_damage(damage, is_critical)

	if Vfx != null:
		Vfx._damage_vfx()

	Entity_stats.current_health -= actual_damage
	emit_signal("health_changed", Entity_stats.current_health)

	_play_hit_feel(actual_damage, damage_source, is_critical)
	_on_damage_received(damage_source, actual_damage, is_critical)

	if debug_log_damage:
		_log_damage(damage, actual_damage, is_critical)

	if damage_source != null and knockback_resistance < 1.0:
		# Terraria: отбрасывание = сила оружия * (1 - сопротивление цели), без рандома
		var knockback_power = knockback_strength + knockback_mod

		if Entity_stats.current_health <= Entity_stats.max_health / 35:
			knockback_power += 40 + damage

		apply_knockback(damage_source, knockback_power * (1.0 - knockback_resistance))

	if Entity_stats.current_health <= 0:
		die()
	elif invincibility_duration > 0:
		_start_invincibility()

## Спрашивает у источника удара, критический ли он.
func _roll_critical(damage_source: Node) -> bool:
	if damage_source != null and damage_source.has_method("roll_crit"):
		return damage_source.roll_crit()
	return false

## Чистая формула урона — без побочных эффектов, удобно тестировать.
func _calculate_damage(raw_damage: float, is_critical: bool) -> float:
	if raw_damage <= 0.0:
		return 0.0

	var dmg := raw_damage

	# 1) Разброс ±15%
	if damage_variance > 0.0:
		dmg *= randf_range(1.0 - damage_variance, 1.0 + damage_variance)

	# 2) Крит
	if is_critical:
		dmg *= crit_multiplier

	# 3) Плоская защита (броня / 2)
	dmg -= Entity_stats.get_flat_defense()

	# 4) Процентное снижение + уязвимость (стаггер у Creature)
	dmg *= (1.0 - Entity_stats.get_endurance()) * get_incoming_damage_multiplier()

	# 5) Целое число, минимум 1
	return maxf(MIN_DAMAGE, roundf(dmg))

# ── SCREEN SHAKE ────────────────────────────────────────────────
func _trigger_screen_shake(is_critical: bool = false) -> void:
	GameJuice.shake(screen_shake_strength * (1.8 if is_critical else 1.0), screen_shake_duration)

# ── HIT-STOP ────────────────────────────────────────────────────
## Безопасен при наложении ударов — время возвращает последний вызов (см. GameJuice).
func _do_hitstop(is_critical: bool = false) -> void:
	GameJuice.hitstop(hitstop_duration * (1.6 if is_critical else 1.0))

# ── IFRAMES ─────────────────────────────────────────────────────
func _start_invincibility() -> void:
	is_invincible = true
	# Мигание полупрозрачностью во время неуязвимости
	if _entity_sprite:
		var tween = create_tween().set_loops(int(invincibility_duration / 0.12))
		tween.tween_property(_entity_sprite, "modulate:a", 0.35, 0.06)
		tween.tween_property(_entity_sprite, "modulate:a", 1.0, 0.06)

	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
	if _entity_sprite:
		_entity_sprite.modulate.a = 1.0

# ── KNOCKBACK ───────────────────────────────────────────────────
func apply_knockback(damage_source: Node2D, knockback_multipiler: float) -> void:
	if is_knocked_back:
		return
	is_knocked_back = true

	var base_dir = (global_position - damage_source.global_position).normalized()
	# Добавляем лёгкий случайный угол для ощущения «живости»
	var angle_variance = deg_to_rad(randf_range(-12.0, 12.0))
	var knockback_direction = base_dir.rotated(angle_variance)
	var knockback_distance = knockback_direction * knockback_multipiler / 3.5

	var tween = create_tween()
	# Быстрый старт → плавное торможение
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "position", position + knockback_distance, knockback_duration)
	tween.tween_callback(func(): is_knocked_back = false)

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	tween.tween_callback(func():
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
	)

# ── HIT FEEL / ID ВРАГА ─────────────────────────────────────────
## Цифры урона + хит-стоп + тряска камеры.
## Хит-стоп и тряска — только если в ударе участвует игрок (иначе драка мобов
## между собой замораживала бы игру).
func _play_hit_feel(actual_damage: float, damage_source: Node, is_critical: bool = false) -> void:
	if actual_damage < 0.5:
		return
	var hurt_player := _is_player_node(self)
	var involves_player := hurt_player or _is_player_node(damage_source)
	var is_heavy := is_critical or actual_damage >= Entity_stats.max_health * heavy_hit_ratio

	# Цвета как в Terraria: оранжевый — урон по врагу, красный — по игроку, крит — жёлтый и крупнее
	var color := Color(1.0, 0.63, 0.31)
	if hurt_player:
		color = Color(1.0, 0.31, 0.35)
	if is_critical:
		color = Color(1.0, 0.45, 0.1) if hurt_player else Color(1.0, 0.85, 0.2)

	var text_scale := 1.0
	if is_critical:
		text_scale = 1.8
	elif is_heavy:
		text_scale = 1.5

	GameJuice.floating_text(global_position + Vector2(0.0, -14.0), str(roundi(actual_damage)),
			color, text_scale)

	if involves_player:
		_do_hitstop(is_heavy)
		_trigger_screen_shake(is_heavy)
		# Геймпад обязателен (GDD): попадание по врагу тоже должно «ощущаться» в руках
		if not hurt_player:
			Rumble.confirm(is_heavy)

## Узел или один из его трёх ближайших предков — игрок (оружие/хитбокс лежат внутри игрока).
func _is_player_node(node: Node) -> bool:
	var current: Node = node
	for i in 3:
		if current == null:
			return false
		if current.is_in_group("Player"):
			return true
		current = current.get_parent()
	return false

## ID для заданий: enemy_id из Инспектора или имя сцены без цифр и суффикса после "_"
## (Slime2.tscn -> "slime", Pig_BOs.tscn -> "pig", CooperKnight.tscn -> "cooperknight").
func get_enemy_id() -> String:
	if not enemy_id.is_empty():
		return enemy_id
	var base := scene_file_path.get_file().get_basename().to_lower()
	if base.is_empty():
		base = String(name).to_lower()
	base = base.split("_")[0]
	while base.length() > 1 and base[-1].is_valid_int():
		base = base.left(base.length() - 1)
	return base

# ── УТИЛИТЫ ─────────────────────────────────────────────────────
func _find_sprite(node: Node) -> Node:
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

## Раньше это был рекурсивный обход всего дерева сцены на каждый удар —
## заменено на встроенный O(1) доступ к активной камере вьюпорта.
func _find_camera() -> Camera2D:
	var vp = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_2d()

func _log_damage(base: float, actual: float, is_critical: bool = false) -> void:
	print("====================================")
	print("Получен урон:" + (" [КРИТ!]" if is_critical else ""))
	print("  Базовый урон: %.1f (разброс ±%d%%)" % [base, roundi(damage_variance * 100.0)])
	print("  Броня: %.1f -> плоская защита: -%.1f" % [Entity_stats.armor, Entity_stats.get_flat_defense()])
	print("  Снижение: %.1f%%" % (Entity_stats.get_endurance() * 100.0))
	print("  Фактический урон: %.0f" % actual)
	print("  Осталось HP: %.1f / %.1f" % [Entity_stats.current_health, Entity_stats.max_health])
	print("====================================")

# ── СМЕРТЬ И ЭФФЕКТЫ ────────────────────────────────────────────
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	# Для заданий KILL_ENEMY, комбо и статистики (игрока не считаем)
	if not is_in_group("Player"):
		Global.report_enemy_killed(self)
	emit_signal("died")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)


func heal(amount: float) -> void:
	if !is_alive:
		return
	Entity_stats.current_health = min(Entity_stats.current_health + amount, Entity_stats.max_health)
	emit_signal("health_changed", Entity_stats.current_health)

## Урон от периодических эффектов (яд, ожог, кровотечение, заражение).
## Отдельно от take_damage(): без хитстопа, тряски камеры, нокбэка и i-фреймов —
## это "фоновый" урон, а не удар оружием. По умолчанию броня/защита его не
## снижают (DoT считается "истинным" уроном) — передай ignore_reduction = false,
## если для конкретного эффекта это должно быть иначе.
func take_dot_damage(amount: float, ignore_reduction: bool = true) -> void:
	if not is_alive or amount <= 0.0:
		return

	var actual_damage := amount
	if not ignore_reduction:
		var total_reduction = clamp(Entity_stats.get_total_damage_reduction(), 0.0, 0.9)
		actual_damage = amount * (1.0 - total_reduction)

	if debug_log_damage:
		print("[DOT] %s: -%.1f HP (%.1f -> %.1f)" % [name, actual_damage, Entity_stats.current_health, Entity_stats.current_health - actual_damage])

	Entity_stats.current_health -= actual_damage
	Vfx._damage_vfx()
	emit_signal("health_changed", Entity_stats.current_health)

	if Entity_stats.current_health <= 0:
		die()
