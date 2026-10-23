# save_load_button.gd
## Карточка сохранения в виде пропуска члена экипажа («Crew ID»).
##
## Три режима (см. Mode):
##   SLOT    – настоящее сохранение. Клик = «сканер» и вход в игру,
##             маленький × / Del / Y = аннулировать пропуск (удалить сохранение).
##   EMPTY   – пустая карточка «Выписать пропуск». Обычная кнопка (сигнал pressed).
##   PREVIEW – живое превью на экране создания персонажа, не интерактивно.
##
## Карточка целиком собирается кодом, поэтому вся «косметика» (размеры, цвета,
## координаты) лежит в константах ниже. Сцена Save_load_Button.tscn – только корень со скриптом.
##
## Сигналы SLOT-режима:
##   activating  – сканирование началось (экран может приглушить остальные карточки)
##   activated   – сканирование закончилось, пора загружать сохранение
##   revoke_confirmed – игрок подтвердил удаление; слушатель удаляет данные слота
##   revoked     – штамп отыгран, карточка сейчас освободит себя (queue_free)
class_name CrewBadge
extends Button

signal activating(slot_name: String)
signal activated(slot_name: String)
signal revoke_confirmed(slot_name: String)
signal revoked(slot_name: String)

enum Mode { SLOT, EMPTY, PREVIEW }
enum State { IDLE, CONFIRMING, ACTIVATING, REVOKING }

# ─────────────────────────────────────────────────────────────────────────────
#  Размеры (в «игровых» пикселях; пропорции как у карточки CR80, 1.6 : 1)
# ─────────────────────────────────────────────────────────────────────────────
const CARD_SIZE := Vector2(112, 70)
const HEADROOM  := 4          ## запас над карточкой, куда она «подпрыгивает»
const LIFT      := 3          ## на сколько пикселей карточка поднимается при наведении
const REST_Y    := HEADROOM   ## положение карточки в покое

const PHOTO_RECT := Rect2(5, 15, 38, 38)
const COL_X      := 48.0      ## левый край правой колонки с текстом
const COL_W      := 59.0

# ─────────────────────────────────────────────────────────────────────────────
#  Палитра
# ─────────────────────────────────────────────────────────────────────────────
const C_CARD     := Color("12151e")
const C_EDGE     := Color("aab3c2")
const C_EDGE_HOT := Color("7fe9ee")
const C_INK_DARK := Color("0a1a20")
const C_INK_LIGHT := Color("f4f7fb")
const C_LABEL    := Color("7a869c")
const C_VALUE    := Color("eef2f8")
const C_ACCENT   := Color("7fe9ee")
const C_OK       := Color("6fd36a")
const C_DANGER   := Color("ff5360")

# ─────────────────────────────────────────────────────────────────────────────
#  Скины
#  ВАЖНО: порядок должен совпадать с PlayerSkin.player_skins в сцене игрока.
# ─────────────────────────────────────────────────────────────────────────────
const SKIN_PATHS: Array[String] = [
	"res://misc/Entity/Player/Textures/Skin.png"
]
## Где на листе скина лежат шлем и комбинезон (тот же лист, что у PlayerSkin)
const SRC_HEAD := Rect2(8, 10, 16, 9)
const SRC_BODY := Rect2(8, 19, 16, 7)
const SRC_HELMET_SAMPLE := Rect2i(10, 11, 12, 8)
const PORTRAIT_SCALE := 2

const SHADER_BADGE := "res://scr/Systems/SaveLoadSlot/crew_badge.gdshader"
const SHADER_SEAL  := "res://scr/Systems/SaveLoadSlot/crew_seal.gdshader"

const SFX_HOVER   := "res://Assets/Audio/SFX/UI/Buttons/Button-01.mp3"
const SFX_ACCEPT  := "res://Assets/Audio/SFX/UI/Buttons/Button-02.mp3"
const SFX_DECLINE := "res://Assets/Audio/SFX/UI/Buttons/Button-03.mp3"

const ID_PREFIX := "SNM"

static var _skin_cache: Array[Texture2D] = []
static var _suit_cache: Dictionary = {}

var slot_name: String = ""

var _mode: Mode = Mode.SLOT
var _state: State = State.IDLE
var _hot: bool = false
var _locked: bool = false
var _face_built: bool = false

# данные карточки
var _name_text: String = ""
var _last_save: int = 0
var _playtime: int = 0
var _skin: int = 0
var _head: int = 0
var _colors: SkinColors = null   # цвета игрока (palette swap); null = оригинальные цвета скина

