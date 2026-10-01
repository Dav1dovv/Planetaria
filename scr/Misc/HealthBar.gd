@icon("res://addons/at-icons/mesh/heart_broken.svg")
@tool
extends Control
class_name HealthBar

# ─────────────────────────────────────────────
#  HP  (всегда 0 … 100)
# ─────────────────────────────────────────────

@export_group("HP")

## Текущее HP (0 … 100)
@export_range(0, 100) var current_hp: float = 100.0 :
	set(v):
		var prev := current_hp
		current_hp = clampf(v, 0.0, 100.0)
		if not is_equal_approx(prev, current_hp):
			_on_value_changed(prev, current_hp)

## Количество контейнеров-сердец (5 по умолчанию, растёт через add_heart)
@export_range(1, 20) var heart_count: int = 5 :
	set(v):
		heart_count = clamp(v, 1, 20)
		if Engine.is_editor_hint():
			current_hp = 100.0
		_rebuild()
		notify_property_list_changed()

# ─────────────────────────────────────────────
#  ТЕКСТУРЫ
# ─────────────────────────────────────────────

@export_group("Текстуры")

@export var full_icon: Texture2D :
	set(v):
		full_icon = v
		_rebuild()

@export var half_icon: Texture2D :
	set(v):
		half_icon = v
		_rebuild()

@export var empty_icon: Texture2D :
	set(v):
		empty_icon = v
		_rebuild()

# ─────────────────────────────────────────────
#  РАСКЛАДКА
# ─────────────────────────────────────────────

@export_group("Раскладка")

@export var icon_size: Vector2 = Vector2(14, 14) :
	set(v):
		icon_size = v
		_rebuild()

@export_range(0, 12) var gap_x: float = 2.0 :
	set(v):
		gap_x = v
		_rebuild()

@export_range(0, 12) var gap_y: float = 2.0 :
	set(v):
		gap_y = v
		_rebuild()

## Сердец в одном ряду
@export_range(1, 20) var hearts_per_row: int = 10 :
	set(v):
		hearts_per_row = max(1, v)
		_rebuild()

## true = новые ряды растут вверх (HUD внизу экрана)
@export var rows_grow_up: bool = false :
	set(v):
		rows_grow_up = v
		_rebuild()

## Прозрачность пустых контейнеров
@export_range(0.0, 1.0) var empty_alpha: float = 0.45 :
	set(v):
		empty_alpha = clampf(v, 0.0, 1.0)
		_refresh_visuals()

# ─────────────────────────────────────────────
#  ЦВЕТА
# ─────────────────────────────────────────────

@export_group("Цвета")

@export var color_normal: Color = Color.WHITE :
	set(v):
		color_normal = v
		_refresh_visuals()

@export var color_critical: Color = Color(1.0, 0.18, 0.18) :
	set(v):
		color_critical = v
		_refresh_visuals()

@export var color_flash: Color = Color(2.0, 2.0, 2.0) :
	set(v):
		color_flash = v

# ─────────────────────────────────────────────
#  АНИМАЦИИ
# ─────────────────────────────────────────────

@export_group("Анимации")

@export var flash_on_damage: bool = true
@export_range(0.05, 0.4) var flash_duration: float = 0.14

@export var bounce_on_heal: bool = true

@export var pulse_on_critical: bool = true

## Порог критического HP (%)
@export_range(0, 100) var critical_threshold: float = 25.0 :
	set(v):
		critical_threshold = clamp(v, 0.0, 100.0)
		_check_critical()

@export_range(0.5, 6.0) var pulse_speed:    float = 2.6
@export_range(0.0, 0.35) var pulse_strength: float = 0.15

# ─────────────────────────────────────────────
#  ПРИВАТНЫЕ ПЕРЕМЕННЫЕ
# ─────────────────────────────────────────────

var _hearts:   Array[TextureRect] = []
var _base_pos: Array[Vector2]     = []
var _flash_t:  Array[float]       = []
var _bounce_t: Array[float]       = []
const _BOUNCE_DUR := 0.22

var _is_critical: bool  = false
var _pulse_t:     float = 0.0

# ─────────────────────────────────────────────
#  ЖИЗНЕННЫЙ ЦИКЛ
# ─────────────────────────────────────────────

func _ready() -> void:
	if not Engine.is_editor_hint():
		current_hp = 100.0
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var dirty := false

	for i in _flash_t.size():
		if _flash_t[i] > 0.0:
			_flash_t[i] = maxf(_flash_t[i] - delta, 0.0)
			dirty = true

	for i in _bounce_t.size():
		if _bounce_t[i] > 0.0:
			_bounce_t[i] = maxf(_bounce_t[i] - delta, 0.0)
			dirty = true

	if pulse_on_critical and _is_critical:
		_pulse_t += delta * pulse_speed * TAU
		dirty = true

	if dirty:
		_refresh_visuals()

# ─────────────────────────────────────────────
#  ПОСТРОЕНИЕ
# ─────────────────────────────────────────────

func _rebuild() -> void:
	for n in _hearts:
		n.queue_free()
	_hearts.clear()
	_base_pos.clear()
	_flash_t.clear()
	_bounce_t.clear()

	if not full_icon or not empty_icon:
		return

	var total_rows: int = ceili(float(heart_count) / float(hearts_per_row))

	for i in range(heart_count):
		var tr := TextureRect.new()
		tr.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = icon_size
		tr.size                = icon_size
		tr.pivot_offset        = icon_size * 0.5

		var col: int = i % hearts_per_row
		var row: int = i / hearts_per_row

		var px := float(col) * (icon_size.x + gap_x)
		var py := float(row) * (icon_size.y + gap_y)
		if rows_grow_up:
			py = float(total_rows - 1 - row) * (icon_size.y + gap_y)

		var pos := Vector2(px, py)
		tr.position = pos
		add_child(tr)
		_hearts.append(tr)
		_base_pos.append(pos)
		_flash_t.append(0.0)
		_bounce_t.append(0.0)

	_check_critical()
	_refresh_visuals()

