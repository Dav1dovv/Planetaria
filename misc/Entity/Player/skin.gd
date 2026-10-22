extends Node2D
class_name PlayerSkin

@export var player_skins: Array[Texture]
@export var player_sprites: Array[Sprite2D]
@onready var head_sprites: Sprite2D = $Body/Head

var skin_index: int = 0
var head_inex:  int = 0  # опечатка сохранена намеренно — используется везде

## Цвета игрока (palette swap). null = оригинальные цвета текстур.
## Хранятся в материалах спрайтов, а не в текстурах: смена формы шлема/костюма цвет не сбрасывает.
var colors: SkinColors = null
signal colors_changed(new_colors: SkinColors)

var _helmet_material: ShaderMaterial
var _suit_material: ShaderMaterial
# Что было у спрайта до перекраски, чтобы вернуть как было: sprite -> use_parent_material
var _original_parent_material: Dictionary = {}

# Флаг: был ли скин уже задан извне (через мультиплеер)
# Если true — не перезаписываем из Global в _ready
var _skin_set_externally: bool = false

func _ready() -> void:
	# В мультиплеере скин придёт через apply_skin_rpc от сервера.
	# Для своего игрока берём из Global, для чужих — ждём RPC.
	var is_multiplayer_active = (
		multiplayer.multiplayer_peer != null and
		not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	)

	if is_multiplayer_active:
		# Определяем чей это скин по имени родительского узла (peer_id)
		var parent = get_parent()
		if parent and parent.name.is_valid_int():
			var peer_id = int(parent.name)
			if peer_id == multiplayer.get_unique_id():
				# Это наш игрок — берём скин из Global
				_load_local_look()
			# else: чужой игрок — не трогаем, ждём apply_skin_rpc от сервера
		else:
			# Имя не число — одиночная игра внутри мультиплеера, берём из Global
			_load_local_look()
	else:
		# Одиночная игра — как раньше
		print("head index: " + str(Global.player_skin_head_index) + "| Skin index: " + str(Global.player_skin_index))
		_load_local_look()


## Скин и цвета локального игрока: индексы из Global, цвета из SkinColors.current
## (их выставляет SaveLoad.load_save из мета-данных слота).
func _load_local_look() -> void:
	skin_index = Global.player_skin_index
	head_inex  = Global.player_skin_head_index
	colors = SkinColors.current.duplicate_colors() if SkinColors.current != null else null
	update_skin()


func update_skin() -> void:
	if player_skins.size() == 0:
		return
	skin_index = wrapi(skin_index, 0, player_skins.size())
	head_inex  = wrapi(head_inex,  0, player_skins.size())
	for sprite in player_sprites:
		sprite.texture = player_skins[skin_index]
	head_sprites.texture = player_skins[head_inex]
	_apply_colors()


## Задать цвета (null = вернуть оригинальные). Для чужих игроков зови с SkinColors.from_dict(...)
## после получения RPC.
func set_colors(new_colors: SkinColors) -> void:
	colors = new_colors
	_apply_colors()
	colors_changed.emit(colors)


## Навешивает палитру на спрайты. Перекрашиваются только те части, чья текстура «перекрашиваемая»
## (нарисована шаблонными цветами), готовые цветные скины остаются как нарисованы.
func _apply_colors() -> void:
	if head_sprites == null:
		return
	_paint(head_sprites, true)
	for node in find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite != head_sprites and player_skins.has(sprite.texture):
			_paint(sprite, false)


func _paint(sprite: Sprite2D, is_helmet: bool) -> void:
	if colors != null and SkinColors.is_colorable(sprite.texture):
		var mat: ShaderMaterial = _material_for(is_helmet)
		if not _original_parent_material.has(sprite):
			_original_parent_material[sprite] = sprite.use_parent_material
		sprite.use_parent_material = false
		sprite.material = mat
	elif _original_parent_material.has(sprite):
		# Раньше красили, а теперь нет (цвета сняты или выбран готовый цветной скин): возвращаем как было
		sprite.material = null
		sprite.use_parent_material = _original_parent_material[sprite]
		_original_parent_material.erase(sprite)


func _material_for(is_helmet: bool) -> ShaderMaterial:
	if is_helmet:
		if _helmet_material == null:
			_helmet_material = colors.make_material(true)
		else:
			colors.apply_to_material(_helmet_material, true)
		return _helmet_material
	if _suit_material == null:
		_suit_material = colors.make_material(false)
	else:
		colors.apply_to_material(_suit_material, false)
	return _suit_material


func _on_next_pressed() -> void:
	skin_index += 1
	update_skin()

func _on_previus_pressed() -> void:
	skin_index -= 1
	update_skin()

func _on_next_head_pressed() -> void:
	head_inex += 1
	update_skin()

func _on_previus_head_pressed() -> void:
	head_inex -= 1
	update_skin()

func randomSkin():
	randomize()
	skin_index = randi() % player_skins.size()
	randomize()
	head_inex = randi() % player_skins.size()
	update_skin()
	print("buttton pressed")