# узлы
var _shadow: Panel
var _body: Control
var _card: Panel
var _card_style: StyleBoxFlat
var _header: Panel
var _header_style: StyleBoxFlat
var _title: Label
var _led: ColorRect
var _portrait: _Portrait
var _barcode: _Barcode
var _seal: ColorRect
var _overlay: ColorRect
var _name_cap: Label
var _name_val: Label
var _id_val: Label
var _last_cap: Label
var _last_val: Label
var _play_cap: Label
var _play_val: Label
var _delete_btn: _DeleteTab
var _confirm: Control
var _confirm_title: Label
var _confirm_name: Label
var _btn_keep: Button
var _btn_revoke: Button
var _empty_face: _EmptyFace
var _empty_label: Label

var _move_tween: Tween
var _sheen_tween: Tween
var _fx_tween: Tween
var _dim_tween: Tween
var _deal_tween: Tween
var _dealing: bool = false
var _hole: Panel
var _stamp: Panel


# ─────────────────────────────────────────────────────────────────────────────
#  Конструктор: каркас (тень + тело). Лицо собирается в setup_*().
# ─────────────────────────────────────────────────────────────────────────────

func _init() -> void:
	custom_minimum_size = CARD_SIZE + Vector2(0, HEADROOM)
	# В сетке ячейки делят свободную ширину поровну, карточка стоит по центру своей ячейки
	size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	flat = true
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())

	_shadow = Panel.new()
	_shadow.position = Vector2(1, REST_Y + 2)
	_shadow.size = CARD_SIZE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 3))
	add_child(_shadow)

	_body = Control.new()
	_body.position = Vector2(0, REST_Y)
	_body.size = CARD_SIZE
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	pressed.connect(_on_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_update_hot)
	mouse_exited.connect(_update_hot)
	focus_entered.connect(_update_hot)
	focus_exited.connect(_update_hot)

	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _face_built:
		_refresh()


# ─────────────────────────────────────────────────────────────────────────────
#  Публичный API
# ─────────────────────────────────────────────────────────────────────────────

## Данные слота: player_name, slot_name, last_save_time, playtime_sec, skin_index, head_index.
## (Имя метода сохранено от старой кнопки, чтобы не ломать экран выбора.)
func setup_slot(save_data: Dictionary) -> void:
	_mode = Mode.SLOT
	slot_name   = str(save_data.get("slot_name", ""))
	_name_text  = str(save_data.get("player_name", slot_name))
	_last_save  = int(save_data.get("last_save_time", 0))
	_playtime   = int(save_data.get("playtime_sec", 0))
	_skin       = int(save_data.get("skin_index", 0))
	_head       = int(save_data.get("head_index", 0))
	_colors     = SkinColors.from_dict(save_data.get("colors"))
	_build_face()
	_refresh()


## Пустая карточка «Выписать пропуск».
func setup_empty() -> void:
	_mode = Mode.EMPTY
	_build_face()
	_refresh()


## Превью нового пропуска (экран создания персонажа).
func setup_preview(player_name: String, skin_index: int, head_index: int, colors: SkinColors = null) -> void:
	_mode = Mode.PREVIEW
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_face()
	set_preview(player_name, skin_index, head_index, colors)


func set_preview(player_name: String, skin_index: int, head_index: int, colors: SkinColors = null) -> void:
	_name_text = player_name.strip_edges()
	_skin = skin_index
	_head = head_index
	_colors = colors
	slot_name = ""
	_clear_stamp()
	_refresh()


func get_slot_name() -> String:
	return slot_name