# ─────────────────────────────────────────────
#  ВИЗУАЛЬНОЕ ОБНОВЛЕНИЕ
# ─────────────────────────────────────────────

func _refresh_visuals() -> void:
	if _hearts.is_empty():
		return

	# Сколько HP на одно сердце
	var hp_per_heart: float = 100.0 / float(heart_count)

	# Цветовой переход → critical
	var base_col := color_normal
	if _is_critical:
		var t := clampf(
			1.0 - (current_hp / 100.0) / (critical_threshold / 100.0),
			0.0, 1.0)
		base_col = color_normal.lerp(color_critical, t)

	# Индекс последнего живого сердца (для пульсации)
	var last_alive: int = ceili(current_hp / hp_per_heart) - 1

	for i in _hearts.size():
		var heart := _hearts[i]

		# Сколько HP попадает в это сердце
		var hp_start  := float(i) * hp_per_heart
		var fill_hp   := clampf(current_hp - hp_start, 0.0, hp_per_heart)
		var fill_ratio := fill_hp / hp_per_heart  # 0.0 … 1.0

		# Текстура: полное / половина / пустое
		if fill_ratio >= 1.0:
			heart.texture = full_icon
		elif fill_ratio >= 0.5 and half_icon:
			heart.texture = half_icon
		else:
			heart.texture = empty_icon

		# Цвет
		var col: Color
		if fill_ratio <= 0.0:
			col = Color(base_col.r, base_col.g, base_col.b, empty_alpha)
		else:
			col = base_col

		# Вспышка
		if i < _flash_t.size() and _flash_t[i] > 0.0:
			var s := (_flash_t[i] / flash_duration) ** 2.0
			col = col.lerp(color_flash, s)

		heart.modulate = col

		# Масштаб: пульсация + подпрыгивание
		var sv := 1.0
		var ey := 0.0

		if pulse_on_critical and _is_critical and i == last_alive and not Engine.is_editor_hint():
			sv = 1.0 + sin(_pulse_t) * pulse_strength

		if i < _bounce_t.size() and _bounce_t[i] > 0.0:
			var bt  := _bounce_t[i] / _BOUNCE_DUR
			var arc := sin(bt * PI)
			var bs  := 1.0 + arc * 0.28
			if bs > sv:
				sv = bs
			ey = -arc * icon_size.y * 0.22

		heart.scale    = Vector2(sv, sv)
		heart.position = _base_pos[i] + Vector2(0.0, ey) - icon_size * (sv - 1.0) * 0.5

# ─────────────────────────────────────────────
#  СОБЫТИЯ
# ─────────────────────────────────────────────

func _on_value_changed(prev_hp: float, next_hp: float) -> void:
	if not Engine.is_editor_hint():
		var hp_per_heart: float = 100.0 / float(heart_count)

		if flash_on_damage and next_hp < prev_hp:
			# Сердца, потерявшие HP
			var h_from: int = int(next_hp / hp_per_heart)
			var h_to:   int = mini(int(ceil(prev_hp / hp_per_heart)) - 1, _hearts.size() - 1)
			for i in range(h_from, h_to + 1):
				if i < _flash_t.size():
					_flash_t[i] = flash_duration

		if bounce_on_heal and next_hp > prev_hp:
			# Сердце, получившее HP
			var h: int = maxi(0, int(ceil(next_hp / hp_per_heart)) - 1)
			if h < _bounce_t.size():
				_bounce_t[h] = _BOUNCE_DUR

	_check_critical()
	_refresh_visuals()


func _check_critical() -> void:
	var was := _is_critical
	_is_critical = current_hp <= critical_threshold and current_hp > 0.0
	if _is_critical != was:
		_pulse_t = 0.0
		_refresh_visuals()

# ─────────────────────────────────────────────
#  ПУБЛИЧНОЕ API
# ─────────────────────────────────────────────

## Нанести урон (в единицах HP, 0–100)
func take_damage(amount: float) -> void:
	current_hp -= amount

## Восстановить HP
func heal(amount: float) -> void:
	current_hp += amount

## Добавить контейнер-сердце (апгрейд).
## heal_new=true → новое сердце сразу заполнено (HP увеличится пропорционально).
func add_heart(heal_new: bool = false) -> void:
	if heart_count >= 20:
		return
	var old_hp_per_heart := 100.0 / float(heart_count)
	heart_count += 1                               # пересчитывает hp_per_heart
	if heal_new:
		# Восполняем ровно одно новое сердце
		var new_hp_per_heart := 100.0 / float(heart_count)
		current_hp = minf(current_hp + new_hp_per_heart, 100.0)
	_rebuild()

## Установить HP напрямую (0.0 … 100.0)
func set_hp(value: float) -> void:
	current_hp = value

## HP как доля 0.0 … 1.0
func get_ratio() -> float:
	return current_hp / 100.0

## Мёртв?
func is_dead() -> bool:
	return current_hp <= 0.0

## Критическое состояние?
func is_critical_state() -> bool:
	return _is_critical

## Сколько HP даёт одно сердце при текущем количестве
func get_hp_per_heart() -> float:
	return 100.0 / float(heart_count)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()
