extends RapierArea2D
class_name Harvest_item

signal collected
signal hit
## Испускается при каждом ударе — множитель можно использовать для UI/попапов чисел
signal combo_hit(multiplier: float, combo_count: int)

var gm

const CORRUPTION = preload("uid://cfxxahs7peuhm")

@onready var Dropper_component : Dropper = $droper
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var _screen_notifier: VisibleOnScreenEnabler2D = get_node_or_null("optimizer")

@export_range(2,999,1) var durability : float = 6
@export_range(0,10) var harvest_tool_lvl : int = 1
@export var VFX_component : VFX

# ────────────────────────────────────────────────────────────────────────────

var player
var tween: Tween
var _last_tool_lvl: int = 999  # запоминаем последний использованный tier

# Ссылка на ShaderMaterial спрайта
var _shader_material: ShaderMaterial

@export_group("Transparency Settings")
@export_range(0.0, 200.0, 10.0) var max_distance : float = 20
@export_range(0.0, 1.0, 0.01) var fade_alpha : float = 0.50
@export_range(0.1, 1.0, 0.05) var fade_duration : float = 0.2

# ОПТИМИЗАЦИЯ: квадрат дистанции — сравнение без sqrt
var _max_distance_sq : float = 0.0
# Текущее "выцветшее" состояние — tween запускаем только при его смене,
# а не каждый physics-кадр
var _is_faded : bool = false


# ─── Combo / Timing Harvest ──────────────────────────────────────────────────
@export_group("Combo Harvest")
## Максимальный интервал между ударами, чтобы комбо не сбросилось (сек)
@export_range(0.2, 3.0, 0.05) var combo_window : float = 0.9
## На сколько растёт множитель за каждый удар в тайминге
@export_range(0.0, 1.0, 0.01) var combo_bonus_per_hit : float = 0.15
## Потолок множителя комбо
@export_range(1.0, 5.0, 0.1) var combo_max_multiplier : float = 2.0

var _combo_count : int = 0
var _combo_multiplier : float = 1.0
var _last_hit_time : float = -999.0

# ─── Rich Vein — редкая "богатая жила" ───────────────────────────────────────
@export_group("Rich Vein")
## Шанс, что этот ресурс окажется "богатой жилой" (только если не заражён)
@export_range(0.0, 1.0, 0.01) var rich_vein_chance : float = 0.08
## Множитель к финальному дропу с богатой жилы
@export_range(1.0, 5.0, 0.1) var rich_vein_multiplier : float = 2.5
@export var rich_vein_tint : Color = Color(1.0, 0.85, 0.2, 1.0)

var is_rich_vein : bool = false
var is_corrupted : bool = false

@export_group("Corruption")
## Отладка: принудительно сделать ЭТОТ ресурс заражённым, чтобы проверить логику
## заражения не дожидаясь рандома. Включай точечно на одном инстансе в
## инспекторе для теста — по умолчанию должно быть false, иначе заражены
## будут все ресурсы, использующие этот скрипт.
@export var force_corrupted : bool = false

# ── ОПТИМИЗАЦИЯ: throttle вне экрана ─────────────────────────────
# В сцене уже есть VisibleOnScreenEnabler2D ("optimizer"), но раньше он не
# использовался в скрипте — update_transparency() дистанции до игрока
# считался для КАЖДОГО Harvestable на карте каждый physics-кадр, даже для
# тех, что далеко за пределами экрана (а таких на большой карте может быть
# сотни одновременно). Теперь вне экрана эта проверка просто пропускается —
# как и у Creature.gd, где этот же паттерн уже применён.
@export var can_infect : bool = true
var _is_active: bool = true

func _init() -> void:
	set_collision_layer_value(2,true)
	set_collision_layer_value(5,true)
	set_collision_mask_value(1,false)
	set_collision_mask_value(4,true)
	set_collision_mask_value(9,true)