## Карточка «сдаётся» на стол: выезжает снизу с задержкой. Для эффекта раздачи карт.
func play_deal(delay: float) -> void:
	_dealing = true
	_body.modulate.a = 0.0
	_body.position.y = REST_Y + 10
	_shadow.modulate.a = 0.0
	_kill(_move_tween)
	_kill(_deal_tween)
	_deal_tween = create_tween()
	_deal_tween.tween_interval(delay)
	_deal_tween.tween_property(_body, "modulate:a", 1.0, 0.12)
	_deal_tween.parallel().tween_property(_shadow, "modulate:a", 1.0, 0.2)
	_deal_tween.parallel().tween_property(_body, "position:y", float(REST_Y), 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deal_tween.tween_callback(_finish_deal)


func _finish_deal() -> void:
	_dealing = false
	# Если за время раздачи на карточку навели курсор/фокус – поднимаем её сейчас
	_move_body_to(_rest_y(), 0.10)


## Блик по карточке (новая карточка, выбранная карточка).
func flash() -> void:
	_play_sheen(0.55)


## Короткий «подскок» (например, при смене скина в превью).
func bump() -> void:
	_kill(_move_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position:y", float(_rest_y() - 3), 0.05)
	_move_tween.tween_property(_body, "position:y", float(_rest_y()), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play_sheen(0.4)


## Штамп поверх карточки. Возвращает ожидаемую длительность анимации.
func play_stamp(text: String, color: Color, angle_deg: float = -12.0) -> float:
	_show_stamp(text, color, angle_deg)
	return 0.5


## Заблокировать (приглушить и сделать нечувствительной) – пока другая карточка «сканируется».
func set_locked(value: bool) -> void:
	if _locked == value or _mode == Mode.PREVIEW:
		return
	_locked = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL
	_kill(_dim_tween)
	_dim_tween = create_tween()
	_dim_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.38 if value else 1.0), 0.15)
	if value:
		_apply_hot(false)


## Вернуть карточку в исходное состояние (например, если загрузка слота не удалась).
func reset_state() -> void:
	if _mode != Mode.SLOT:
		return
	_kill(_fx_tween)
	_state = State.IDLE
	_set_overlay("scan_strength", 0.0)
	_apply_theme_state(C_EDGE, _header_color(), _ink_for(_header_color()), C_ACCENT)
	_title.text = Loc.t("CREW ID")
	_hole.visible = true
	_title.size.x = 40
	_hot = false
	_body.position = Vector2(0, REST_Y)
	_update_hot()


func request_revoke() -> void:
	if _mode != Mode.SLOT or _state != State.IDLE or _locked:
		return
	_state = State.CONFIRMING
	_delete_btn.visible = false
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	create_tween().tween_property(_confirm, "modulate:a", 1.0, 0.08)
	_btn_keep.grab_focus()
	set_process_input(true)
	_sfx(SFX_DECLINE, 1.1, -8.0)


# ─────────────────────────────────────────────────────────────────────────────
#  Сборка «лица» карточки
# ─────────────────────────────────────────────────────────────────────────────

func _build_face() -> void:
	if _face_built:
		return
	_face_built = true

	_card_style = _flat(C_CARD, C_EDGE, 1, 3)
	_card = Panel.new()
	_card.size = CARD_SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_style)
	_body.add_child(_card)

	if _mode == Mode.EMPTY:
		_build_empty_face()
	else:
		_build_pass_face()

	# Блик/сканер поверх всего
	_overlay = ColorRect.new()
	_overlay.size = CARD_SIZE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _make_material(SHADER_BADGE)
	_body.add_child(_overlay)

	if _mode == Mode.SLOT:
		_build_delete_button()
		_build_confirm_layer()


func _build_pass_face() -> void:
	# Шапка (цвет подстраивается под комбинезон, см. _refresh)
	_header_style = _flat(C_ACCENT, Color.TRANSPARENT, 0, 0)
	_header_style.corner_radius_top_left = 2
	_header_style.corner_radius_top_right = 2
	_header = Panel.new()
	_header.position = Vector2(1, 1)
	_header.size = Vector2(CARD_SIZE.x - 2, 11)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_stylebox_override("panel", _header_style)
	_body.add_child(_header)

	_title = _make_label(_body, Vector2(5, 1), 40, 6, C_INK_DARK)
	_title.size.y = 11
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Прорезь для шнурка
	_hole = Panel.new()
	_hole.position = Vector2(48, 4)
	_hole.size = Vector2(16, 4)
	_hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hole.add_theme_stylebox_override("panel", _flat(Color("07090d"), Color(0, 0, 0, 0.35), 1, 1))
	_body.add_child(_hole)

	# «Живой» индикатор
	_led = ColorRect.new()
	_led.position = Vector2(CARD_SIZE.x - 9, 5)
	_led.size = Vector2(3, 3)
	_led.color = C_ACCENT
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_led)

	# Фото
	var frame := Panel.new()
	frame.position = PHOTO_RECT.position
	frame.size = PHOTO_RECT.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _flat(Color("0b1020"), C_EDGE, 1, 0))
	_body.add_child(frame)

	_portrait = _Portrait.new()
	_portrait.position = PHOTO_RECT.position + Vector2.ONE
	_portrait.size = PHOTO_RECT.size - Vector2(2, 2)
	_body.add_child(_portrait)

	_seal = ColorRect.new()
	_seal.size = Vector2(11, 11)
	_seal.position = PHOTO_RECT.end - Vector2(13, 13)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.material = _make_material(SHADER_SEAL)
	_body.add_child(_seal)

	# Чип и штрихкод
	var chip := _Chip.new()
	chip.position = Vector2(5, 57)
	chip.size = Vector2(12, 8)
	_body.add_child(chip)

	_barcode = _Barcode.new()
	_barcode.position = Vector2(21, 57)
	_barcode.size = Vector2(CARD_SIZE.x - 21 - 5, 8)
	_body.add_child(_barcode)

	# Правая колонка
	_name_cap = _make_label(_body, Vector2(COL_X, 14), COL_W, 5, C_LABEL)
	_name_val = _make_label(_body, Vector2(COL_X, 19), COL_W, 10, C_VALUE)
	_id_val   = _make_label(_body, Vector2(COL_X, 31), COL_W, 6, C_ACCENT)

	var divider := ColorRect.new()
	divider.position = Vector2(COL_X, 40)
	divider.size = Vector2(COL_W, 1)
	divider.color = Color(1, 1, 1, 0.12)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(divider)

	_last_cap = _make_label(_body, Vector2(COL_X, 42), 32, 5, C_LABEL)
	_last_val = _make_label(_body, Vector2(COL_X, 47), 32, 7, C_VALUE)
	_play_cap = _make_label(_body, Vector2(COL_X + 32, 42), COL_W - 32, 5, C_LABEL)
	_play_val = _make_label(_body, Vector2(COL_X + 32, 47), COL_W - 32, 7, C_VALUE)

	if _mode == Mode.SLOT:
		_start_led_blink()


