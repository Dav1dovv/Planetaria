# skin_colors.gd
## Цвета внешнего вида игрока (palette swap) и вся математика вокруг них.
##
## ИДЕЯ
##   Игрок выбирает три цвета: ШЛЕМ, КОМБИНЕЗОН и АКЦЕНТ (визор, пояс, сапоги).
##   Из каждого цвета строится рамп оттенков (светлый → средний → тёмный) и подставляется
##   вместо шаблонных оттенков серого скина шейдером palette_swap.gdshader.
##   Рисовать отдельный спрайт под каждый цвет не нужно.
##
## КАК РИСОВАТЬ НОВЫЕ ДЕТАЛИ (шлемы, комбинезоны, …)
##   Рисуй обычным серым шаблоном – ТОЧНО этими цветами (они же в Skin.png):
##       основной   #8B93AF      – перекрашивается в выбранный цвет
##       тень       #6D758D      – его средний оттенок
##       глубокая   #4A5462      – его тёмный оттенок
##       подкладка  #333941 и #122020 – тёмные детали, слегка тонируются цветом
##       акцент     #FFD541 и #F9A31B – визор/пояс/сапоги, цвет акцента
##       контур     #060608      – не меняется никогда
##   Любые ДРУГИЕ цвета проходят как есть (готовые скины Skin2…Skin5 продолжают работать,
##   просто не перекрашиваются). Новый спрайт подхватится автоматически: деталь считается
##   «перекрашиваемой», если в ней есть хотя бы один пиксель основного оттенка.
##
## ХРАНЕНИЕ
##   SkinColors.current – цвета локального игрока (null = оригинальные цвета текстур).
##   Сохраняются в мета-данных слота (to_dict/from_dict), вешаются на спрайты через
##   PlayerSkin.set_colors(). Для мультиплеера отправляй to_dict() теми же RPC, что и скин.
class_name SkinColors
extends RefCounted

# ─────────────────────────────────────────────────────────────────────────────
#  Шаблонные («ключевые») цвета серого скина
# ─────────────────────────────────────────────────────────────────────────────
const KEY_RAMP: Array[Color] = [
	Color8(139, 147, 175),  # основной
	Color8(109, 117, 141),  # тень
	Color8(74, 84, 98),     # глубокая тень
]
const KEY_DARK: Array[Color] = [
	Color8(51, 57, 65),     # подкладка
	Color8(18, 32, 32),     # самая тёмная подкладка
]
const KEY_ACCENT: Array[Color] = [
	Color8(255, 213, 65),   # акцент светлый
	Color8(249, 163, 27),   # акцент тёмный
]

## Цвета для выбора в интерфейсе (шестнадцать «хороших» цветов; игрок не может выбрать плохой)
const PRESETS: Array[Color] = [
	Color("8b93af"), Color("e8ecf3"), Color("3a4252"), Color("1d1f2b"),
	Color("b4202a"), Color("e8702a"), Color("e8c53a"), Color("7bc74d"),
	Color("2f9e57"), Color("25b5a8"), Color("3fb0e8"), Color("285cc4"),
	Color("8a4fd6"), Color("d63fa0"), Color("f28bb0"), Color("8a5a3a"),
]

## Цвета по умолчанию = оригинальный вид шаблона (рамп совпадает с художественным).
const DEFAULT_HELMET := Color("8b93af")
const DEFAULT_SUIT := Color("8b93af")
const DEFAULT_ACCENT := Color("ffd541")

## Локальный игрок. null = ничего не перекрашивать.
static var current: SkinColors = null

static var _colorable_cache: Dictionary = {}

var helmet: Color = DEFAULT_HELMET
var suit: Color = DEFAULT_SUIT
var accent: Color = DEFAULT_ACCENT


func _init(p_helmet: Color = DEFAULT_HELMET, p_suit: Color = DEFAULT_SUIT, p_accent: Color = DEFAULT_ACCENT) -> void:
	helmet = p_helmet
	suit = p_suit
	accent = p_accent


func duplicate_colors() -> SkinColors:
	return SkinColors.new(helmet, suit, accent)


func equals(other: SkinColors) -> bool:
	return other != null and helmet.is_equal_approx(other.helmet) \
		and suit.is_equal_approx(other.suit) and accent.is_equal_approx(other.accent)


# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение / сеть
# ─────────────────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"helmet": helmet.to_html(false),
		"suit": suit.to_html(false),
		"accent": accent.to_html(false),
	}


## Пустой/битый словарь = null (оригинальные цвета). Никогда не падает на чужих данных.
static func from_dict(data: Variant) -> SkinColors:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var d: Dictionary = data
	return SkinColors.new(
		_parse(d.get("helmet"), DEFAULT_HELMET),
		_parse(d.get("suit"), DEFAULT_SUIT),
		_parse(d.get("accent"), DEFAULT_ACCENT))


static func _parse(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


# ─────────────────────────────────────────────────────────────────────────────
#  Оттенки из одного цвета
# ─────────────────────────────────────────────────────────────────────────────

## Рамп детали из одного цвета: [основной, тень, глубокая, подкладка, тёмная подкладка].
## Формулу подбирал по твоим ручным синему и красному скинам: тень ≈ 0.7·V, глубокая ≈ 0.5·V
## с небольшим сдвигом оттенка в «холодную» сторону (так рисуется пиксель-арт).
static func ramp_for(base: Color) -> Array[Color]:
	var h := base.h
	var s := base.s
	var v := base.v
	return [
		base,
		Color.from_hsv(fposmod(h - 0.012, 1.0), s, maxf(v * 0.72, 0.10)),
		Color.from_hsv(fposmod(h - 0.020, 1.0), minf(s * 1.05, 1.0), maxf(v * 0.50, 0.07)),
		Color.from_hsv(h, minf(s * 0.50, 0.50), 0.22),
		Color.from_hsv(h, minf(s * 0.50, 0.50), 0.11),
	]


## Акцент: светлый и тёмный оттенки (у художественного золота: -10° оттенка, насыщеннее).
static func accent_ramp_for(base: Color) -> Array[Color]:
	return [
		base,
		Color.from_hsv(fposmod(base.h - 0.028, 1.0), minf(base.s * 1.18, 1.0), base.v * 0.97),
	]


## Ключи и цели в одном порядке (для шейдера).
static func all_keys() -> PackedColorArray:
	var out := PackedColorArray()
	out.append_array(KEY_RAMP)
	out.append_array(KEY_DARK)
	out.append_array(KEY_ACCENT)
	return out


func targets_for(part_color: Color) -> PackedColorArray:
	var ramp := ramp_for(part_color)
	var acc := accent_ramp_for(accent)
	var out := PackedColorArray()
	out.append_array(ramp)  # 5: 3 ключа рампа + 2 ключа подкладки
	out.append_array(acc)
	return out


## Материал для шлема (is_helmet = true) или комбинезона.
func make_material(is_helmet: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scr/Systems/Skin/palette_swap.gdshader") as Shader
	apply_to_material(mat, is_helmet)
	return mat


func apply_to_material(mat: ShaderMaterial, is_helmet: bool) -> void:
	var keys := all_keys()
	mat.set_shader_parameter("keys", _padded(keys))
	mat.set_shader_parameter("targets", _padded(targets_for(helmet if is_helmet else suit)))
	mat.set_shader_parameter("key_count", keys.size())


## Массивы uniform в шейдере фиксированной длины (8).
static func _padded(colors: PackedColorArray) -> PackedColorArray:
	var out := colors.duplicate()
	while out.size() < 8:
		out.append(Color.BLACK)
	return out


# ─────────────────────────────────────────────────────────────────────────────
#  «Перекрашиваема ли эта текстура?»
# ─────────────────────────────────────────────────────────────────────────────

## Текстура перекрашиваема, если содержит хотя бы один пиксель основного шаблонного оттенка.
## Готовые цветные скины (синий, красный) – нет: цвет им ничего не даст, и интерфейс это знает.
static func is_colorable(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var id := tex.get_rid().get_id()
	if _colorable_cache.has(id):
		return _colorable_cache[id]
	var result := false
	var img := tex.get_image()
	if img != null and not img.is_empty() and not img.is_compressed():
		var key := KEY_RAMP[0]
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.is_equal_approx(key):
					result = true
					break
			if result:
				break
	_colorable_cache[id] = result
	return result