func _ready() -> void:
	add_to_group("Harvestable")
	if not is_inside_tree():
		await tree_entered
	# ── Шанс стать заражённым ресурсом ───────────────────────────────────────
	# БЫЛО: randi() / Global.corruption — целочисленное деление огромного randi()
	# на int почти никогда не давало < 0.3, is_corrupted не срабатывал вообще
	# (шанс ~1 к 64 млн). Теперь шанс честно масштабируется от уровня заражения
	# мира (Global.corruption, 0-100): при 100% заражении мира — до 30% шанс
	# на ресурс, при 0% — 0%.
	# ── Шанс стать заражённым ресурсом ───────────────────────────────────────
	# force_corrupted — точечный оверрайд для теста ОДНОГО ресурса в инспекторе.
	# can_infect — может ли этот тип ресурса вообще заражаться (выключи у тех
	# ресурсов, которые по дизайну не должны быть заражёнными).
	if force_corrupted:
		$Corruption.emitting = true
		is_corrupted = true
	elif can_infect:
		var max_corrupt_chance := 0.3
		var corrupt_chance := (float(Global.corruption) / 100.0) * max_corrupt_chance
		if randf() < corrupt_chance:
			$Corruption.emitting = true
			is_corrupted = true

	Dropper_component = $droper
	player = get_tree().get_first_node_in_group("Player")
	gm = get_tree().get_first_node_in_group("World")

	var sprite = $Sprite2D
	if sprite and sprite.material is ShaderMaterial:
		_shader_material = sprite.material
		_shader_material.set_shader_parameter("wind_offset", global_position.x)

	_max_distance_sq = max_distance * max_distance
	_setup_screen_throttle()


## Подключаемся к уже существующему VisibleOnScreenEnabler2D ("optimizer" в сцене) —
## тот же паттерн, что и в Creature.gd.
func _setup_screen_throttle() -> void:
	if _screen_notifier == null:
		return
	_screen_notifier.screen_entered.connect(func(): _is_active = true)
	_screen_notifier.screen_exited.connect(func(): _is_active = false)
	_is_active = _screen_notifier.is_on_screen()


func _physics_process(_delta: float) -> void:
	if not _is_active:
		return
	update_transparency()


func Harvest(hit_strenght : float, tool_lvl : int, is_weapon : bool) -> void:
	if is_weapon:
		return

	# Запоминаем тир для spawn CurseObject при разрушении
	_last_tool_lvl = tool_lvl

	# ── Заражение игрока: осколки заражённого ресурса летят при каждом ударе ─
	if is_corrupted:
		var cor = CORRUPTION.instantiate()
		add_child(cor)
	# ─────────────────────────────────────────────────────────────────────────

	# ── Комбо-тайминг: бей ритмично — множитель растёт ───────────────────────
	#_update_combo()
	# ─────────────────────────────────────────────────────────────────────────

	# ── Визуальный фидбэк ────────────────────────────────────────────────────
	if VFX_component != null:
		VFX_component._hit_vfx($Sprite2D)
		#await VFX_component.vfx_finished
	# ─────────────────────────────────────────────────────────────────────────

	# ── Уменьшение прочности (с бонусом от комбо-тайминга) ───────────────────
	durability -= hit_strenght * _combo_multiplier
	# ─────────────────────────────────────────────────────────────────────────

	if durability <= 0:
		_on_destroyed(tool_lvl)


## Заражает игрока осколками при ударе по заражённому ресурсу.
func _infect_player() -> void:
	if player == null:
		return



func _on_destroyed(tool_lvl: int) -> void:
		
		
	$CollisionShape2D.disabled = true
	Dropper_component._drop_items()
	if animation.has_animation("destroy"):
		animation.play("destroy")
		await animation.animation_finished
	else : 
		$Sprite2D .visible = false
		$StaticBody2D.queue_free()
	if $Destroy:
		$Destroy.play()
		await $Destroy.finished

	# Регистрация сбора в мире
	if gm and gm.has_method("register_harvested"):
		var loc_key := get_tree().current_scene.scene_file_path
		gm.register_harvested(loc_key, global_position)
	# ─────────────────────────────────────────────────────────────────────────

	emit_signal("collected")
	queue_free()


#region Background transparency
## ОПТИМИЗАЦИЯ: distance_squared_to вместо distance_to (без sqrt) +
## tween запускаем только при смене состояния near/far, а не каждый кадр —
## иначе на каждый Harvestable в мире это create_tween()+kill() 60 раз/сек.
func update_transparency() -> void:
	if _shader_material == null:
		return

	var should_fade := false
	if player != null:
		var dist_sq := global_position.distance_squared_to(player.global_position)
		var player_behind = player.global_position.y < global_position.y
		should_fade = player_behind and dist_sq < _max_distance_sq

	if should_fade == _is_faded:
		return  # состояние не изменилось — tween не нужен

	_is_faded = should_fade
	_tween_fade(fade_alpha if should_fade else 1.0)

func _tween_fade(target_alpha: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var current_alpha: float = _shader_material.get_shader_parameter("fade_alpha")
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("fade_alpha", v),
		current_alpha,
		target_alpha,
		fade_duration
	)
#endregion