func _build_empty_face() -> void:
	_empty_face = _EmptyFace.new()
	_empty_face.size = CARD_SIZE
	_body.add_child(_empty_face)

	_empty_label = _make_label(_body, Vector2(6, 42), CARD_SIZE.x - 12, 7, C_LABEL)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_delete_button() -> void:
	# Собственный маленький контрол вместо Button: тема проекта задаёт кнопкам большой минимальный размер
	_delete_btn = _DeleteTab.new()
	_delete_btn.position = Vector2(CARD_SIZE.x - 15, 2)
	_delete_btn.size = Vector2(12, 9)
	_delete_btn.visible = false
	_delete_btn.pressed.connect(request_revoke)
	_body.add_child(_delete_btn)


func _build_confirm_layer() -> void:
	_confirm = Control.new()
	_confirm.size = CARD_SIZE
	_confirm.visible = false
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(_confirm)

	var dim := Panel.new()
	dim.size = CARD_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_theme_stylebox_override("panel", _flat(Color(0.17, 0.03, 0.06, 1.0), C_DANGER, 1, 3))
	_confirm.add_child(dim)

	_confirm_title = _make_label(_confirm, Vector2(4, 9), CARD_SIZE.x - 8, 7, C_DANGER)
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_name = _make_label(_confirm, Vector2(4, 22), CARD_SIZE.x - 8, 10, C_VALUE)
	_confirm_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_btn_keep   = _make_confirm_button(Vector2(8, 46), C_EDGE, Color("1a1f2b"))
	_btn_revoke = _make_confirm_button(Vector2(58, 46), C_DANGER, Color("5a0f19"))
	_btn_keep.pressed.connect(_cancel_revoke)
	_btn_revoke.pressed.connect(_confirm_revoke)

	_btn_keep.focus_neighbor_right = _btn_keep.get_path_to(_btn_revoke)
	_btn_revoke.focus_neighbor_left = _btn_revoke.get_path_to(_btn_keep)
	_btn_keep.focus_neighbor_left = NodePath(".")
	_btn_revoke.focus_neighbor_right = NodePath(".")
	for b in [_btn_keep, _btn_revoke]:
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")


func _make_confirm_button(pos: Vector2, edge: Color, fill: Color) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(46, 14)
	b.add_theme_font_size_override("font_size", 6)
	b.add_theme_color_override("font_color", C_VALUE)
	b.add_theme_stylebox_override("normal", _flat(fill, edge.darkened(0.25), 1, 1))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.18), edge, 1, 1))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.2), edge, 1, 1))
	b.add_theme_stylebox_override("focus", _flat(Color.TRANSPARENT, Color.WHITE, 1, 1))
	_confirm.add_child(b)
	return b


# ─────────────────────────────────────────────────────────────────────────────
#  Наполнение данными
# ─────────────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _face_built:
		return
	if _mode == Mode.EMPTY:
		_fit(_empty_label, Loc.t("ISSUE NEW ID"), _empty_label.size.x, 7, 5)
		return

	var suit := _header_color()
	_portrait.set_look(get_skin(_head), get_skin(_skin), suit.darkened(0.72), _colors)
	if _state != State.ACTIVATING:
		_apply_theme_state(C_EDGE if not _hot else C_EDGE_HOT, suit, _ink_for(suit), C_ACCENT)
		_title.text = Loc.t("CREW ID")

	var key := _slot_key()
	_barcode.seed_value = key.hash()
	_barcode.queue_redraw()
	_id_val.text = "%s-%s" % [ID_PREFIX, ("%04d" % (key.hash() % 10000)) if not key.is_empty() else "XXXX"]

	_name_cap.text = Loc.t("NAME")
	if _name_text.is_empty():
		_fit(_name_val, Loc.t("CHARACTER  NAME"), COL_W, 8, 5)
		_name_val.add_theme_color_override("font_color", C_LABEL)
	else:
		_fit(_name_val, _name_text, COL_W, 10, 5)
		_name_val.add_theme_color_override("font_color", C_VALUE)

	_fit(_last_cap, Loc.t("LAST LOGIN"), _last_cap.size.x, 5, 4)
	_fit(_play_cap, Loc.t("FLIGHT"), _play_cap.size.x, 5, 4)
	_fit(_last_val, _format_date(_last_save), _last_val.size.x, 7, 5)
	_fit(_play_val, _format_playtime(_playtime), _play_val.size.x, 7, 4)

	if _mode == Mode.SLOT:
		_confirm_title.text = Loc.t("REVOKE ID?")
		_fit(_confirm_name, _name_text, CARD_SIZE.x - 12, 10, 6)
		_btn_keep.text = Loc.t("KEEP")
		_btn_revoke.text = Loc.t("REVOKE")


## Цвет шапки: костюм игрока, если он выбрал цвета, иначе основной цвет шлема скина.
func _header_color() -> Color:
	if _colors != null and SkinColors.is_colorable(get_skin(_skin)):
		# Почти чёрный костюм слился бы с фоном карточки: тогда шапка берёт цвет шлема
		return _colors.suit if _colors.suit.get_luminance() >= 0.06 else _colors.helmet
	return _suit_color(_head)


## Цвета «шапки» карточки: фон, текст, светодиод и рамка.
func _apply_theme_state(edge: Color, header: Color, ink: Color, led: Color) -> void:
	_card_style.border_color = edge
	_header_style.bg_color = header
	_title.add_theme_color_override("font_color", ink)
	_led.color = led


func _slot_key() -> String:
	if not slot_name.is_empty():
		return slot_name
	# Превью: считаем так же, как SaveSystem._safe_name(), чтобы ID совпал с будущим
	return _name_text.replace(" ", "_").replace("/", "").replace("\\", "")


# ─────────────────────────────────────────────────────────────────────────────
#  Ввод и состояния
# ─────────────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _mode != Mode.SLOT or _state != State.IDLE:
		return
	var wants_revoke := false
	if event is InputEventKey:
		wants_revoke = event.pressed and not event.echo and event.keycode == KEY_DELETE
	elif event is InputEventJoypadButton:
		wants_revoke = event.pressed and event.button_index == JOY_BUTTON_Y
	if wants_revoke:
		request_revoke()
		accept_event()


func _input(event: InputEvent) -> void:
	# Включается только пока открыто подтверждение: Esc = «оставить пропуск»
	if _state == State.CONFIRMING and Global.is_escape_event(event):
		get_viewport().set_input_as_handled()
		Global.mark_menu_closed()
		_cancel_revoke()


func _on_pressed() -> void:
	if _mode == Mode.SLOT:
		if _state == State.IDLE and not _locked:
			_begin_activate()
	elif _mode == Mode.EMPTY:
		_sfx(SFX_ACCEPT, 1.28)
		bump()


func _on_button_down() -> void:
	if _mode == Mode.PREVIEW or _state != State.IDLE:
		return
	_move_body_to(REST_Y + 1, 0.04)


func _on_button_up() -> void:
	if _mode == Mode.PREVIEW or _state != State.IDLE:
		return
	_move_body_to(REST_Y - LIFT if _hot else REST_Y, 0.08)


func _update_hot() -> void:
	if _mode == Mode.PREVIEW or _locked or not is_inside_tree():
		return
	# mouse_exited приходит и когда курсор заходит на дочернюю кнопку «×»,
	# поэтому проверяем прямоугольник сами.
	var inside := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	_apply_hot(has_focus() or inside)


func _apply_hot(value: bool) -> void:
	if _hot == value or _state != State.IDLE:
		return
	_hot = value
	_move_body_to(REST_Y - LIFT if value else REST_Y, 0.10 if value else 0.14)
	_card_style.border_color = C_EDGE_HOT if value else C_EDGE
	if _mode == Mode.EMPTY:
		_empty_face.hot = value
		_empty_face.queue_redraw()
		_empty_label.add_theme_color_override("font_color", C_ACCENT if value else C_LABEL)
	else:
		(_seal.material as ShaderMaterial).set_shader_parameter("hot", 1.0 if value else 0.0)
	if _delete_btn != null:
		var show_delete := value or InputHints.is_touch()
		_delete_btn.visible = show_delete
		_led.visible = not show_delete
	if value:
		_play_sheen(0.5)
		_sfx(SFX_HOVER, 1.0, -6.0)


# ─────────────────────────────────────────────────────────────────────────────
#  Вход: «сканирование пропуска»
# ─────────────────────────────────────────────────────────────────────────────

func _begin_activate() -> void:
	_state = State.ACTIVATING
	activating.emit(slot_name)
	_sfx(SFX_ACCEPT, 1.28)
	if _delete_btn != null:
		_delete_btn.visible = false
	_led.visible = true

	_kill(_fx_tween)
	_kill(_move_tween)
	_fx_tween = create_tween()
	_fx_tween.tween_property(_body, "position:y", float(REST_Y + 2), 0.05)
	_fx_tween.tween_callback(_set_overlay.bind("scan_strength", 1.0))
	_fx_tween.tween_method(_set_scan, -0.15, 1.15, 0.36)
	_fx_tween.parallel().tween_callback(_show_granted).set_delay(0.16)
	_fx_tween.tween_interval(0.18)
	_fx_tween.tween_callback(func() -> void: activated.emit(slot_name))


func _show_granted() -> void:
	_apply_theme_state(C_OK, C_OK, C_INK_DARK, Color.WHITE)
	_hole.visible = false
	_title.size.x = CARD_SIZE.x - 30
	_fit(_title, Loc.t("ACCESS GRANTED"), CARD_SIZE.x - 30, 6, 4)
	_sfx(SFX_ACCEPT, 1.7)


func _set_scan(value: float) -> void:
	_set_overlay("scan", value)


func _set_overlay(param: String, value: float) -> void:
	(_overlay.material as ShaderMaterial).set_shader_parameter(param, value)


func _play_sheen(duration: float) -> void:
	if _overlay == null:
		return
	_kill(_sheen_tween)
	_sheen_tween = create_tween()
	_sheen_tween.tween_method(func(v: float) -> void: _set_overlay("sheen", v), -0.25, 1.3, duration)


# ─────────────────────────────────────────────────────────────────────────────
#  Аннулирование: подтверждение и штамп
# ─────────────────────────────────────────────────────────────────────────────

func _cancel_revoke() -> void:
	_confirm.visible = false
	_state = State.IDLE
	set_process_input(false)
	# Сбрасываем визуал «наведения», затем возвращаем его, если карточка всё ещё в фокусе/под курсором
	_hot = true
	_apply_hot(false)
	grab_focus()
	_update_hot()


func _confirm_revoke() -> void:
	_state = State.REVOKING
	set_process_input(false)
	_confirm.visible = false
	_hot = false
	_delete_btn.visible = false
	_led.visible = false
	_kill(_move_tween)
	revoke_confirmed.emit(slot_name)
	_sfx(SFX_DECLINE, 0.64)
	_show_stamp(Loc.t("REVOKED"), C_DANGER, -12.0)

	_fx_tween = create_tween()
	_fx_tween.tween_interval(0.16)
	for dx in [-2.0, 2.0, -1.0, 1.0, 0.0]:
		_fx_tween.tween_property(_body, "position:x", dx, 0.035)
	_fx_tween.tween_interval(0.25)
	_fx_tween.tween_property(_body, "position:y", float(REST_Y + 16), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fx_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.28)
	_fx_tween.tween_callback(_finish_revoke)


func _finish_revoke() -> void:
	revoked.emit(slot_name)
	queue_free()


func _clear_stamp() -> void:
	if _stamp != null and is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null


func _show_stamp(text: String, color: Color, angle_deg: float) -> void:
	_clear_stamp()
	var stamp := Panel.new()
	_stamp = stamp
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_theme_stylebox_override("panel", _flat(Color(color, 0.14), color, 1, 1))
	_body.add_child(stamp) # сначала в дерево: шрифт темы известен только там
	var label := _make_label(stamp, Vector2(3, 1), 90, 9, color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	label.text = text
	var font := label.get_theme_font("font")
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	label.size = Vector2(text_w + 2, 12)
	stamp.size = Vector2(text_w + 8, 14)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.position = (CARD_SIZE - stamp.size) / 2.0 + Vector2(0, 3)
	stamp.rotation = deg_to_rad(angle_deg)
	stamp.scale = Vector2(2.6, 2.6)
	stamp.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(stamp, "modulate:a", 1.0, 0.08)


# ─────────────────────────────────────────────────────────────────────────────
#  Утилиты
# ─────────────────────────────────────────────────────────────────────────────

func _rest_y() -> int:
	return REST_Y - LIFT if _hot else REST_Y


func _move_body_to(y: float, duration: float) -> void:
	if _dealing:
		return
	_kill(_move_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position:y", y, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_led_blink() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_led, "modulate:a", 0.25, 0.9)
	tw.tween_property(_led, "modulate:a", 1.0, 0.9)


func _sfx(path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not is_inside_tree() or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.pitch_scale = pitch
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


static func _flat(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	return sb


static func _make_material(shader_path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists(shader_path):
		mat.shader = load(shader_path) as Shader
	return mat


static func _make_label(parent: Control, pos: Vector2, width: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(width, font_size + 4)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 0)
	parent.add_child(label)
	return label


## Подбирает размер шрифта так, чтобы строка влезла по ширине.
func _fit(label: Label, text: String, max_width: float, max_size: int, min_size: int) -> void:
	label.text = text
	var font := label.get_theme_font("font")
	var font_size := max_size
	while font_size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


static func _ink_for(bg: Color) -> Color:
	return C_INK_DARK if bg.get_luminance() > 0.38 else C_INK_LIGHT


## dd.mm.yy в ЛОКАЛЬНОМ времени игрока (get_datetime_dict_from_unix_time отдаёт UTC).
static func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "—"
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	return "%02d.%02d.%02d" % [d.day, d.month, d.year % 100]


static func _format_playtime(seconds: int) -> String:
	return Loc.t("%dh %02dm") % [floori(seconds / 3600.0), floori((seconds % 3600) / 60.0)]


# ─────────────────────────────────────────────────────────────────────────────
#  Скины (статические: общие для всех карточек)
# ─────────────────────────────────────────────────────────────────────────────

static func skin_count() -> int:
	return SKIN_PATHS.size()


static func get_skin(index: int) -> Texture2D:
	if _skin_cache.is_empty():
		for path in SKIN_PATHS:
			_skin_cache.append((load(path) as Texture2D) if ResourceLoader.exists(path) else null)
	return _skin_cache[wrapi(index, 0, _skin_cache.size())]


## Основной цвет шлема скина: красит шапку карточки, чтобы экипаж различался с первого взгляда.
static func _suit_color(skin_index: int) -> Color:
	var idx := wrapi(skin_index, 0, SKIN_PATHS.size())
	if _suit_cache.has(idx):
		return _suit_cache[idx] as Color
	var result := C_ACCENT
	var tex := get_skin(idx)
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty() and not img.is_compressed():
			var counts: Dictionary = {}
			var best := 0
			for y in range(SRC_HELMET_SAMPLE.position.y, SRC_HELMET_SAMPLE.end.y):
				for x in range(SRC_HELMET_SAMPLE.position.x, SRC_HELMET_SAMPLE.end.x):
					var c := img.get_pixel(x, y)
					if c.a < 0.5:
						continue
					var n: int = counts.get(c, 0) + 1
					counts[c] = n
					if n > best:
						best = n
						result = c
	_suit_cache[idx] = result
	return result


# ─────────────────────────────────────────────────────────────────────────────
#  Внутренние «рисовалки»
# ─────────────────────────────────────────────────────────────────────────────

## Портрет: шлем из одной текстуры, комбинезон из другой – как собирает PlayerSkin.
## Шлем и костюм – разные слои, потому что у них разные палитры (разные материалы).
class _Portrait extends Control:
	var backdrop: Color = Color("101a2e")
	var _head: _Layer
	var _body: _Layer
	var _scan: _Scan
	var _helmet_mat: ShaderMaterial
	var _suit_mat: ShaderMaterial

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		_body = _Layer.new()
		_head = _Layer.new()
		_scan = _Scan.new()
		_head.src = CrewBadge.SRC_HEAD
		_body.src = CrewBadge.SRC_BODY
		add_child(_body)
		add_child(_head)
		add_child(_scan)

	func set_look(head_tex: Texture2D, body_tex: Texture2D, back: Color, colors: SkinColors) -> void:
		backdrop = back
		_head.tex = head_tex
		_body.tex = body_tex
		_head.material = _material_for(true, head_tex, colors)
		_body.material = _material_for(false, body_tex, colors)
		_layout()
		queue_redraw()
		_head.queue_redraw()
		_body.queue_redraw()

	func _material_for(is_helmet: bool, tex: Texture2D, colors: SkinColors) -> ShaderMaterial:
		# Готовые цветные скины не перекрашиваем: цвета в них нарисованы руками
		if colors == null or not SkinColors.is_colorable(tex):
			return null
		var mat: ShaderMaterial = _helmet_mat if is_helmet else _suit_mat
		if mat == null:
			mat = colors.make_material(is_helmet)
			if is_helmet:
				_helmet_mat = mat
			else:
				_suit_mat = mat
		else:
			colors.apply_to_material(mat, is_helmet)
		return mat

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout()

	func _layout() -> void:
		var s := CrewBadge.PORTRAIT_SCALE
		var head_size := CrewBadge.SRC_HEAD.size * s
		var body_size := CrewBadge.SRC_BODY.size * s
		var origin := ((size - head_size - Vector2(0, body_size.y)) / 2.0).floor()
		_head.position = origin
		_head.size = head_size
		_body.position = origin + Vector2(0, head_size.y)
		_body.size = body_size
		_scan.size = size

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), backdrop)
		draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), backdrop.darkened(0.25))


## Один слой портрета: кусок листа скина.
class _Layer extends Control:
	var tex: Texture2D
	var src: Rect2

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if tex != null:
			draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src)


## Строчная развёртка поверх портрета, как у экрана камеры/сканера.
class _Scan extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.16))
			y += 2.0


## Штрихкод из хеша имени слота: у каждого экипажа свой.
class _Barcode extends Control:
	var seed_value: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var x := 0.0
		var bar_on := true
		while x < size.x:
			var w := float(rng.randi_range(1, 2))
			w = minf(w, size.x - x)
			if bar_on:
				draw_rect(Rect2(x, 0, w, size.y), Color(0.78, 0.82, 0.9, 0.85))
			x += w
			bar_on = not bar_on


## Золотой чип, как на банковских картах.
class _Chip extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gold := Color("d9b24f")
		var dark := Color("8a6a22")
		draw_rect(Rect2(Vector2.ZERO, size), gold)
		draw_rect(Rect2(0, 0, size.x, 1), gold.lightened(0.3))
		draw_rect(Rect2(size.x * 0.5 - 0.5, 0, 1, size.y), dark)
		draw_rect(Rect2(0, size.y * 0.5 - 0.5, size.x, 1), dark)
		draw_rect(Rect2(3, 2, size.x - 6, size.y - 4), Color(dark, 0.35), false, 1.0)


## Пустая карточка: пунктирная рамка и плюс.
class _EmptyFace extends Control:
	var hot: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(CrewBadge.C_ACCENT, 0.95) if hot else Color(CrewBadge.C_LABEL, 0.75)
		if hot:
			draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Color(CrewBadge.C_ACCENT, 0.07))
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		_dashed(r.position, Vector2(r.end.x, r.position.y), col)
		_dashed(Vector2(r.position.x, r.end.y), r.end, col)
		_dashed(r.position, Vector2(r.position.x, r.end.y), col)
		_dashed(Vector2(r.end.x, r.position.y), r.end, col)
		var c := Vector2(size.x / 2.0, 26)
		var arm := 7.0 if hot else 6.0
		draw_rect(Rect2(c.x - arm, c.y - 1, arm * 2.0, 2), col)
		draw_rect(Rect2(c.x - 1, c.y - arm, 2, arm * 2.0), col)

	func _dashed(from: Vector2, to: Vector2, col: Color) -> void:
		var dir := (to - from)
		var length := dir.length()
		dir = dir.normalized()
		var t := 0.0
		while t < length:
			draw_line(from + dir * t, from + dir * minf(t + 4.0, length), col, 1.0)
			t += 7.0


## Крошечная кнопка «×» в углу шапки. Не Button, чтобы тема проекта не раздувала её.
class _DeleteTab extends Control:
	signal pressed

	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _set_hover(value: bool) -> void:
		_hover = value
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var danger := CrewBadge.C_DANGER
		var fill := danger.darkened(0.1) if _hover else Color(0.35, 0.06, 0.1, 0.95)
		var edge := Color.WHITE if _hover else danger.darkened(0.3)
		draw_rect(Rect2(Vector2.ZERO, size), edge)
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), fill)
		# «×» 5×5 пикселей
		var c := (size / 2.0).floor()
		var ink := Color.WHITE if _hover else Color("ffd5d9")
		for i in range(-2, 3):
			for d in [Vector2(i, i), Vector2(i, -i)]:
				draw_rect(Rect2(c + d, Vector2(1, 1)), ink)
